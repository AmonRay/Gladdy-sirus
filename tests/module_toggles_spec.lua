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
local function runningDR()
    setup(); D:AuraGain('arena1', 122, 'mage'); D:AuraFade('arena1', 122, 'mage')
    local icon = D:FindLastIcon('arena1', 'root')
    return icon, icon.endTime, D.frames.arena1.tracked.root
end

test('DR category callback hides and restores the same state immediately', function()
    local icon, deadline, level = runningDR(); local options = D:CategoryOptions().root.args
    options.enabled.set(nil, false)
    assert(not icon:IsShown() and icon.endTime == deadline and D.frames.arena1.tracked.root == level)
    now = 105; options.enabled.set(nil, true)
    assert(icon:IsShown() and icon.endTime == deadline and D.frames.arena1.tracked.root == level)
end)
test('DR bulk callbacks preserve deadlines and tracked effects', function()
    local icon, deadline = runningDR(); local options = D:CategoryOptions()
    options.uncheckAll.func(); assert(not icon:IsShown() and icon.endTime == deadline)
    options.checkAll.func(); assert(icon:IsShown() and icon.endTime == deadline)
end)
test('DR category refresh does not reset overlapping control', function()
    setup(); D:AuraGain('arena1', 122, 'mage'); D:AuraGain('arena1', 122, 'other')
    local icon = D:FindLastIcon('arena1', 'root'); local options = D:CategoryOptions().root.args
    options.enabled.set(nil, false); D:AuraFade('arena1', 122, 'mage')
    options.enabled.set(nil, true); assert(icon.active and not icon.running)
    D:AuraFade('arena1', 122, 'other'); assert(icon.running)
end)
test('DR callbacks expire hidden timers instead of briefly resurrecting them', function()
    local icon, deadline = runningDR(); local options = D:CategoryOptions().root.args
    options.enabled.set(nil, false); now = deadline + 1; options.enabled.set(nil, true)
    assert(not icon.active and not icon:IsShown() and not D.frames.arena1.tracked.root)
end)
test('DR icon callbacks update textures without restarting the timer', function()
    local icon, deadline = runningDR(); local texture
    icon.texture.SetTexture = function(_, value) texture = value end
    local options = D:CategoryOptions().root.args
    options.icon.set(nil, 'custom'); options.forceIcon.set(nil, true)
    assert(texture == 'custom' and icon.endTime == deadline)
    options.icon.set(nil, 'other'); assert(texture == 'other' and icon.endTime == deadline)
    options.forceIcon.set(nil, false); assert(texture == 'icon122' and icon.endTime == deadline)
end)
local auraLib = LibStub('LibClassAuras-1.0')
auraLib.GetAltName = function() end
auraLib.GetSpellNameToId = function() return {} end
local function importantSetup()
    local button = setup(); local entries = {}
    for _, info in pairs(A.auras) do
        if info.track == AURA_TYPE_DEBUFF then entries[#entries + 1] = info end
    end
    table.sort(entries, function(a,b) return a.spellID < b.spellID end)
    local first, second = entries[1].spellID, entries[2].spellID
    local function add(id, duration, expiration, priority)
        local name = GetSpellInfo(id); local info = A.auras[name]
        local config = G.db.auraListDefault[tostring(info.spellID)]
        config.enabled, config.priority = true, priority or 10
        button.auras[id] = {info.track, id, name, 'icon' .. id, duration, expiration, 1, 'Magic'}
        A:AURA_GAIN('arena1', unpack(button.auras[id]))
        return A:GetAuraOptions(info.track)[tostring(info.spellID)].args
    end
    return button, first, second, add
end
test('important aura enabled callback hides immediately and restores the original deadline', function()
    local button, first, second, add = importantSetup(); local options = add(first, 30, 130)
    local frame = A.frames.arena1
    options.enabled.set(nil, false); assert(not frame.active and button.auras[first])
    now = 107; options.enabled.set(nil, true)
    assert(frame.active and frame.spellID == first and frame.endTime == 130 and frame.timeLeft == 23)
end)
test('important aura priority callbacks immediately select a different saved aura', function()
    local button, first, second, add = importantSetup()
    local low = add(first, 30, 130, 10); local high = add(second, 20, 120, 20)
    local frame = A.frames.arena1; assert(frame.spellID == second)
    low.priority.set(nil, 30); assert(frame.spellID == first and frame.priority == 30 and frame.endTime == 130)
    low.priority.set(nil, 5); assert(frame.spellID == second and frame.priority == 20 and frame.endTime == 120)
    high.enabled.set(nil, false); assert(frame.spellID == first and frame.endTime == 130)
end)
test('important aura bulk callbacks hide and restore current snapshots', function()
    local button, first, second, add = importantSetup(); add(first, 30, 130)
    local options = A:GetAuraOptions(AURA_TYPE_DEBUFF)
    options.uncheckAll.func(); assert(not A.frames.arena1.active)
    now = 106; options.ckeckAll.func(); assert(A.frames.arena1.active and A.frames.arena1.endTime == 130)
end)
test('important aura callbacks do not restore removed or expired snapshots', function()
    local button, first, second, add = importantSetup(); local options = add(first, 30, 130)
    options.enabled.set(nil, false); now = 131; options.enabled.set(nil, true); assert(not A.frames.arena1.active)
    now = 100; options = add(first, 30, 130); button.auras[first] = nil
    options.priority.set(nil, 40); assert(not A.frames.arena1.active)
end)
test('important aura callbacks respect stealth without retaining a disabled icon', function()
    local button, first, second, add = importantSetup(); local options = add(first, 30, 130)
    button.stealthed = true; options.enabled.set(nil, false); assert(not A.frames.arena1.active)
    options.enabled.set(nil, true); assert(A.frames.arena1.active and A.frames.arena1.endTime == 130)
end)
test('important aura callbacks leave interrupt state untouched', function()
    local button, first, second, add = importantSetup(); local options = add(first, 30, 130)
    local interrupt = A.frames.arena1.interruptFrame
    interrupt.active, interrupt.endTime, interrupt.priority = true, 111, 50
    options.priority.set(nil, 20)
    assert(interrupt.active and interrupt.endTime == 111 and interrupt.priority == 50)
end)
for _, id in ipairs({8178, 50461}) do
    test('special aura ' .. id .. ' retains its deadline through filter and live refreshes', function()
        local button, first, second, add = importantSetup(); local options = add(id, 0, 0, 40)
        local frame = A.frames.arena1; local deadline = frame.endTime
        assert(deadline == 100 + G.db.specialSpells[id])
        now = 104; options.priority.set(nil, 45); assert(frame.endTime == deadline)
        options.enabled.set(nil, false); now = 107; options.enabled.set(nil, true)
        assert(frame.endTime == deadline)
        A:AURA_GAIN('arena1', unpack(button.auras[id])); assert(frame.endTime == deadline)
        now = deadline + 1; options.priority.set(nil, 30); assert(not frame.active)
    end)
end
test('hidden special auras retain their initial deadline before becoming highest priority', function()
    local button, first, second, add = importantSetup(); add(first, 60, 160, 50)
    local options = add(8178, 0, 0, 10); assert(A.frames.arena1.spellID == first)
    now = 110; options.priority.set(nil, 50)
    if A.frames.arena1.spellID ~= 8178 then
        A:GetAuraOptions(AURA_TYPE_DEBUFF)[tostring(first)].args.enabled.set(nil, false)
    end
    assert(A.frames.arena1.spellID == 8178 and A.frames.arena1.endTime == 145)
end)
test('removed special aura is observed with a new deadline when reapplied', function()
    local button, first, second, add = importantSetup(); add(8178, 0, 0, 40)
    button.auras[8178] = nil; A:RefreshFilters(); assert(not A.frames.arena1.active)
    now = 110; add(8178, 0, 0, 40); assert(A.frames.arena1.endTime == 155)
end)
test('DR category callbacks refresh all arena frames without resetting individual deadlines', function()
    local first, deadline = runningDR(); G:CreateButton(2)
    now = 105; D:AuraGain('arena2', 122, 'mage'); D:AuraFade('arena2', 122, 'mage')
    local second = D:FindLastIcon('arena2', 'root'); local secondDeadline = second.endTime
    local options = D:CategoryOptions().root.args
    options.enabled.set(nil, false); assert(not first:IsShown() and not second:IsShown())
    options.enabled.set(nil, true)
    assert(first:IsShown() and second:IsShown() and first.endTime == deadline and second.endTime == secondDeadline)
end)
test('important aura callbacks refresh all arena units without rescanning UnitAura', function()
    local button, first, second, add = importantSetup(); local options = add(first, 30, 130)
    G:CreateButton(2); G.buttons.arena2.auras[first] = copy(button.auras[first])
    G.buttons.arena2.auras[first][6] = 135
    A:AURA_GAIN('arena2', unpack(G.buttons.arena2.auras[first]))
    local original = UnitAura; UnitAura = function() error('unexpected scan') end
    options.enabled.set(nil, false); assert(not A.frames.arena1.active and not A.frames.arena2.active)
    options.enabled.set(nil, true)
    assert(A.frames.arena1.endTime == 130 and A.frames.arena2.endTime == 135)
    UnitAura = original
end)
local function interrupt(id, school)
    A:SPELL_INTERRUPT('arena1', id or 2139, GetSpellInfo(id or 2139), 16, 1, 'cast', school or 4)
    return A.frames.arena1.interruptFrame
end
local function interruptOptions(id)
    return A:GetInterruptOptions()[tostring(id or 2139)].args
end
local function toggleAuras(enabled)
    G.db.auraEnabled = enabled
    for unit in pairs(A.frames) do A:UpdateFrame(unit) end
    A:UpdateFrameOnce()
end
test('interrupt enabled callback immediately hides and restores the original deadline', function()
    setup(); local frame = interrupt(); local deadline = frame.endTime
    local options = interruptOptions(); options.enabled.set(nil, false)
    assert(not frame.active and not frame:GetScript('OnUpdate') and A.interrupts.arena1['2139'].endTime == deadline)
    now = 103; options.enabled.set(nil, true)
    assert(frame.active and frame.endTime == deadline and frame.startTime == 100 and frame.timeLeft == 5)
end)
test('interrupt priority callback updates the visible priority without restarting the timer', function()
    setup(); local frame = interrupt(); local deadline = frame.endTime
    interruptOptions().priority.set(nil, 40)
    assert(frame.active and frame.priority == 40 and frame.endTime == deadline)
end)
test('interrupt bulk callbacks immediately hide and restore all active units', function()
    setup(); G:CreateButton(2); local first = interrupt()
    A:SPELL_INTERRUPT('arena2', 1766, GetSpellInfo(1766), 1, 1, 'cast', 16)
    local second = A.frames.arena2.interruptFrame; local options = A:GetInterruptOptions()
    options.uncheckAll.func(); assert(not first.active and not second.active)
    now = 102; options.checkAll.func()
    assert(first.active and first.endTime == 108 and second.active and second.endTime == 105)
end)
test('interrupt disabled by its filter is still tracked from the original event', function()
    setup(); interruptOptions().enabled.set(nil, false); local frame = interrupt()
    assert(not frame.active); now = 104; interruptOptions().enabled.set(nil, true)
    assert(frame.active and frame.startTime == 100 and frame.endTime == 108)
end)
test('expired hidden interrupts are not resurrected by settings callbacks', function()
    setup(); local frame = interrupt(); interruptOptions().enabled.set(nil, false)
    now = 109; interruptOptions().enabled.set(nil, true)
    assert(not frame.active and not next(A.interrupts.arena1))
end)
test('interrupt priority changes select another running lockout without extending either deadline', function()
    setup(); G.db.auraListInterrupts['2139'].priority = 40
    local frame = interrupt(); now = 101; interrupt(1766, 16)
    assert(frame.spellID == 2139 and frame.endTime == 108)
    interruptOptions(1766).priority.set(nil, 50)
    assert(frame.spellID == 1766 and frame.endTime == 106 and frame.spellSchool == 16)
    interruptOptions(1766).enabled.set(nil, false)
    assert(frame.spellID == 2139 and frame.endTime == 108 and frame.spellSchool == 4)
end)
test('interrupt expiry reveals another unexpired saved lockout', function()
    setup(); G.db.auraListInterrupts['2139'].priority = 10; interrupt()
    now = 101; G.db.auraListInterrupts['1766'].priority = 40; local frame = interrupt(1766)
    assert(frame.endTime == 106); now = 106; frame:GetScript('OnUpdate')(frame, 0)
    assert(frame.active and frame.spellID == 2139 and frame.endTime == 108)
    now = 108; frame:GetScript('OnUpdate')(frame, 0)
    assert(not frame.active and not frame:GetScript('OnUpdate') and not next(A.interrupts.arena1))
end)
test('a new interrupt event legitimately replaces that spell deadline', function()
    setup(); local frame = interrupt(); now = 103; interrupt()
    assert(frame.startTime == 103 and frame.endTime == 111)
end)
test('interrupt filter refresh preserves specialization duration modifiers', function()
    local button = setup(); button.class, button.spec = 'SHAMAN', 'Restoration'
    local frame = interrupt(); local deadline = frame.endTime
    assert(math.abs(deadline - 105.6) < 0.00001)
    interruptOptions().enabled.set(nil, false); now = 101; interruptOptions().enabled.set(nil, true)
    assert(frame.endTime == deadline)
end)
test('interrupt filter updates do not modify the displayed important aura', function()
    local button, first, second, add = importantSetup(); add(first, 30, 130, 30)
    interrupt(); interruptOptions().priority.set(nil, 40)
    assert(A.frames.arena1.active and A.frames.arena1.endTime == 130 and A.frames.arena1.priority == 30)
end)
test('interrupt filter callbacks preserve stealth and do not rescan unit auras', function()
    local button = setup(); local frame = interrupt(); button.stealthed = true
    local original = UnitAura; UnitAura = function() error('unexpected scan') end
    interruptOptions().enabled.set(nil, false); now = 102; interruptOptions().enabled.set(nil, true)
    assert(frame.endTime == 108 and button.stealthed)
    UnitAura = original
end)
test('interrupt filters respect hidden cooldown circles on restoration', function()
    setup(); G.db.auraDisableCircle = true; local frame = interrupt()
    interruptOptions().enabled.set(nil, false); interruptOptions().enabled.set(nil, true)
    assert(frame.active and not frame.cooldown:IsShown())
end)
test('resetting the arena unit clears all saved interrupt states', function()
    setup(); local frame = interrupt(); A:ResetUnit('arena1')
    interruptOptions().enabled.set(nil, true)
    assert(not frame.active and not A.interrupts.arena1 and not frame.spellID and not frame.name)
end)
test('interrupt preview bulk callbacks clear disabled icons and can restore enabled icons', function()
    setup(); G.frame.testing = true; A:Test('arena1'); local frame = A.frames.arena1.interruptFrame
    assert(frame.active); local options = A:GetInterruptOptions()
    options.uncheckAll.func(); assert(not frame.active)
    options.checkAll.func(); assert(frame.active)
end)
test('enabling important auras restores an already observed snapshot without a new event', function()
    setup({auraEnabled = false})
    local aura = {AURA_TYPE_DEBUFF, 12826, 'spell12826', 'icon', 10, 110, 1, 'Magic'}
    G.buttons.arena1.auras[12826] = aura; A:AURA_GAIN('arena1', unpack(aura))
    assert(not A.frames.arena1.active); now = 103; toggleAuras(true)
    assert(A.frames.arena1.active and A.frames.arena1.endTime == 110 and A.frames.arena1.timeLeft == 7)
end)
test('aura module disabling and enabling preserves both aura and interrupt deadlines', function()
    local button, first, second, add = importantSetup(); add(first, 30, 130); local frame = interrupt()
    toggleAuras(false); assert(not A.frames.arena1.active and not frame.active)
    now = 104; toggleAuras(true)
    assert(A.frames.arena1.active and A.frames.arena1.endTime == 130 and frame.active and frame.endTime == 108)
end)
test('important aura restoration excludes expired and removed effects while disabled', function()
    local button, first, second, add = importantSetup(); add(first, 30, 130)
    toggleAuras(false); button.auras[first] = nil; toggleAuras(true); assert(not A.frames.arena1.active)
    add(first, 30, 130); toggleAuras(false); now = 131; toggleAuras(true); assert(not A.frames.arena1.active)
end)
test('important aura module enabling chooses the highest priority saved effect', function()
    local button, first, second, add = importantSetup(); add(first, 30, 130, 10); add(second, 20, 120, 30)
    toggleAuras(false); now = 103; toggleAuras(true)
    assert(A.frames.arena1.spellID == second and A.frames.arena1.endTime == 120)
end)
test('special aura observation while disabled preserves its original deadline on enabling', function()
    local button, first, second, add = importantSetup(); toggleAuras(false); add(8178, 0, 0, 40)
    assert(not A.frames.arena1.active); now = 110; toggleAuras(true)
    assert(A.frames.arena1.active and A.frames.arena1.endTime == 145)
end)
test('interrupt events while the module is disabled are restored only before their deadline', function()
    setup({auraEnabled = false}); local frame = interrupt(); assert(not frame.active)
    now = 103; toggleAuras(true); assert(frame.active and frame.endTime == 108)
    toggleAuras(false); now = 109; toggleAuras(true); assert(not frame.active)
end)
test('ordinary aura configuration refresh does not replay active effects or interrupts', function()
    local button, first, second, add = importantSetup(); add(first, 30, 130); local frame = interrupt()
    local refresh, interruptRefresh = A.RefreshFilters, A.RefreshInterruptFilters
    A.RefreshFilters = function() error('unexpected aura replay') end
    A.RefreshInterruptFilters = function() error('unexpected interrupt replay') end
    A:UpdateFrame('arena1'); A:UpdateFrameOnce(); A:UpdateFrameOnce()
    assert(A.frames.arena1.endTime == 130 and frame.endTime == 108)
    A.RefreshFilters, A.RefreshInterruptFilters = refresh, interruptRefresh
end)
test('aura module restoration does not request a new UnitAura scan', function()
    local button, first, second, add = importantSetup(); add(first, 30, 130); toggleAuras(false)
    local original = UnitAura; UnitAura = function() error('unexpected scan') end
    toggleAuras(true); assert(A.frames.arena1.active and A.frames.arena1.endTime == 130)
    UnitAura = original
end)
test('disabling the aura module in preview stops both timer callbacks', function()
    setup(); G.frame.testing = true; A:Test('arena1')
    local frame = A.frames.arena1
    toggleAuras(false)
    assert(not frame.active and not frame:GetScript('OnUpdate'))
    assert(not frame.interruptFrame.active and not frame.interruptFrame:GetScript('OnUpdate'))
    toggleAuras(true); assert(frame.active and frame.interruptFrame.active)
end)
test('module toggle regressions report no swallowed errors', function()
    assert(#wow.errors == 0, table.concat(wow.errors, '\n'))
end)
print('PASS: ' .. passed .. ' module toggle regression tests')
