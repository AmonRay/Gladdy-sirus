local passed = 0
local function test(name, fn)
    local ok, err = xpcall(fn, debug.traceback)
    assert(ok, name .. ': ' .. tostring(err))
    passed = passed + 1
    print('ok ' .. passed .. ' - ' .. name)
end
local wow = dofile('tests/wow_ui_stub.lua'); wow.install()
local noop = function() end
local now, combat = 100, false
GetTime = function() return now end
InCombatLockdown = function() return combat end
GetSpellInfo = function(id) return 'spell' .. id, '', 'icon' .. id end
GetItemInfo = noop
GetBindingKey = noop; ClearOverrideBindings = noop; SetOverrideBindingClick = noop
GetNumPartyMembers = function() return 0 end; GetNumRaidMembers = GetNumPartyMembers
SendChatMessage = noop; RaidNotice_AddMessage = noop; CombatText_AddMessage = noop
UnitName = function() return 'Enemy' end
UnitExists = function(unit) return unit == 'arena1' end
UnitClass = function() return 'Rogue', 'ROGUE' end
UnitRace = function() return 'Human', 'Human' end
UnitGUID = function() return 'enemy-guid' end
UnitIsUnit = function(a, b) return a == b end
UnitHealth = function() return 80 end; UnitHealthMax = function() return 100 end
UnitPower = function() return 60 end; UnitPowerMax = function() return 100 end
UnitPowerType = function() return 3 end
UnitIsDead = function() return false end; UnitIsDeadOrGhost = UnitIsDead
local casting, channeling = false, false
UnitAura = noop; SetPortraitTexture = noop
UnitCastingInfo = function() if casting then return 'Cast', '', 'Cast', 'icon', 100000, 110000, false, 1, false end end
UnitChannelInfo = function() if channeling then return 'Channel', '', 'Channel', 'icon', 100000, 110000, false, false end end
AURA_TYPE_BUFF, AURA_TYPE_DEBUFF = 'BUFF', 'DEBUFF'
tinsert, tremove, format, mod = table.insert, table.remove, string.format, math.fmod
RAID_CLASS_COLORS = setmetatable({}, {__index = function() return {r = 1, g = 1, b = 1} end})
local libs = {}
LibStub = setmetatable({NewLibrary = function(_, name) libs[name] = libs[name] or {}; return libs[name] end}, {__call = function(_, name)
    libs[name] = libs[name] or {Embed = noop, PixelGlow_Stop = noop, PixelGlow_Start = noop}
    return libs[name]
end})
dofile('Gladdy/Gladdy.lua'); dofile('Gladdy/Lang.lua'); dofile('Gladdy/Frame.lua'); dofile('Gladdy/Util.lua')
SlashCmdList = {}; dofile('Gladdy/Options.lua')
dofile('Gladdy/Constants_shared.lua'); dofile('Gladdy/Constants_Wrath.lua')
dofile('Gladdy/Libs/DRList-1.0/DRList-1.0.lua'); dofile('Gladdy/Libs/DRList-1.0/Spells.lua')
local G = LibStub('Gladdy')
G.GetAuras = function() return {}, {} end
G.SMFetch = function() return 'font' end
G.SetPosition = noop; G.CreateMover = noop
G.ScheduleTimer = function(_, fn) return {fn = fn} end; G.CancelTimer = noop
G.ScheduleRepeatingTimer = function(_, fn) return {fn = fn} end
G.isFeignDeath = function() return false end
for _, name in ipairs({'Healthbar','Powerbar','Classicon','Auras','Cooldowns','Diminishings','BuffsDebuffs','Clicks','Announcements','ShadowsightTimer','Trinket','Racial','Castbar','RangeCheck'}) do
    dofile('Gladdy/Modules/' .. name .. '.lua')
end
G.specSpells=G:GetSpecSpells();G.specBuffs=G:GetSpecBuffs()
dofile('Gladdy/EventListener.lua')
local C, A, D, B, K, N, S = G.modules.Cooldowns, G.modules.Auras, G.modules.Diminishings, G.modules['Buffs and Debuffs'], G.modules.Clicks, G.modules.Announcements, G.modules['Shadowsight Timer']
local function copy(tbl) local result = {}; for k, v in pairs(tbl) do result[k] = type(v) == 'table' and copy(v) or v end; return result end
local function setup(off)
    for _, name in ipairs(wow.names) do if name:match('^Gladdy') then _G[name] = nil end end
    now, combat, casting, channeling = 100, false, false, false
    G.db = copy(G.defaults.profile); G.db.locked = true; G.db.hideBlizzard = 'never'
    if off then for key, value in pairs(off) do G.db[key] = value end end
    G.buttons = {}; G.guids = {}; G.frame = CreateFrame('Frame'); G.frame.testing = false; G.curBracket = 1
    G.pendingUpdateFrame = nil
    for _, module in G:IterModules() do G:Call(module, 'Initialize') end
    G:CreateButton(1)
    local button = G.buttons.arena1
    button.class, button.race, button.name, button.opponentKnown = 'ROGUE', 'Human', 'Enemy', true
    G.guids['enemy-guid'] = 'arena1'
    return button
end


