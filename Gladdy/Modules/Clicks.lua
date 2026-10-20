local tinsert = table.insert
local pairs = pairs
local ipairs = ipairs
local InCombatLockdown = InCombatLockdown
local tonumber = tonumber
local tostring = tostring

local GetBindingKey = GetBindingKey
local ClearOverrideBindings = ClearOverrideBindings
local SetOverrideBindingClick = SetOverrideBindingClick

local Gladdy = LibStub("Gladdy")
local L = Gladdy.L

local attributes = {
    { name = L["Target"], button = "1", modifier = "", action = "target", spell = "" },
    { name = L["Focus"], button = "2", modifier = "", action = "focus", spell = "" },
}
for i = 3, 10 do
    tinsert(attributes, { name = L["Action #%d"]:format(i), button = "", modifier = "", action = "disabled", spell = "" })
end
local Clicks = Gladdy:NewModule("Clicks", nil, {
    attributes = attributes,
})

function Clicks:UpdateLocalization()
    BINDING_HEADER_GLADDY = "Gladdy"
    BINDING_NAME_GLADDYBUTTON1_LEFT = L["Left Click Enemy 1"]
    BINDING_NAME_GLADDYBUTTON2_LEFT = L["Left Click Enemy 2"]
    BINDING_NAME_GLADDYBUTTON3_LEFT = L["Left Click Enemy 3"]
    BINDING_NAME_GLADDYBUTTON4_LEFT = L["Left Click Enemy 4"]
    BINDING_NAME_GLADDYBUTTON5_LEFT = L["Left Click Enemy 5"]

    BINDING_NAME_GLADDYBUTTON1_RIGHT = L["Right Click Enemy 1"]
    BINDING_NAME_GLADDYBUTTON2_RIGHT = L["Right Click Enemy 2"]
    BINDING_NAME_GLADDYBUTTON3_RIGHT = L["Right Click Enemy 3"]
    BINDING_NAME_GLADDYBUTTON4_RIGHT = L["Right Click Enemy 4"]
    BINDING_NAME_GLADDYBUTTON5_RIGHT = L["Right Click Enemy 5"]

    BINDING_NAME_GLADDYBUTTON1_MIDDLE = L["Middle Click Enemy 1"]
    BINDING_NAME_GLADDYBUTTON2_MIDDLE = L["Middle Click Enemy 2"]
    BINDING_NAME_GLADDYBUTTON3_MIDDLE = L["Middle Click Enemy 3"]
    BINDING_NAME_GLADDYBUTTON4_MIDDLE = L["Middle Click Enemy 4"]
    BINDING_NAME_GLADDYBUTTON5_MIDDLE = L["Middle Click Enemy 5"]

    BINDING_NAME_GLADDYBUTTON1_BUTTON4 = L["Button4 Click Enemy 1"]
    BINDING_NAME_GLADDYBUTTON2_BUTTON4 = L["Button4 Click Enemy 2"]
    BINDING_NAME_GLADDYBUTTON3_BUTTON4 = L["Button4 Click Enemy 3"]
    BINDING_NAME_GLADDYBUTTON4_BUTTON4 = L["Button4 Click Enemy 4"]
    BINDING_NAME_GLADDYBUTTON5_BUTTON4 = L["Button4 Click Enemy 5"]

    BINDING_NAME_GLADDYBUTTON1_BUTTON5 = L["Button5 Click Enemy 1"]
    BINDING_NAME_GLADDYBUTTON2_BUTTON5 = L["Button5 Click Enemy 2"]
    BINDING_NAME_GLADDYBUTTON3_BUTTON5 = L["Button5 Click Enemy 3"]
    BINDING_NAME_GLADDYBUTTON4_BUTTON5 = L["Button5 Click Enemy 4"]
    BINDING_NAME_GLADDYBUTTON5_BUTTON5 = L["Button5 Click Enemy 5"]
end

Clicks:UpdateLocalization()

function Clicks:Initialize()
end

function Clicks:Reset()
end

function Clicks:ResetUnit(unit)
end

function Clicks:UpdateFrame(unit)
    self:SetupAttributes(unit)
end

function Clicks:DeferUpdates()
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:SetScript("OnEvent", function(module)
        if InCombatLockdown() then return end
        module:UnregisterEvent("PLAYER_REGEN_ENABLED")
        module:SetScript("OnEvent", nil)
        module:UpdateFrameOnce()
        for unit in pairs(Gladdy.buttons) do module:SetupAttributes(unit) end
    end)
end

