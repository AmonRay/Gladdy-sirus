local Gladdy = LibStub("Gladdy")
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
