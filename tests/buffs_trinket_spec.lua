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
CLASS_ICON_TCOORDS = {}
LOCALIZED_CLASS_NAMES_MALE = setmetatable({}, {__index = function(_, key) return key end})
SlashCmdList = {}; dofile('Gladdy/Options.lua')
dofile('Gladdy/Constants_shared.lua'); dofile('Gladdy/Constants_Wrath.lua')
dofile('Gladdy/Libs/DRList-1.0/DRList-1.0.lua'); dofile('Gladdy/Libs/DRList-1.0/Spells.lua')
local G = LibStub('Gladdy')
local getAuras = G.GetAuras
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


local T = G.modules.Trinket
local auraLib = LibStub('LibClassAuras-1.0')
auraLib.GetAltName = function() end
auraLib.GetSpellNameToId = function()
    return {spell999001 = {{id = {999001}}}, spell999002 = {{id = {999002}}}}
end
local function aura(unit, kind, id, duration, expiration)
    G.db.trackedBuffs['999001'] = true; G.db.trackedDebuffs['999002'] = true
    G.buttons[unit].auras[id] = {kind, id, 'spell' .. id, 'icon' .. id, duration, expiration, 1, 'Magic'}
end
local function visible(frame)
    while frame do if not frame:IsShown() then return false end; frame = frame:GetParent() end
    return true
