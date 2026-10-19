local type, pairs, str_match = type, pairs, string.match

local Gladdy = LibStub("Gladdy")
local AceSerializer = LibStub("AceSerializer-3.0")
local L = Gladdy.L
local AceGUI = LibStub("AceGUI-3.0")
local LibDeflate = LibStub:GetLibrary("LibDeflate")

local function table_copy(t, str)
    local t2 = {};
    if str == nil then
        str = "Gladdy.db"
    end
    for k,v in pairs(t) do
        if type(v) == "table" then
            t2[k] = table_copy(v, str .. "." .. k);
        else

            t2[k] = v;
        end
    end
    return t2;
end

local ExportImport = Gladdy:NewModule("Export Import", nil, {
    expansion = Gladdy.expansion,
})

do
    local floor, byte = math.floor, string.byte
    local lengthBase = {3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258}
    local lengthBits = {0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0}
    local distanceBase = {1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577}
    local distanceBits = {0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13}
    local codeOrder = {16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15}

    local function tree(lengths, size, complete)
        local counts, symbols, offsets = {}, {}, {}
        local used, longest = 0, 0
        for n = 0, 15 do counts[n] = 0 end
        for n = 0, size - 1 do
            local len = lengths[n] or 0
            if len < 0 or len > 15 then return end
            counts[len] = counts[len] + 1
            if len > 0 then used = used + 1; longest = math.max(longest, len) end
        end
        local left = 1
        for n = 1, 15 do
            left = left * 2 - counts[n]
            if left < 0 then return end
        end
        if left > 0 and (complete or (used > 0 and (used ~= 1 or longest ~= 1))) then return end
        offsets[1] = 1
        for n = 1, 14 do offsets[n + 1] = offsets[n] + counts[n] end
        for n = 0, size - 1 do
            local len = lengths[n] or 0
            if len > 0 then
                symbols[offsets[len]] = n
                offsets[len] = offsets[len] + 1
            end
        end
        return {counts = counts, symbols = symbols}
    end

    local fixedLengths, fixedDistances = {}, {}
    for n = 0, 287 do fixedLengths[n] = n <= 143 and 8 or n <= 255 and 9 or n <= 279 and 7 or 8 end
    for n = 0, 31 do fixedDistances[n] = 5 end
    local fixedLiteralTree, fixedDistanceTree = tree(fixedLengths, 288), tree(fixedDistances, 32)

    function Gladdy:ValidateZlibSize(str, limit)
        if type(str) ~= "string" or type(limit) ~= "number" or limit < 0 or limit ~= limit or limit == math.huge then
            return nil, "Invalid compressed profile size limit"
        end
        local cmf, flags = byte(str, 1, 2)
        if not flags or cmf % 16 ~= 8 or floor(cmf / 16) > 7 or (cmf * 256 + flags) % 31 ~= 0
            or floor(flags / 32) % 2 ~= 0 then return nil, "Invalid compressed profile header" end
        local pos, last, buffer, available, failed, total = 3, #str - 4, 0, 0, false, 0
        local window = 2 ^ (floor(cmf / 16) + 8)
        local function bits(count)
            while available < count do
                if pos > last then failed = true; return 0 end
                buffer = buffer + byte(str, pos) * 2 ^ available
                available, pos = available + 8, pos + 1
            end
            local value = buffer % 2 ^ count
            buffer, available = floor(buffer / 2 ^ count), available - count
            return value
        end
        local function symbol(codes)
            if not codes then failed = true; return 0 end
            local code, first, index = 0, 0, 1
            for len = 1, 15 do
                code = code + bits(1)
                if failed then return 0 end
                local count = codes.counts[len]
                if code < first + count then return codes.symbols[index + code - first] end
                index = index + count
                first, code = (first + count) * 2, code * 2
            end
            failed = true
            return 0
        end
        local final = 0
        repeat
            final = bits(1)
            local kind = bits(2)
            if failed then return nil, "Truncated compressed profile" end
            if kind == 0 then
                bits(available % 8)
                local size, complement = bits(16), bits(16)
                if failed or size + complement ~= 65535 or pos + size - 1 > last then
                    return nil, "Invalid uncompressed profile block"
                end
                total, pos = total + size, pos + size
            elseif kind == 1 or kind == 2 then
                local literals, distances = fixedLiteralTree, fixedDistanceTree
                if kind == 2 then
                    local literalCount, distanceCount, codeCount = bits(5) + 257, bits(5) + 1, bits(4) + 4
                    if failed or literalCount > 286 then return nil, "Invalid compressed profile tree" end
                    local codeLengths = {}
                    for n = 1, codeCount do codeLengths[codeOrder[n]] = bits(3) end
                    local codeTree = tree(codeLengths, 19, true)
                    local lengths, index, count = {}, 0, literalCount + distanceCount
                    while index < count and not failed do
                        local value = symbol(codeTree)
                        if value < 16 then
                            lengths[index], index = value, index + 1
                        else
                            local repeatCount, previous
                            if value == 16 then
                                if index == 0 then failed = true; break end
                                repeatCount, previous = bits(2) + 3, lengths[index - 1]
                            elseif value == 17 then repeatCount, previous = bits(3) + 3, 0
                            else repeatCount, previous = bits(7) + 11, 0 end
                            if index + repeatCount > count then failed = true; break end
                            for n = 1, repeatCount do lengths[index], index = previous, index + 1 end
                        end
                    end
                    if failed or not lengths[256] or lengths[256] == 0 then
                        return nil, "Invalid compressed profile code lengths"
                    end
                    local distanceLengths = {}
                    for n = 0, distanceCount - 1 do distanceLengths[n] = lengths[literalCount + n] end
                    literals, distances = tree(lengths, literalCount), tree(distanceLengths, distanceCount)
                end
                local value
                repeat
                    value = symbol(literals)
                    if failed then return nil, "Invalid compressed profile symbol" end
                    if value < 256 then
                        total = total + 1
                    elseif value > 256 then
                        local index = value - 256
                        if not lengthBase[index] then return nil, "Invalid compressed profile length" end
                        local size = lengthBase[index] + bits(lengthBits[index])
                        local distanceCode = symbol(distances) + 1
                        if failed or not distanceBase[distanceCode] then return nil, "Invalid compressed profile distance" end
                        local distance = distanceBase[distanceCode] + bits(distanceBits[distanceCode])
                        if failed or distance > total or distance > window then return nil, "Invalid compressed profile backreference" end
                        total = total + size
                    end
                    if total > limit then return nil, "Serialized profile size limit exceeded" end
                until value == 256
            else
                return nil, "Reserved compressed profile block"
            end
            if total > limit then return nil, "Serialized profile size limit exceeded" end
        until final == 1
        if failed or pos ~= last + 1 then return nil, "Invalid compressed profile boundary" end
        return total
    end