LibStub.GetLibrary = function(_, name) return libs[name] end
dofile('Gladdy/Libs/Ace3/AceSerializer-3.0/AceSerializer-3.0.lua')
dofile('Gladdy/Libs/LibDeflate/LibDeflate.lua')
dofile('Gladdy/ImportStrings.lua'); dofile('Gladdy/ImportValidation.lua'); dofile('Gladdy/Modules/ExportImport.lua'); dofile('Gladdy/Modules/XiconProfiles.lua')
local X = G.modules.XiconProfiles
local T = G.modules.Trinket
local mt = getmetatable(T)
setmetatable(T, {__index = function(self, key) if key == 'ForceUpdate' then return nil end; return mt.__index(self, key) end})
LibStub('AceConfigRegistry-3.0').NotifyChange = noop
G.options = {args = {lock = {}, showMover = {}}}
G.ApplyLocalization = noop
G.UpdateLocalization = noop
local resets, warnings = 0, {}
G.Warn = function(_, message) warnings[#warnings + 1] = message end
local function profileSetup()
    setup(); G.dbi = {profile = G.db, GetCurrentProfile = function() return 'Default' end}
    G.dbi.ResetProfile = function(self, noChildren, noCallbacks)
        assert(noChildren == true and noCallbacks == true)
        resets = resets + 1
        G.db = copy(G.defaults.profile); self.profile = G.db
        G.db.locked = true; G.db.hideBlizzard = 'never'
    end
end

local realToggle = G.ToggleFrame
local toggles, directTests, used, changed = 0, 0, 0, 0
G.ToggleFrame = function(self, count)
    toggles = toggles + 1
    self.curBracket = count
    self.frame.testing = true
    self.frame:Show()
end
local send = G.SendMessage
G.SendMessage = function(self, message, ...)
    if message == 'TRINKET_USED' then used = used + 1 end
    if message == 'GLADDY_PROFILE_CHANGED' then changed = changed + 1 end
    return send(self, message, ...)
end
for _, module in G:IterModules() do
    if module.Test then module.Test = function() directTests = directTests + 1 end end
end
local expected = {
    blizzardProfile = 'GetBlizzardProfile', classicProfile = 'GetClassicProfile',
    classicProfileNoPet = 'GetClassicProfileNoPet', knallProfile = 'GetKnallProfile',
    klimpProfiles = 'GetKlimpProfile', rukkProfile = 'GetRukkProfile',
    mirProfile = 'GetMirProfile', mirProfileEdited = 'GetMirEditedProfile', likeGladiusProfile = 'GetLikeGladius',
}
local function resetCounts() toggles, directTests, used, changed, resets, warnings = 0, 0, 0, 0, 0, {} end
for key, getter in pairs(expected) do
    test('built-in action ' .. key .. ' applies its profile without ForceUpdate or duplicate tests', function()
        profileSetup(); resetCounts(); assert(T.ForceUpdate == nil)
        local decoded = assert(G.modules['Export Import']:Decode(G[getter](G)))
        X:GetOptions()[key].func()
        assert(toggles == 1 and directTests == 0 and used == 0 and changed == 1 and resets == 1)
        assert(G.frame.testing and G.curBracket == 3 and G.frame:IsShown())
        assert(G.db.frameScale == (decoded.frameScale or G.defaults.profile.frameScale))
    end)
end
test('built-in profile application defers test frames during combat', function()
    profileSetup(); resetCounts(); G.ToggleFrame = realToggle; combat = true
    X:GetOptions().classicProfileNoPet.func()
    assert(G.startTest and G.showFrame and G.curBracket == 3 and directTests == 0 and used == 0)
    local update, preview, message = G.UpdateFrame, G.Test, G.SendMessage
    local updates, previews = 0, 0
    G.UpdateFrame = function() assert(not combat); updates = updates + 1 end
    G.Test = function() assert(not combat); previews = previews + 1 end
    G.SendMessage = noop
    combat = false; G:PLAYER_REGEN_ENABLED()
    assert(updates == 1 and previews == 1 and not G.startTest and not G.showFrame)
    G.UpdateFrame, G.Test, G.SendMessage = update, preview, message
    G.ToggleFrame = function(self, count) toggles = toggles + 1; self.curBracket = count end
end)
test('built-in profile works before arena buttons have been created', function()
    profileSetup(); resetCounts(); G.buttons = {}; T.frames = {}
    X:GetOptions().classicProfile.func(); assert(toggles == 1 and directTests == 0 and changed == 1)
end)
test('corrupt built-in profile is rejected before resetting current settings', function()
    profileSetup(); resetCounts(); G.db.customSavedValue = 'keep'
    local getter = G.GetClassicProfile; G.GetClassicProfile = function() return 'corrupt' end
    X:GetOptions().classicProfile.func(); G.GetClassicProfile = getter
    assert(resets == 0 and toggles == 0 and changed == 0 and G.db.customSavedValue == 'keep' and #warnings == 1)
end)
test('failed import validation is rejected before reset or preview', function()
    profileSetup(); resetCounts(); G.db.customSavedValue = 'keep'
    local importer = G.modules['Export Import']; local apply = importer.ApplyImport
    importer.ApplyImport = function() return false, 'Rejected profile' end
    X:GetOptions().classicProfile.func(); importer.ApplyImport = apply
    assert(resets == 0 and toggles == 0 and G.db.customSavedValue == 'keep' and warnings[1] == 'Rejected profile')
end)
test('numeric default textures accept all bundled historical profiles', function()
    profileSetup()
    local original = copy(G.defaults.profile.drCategories)
    for _, category in pairs(G.defaults.profile.drCategories) do category.icon = 136000 end
    for _, getter in pairs(expected) do assert(G.modules['Export Import']:Decode(G[getter](G))) end
    G.defaults.profile.drCategories = original
end)
test('profile action tests leave no swallowed UI errors', function()
    assert(#wow.errors == 0, table.concat(wow.errors, '\n'))
end)
print('PASS: ' .. passed .. ' built-in profile action tests')