function Clicks:UpdateFrameOnce()
    if InCombatLockdown() then self:DeferUpdates(); return end
    for _, v in pairs(Gladdy.buttons) do
        local left = GetBindingKey(("GLADDYBUTTON%d_LEFT"):format(v.id))
        local right = GetBindingKey(("GLADDYBUTTON%d_RIGHT"):format(v.id))
        local middle = GetBindingKey(("GLADDYBUTTON%d_MIDDLE"):format(v.id))
        local button4 = GetBindingKey(("GLADDYBUTTON%d_BUTTON4"):format(v.id))
        local button5 = GetBindingKey(("GLADDYBUTTON%d_BUTTON5"):format(v.id))

        ClearOverrideBindings(v.secure)

        if (left) then
            SetOverrideBindingClick(v.secure, false, left, v.secure:GetName(), "LeftButton")
        end

        if (right) then
            SetOverrideBindingClick(v.secure, false, right, v.secure:GetName(), "RightButton")
        end

        if (middle) then
            SetOverrideBindingClick(v.secure, false, middle, v.secure:GetName(), "MiddleButton")
        end

        if (button4) then
            SetOverrideBindingClick(v.secure, false, button4, v.secure:GetName(), "Button4")
        end

        if (button5) then
            SetOverrideBindingClick(v.secure, false, button5, v.secure:GetName(), "Button5")
        end
    end
end

function Clicks:SetupAttributes(unit)
    local button = Gladdy.buttons[unit]
    if (not button) then
        return
    end

    if InCombatLockdown() then self:DeferUpdates(); return end
    for attr in pairs(button.clickAttributes or {}) do button.secure:SetAttribute(attr, nil) end
    button.clickAttributes = {}
    for _, v in ipairs(Gladdy.db.attributes) do
        self:SetupAttribute(button, v.button, v.modifier, v.action, v.spell)
    end
end

function Clicks:SetupAttribute(button, key, mod, action, spell)
    if InCombatLockdown() then self:DeferUpdates(); return end
    if type(key) ~= "string" or not key:match("^[1-5]$") or type(mod) ~= "string" then return end
    if mod ~= "" and mod ~= "*" and mod ~= "ctrl-" and mod ~= "shift-" and mod ~= "alt-" then return end
    button.clickAttributes = button.clickAttributes or {}
    for _, kind in ipairs({"type", "spell", "macrotext"}) do
        local attr = mod .. kind .. key
        button.secure:SetAttribute(attr, nil)
        button.clickAttributes[attr] = true
    end
    if action == "target" or action == "focus" then
        button.secure:SetAttribute(mod .. "type" .. key, action)
    elseif action == "macro" and type(spell) == "string" then
        button.secure:SetAttribute(mod .. "macrotext" .. key, spell:gsub("%*arena%*", button.unit))
        button.secure:SetAttribute(mod .. "type" .. key, "macro")
    elseif action == "spell" and type(spell) == "string" then
        button.secure:SetAttribute(mod .. "spell" .. key, spell)
        button.secure:SetAttribute(mod .. "type" .. key, "spell")
    end
end


local function SetupAttributeOption(i)
    local buttons = { ["1"] = L["Left button"], ["2"] = L["Right button"], ["3"] = L["Middle button"], ["4"] = L["Button 4"], ["5"] = L["Button 5"] }
    local modifiers = { [""] = L["None"], ["*"] = L["All"], ["ctrl-"] = L["CTRL"], ["shift-"] = L["SHIFT"], ["alt-"] = L["ALT"] }
    local clickValues = { ["macro"] = L["Macro"], ["target"] = L["Target"], ["focus"] = L["Focus"], ["spell"] = L["Cast Spell"], ["disabled"] = L["Disabled"] }
    return {
        type = "group",
        name = Gladdy.dbi.profile.attributes[i].name,
        desc = Gladdy.dbi.profile.attributes[i].name,
        order = i + 1,
        get = function(info)
            return Gladdy.dbi.profile.attributes[tonumber(info[#info - 1])][info[#info]]
        end,
        set = function(info, value)
            Gladdy.dbi.profile.attributes[tonumber(info[#info - 1])][info[#info]] = value

            if (info[#info] == "name") then
                Gladdy.options.args.Clicks.args[info[#info - 1]].name = value
            end

            Gladdy:UpdateFrame()
        end,
        args = {
            name = {
                type = "input",
                name = L["Name"],
                desc = L["Select the name of the click option"],
                order = 1,
            },
            button = {
                type = "select",
                name = L["Button"],
                desc = L["Select which mouse button to use"],
                order = 2,
                values = buttons,
            },
            modifier = {
                type = "select",
                name = L["Modifier"],
                desc = L["Select which modifier to use"],
                order = 3,
                values = modifiers,
            },
            action = {
                type = "select",
                name = L["Action"],
                desc = L["Select what action this mouse button does"],
                order = 4,
                values = clickValues,
            },
            spell = {
                type = "input",
                name = L["Cast Spell / Macro"],
                desc = L["\n|cff1ac742Cast Spell:|r\n" ..
                        "Type in the spell name.\n" ..
                        "For example:\n" ..
                        "|cff17d1c8Polymorph|r\n" ..
                        "\n" ..
                        "|cff1ac742Macro:|r\n" ..
                        "Use *arena* as placeholder.\n" ..
                        "For example:\n" ..
                        "|cff17d1c8/cast [@*arena*] Blind\n" ..
                        "/run SendChatMessage(\"Blinding \" .. UnitName(\"*arena*\"), \"PARTY\")|r"],
                order = 5,
                width = "full",
                multiline = 10,
            },
        },
    }
end

function Clicks:GetOptions()
    local options = {}
    for i = 1, 10 do
        options[tostring(i)] = SetupAttributeOption(i)
    end
    return options
end