end
local ValidateZlibSize = Gladdy.ValidateZlibSize

local export, import

local function GetExportWindow()
    if export then return export end
    export = AceGUI:Create("Frame")
    export:SetWidth(550)
    export.sizer_se:Hide()
    export:SetStatusText("")
    export:SetLayout("Flow")
    export:SetTitle("Export")
    export:Hide()
    local exportEditBox = AceGUI:Create("MultiLineEditBox")
    exportEditBox:SetLabel('ExportString')
    exportEditBox:SetNumLines(29)
    exportEditBox:SetText("")
    exportEditBox:SetWidth(500)
    exportEditBox.button:Hide()
    export:AddChild(exportEditBox)
    export.eb = exportEditBox
    return export
end

local function GetImportWindow()
    if import then return import end
    import = AceGUI:Create("Frame")
    import:SetWidth(550)
    import:Hide()
    import:SetLayout("Flow")
    import.sizer_se:Hide()
    import:SetStatusText("")
    import:SetTitle("Import")
    import:SetCallback("OnClose", function(widget)
        import.eb:SetCallback("OnTextChanged", nil)
        import.deserializedTable = nil
    end)
    local importEditBox = AceGUI:Create("MultiLineEditBox")
    importEditBox:SetLabel('ImportString')
    importEditBox:SetNumLines(23)
    importEditBox:SetText("")
    importEditBox:SetWidth(500)
    importEditBox.button:Hide()
    import:AddChild(importEditBox)
    import.eb = importEditBox
    local importButton = AceGUI:Create("Button")
    importButton:SetText("Import\n(this will overwrite your current profile!)")
    importButton:SetWidth(200)
    importButton:SetHeight(50)
    importButton:SetCallback("OnClick", function(widget)
        local ok, err = ExportImport:ApplyImport(import.deserializedTable, Gladdy.db)
        if not ok then
            import.deserializedTable = nil
            import.button:SetDisabled(true)
            import:SetStatusText(err)
            import.statustext:SetTextColor(1,0,0)
            return
        end
        import:Hide()
        Gladdy:Reset()
        Gladdy:HideFrame()
        Gladdy:ToggleFrame(3)
        LibStub("AceConfigRegistry-3.0"):NotifyChange("Gladdy")
    end)
    import:AddChild(importButton)
    import.button = importButton
    local importClearButton = AceGUI:Create("Button")
    importClearButton:SetText("Clear")
    importClearButton:SetWidth(200)
    importClearButton:SetCallback("OnClick", function(widget)
        import.deserializedTable = nil
        import.eb:SetText("")
        import.eb:SetFocus()
        import.button:SetDisabled(true)
        import:SetStatusText("Invalid Import String")
        import.statustext:SetTextColor(1,0,0)
    end)
    import:AddChild(importClearButton)
    import.clearButton = importClearButton
    return import
