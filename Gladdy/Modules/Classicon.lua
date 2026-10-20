local select, str_gsub = select, string.gsub

local Gladdy = LibStub("Gladdy")
local CreateFrame = CreateFrame
local GetSpellInfo = GetSpellInfo
local L = Gladdy.L

local Classicon = Gladdy:NewModule("Class Icon", 81, {
    classIconEnabled = true,
    classIconSize = 60 + 20 + 1,
    classIconWidthFactor = 0.9,
    classIconZoomed = false,
    classIconBorderStyle = "Interface\\AddOns\\Gladdy\\Images\\Border_rounded_blp",
    classIconBorderColor = { r = 0, g = 0, b = 0, a = 1 },
    classIconSpecIcon = false,
    classIconXOffset = 0,
    classIconYOffset = 0,
    classIconFrameStrata = "MEDIUM",
    classIconFrameLevel = 5,
    classIconGroup = false,
    classIconGroupDirection = "DOWN"
})

local classIconPath = "Interface\\Addons\\Gladdy\\Images\\Classes\\"
local classIcons = {
    ["DRUID"] = classIconPath .. "inv_misc_monsterclaw_04",
    ["DEATHKNIGHT"] = select(3, GetSpellInfo(49023)),
    ["HUNTER"] = classIconPath .. "inv_weapon_bow_07",
    ["MAGE"] = classIconPath .. "inv_staff_13",
    ["PALADIN"] = classIconPath .. "inv_hammer_01",
    ["PRIEST"] = classIconPath .. "inv_staff_30",
    ["ROGUE"] = classIconPath .. "inv_throwingknife_04",
    ["SHAMAN"] = classIconPath .. "inv_jewelry_talisman_04",
    ["WARLOCK"] = classIconPath .. "spell_nature_drowsy",
    ["WARRIOR"] = classIconPath .. "inv_sword_27",
}

local specIcons = {
    ["DRUID"] = {
        ["Balance"] = select(3, GetSpellInfo(8921)),
        ["Feral"] = select(3, GetSpellInfo(27545)),
        ["Restoration"] = select(3, GetSpellInfo(5185)),
    },
    ["DEATHKNIGHT"] = {
        ["Unholy"] = select(3, GetSpellInfo(48265)),
        ["Blood"] = select(3, GetSpellInfo(48266)),
        ["Frost"] = select(3, GetSpellInfo(48263)),
    },
    ["HUNTER"] = {
        ["Beast Mastery"] = select(3, GetSpellInfo(1515)),
        ["Marksmanship"] = select(3, GetSpellInfo(42243)),
        ["Survival"] = select(3, GetSpellInfo(1495)),
    },
    ["MAGE"] = {
        ["Arcane"] = select(3, GetSpellInfo(1459)),
        ["Fire"] = select(3, GetSpellInfo(133)),
        ["Frost"] = select(3, GetSpellInfo(116)),
    },
    ["PALADIN"] = {
        ["Holy"] = select(3, GetSpellInfo(635)),
        ["Retribution"] = select(3, GetSpellInfo(7294)),
        ["Protection"] = select(3, GetSpellInfo(32828)),
    },
    ["PRIEST"] = {
        ["Discipline"] = select(3, GetSpellInfo(1243)),
        ["Shadow"] = select(3, GetSpellInfo(589)),
        ["Holy"] = select(3, GetSpellInfo(635)),
    },
    ["ROGUE"] = {
        ["Assassination"] = select(3, GetSpellInfo(1329)),
        ["Combat"] = select(3, GetSpellInfo(53)),
        ["Subtlety"] = select(3, GetSpellInfo(1784)),
    },
    ["SHAMAN"] = {
        ["Elemental"] = select(3, GetSpellInfo(403)),
        ["Enhancement"] = select(3, GetSpellInfo(324)),
        ["Restoration"] = select(3, GetSpellInfo(331)),
    },
    ["WARLOCK"] = {
        ["Affliction"] = select(3, GetSpellInfo(6789)),
        ["Demonology"] = select(3, GetSpellInfo(5500)),
        ["Destruction"] = select(3, GetSpellInfo(5740)),
    },
    ["WARRIOR"] = {
        ["Arms"] = select(3, GetSpellInfo(12294)),
        ["Fury"] = select(3, GetSpellInfo(12325)),
        ["Protection"] = select(3, GetSpellInfo(71)),
    },
}

function Classicon:Initialize()
    self.frames = {}

    if Gladdy.db.classIconEnabled then
        self:RegisterMessage("ENEMY_SPOTTED")
        self:RegisterMessage("UNIT_DEATH")
        self:RegisterMessage("UNIT_SPEC")
    end
end

function Classicon:UpdateFrameOnce()
    if Gladdy.db.classIconEnabled then
        self:RegisterMessage("ENEMY_SPOTTED")
        self:RegisterMessage("UNIT_DEATH")
        self:RegisterMessage("UNIT_SPEC")
    else
        self:UnregisterAllMessages()
    end
end