end
local function refresh() B:UpdateFrame('arena1'); B:UpdateFrameOnce() end
local function trackColor(frame)
    local calls = {}
    frame.SetBackdropColor = function(_, r, g, b, a) calls[#calls + 1] = {r, g, b, a} end
    return calls
end
local function readyMessages()
    local messages = {}
    G.db.announcements.trinketReady = true
    N.Send = function(_, text, throttle, color, unit) messages[#messages + 1] = {text = text, unit = unit} end
    return messages
end

test('disabling buffs immediately hides permanent and timed icons and stops callbacks', function()
    setup(); aura('arena1', AURA_TYPE_BUFF, 999001, 0, 0); aura('arena1', AURA_TYPE_DEBUFF, 999002, 20, 120); refresh()
    local buff = B.frames.arena1.auras[AURA_TYPE_BUFF][1]; local debuff = B.frames.arena1.auras[AURA_TYPE_DEBUFF][1]
    assert(visible(buff) and visible(debuff) and debuff:GetScript('OnUpdate'))
    G.db.buffsEnabled = false; B:UpdateFrame('arena1'); assert(not visible(buff) and not visible(debuff))
    B:UpdateFrameOnce(); assert(not buff:GetScript('OnUpdate') and not debuff:GetScript('OnUpdate'))
    assert(#B.frames.arena1.auras[AURA_TYPE_BUFF] == 0 and #B.frames.arena1.auras[AURA_TYPE_DEBUFF] == 0)
end)
test('show buffs toggle hides only buffs and restores them from the current snapshot', function()
    setup(); aura('arena1', AURA_TYPE_BUFF, 999001, 0, 0); aura('arena1', AURA_TYPE_DEBUFF, 999002, 20, 120); refresh()
    G.db.buffsShowBuffs = false; refresh(); local frame = B.frames.arena1
    assert(not frame.buffFrame:IsShown() and frame.debuffFrame:IsShown() and #frame.auras[AURA_TYPE_BUFF] == 0)
    assert(visible(frame.auras[AURA_TYPE_DEBUFF][1]))
    G.db.buffsShowBuffs = true; refresh(); assert(visible(frame.auras[AURA_TYPE_BUFF][1]))
end)
test('show debuffs toggle hides only debuffs', function()
    setup(); aura('arena1', AURA_TYPE_BUFF, 999001, 0, 0); aura('arena1', AURA_TYPE_DEBUFF, 999002, 20, 120); refresh()
    G.db.buffsShowDebuffs = false; refresh(); local frame = B.frames.arena1
    assert(frame.buffFrame:IsShown() and not frame.debuffFrame:IsShown() and #frame.auras[AURA_TYPE_DEBUFF] == 0)
    assert(visible(frame.auras[AURA_TYPE_BUFF][1]))
end)
test('reenabling buffs preserves the original timed aura deadline', function()
    setup(); aura('arena1', AURA_TYPE_BUFF, 999001, 20, 120); refresh()
    G.db.buffsEnabled = false; refresh(); now = 105; G.db.buffsEnabled = true; refresh()
    local icon = B.frames.arena1.auras[AURA_TYPE_BUFF][1]
    assert(icon.endtime == 120 and visible(icon)); icon:GetScript('OnUpdate')(icon, 0); assert(icon.timeLeft == 15)
end)
test('aura expired while disabled is not resurrected on enable', function()
    setup(); aura('arena1', AURA_TYPE_BUFF, 999001, 20, 120); refresh(); G.db.buffsEnabled = false; refresh()
    now = 125; G.db.buffsEnabled = true; refresh(); assert(#B.frames.arena1.auras[AURA_TYPE_BUFF] == 0)
end)
test('permanent aura removed from the snapshot while disabled does not reappear', function()
    setup(); aura('arena1', AURA_TYPE_BUFF, 999001, 0, 0); refresh(); G.db.buffsEnabled = false; refresh()
    G.buttons.arena1.auras[999001] = nil; G.db.buffsEnabled = true; refresh()
    assert(#B.frames.arena1.auras[AURA_TYPE_BUFF] == 0)
end)
test('buff module disabled at startup renders existing aura snapshots after enabling', function()
    setup({buffsEnabled = false}); aura('arena1', AURA_TYPE_BUFF, 999001, 0, 0); refresh()
    G.db.buffsEnabled = true; refresh(); assert(visible(B.frames.arena1.auras[AURA_TYPE_BUFF][1]))
end)
test('repeated configuration refreshes reuse the buff frame pool', function()
    setup(); aura('arena1', AURA_TYPE_BUFF, 999001, 0, 0); aura('arena1', AURA_TYPE_DEBUFF, 999002, 20, 120); refresh()
    local objects = {[B.frames.arena1.auras[AURA_TYPE_BUFF][1]] = true, [B.frames.arena1.auras[AURA_TYPE_DEBUFF][1]] = true}
    for i = 1, 10 do refresh() end
    assert(objects[B.frames.arena1.auras[AURA_TYPE_BUFF][1]] and objects[B.frames.arena1.auras[AURA_TYPE_DEBUFF][1]])
end)
test('buff preview respects both visibility toggles without live aura events', function()
    setup(); G.frame.testing = true; G.db.trackedBuffs['999001'] = true; G.db.trackedDebuffs['999002'] = true
    refresh(); assert(#B.frames.arena1.auras[AURA_TYPE_BUFF] > 0)
    G.db.buffsShowBuffs = false; refresh(); assert(not B.frames.arena1.buffFrame:IsShown())
    G.db.buffsShowBuffs = true; refresh(); assert(visible(B.frames.arena1.auras[AURA_TYPE_BUFF][1]))
end)
test('trinket timer keeps its owning arena unit across reset', function()
    setup(); assert(T.frames.arena1.unit == 'arena1'); T:ResetUnit('arena1'); assert(T.frames.arena1.unit == 'arena1')
end)
test('real trinket expiry announces the correct opponent exactly once', function()
    setup(); local messages = readyMessages(); T:TRINKET_USED('arena1'); local frame = T.frames.arena1
    local update = frame:GetScript('OnUpdate'); now = 221; update(frame, 0); update(frame, 0)
    assert(#messages == 1 and messages[1].unit == 'arena1' and messages[1].text:find('Enemy', 1, true))
end)
test('different trinket timers announce their own opponents', function()
    setup(); G:CreateButton(2); G.buttons.arena2.name, G.buttons.arena2.class = 'Second', 'MAGE'
    local messages = readyMessages(); T:TRINKET_USED('arena1'); T:TRINKET_USED('arena2'); now = 221
    T.frames.arena2:GetScript('OnUpdate')(T.frames.arena2, 0); T.frames.arena1:GetScript('OnUpdate')(T.frames.arena1, 0)
    assert(#messages == 2 and messages[1].unit == 'arena2' and messages[2].unit == 'arena1')
end)
test('resetting an active trinket emits no false ready announcement', function()
    setup(); local messages = readyMessages(); T:TRINKET_USED('arena1'); T:ResetUnit('arena1'); assert(#messages == 0)
end)
test('rediscovery keeps the active trinket color and deadline', function()
    setup(); G.db.trinketColored = true; local frame = T.frames.arena1; local color = trackColor(frame)
    T:TRINKET_USED('arena1'); local ending = frame.endTime; T:ENEMY_SPOTTED('arena1')
    assert(frame.active and frame.endTime == ending and color[#color][1] == 1 and color[#color][2] == 0)
end)
test('stealth and return do not paint a cooling trinket as ready', function()
    setup(); G.db.trinketColored = true; local frame = T.frames.arena1; local color = trackColor(frame); T:TRINKET_USED('arena1')
    G.modules.EventListener:ARENA_OPPONENT_UPDATE('arena1', 'unseen'); now = 105
    G.modules.EventListener:ARENA_OPPONENT_UPDATE('arena1', 'seen')
    assert(frame.active and frame.endTime == 220 and color[#color][1] == 1 and color[#color][2] == 0)
end)
test('trinket rediscovery and layout changes agree on configured colors', function()
    setup(); G.db.trinketColored = true; G.db.trinketColoredCd = {r = 0.2, g = 0.3, b = 0.4, a = 0.5}
    local frame = T.frames.arena1; local color = trackColor(frame); T:TRINKET_USED('arena1'); T:ENEMY_SPOTTED('arena1'); T:UpdateFrame('arena1')
    assert(color[#color][1] == 0.2 and color[#color][4] == 0.5 and frame.endTime == 220)
end)
test('expired hidden trinket shows ready color before its next tick and announces once', function()
    setup(); G.db.trinketColored = true; local messages = readyMessages(); local frame = T.frames.arena1; local color = trackColor(frame)
    T:TRINKET_USED('arena1'); now = 221; T:ENEMY_SPOTTED('arena1'); assert(color[#color][1] == 0 and color[#color][2] == 1)
    frame:GetScript('OnUpdate')(frame, 0); assert(#messages == 1 and not frame.active)
end)
test('a ready trinket still uses its configured ready color', function()
    setup(); G.db.trinketColored = true; local frame = T.frames.arena1; local color = trackColor(frame); T:ENEMY_SPOTTED('arena1')
    assert(not frame.active and color[#color][1] == 0 and color[#color][2] == 1)
end)
local function filterOptions()
    G.dbi = {profile = G.db}
    AceGUIWidgetLSMlists = {font = {}, border = {}, statusbar = {}}
    return B:GetOptions()
end
for _, spec in ipairs({{AURA_TYPE_BUFF, 999001, 'buffList'}, {AURA_TYPE_DEBUFF, 999002, 'debuffList'}}) do
    test(spec[1] .. ' filter callback immediately hides permanent icons and restores them from snapshots', function()
        setup(); aura('arena1', spec[1], spec[2], 0, 0); refresh()
        local options = filterOptions()[spec[3]]; local snapshot = G.buttons.arena1.auras[spec[2]]
        assert(#B.frames.arena1.auras[spec[1]] == 1)
        options.set({spec[3], tostring(spec[2])}, false)
        assert(#B.frames.arena1.auras[spec[1]] == 0 and G.buttons.arena1.auras[spec[2]] == snapshot)
        options.set({spec[3], tostring(spec[2])}, true)
        local icon = B.frames.arena1.auras[spec[1]][1]
        assert(icon and visible(icon) and not icon:GetScript('OnUpdate'))
    end)
    test(spec[1] .. ' filter callback preserves timed deadlines and ignores expired effects', function()
        setup(); aura('arena1', spec[1], spec[2], 30, 130); refresh()
        local options = filterOptions()[spec[3]]
        options.set({spec[3], tostring(spec[2])}, false); now = 110
        options.set({spec[3], tostring(spec[2])}, true)
        assert(B.frames.arena1.auras[spec[1]][1].endtime == 130)
        options.set({spec[3], tostring(spec[2])}, false); now = 131
        options.set({spec[3], tostring(spec[2])}, true)
        assert(#B.frames.arena1.auras[spec[1]] == 0)
    end)
    test(spec[1] .. ' bulk callbacks immediately rebuild icons without changing snapshots', function()
        setup(); aura('arena1', spec[1], spec[2], 0, 0); refresh(); filterOptions()
        local key = tostring(spec[2]); local defaults = spec[1] == AURA_TYPE_BUFF and G.defaults.profile.trackedBuffs or G.defaults.profile.trackedDebuffs
        local old = defaults[key]; defaults[key] = true
        local lib = LibStub('LibClassAuras-1.0'); lib.GetClassBuffs = function() return {} end; lib.GetClassDebuffs = lib.GetClassBuffs
        local options = getAuras(G, spec[1])
        options.uncheckAll.func(); assert(#B.frames.arena1.auras[spec[1]] == 0)
        options.ckeckAll.func(); assert(#B.frames.arena1.auras[spec[1]] == 1)
        defaults[key] = old
    end)
end
test('important aura filtering immediately updates exclusion from ordinary buff icons', function()
    setup(); G.db.buffsShowAuraDebuffs = false
    local id
    for _, info in pairs(A.auras) do if info.track == AURA_TYPE_BUFF then id = info.spellID; break end end
    assert(id)
    local original = auraLib.GetSpellNameToId
    auraLib.GetSpellNameToId = function() return {['spell' .. id] = {{id = {id}}}} end
    G.db.trackedBuffs[tostring(id)] = true
    G.buttons.arena1.auras[id] = {AURA_TYPE_BUFF, id, 'spell' .. id, 'icon' .. id, 30, 130, 1, 'Magic'}
    A:AURA_GAIN('arena1', unpack(G.buttons.arena1.auras[id])); refresh()
    assert(#B.frames.arena1.auras[AURA_TYPE_BUFF] == 0)
    local options = A:GetAuraOptions(AURA_TYPE_BUFF)[tostring(id)].args
    options.enabled.set(nil, false)
    assert(not A.frames.arena1.active and #B.frames.arena1.auras[AURA_TYPE_BUFF] == 1)
    assert(B.frames.arena1.auras[AURA_TYPE_BUFF][1].endtime == 130)
    options.enabled.set(nil, true)
    assert(A.frames.arena1.active and #B.frames.arena1.auras[AURA_TYPE_BUFF] == 0)
    auraLib.GetSpellNameToId = original
end)
test('buff filter refresh updates every existing arena frame', function()
    setup(); G:CreateButton(2); G.dbi = {profile = G.db}
    aura('arena1', AURA_TYPE_BUFF, 999001, 30, 130)
    aura('arena2', AURA_TYPE_BUFF, 999001, 30, 130)
    B:RefreshFilters(); local options = filterOptions().buffList
    options.set({'buffList', '999001'}, false)
    assert(#B.frames.arena1.auras[AURA_TYPE_BUFF] == 0 and #B.frames.arena2.auras[AURA_TYPE_BUFF] == 0)
    options.set({'buffList', '999001'}, true)
    assert(B.frames.arena1.auras[AURA_TYPE_BUFF][1].endtime == 130 and B.frames.arena2.auras[AURA_TYPE_BUFF][1].endtime == 130)
end)
test('buff and trinket regressions report no swallowed errors', function() assert(#wow.errors == 0, table.concat(wow.errors, '\n')) end)
print('PASS: ' .. passed .. ' buff and trinket regression tests')