end

local deletedOptions = {
    repentance = true,
    sleep = true,
    impconc = true,
    dragonsbreath = true,
    freezetrap = true,
    castBarPos = true,
    buffsCooldownPos = true,
    buffsBuffsCooldownPos = true,
    classIconPos = true,
    ciAnchor = true,
    ciPos = true,
    cooldownYPos = true,
    cooldownXPos = true,
    drCooldownPos = true,
    racialAnchor = true,
    racialPos = true,
    trinketPos = true,
    padding = true,
    growUp = true,
    powerBarFontSize = true,
    ["38373"] = true,
    ["34692"] = true,
}

local expansionSpecific = {
    "drCategories",
    "auraListDefault",
    "auraListInterrupts",
    "trackedDebuffs",
    "trackedBuffs",
    "cooldownCooldowns",
    "cooldownCooldownsOrder",
}

local limits = { encoded = 524288, serialized = 2097152, depth = 32, entries = 50000, tokens = 120000 }
ExportImport.IMPORT_LIMITS = limits

local function FiniteNumber(value)
    return value == value and value > -math.huge and value < math.huge
end

local function TextureTypeCompatible(path, key, expected, value)
    local texture = path == "Gladdy.db" and key == "trinketIcon"
        or key == "icon" and path:match("^Gladdy%.db%.drCategories%.[^.]+$")
    if not texture then return false end
    local a, b = type(expected), type(value)
    if a ~= "string" and a ~= "number" then return false end
    return b == "string" or b == "number" and value > 0 and value % 1 == 0
end

