local Gladdy = LibStub("Gladdy")
local L = Gladdy.L

local XiconProfiles = Gladdy:NewModule("XiconProfiles", nil, {
})

local function applyProfile(profileString)
    local importer = Gladdy.modules["Export Import"]
    local deserialized, err = importer:Decode(profileString)
    if not deserialized then Gladdy:Warn(err); return false end
    local profile = Gladdy:DeepCopy(Gladdy.defaults.profile)
    local ok
    ok, err = importer:ApplyImport(deserialized, profile)
    if not ok then Gladdy:Warn(err); return false end

    Gladdy.dbi:ResetProfile(true, true)
    Gladdy.db = Gladdy.dbi.profile
    for key, value in pairs(profile) do Gladdy.db[key] = value end
    Gladdy:ApplyLocalization()
    Gladdy:HideFrame()
    Gladdy:ToggleFrame(3)
    Gladdy:SendMessage("GLADDY_PROFILE_CHANGED")
    return true
end

function XiconProfiles:GetOptions()
    return {
        headerProfileBlizzard = {
            type = "header",
            name = L["Blizzard Profile"],
            order = 2,
        },
        blizzardProfile = {
            type = "execute",
            func = function()
                applyProfile(Gladdy:GetBlizzardProfile())
            end,
            name = " ",
            desc = L["Blizzard Profile"],
            image = "Interface\\AddOns\\Gladdy\\Images\\BasicProfiles\\Blizz1.blp",
            imageWidth = 350,
            imageHeight = 175,
            width = "full",
            order = 3,
        },
        headerProfileClassic = {
            type = "header",
            name = L["Classic Profile"],
            order = 4,
        },
        classicProfile = {
            type = "execute",
            func = function()
                applyProfile(Gladdy:GetClassicProfile())
            end,
            name = " ",
            desc = L["Classic Profile"],
            image = "Interface\\AddOns\\Gladdy\\Images\\BasicProfiles\\Classic1.blp",
            imageWidth = 350,
            imageHeight = 175,
            width = "full",
            order = 5,
        },
        headerProfileClassicNoPet = {
            type = "header",
            name = L["Classic Profile No Pet"],
            order = 6,
        },
        classicProfileNoPet = {
            type = "execute",
            func = function()
                applyProfile(Gladdy:GetClassicProfileNoPet())
            end,
            name = " ",
            desc = L["Classic Profile No Pet"],
            image = "Interface\\AddOns\\Gladdy\\Images\\BasicProfiles\\Classic2.blp",
            imageWidth = 350,
            imageHeight = 175,
            width = "full",
            order = 7,
        },
        headerProfileKnall = {
            type = "header",
            name = L["Knall's Profile"],
            order = 8,
        },
        knallProfile = {
            type = "execute",
            func = function()
                applyProfile(Gladdy:GetKnallProfile())
            end,
            name = " ",
            desc = L["Knall's Profile"],
            image = "Interface\\AddOns\\Gladdy\\Images\\BasicProfiles\\Knall1.blp",
            imageWidth = 350,
            imageHeight = 175,
            width = "full",
            order = 9,
        },
        headerProfileKlimp = {
            type = "header",
            name = L["Klimp's Profile"],
            order = 10,
        },
        klimpProfiles = {
            type = "execute",
            func = function()
                applyProfile(Gladdy:GetKlimpProfile())
            end,
            image = "Interface\\AddOns\\Gladdy\\Images\\BasicProfiles\\Klimp1.blp",
            imageWidth = 350,
            imageHeight = 175,
            name = " ",
            desc = L["Klimp's Profile"],
            width = "full",
            order = 11,
        },
        headerProfileRukk = {
            type = "header",
            name = L["Rukk1's Profile"],
            order = 12,
        },
        rukkProfile = {
            type = "execute",
            func = function()
                applyProfile(Gladdy:GetRukkProfile())
            end,
            name = " ",
            desc = L["Rukk1's Profile"],
            image = "Interface\\AddOns\\Gladdy\\Images\\BasicProfiles\\Rukk1.blp",
            imageWidth = 350,
            imageHeight = 175,
            width = "full",
            order = 13,
        },
        headerProfileMir = {
            type = "header",
            name = L["Mir's Profile"],
            order = 14,
        },
        mirProfile = {
            type = "execute",
            func = function()
                applyProfile(Gladdy:GetMirProfile())
            end,
            name = " ",
            desc = L["Mir's Profile"],
            image = "Interface\\AddOns\\Gladdy\\Images\\BasicProfiles\\Mir1.blp",
            imageWidth = 350,
            imageHeight = 175,
            width = "full",
            order = 15,
        },
        headerProfileMirEdited = {
            type = "header",
            name = L["Mir's Profile edited"],
            order = 16,
        },
        mirProfileEdited = {
            type = "execute",
            func = function()
                applyProfile(Gladdy:GetMirEditedProfile())
            end,
            name = " ",
            desc = L["Mir's Profile"],
            image = "Interface\\AddOns\\Gladdy\\Images\\BasicProfiles\\Mir1_edited.blp",
            imageWidth = 350,
            imageHeight = 175,
            width = "full",
            order = 17,
        },
        headerProfileGladius = {
            type = "header",
            name = L["Gladius Profile"],
            order = 18,
        },
        likeGladiusProfile = {
            type = "execute",
            func = function()
                applyProfile(Gladdy:GetLikeGladius())
            end,
            name = " ",
            desc = L["Gladius default Profile"],
            image = "Interface\\AddOns\\Gladdy\\Images\\BasicProfiles\\gladius.blp",
            imageWidth = 350,
            imageHeight = 175,
            width = "full",
            order = 19,
        },
    }
end