function Classicon:ResetUnit(unit)
    local classIcon = self.frames[unit]
    if not classIcon then return end

    classIcon.texture:SetTexture("")
end

function Classicon:CreateFrame(unit)
    local classIcon = CreateFrame("Frame", nil, Gladdy.buttons[unit])
    classIcon:EnableMouse(false)
    classIcon:SetFrameStrata(Gladdy.db.classIconFrameStrata)
    classIcon:SetFrameLevel(Gladdy.db.classIconFrameLevel)

    classIcon.texture = classIcon:CreateTexture(nil, "BACKGROUND")
    classIcon.texture:SetAllPoints(classIcon)

    classIcon.texture.overlay = classIcon:CreateTexture(nil, "BORDER")
    classIcon.texture.overlay:SetAllPoints(classIcon)
    classIcon.texture.overlay:SetTexture(Gladdy.db.classIconBorderStyle)

    classIcon:SetFrameStrata(Gladdy.db.classIconFrameStrata)
    classIcon:SetFrameLevel(Gladdy.db.classIconFrameLevel)

    Gladdy.buttons[unit].classIcon = classIcon
    self.frames[unit] = classIcon
end

function Classicon:UpdateFrame(unit)
    local classIcon = self.frames[unit]
    if not classIcon then return end

    local testAgain = false

    classIcon:SetFrameStrata(Gladdy.db.classIconFrameStrata)
    classIcon:SetFrameLevel(Gladdy.db.classIconFrameLevel)

    local width, height = Gladdy.db.classIconSize * Gladdy.db.classIconWidthFactor, Gladdy.db.classIconSize
    classIcon:SetWidth(width)
    classIcon:SetHeight(height)

    if Gladdy.db.classIconZoomed then
        classIcon.texture:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    else
        classIcon.texture:SetTexCoord(0, 1, 0, 1)
        if Gladdy.frame.testing then
            testAgain = true
        end
    end

    Gladdy:SetPosition(classIcon, unit, "classIconXOffset", "classIconYOffset", Classicon)

    if Gladdy.db.classIconGroup then
        if unit ~= "arena1" then
            local previousUnit = "arena" .. str_gsub(unit, "arena", "") - 1
            classIcon:ClearAllPoints()
            if Gladdy.db.classIconGroupDirection == "RIGHT" then
                classIcon:SetPoint("LEFT", self.frames[previousUnit], "RIGHT", 0, 0)
            elseif Gladdy.db.classIconGroupDirection == "LEFT" then
                classIcon:SetPoint("RIGHT", self.frames[previousUnit], "LEFT", 0, 0)
            elseif Gladdy.db.classIconGroupDirection == "UP" then
                classIcon:SetPoint("BOTTOM", self.frames[previousUnit], "TOP", 0, 0)
            elseif Gladdy.db.classIconGroupDirection == "DOWN" then
                classIcon:SetPoint("TOP", self.frames[previousUnit], "BOTTOM", 0, 0)
            end
        end
    end

    if unit == "arena1" then
        Gladdy:CreateMover(classIcon, "classIconXOffset", "classIconYOffset", L["Class Icon"],
            {"TOPLEFT", "TOPLEFT"},
            width, height,
            0, 0, "classIconEnabled")
    end

    classIcon.texture:ClearAllPoints()
    classIcon.texture:SetAllPoints(classIcon)

    if Gladdy.db.classIconBorderStyle ~= "None" then
        classIcon.texture.overlay:SetTexture(Gladdy.db.classIconBorderStyle)
        classIcon.texture.overlay:SetVertexColor(Gladdy:SetColor(Gladdy.db.classIconBorderColor))
    else
        classIcon.texture.overlay:SetTexture("")
    end

    if Gladdy.db.classIconEnabled then
        classIcon:Show()
        if testAgain then self:ResetUnit(unit) end
        self:ENEMY_SPOTTED(unit)
    else
        classIcon:Hide()
    end
end

function Classicon:ENEMY_SPOTTED(unit)
    if not Gladdy.db.classIconEnabled then return end

    local classIcon = self.frames[unit]
    if not classIcon then return end

    local button = Gladdy.buttons[unit]
    if not button then return end
    if Gladdy.db.classIconSpecIcon and button.spec then
        self:UNIT_SPEC(unit, button.spec)
    else
        classIcon.texture:SetTexture(classIcons[button.class])
    end
    classIcon.texture:SetAllPoints(classIcon)
end

function Classicon:UNIT_SPEC(unit, spec)
    if not Gladdy.db.classIconEnabled then return end

    local classIcon = self.frames[unit]
    if not Gladdy.db.classIconSpecIcon or not classIcon then return end

    local button = Gladdy.buttons[unit]
    if not button or not button.class then return end

    local key = Gladdy:NormalizeSpec(spec, button.class)
    local specIconTexture = key and specIcons[button.class] and specIcons[button.class][key]

    if specIconTexture then
        classIcon.texture:SetTexture(specIconTexture)
    else
        classIcon.texture:SetTexture(classIcons[button.class])
    end