local function ValidateTree(tbl, refTbl, depth, state, path)
    if depth > limits.depth then return false, "Profile nesting limit exceeded" end
    if state.seen[tbl] then return false, "Cyclic profile table" end
    state.seen[tbl] = true
    for key, value in pairs(tbl) do
        state.entries = state.entries + 1
        if state.entries > limits.entries then return false, "Profile entry limit exceeded" end
        local keyType, valueType = type(key), type(value)
        if keyType ~= "string" and (keyType ~= "number" or not FiniteNumber(key)) then
            return false, "Invalid profile key at " .. path
        end
        state.bytes = (state.bytes or 0) + (keyType == "string" and #key or 8) + (valueType == "string" and #value or 8)
        if state.bytes > limits.serialized then return false, "Profile data size limit exceeded" end
        local field = path .. "." .. tostring(key)
        if valueType ~= "table" and valueType ~= "string" and valueType ~= "boolean" and valueType ~= "number" then
            return false, "Invalid profile value at " .. field
        end
        if valueType == "number" and not FiniteNumber(value) then return false, "Invalid number at " .. field end
        local expected = refTbl and refTbl[key]
        if expected ~= nil and type(expected) ~= valueType and not deletedOptions[tostring(key)]
            and not TextureTypeCompatible(path, key, expected, value) then
            return false, field .. " type error. Expected " .. type(expected) .. " found " .. valueType
        end
        if valueType == "table" then
            local ok, err = ValidateTree(value, type(expected) == "table" and expected or nil, depth + 1, state, field)
            if not ok then return false, err end
        end
    end
    state.seen[tbl] = nil
    return true
end

function ExportImport:CheckDeserializedOptions(tbl, refTbl, str)
    if type(tbl) ~= "table" then return false, "Profile root must be a table" end
    if tbl.expansion ~= nil and type(tbl.expansion) ~= "string" then return false, "Invalid profile expansion" end
    if not str then
        local version = tbl.version_major_num
        if type(version) ~= "number" or not FiniteNumber(version) or version < 1 or version % 1 ~= 0 then
            return false, "Invalid or missing profile version"
        end
        if version > Gladdy.version_major_num then return false, "Profile version is newer than Gladdy" end
    end
    if type(refTbl) ~= "table" then return false, "Profile defaults are unavailable" end
    return ValidateTree(tbl, refTbl, 1, {seen = {}, entries = 0}, str or "Gladdy.db")
end

local function ValidateSerialized(str)
    if #str > limits.serialized then return false, "Serialized profile size limit exceeded" end
    str = str:gsub("[%c ]", "")
    if str:sub(1,4) ~= "^1^T" or str:sub(-2) ~= "^^" then return false, "Invalid serialized profile root" end
    local depth, tokens, closed, ended = 0, 0, false, false
    for ctl in str:sub(3):gmatch("%^(.)") do
        tokens = tokens + 1
        if tokens > limits.tokens then return false, "Serialized profile token limit exceeded" end
        if ended or (closed and ctl ~= "^") then return false, "Unexpected data after profile" end
        if ctl == "T" then
            depth = depth + 1
            if depth > limits.depth then return false, "Profile nesting limit exceeded" end
        elseif ctl == "t" then
            depth = depth - 1
            if depth < 0 then return false, "Invalid profile table boundary" end
            if depth == 0 then closed = true end
        elseif ctl == "^" then
            if not closed or depth ~= 0 then return false, "Invalid profile terminator" end
            ended = true
        end
    end
    if not closed or not ended then return false, "Incomplete serialized profile" end
    return true
end

local function ImportError(message, showError)
    if showError and import then
        import.deserializedTable = nil
        import.statustext:SetTextColor(1,0,0)
        import:SetStatusText(message)
        import.button:SetDisabled(true)
    end
    return nil, message
end

function ExportImport:GetOptions()
    return {
        headerProfileClassic = {
            type = "header",
            name = L["Profile Export Import"],
            order = 2,
        },
        export = {
            type = "execute",
            func = function()
                local db = table_copy(Gladdy.db)
                db.version_major_num = Gladdy.version_major_num
                local export = GetExportWindow()
                local dump = AceSerializer:Serialize(db)
                local compress_deflate = LibDeflate:CompressZlib(dump)
                local printable_compressed = LibDeflate:EncodeForPrint(compress_deflate)
                export.eb:SetText(printable_compressed)
                export:Show()
                export.eb:SetFocus()
                export.eb:HighlightText(0, export.eb.editBox:GetNumLetters())
                export:SetStatusText("Copy this string to share your configuration with others.")
            end,
            name = L["Export"],
            desc = L["Export your current profile to share with others or your various accounts."],
            order = 3,
        },
        import = {
            type = "execute",
            func = function()
                local import = GetImportWindow()
                import.deserializedTable = nil
                import.eb:SetText("")
                import:Show()
                import:SetStatusText("Invalid Import String")
                import.button:SetDisabled(true)
                import.statustext:SetTextColor(1,0,0)
                import.eb:SetFocus()
                import.eb:SetCallback("OnTextChanged", function(widget)
                    import.deserializedTable = nil
                    import.button:SetDisabled(true)
                    local deserialized = ExportImport:Decode(widget:GetText(), true)
                    if not deserialized then
                        return
                    end
                    import.statustext:SetTextColor(0,1,0)
                    import:SetStatusText("SUCCESS")
                    import.button:SetDisabled(false)
                    import.deserializedTable = deserialized
                end)
            end,
            name = L["Import"],
            desc = L["This will overwrite your current profile!"],
            order = 4,
        },
    }
end

local function ApplyTable(source, target, crossExpansion)
    for key, value in pairs(source) do
        local skip = key == "expansion" or key == "version_major_num" or deletedOptions[tostring(key)]
        if crossExpansion and Gladdy:contains(key, expansionSpecific) then skip = true end
        if not skip then
            if type(value) == "table" then
                if type(target[key]) == "table" then ApplyTable(value, target[key], false) end
            else
                target[key] = value
            end
        end
    end
end

function ExportImport:ApplyImport(tbl, target)
    if type(tbl) ~= "table" or type(target) ~= "table" then return false, "Invalid profile table" end
    local ok, err = ValidateTree(tbl, target, 1, {seen = {}, entries = 0}, "Gladdy.db")
    if not ok then return false, err end
    local expansion = tbl.expansion or "BCC"
    if not tbl.newLayout then target.newLayout = false end
    ApplyTable(tbl, target, expansion ~= target.expansion)
    return true
end

function ExportImport:Decode(str, showError)
    if type(str) ~= "string" or #str == 0 then return ImportError("Invalid import string", showError) end
    if #str > limits.encoded then return ImportError("Import string size limit exceeded", showError) end
    local ok, decoded = pcall(LibDeflate.DecodeForPrint, LibDeflate, str)
    if not ok or not decoded then return ImportError("Invalid import encoding", showError) end
    local checked, expected, sizeError = pcall(ValidateZlibSize, Gladdy, decoded, limits.serialized)
    if not checked then return ImportError("Profile size validation failed: " .. tostring(expected):sub(1, 300), showError) end
    if not expected then return ImportError(sizeError, showError) end
    local raw, remaining
    ok, raw, remaining = pcall(LibDeflate.DecompressZlib, LibDeflate, decoded)
    if not ok then return ImportError("Profile decompression failed: " .. tostring(raw):sub(1, 300), showError) end
    if not raw then return ImportError("Profile decompression failed (LibDeflate status: " .. tostring(remaining) .. ")", showError) end
    if type(raw) ~= "string" then return ImportError("Invalid decompressed profile type", showError) end
    if #raw ~= expected then return ImportError("Profile decompressed size mismatch: expected " .. expected .. ", got " .. #raw, showError) end
    if remaining and remaining ~= 0 then return ImportError("Unexpected trailing compressed profile data", showError) end
    local err
    ok, err = ValidateSerialized(raw)
    if not ok then return ImportError(err, showError) end
    local success, deserialized = AceSerializer:Deserialize(raw)
    if not success then return ImportError("Invalid serialized profile", showError) end
    ok, err = self:CheckDeserializedOptions(deserialized, Gladdy.defaults.profile)
    if not ok then return ImportError(err, showError) end
    deserialized.version_major_num = nil
    return deserialized
end
