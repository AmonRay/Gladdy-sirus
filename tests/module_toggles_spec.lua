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

local T, R, CB, RC, E = G.modules.Trinket, G.modules.Racial, G.modules['Cast Bar'], G.modules['Range Check'], G.modules.EventListener
local function auraEvent(kind, id, source)
    E:COMBAT_LOG_EVENT_UNFILTERED(now, kind, source or 'mage', 'Source', 0, 'enemy-guid', 'Enemy', 0, id, 'spell' .. id, 16, AURA_TYPE_DEBUFF)
end
local function colors(texture)
    local log = {}
    texture.SetVertexColor = function(_, r, g, b) log[#log + 1] = {r, g, b} end
    return log
end
local function registered(frame)
    local events = {}
    frame.RegisterUnitEvent = function(_, name, unit) events[name] = unit end
    frame.UnregisterAllEvents = function() for name in pairs(events) do events[name] = nil end end
    return events
end

test('trinket disabled at startup restores all subscriptions and tracks usage', function()
    setup({trinketEnabled = false}); assert(not T.messages.TRINKET_USED)
    G.db.trinketEnabled = true; T:UpdateFrameOnce()
    assert(T.messages.JOINED_ARENA and T.messages.ENEMY_SPOTTED and T.messages.TRINKET_USED and T.messages.RACIAL_USED)
    G:SendMessage('TRINKET_USED', 'arena1'); assert(T.frames.arena1.active and T.frames.arena1.endTime == 220)
end)
test('trinket disable enable preserves a running deadline and restores usage', function()
    setup(); G:SendMessage('TRINKET_USED', 'arena1'); local frame = T.frames.arena1
    G.db.trinketEnabled = false; T:UpdateFrame('arena1'); T:UpdateFrameOnce(); assert(not T.messages.TRINKET_USED)
    now = 105; G.db.trinketEnabled = true; T:UpdateFrame('arena1'); T:UpdateFrameOnce(); assert(frame.endTime == 220)
    G:SendMessage('TRINKET_USED', 'arena1'); assert(frame.endTime == 225)
end)
test('castbar disabled at startup subscribes to unit events when enabled mid match', function()
    setup({castBarEnabled = false}); local frame = CB.frames.arena1; local events = registered(frame)
    G.db.castBarEnabled = true; CB:UpdateFrame('arena1'); CB:UpdateFrameOnce()
    assert(frame:GetScript('OnEvent') == CB.OnEvent)
    local count = 0; for _, unit in pairs(events) do assert(unit == 'arena1'); count = count + 1 end
    assert(count == 9)
    casting = true; frame:GetScript('OnEvent')(frame, 'UNIT_SPELLCAST_START', 'arena1')
    assert(frame.casting and frame:GetScript('OnUpdate') == CB.OnUpdate)
end)
test('castbar enabling restores an already running cast', function()
    setup({castBarEnabled = false}); casting = true; G.db.castBarEnabled = true; CB:UpdateFrameOnce()
    local frame = CB.frames.arena1; assert(frame.casting and frame.maxValue == 10 and frame:GetScript('OnUpdate'))
end)
test('castbar enabling restores an already running channel', function()
    setup({castBarEnabled = false}); channeling = true; G.db.castBarEnabled = true; CB:UpdateFrameOnce()
    local frame = CB.frames.arena1; assert(frame.channeling and not frame.casting and frame.maxValue == 10)
end)
test('disabling castbar clears events cast fade and update callbacks', function()
    setup(); local frame = CB.frames.arena1; local events = registered(frame); casting = true; CB:JOINED_ARENA()
    assert(next(events)); frame.fadeOut = true
    G.db.castBarEnabled = false; CB:UpdateFrame('arena1'); CB:UpdateFrameOnce()
    assert(not next(events) and not frame:GetScript('OnEvent') and not frame:GetScript('OnUpdate'))
    assert(not frame.casting and not frame.channeling and not frame.fadeOut and not frame.icon:IsShown())
    CB.OnEvent(frame, 'UNIT_SPELLCAST_START', 'arena1'); CB:CAST_START('arena1', 'Cast', 'icon', 0, 10)
    assert(not frame.casting and not frame:GetScript('OnUpdate'))
end)
test('stale castbar update cannot render after disabling', function()
    setup(); casting = true; CB:JOINED_ARENA(); local frame = CB.frames.arena1; local update = frame:GetScript('OnUpdate')
    G.db.castBarEnabled = false; update(frame, 0.1)
    assert(not frame.casting and not frame:GetScript('OnUpdate') and not frame:GetScript('OnEvent'))
end)
test('repeated castbar configuration updates do not reset an active cast', function()
    setup(); casting = true; CB:UpdateFrameOnce(); local frame = CB.frames.arena1
    frame.value = 3; local callback = frame:GetScript('OnUpdate')
    CB:UpdateFrameOnce(); CB:UpdateFrameOnce(); assert(frame.value == 3 and frame:GetScript('OnUpdate') == callback)
end)
test('test mode never attaches live castbar events during configuration updates', function()
    setup(); G.frame.testing = true; CB:UpdateFrameOnce(); assert(not CB.frames.arena1:GetScript('OnEvent'))
    CB:Test('arena1'); assert(CB.frames.arena1.channeling and CB.frames.arena1:GetScript('OnUpdate'))
end)
test('DR removal while disabled still starts the original reset deadline', function()
    setup(); auraEvent('SPELL_AURA_APPLIED', 122); local icon = D:FindLastIcon('arena1', 'root')
    G.db.drEnabled = false; D:UpdateFrame('arena1'); now = 105; auraEvent('SPELL_AURA_REMOVED', 122)
    assert(icon.running and icon.endTime == 123 and next(D.frames.arena1.effects.root) == nil)
    now = 110; G.db.drEnabled = true; D:UpdateFrame('arena1')
    assert(icon.running and icon.timeLeft == 13 and icon:IsShown())
end)
test('DR expired while disabled is removed before displaying again', function()
    setup(); auraEvent('SPELL_AURA_APPLIED', 122); G.db.drEnabled = false; D:UpdateFrame('arena1')
    auraEvent('SPELL_AURA_REMOVED', 122); now = 150; G.db.drEnabled = true; D:UpdateFrame('arena1')
    assert(D.frames.arena1.tracked.root == nil)
    for i = 1, 16 do assert(not D.frames.arena1['icon' .. i].active) end
    auraEvent('SPELL_AURA_APPLIED', 122); assert(D:FindLastIcon('arena1', 'root').diminishing == 0.5)
end)
test('DR disabled at startup still tracks applications refreshes and removals', function()
    setup({drEnabled = false}); D:UpdateFrame('arena1'); auraEvent('SPELL_AURA_APPLIED', 122)
    now = 101; auraEvent('SPELL_AURA_REFRESH', 122); now = 102; auraEvent('SPELL_AURA_REMOVED', 122)
    local icon = D:FindLastIcon('arena1', 'root'); assert(icon.running and icon.diminishing == 0.25 and icon.endTime == 120)
    G.db.drEnabled = true; D:UpdateFrame('arena1'); assert(icon:IsShown() and icon.endTime == 120)
end)
test('overlapping DR effects still wait for the last removal while disabled', function()
    setup(); auraEvent('SPELL_AURA_APPLIED', 122, 'mage'); auraEvent('SPELL_AURA_APPLIED', 33395, 'pet')
    G.db.drEnabled = false; D:UpdateFrame('arena1'); auraEvent('SPELL_AURA_REMOVED', 122, 'mage')
    local icon = D:FindLastIcon('arena1', 'root'); assert(not icon.running)
    now = 105; auraEvent('SPELL_AURA_REMOVED', 33395, 'pet'); assert(icon.endTime == 123)
end)
test('disabling an individual DR category hides it without losing events', function()
    setup(); auraEvent('SPELL_AURA_APPLIED', 122); local icon = D:FindLastIcon('arena1', 'root')
    G.db.drCategories.root.enabled = false; D:UpdateFrame('arena1'); assert(not icon:IsShown())
    now = 105; auraEvent('SPELL_AURA_REMOVED', 122); assert(icon.endTime == 123 and not icon:IsShown())
    G.db.drCategories.root.enabled = true; D:UpdateFrame('arena1'); assert(icon:IsShown() and icon.running)
end)
test('disabled DR resets completely on arena exit', function()
    setup({drEnabled = false}); auraEvent('SPELL_AURA_APPLIED', 122); D:ResetUnit('arena1')
    assert(not next(D.frames.arena1.effects) and not next(D.frames.arena1.tracked))
    G.db.drEnabled = true; D:UpdateFrame('arena1'); auraEvent('SPELL_AURA_APPLIED', 122)
    assert(D:FindLastIcon('arena1', 'root').diminishing == 0.5)
end)
test('range options address the actual trinket and racial frames', function()
    local button = setup(); assert(button.trinket == T.frames.arena1 and button.racial == R.frames.arena1)
    local tc, rc = colors(button.trinket.texture), colors(button.racial.texture)
    G.db.rangeCheckTrinket = true; G.db.rangeCheckRacial = true; RC:SetRangeAlpha(button, false)
    assert(tc[#tc][1] == 1 / G.db.rangeCheckOorFactor and rc[#rc][1] == 1 / G.db.rangeCheckOorFactor)
end)
test('changing range targets at the same distance invalidates cached colors', function()
    local button = setup(); local tc = colors(button.trinket.texture)
    G.db.rangeCheckTrinket = false; RC:SetRangeAlpha(button, false); assert(tc[#tc][1] == 1)
    G.db.rangeCheckTrinket = true; RC:UpdateFrame('arena1'); RC:UpdateFrameOnce()
    assert(tc[#tc][1] == 1 / G.db.rangeCheckOorFactor)
    G.db.rangeCheckTrinket = false; RC:UpdateFrameOnce(); assert(tc[#tc][1] == 1)
end)
test('changing darkening factor reapplies the new factor without a range transition', function()
    local button = setup(); local tc = colors(button.trinket.texture); G.db.rangeCheckTrinket = true
    RC:SetRangeAlpha(button, false); G.db.rangeCheckOorFactor = 3; RC:UpdateFrameOnce()
    assert(button.lastState == 3 and tc[#tc][1] == 1 / 3)
end)
test('disabling range forces restoration and cancels polling', function()
    local button = setup(); local tc = colors(button.trinket.texture); G.db.rangeCheckTrinket = true
    RC:UpdateFrameOnce(); RC:SetRangeAlpha(button, false); assert(button.range)
    G.db.rangeCheckEnabled = false; RC:UpdateFrameOnce(); assert(not button.range and button.lastState == 1 and tc[#tc][1] == 1)
end)
test('unchanged range polling does not repeat color writes after refresh', function()
    local button = setup(); local tc = colors(button.trinket.texture); RC:SetRangeAlpha(button, false)
    RC:UpdateFrameOnce(); local count = #tc
    for i = 1, 100 do RC:SetRangeAlpha(button, false) end
    assert(#tc == count)
end)
test('range configuration refresh preserves simulated range in test mode', function()
    local button = setup(); G.frame.testing = true; RC:Test('arena1'); RC:UpdateFrameOnce()
    assert(RC.test and button.lastState == 1 and not button.range)
end)
test('module toggle regressions report no swallowed errors', function()
    assert(#wow.errors == 0, table.concat(wow.errors, '\n'))
end)
print('PASS: ' .. passed .. ' module toggle regression tests')