end

function Classicon:GetOptions()
    return {
        headerClassicon = {
            type = "header",
            name = L["Class Icon"],
            order = 2,
        },
        classIconEnabled = Gladdy:option({
            type = "toggle",
            name = L["Class Icon Enabled"],
            order = 3,
        }),
        classIconSpecIcon = {
            type = "toggle",
            name = L["Show Spec Icon"],
            desc = L["Shows Spec Icon once spec is detected"],
            order = 4,
            disabled = function() return not Gladdy.db.classIconEnabled end,
            get = function() return Gladdy.db.classIconSpecIcon end,
            set = function(_, value)
                Gladdy.db.classIconSpecIcon = value
                if Gladdy.curBracket and Gladdy.curBracket > 0 then
                    for i=1,Gladdy.curBracket do
                        local unit = "arena" .. i
                        if Gladdy.buttons[unit] then
                            local spec = Gladdy.buttons[unit].spec
                            if Gladdy.frame.testing and not spec and Gladdy.testData[unit] then
                                spec = Gladdy.testData[unit].testSpec
                            end

                            if value and spec then
                                self:UNIT_SPEC(unit, spec)
                            else
                                self:ENEMY_SPOTTED(unit)
                            end
                        end
                    end
                end
            end
        },
        classIconGroup = Gladdy:option({
            type = "toggle",
            name = L["Group Class Icon"],
            order = 5,
            disabled = function() return not Gladdy.db.classIconEnabled end,
        }),
        classIconGroupDirection = Gladdy:option({
            type = "select",
            name = L["Group direction"],
            order = 6,
            values = {
                ["RIGHT"] = L["Right"],
                ["LEFT"] = L["Left"],
                ["UP"] = L["Up"],
                ["DOWN"] = L["Down"],
            },
            disabled = function()
                return not Gladdy.db.classIconGroup or not Gladdy.db.classIconEnabled
            end,
        }),
        group = {
            type = "group",
            childGroups = "tree",
            name = L["Frame"],
            order = 7,
            disabled = function() return not Gladdy.db.classIconEnabled end,
            args = {
                size = {
                    type = "group",
                    name = L["Icon"],
                    order = 1,
                    args = {
                        header = {
                            type = "header",
                            name = L["Icon"],
                            order = 1,
                        },
                        classIconZoomed = Gladdy:option({
                            type = "toggle",
                            name = L["Zoomed Icon"],
                            desc = L["Zooms the icon to remove borders"],
                            order = 2,
                            width = "full",
                        }),
                        classIconSize = Gladdy:option({
                            type = "range",
                            name = L["Size"],
                            min = 3,
                            max = 100,
                            step = .1,
                            order = 3,
                            width = "full",
                        }),
                        classIconWidthFactor = Gladdy:option({
                            type = "range",
                            name = L["Icon width factor"],
                            min = 0.5,
                            max = 2,
                            step = 0.05,
                            order = 4,
                            width = "full",
                        }),
                    },
                },
                position = {
                    type = "group",
                    name = L["Position"],
                    order = 3,
                    args = {
                        headerPosition = {
                            type = "header",
                            name = L["Position"],
                            order = 5,
                        },
                        classIconXOffset = Gladdy:option({
                            type = "range",
                            name = L["Horizontal offset"],
                            order = 11,
                            min = -800,
                            max = 800,
                            step = 0.1,
                            width = "full",
                        }),
                        classIconYOffset = Gladdy:option({
                            type = "range",
                            name = L["Vertical offset"],
                            order = 12,
                            min = -800,
                            max = 800,
                            step = 0.1,
                            width = "full",
                        }),
                    },
                },
                border = {
                    type = "group",
                    name = L["Border"],
                    order = 2,
                    args = {
                        headerBorder = {
                            type = "header",
                            name = L["Border"],
                            order = 10,
                        },
                        classIconBorderStyle = Gladdy:option({
                            type = "select",
                            name = L["Border style"],
                            order = 11,
                            values = Gladdy:GetIconStyles()
                        }),
                        classIconBorderColor = Gladdy:colorOption({
                            type = "color",
                            name = L["Border color"],
                            desc = L["Color of the border"],
                            order = 12,
                            hasAlpha = true,
                        }),
                    },
                },
                frameStrata = {
                    type = "group",
                    name = L["Frame Strata and Level"],
                    order = 4,
                    args = {
                        headerAuraLevel = {
                            type = "header",
                            name = L["Frame Strata and Level"],
                            order = 1,
                        },
                        classIconFrameStrata = Gladdy:option({
                            type = "select",
                            name = L["Frame Strata"],
                            order = 2,
                            values = Gladdy.frameStrata,
                            sorting = Gladdy.frameStrataSorting,
                            width = "full",
                        }),
                        classIconFrameLevel = Gladdy:option({
                            type = "range",
                            name = L["Frame Level"],
                            min = 0,
                            max = 500,
                            step = 1,
                            order = 3,
                            width = "full",
                        }),
                    },
                },
            },
        },
    }
end
