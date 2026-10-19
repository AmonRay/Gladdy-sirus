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
UnitAura = noop; UnitCastingInfo = noop; UnitChannelInfo = noop; SetPortraitTexture = noop
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
G.isFeignDeath = function() return false end
for _, name in ipairs({'Healthbar','Powerbar','Classicon','Auras','Cooldowns','Diminishings','BuffsDebuffs','Clicks','Announcements','ShadowsightTimer'}) do
    dofile('Gladdy/Modules/' .. name .. '.lua')
end
G.specSpells=G:GetSpecSpells();G.specBuffs=G:GetSpecBuffs()
dofile('Gladdy/EventListener.lua')
local C, A, D, B, K, N, S = G.modules.Cooldowns, G.modules.Auras, G.modules.Diminishings, G.modules['Buffs and Debuffs'], G.modules.Clicks, G.modules.Announcements, G.modules['Shadowsight Timer']
local function copy(tbl) local result = {}; for k, v in pairs(tbl) do result[k] = type(v) == 'table' and copy(v) or v end; return result end
local function setup(off)
    for _, name in ipairs(wow.names) do if name:match('^Gladdy') then _G[name] = nil end end
    now, combat = 100, false
    G.db = copy(G.defaults.profile); G.db.locked = true; G.db.hideBlizzard = 'never'
    if off then G.db.cooldown = false; G.db.auraEnabled = false end
    G.buttons = {}; G.guids = {}; G.frame = CreateFrame('Frame'); G.frame.testing = false; G.curBracket = 1
    G.pendingUpdateFrame = nil
    for _, module in G:IterModules() do G:Call(module, 'Initialize') end
    G:CreateButton(1)
    local button = G.buttons.arena1
    button.class, button.race, button.name, button.opponentKnown = 'ROGUE', 'Human', 'Enemy', true
    G.guids['enemy-guid'] = 'arena1'
    return button
end
local function attrs(button)
    local values = {}
    button.secure.SetAttribute = function(_, key, value) assert(not combat); assert(key ~= ''); values[key] = value end
    return values
end
local function counters(font)
    local calls = {colors = 0, texts = 0}
    local color, text = font.SetTextColor, font.SetText
    font.SetTextColor = function(self, ...) calls.colors = calls.colors + 1; return color(self, ...) end
    font.SetText = function(self, ...) calls.texts = calls.texts + 1; return text(self, ...) end
    return calls
end

test('disabling a click removes all related secure attributes', function()
    local button = setup(); local values = attrs(button)
    K:SetupAttribute(button, '1', '', 'macro', '/target *arena*'); assert(values.macrotext1 == '/target arena1')
    K:SetupAttribute(button, '1', '', 'disabled', ''); assert(values.type1 == nil and values.macrotext1 == nil and values.spell1 == nil)
end)
test('remapping a click clears the previous button and modifier', function()
    local button = setup(); local values = attrs(button); K:SetupAttributes('arena1'); assert(values.type1 == 'target')
    G.db.attributes[1].button = '3'; G.db.attributes[1].modifier = 'shift-'; K:SetupAttributes('arena1')
    assert(values.type1 == nil and values['shift-type3'] == 'target' and values.type2 == 'focus')
end)
test('click updates defer until combat ends and use the latest configuration', function()
    local button = setup(); local values = attrs(button); K:SetupAttributes('arena1')
    combat = true; G.db.attributes[1].action = 'disabled'; K:SetupAttributes('arena1')
    assert(values.type1 == 'target' and K:GetScript('OnEvent'))
    combat = false; K:GetScript('OnEvent')(K, 'PLAYER_REGEN_ENABLED'); assert(values.type1 == nil and not K:GetScript('OnEvent'))
end)
test('invalid click keys and modifiers never write malformed secure attributes', function()
    local button = setup(); local values = attrs(button)
    K:SetupAttribute(button, '', '', 'target', ''); K:SetupAttribute(button, '1', 'invalid', 'target', '')
    assert(next(values) == nil)
end)
test('cooldowns disabled at startup can be enabled without reload', function()
    local button = setup(true); assert(C.cooldownSpellIds.spell26889 and C.messages.ENEMY_SPOTTED)
    G.db.cooldown = true; C:UpdateFrame('arena1'); C:CooldownUsed('arena1', 'ROGUE', 26889)
    local active; for _, icon in ipairs(button.spellCooldownFrame.icons) do if icon.spellId == 26889 then active = icon end end
    assert(active and active.active and active.endTime > now)
    local ending = active.endTime; G.db.cooldown = false; C:UpdateFrame('arena1'); now = 105
    G.db.cooldown = true; C:UpdateFrame('arena1'); assert(active.endTime == ending and active:GetParent() == button.spellCooldownFrame)
end)
test('auras disabled at startup can be enabled without reinitializing frames', function()
    setup(true); local frame = A.frames.arena1; assert(A.auras and A.messages.AURA_GAIN)
    G.db.auraEnabled = true; A:UpdateFrame('arena1'); A:AURA_GAIN('arena1', AURA_TYPE_DEBUFF, 12826, 'spell12826', 'icon', 10, now + 10, 1, 'Magic')
    assert(A.frames.arena1 == frame and frame.active and frame:GetScript('OnUpdate'))
end)
test('overlapping roots start the DR reset only after the last effect ends', function()
    setup(); D:AuraGain('arena1', 122, 'mage'); D:AuraGain('arena1', 33395, 'pet')
    local icon = D:FindLastIcon('arena1', 'root'); assert(icon.diminishing == 0.25)
    D:AuraFade('arena1', 122, 'mage'); assert(not icon.running and icon.endTime == nil)
    now = 105; D:AuraFade('arena1', 33395, 'pet'); assert(icon.running and icon.endTime == 123)
end)
test('same spell from different casters remains independently active', function()
    setup(); D:AuraGain('arena1', 5782, 'warlock1'); D:AuraGain('arena1', 5782, 'warlock2')
    local icon = D:FindLastIcon('arena1', 'fear'); D:AuraFade('arena1', 5782, 'warlock1'); assert(not icon.running)
    D:AuraFade('arena1', 5782, 'warlock2'); assert(icon.running)
end)
test('duplicate DR apply and fade events neither advance nor restart DR', function()
    setup(); D:AuraGain('arena1', 122, 'mage', false, 1); D:AuraGain('arena1', 122, 'mage', false, 1)
    local icon = D:FindLastIcon('arena1', 'root'); assert(icon.diminishing == 0.5)
    D:AuraFade('arena1', 122, 'mage'); local ending = icon.endTime; now = 105
    D:AuraFade('arena1', 122, 'mage'); assert(icon.endTime == ending)
end)
test('refresh events advance DR once per event and immunity never wraps to half', function()
    setup(); D:AuraGain('arena1', 122, 'mage', false, 1)
    D:AuraGain('arena1', 122, 'mage', true, 2); D:AuraGain('arena1', 122, 'mage', true, 2)
    local icon = D:FindLastIcon('arena1', 'root'); assert(icon.diminishing == 0.25)
    D:AuraGain('arena1', 122, 'mage', true, 3); D:AuraGain('arena1', 122, 'mage', true, 4); assert(icon.diminishing == 0)
end)
test('DR expires by deadline after a long hidden interval and becomes idle', function()
    setup(); D:AuraGain('arena1', 122); D:AuraFade('arena1', 122)
    local icon = D:FindLastIcon('arena1', 'root'); now = icon.endTime + 10; icon:GetScript('OnUpdate')(icon, 0)
    assert(not icon.active and not icon:GetScript('OnUpdate') and D.frames.arena1.tracked.root == nil)
    D:AuraGain('arena1', 122); assert(icon.diminishing == 0.5 and not icon:GetScript('OnUpdate'))
end)
test('DR reset clears active effect identities and callbacks', function()
    setup(); D:AuraGain('arena1', 122, 'mage'); D:ResetUnit('arena1')
    assert(next(D.frames.arena1.effects) == nil and next(D.frames.arena1.tracked) == nil)
    for i = 1, 16 do assert(not D.frames.arena1['icon' .. i]:GetScript('OnUpdate')) end
end)
test('aura and interrupt countdowns use deadlines and remove expired callbacks', function()
    setup(); local frame = A.frames.arena1; assert(not frame:GetScript('OnUpdate') and not frame.interruptFrame:GetScript('OnUpdate'))
    A:AURA_GAIN('arena1', AURA_TYPE_DEBUFF, 12826, 'spell12826', 'icon', 10, 110, 1, 'Magic')
    now = 107; frame:GetScript('OnUpdate')(frame, 0); assert(frame.timeLeft == 3)
    now = 111; frame:GetScript('OnUpdate')(frame, 0); assert(not frame.active and not frame:GetScript('OnUpdate'))
    A:SPELL_INTERRUPT('arena1', 2139, 'spell2139', 64, 12826, 'spell12826', 64)
    local interrupt = frame.interruptFrame; assert(interrupt.active and interrupt:GetScript('OnUpdate'))
    now = interrupt.endTime + 1; interrupt:GetScript('OnUpdate')(interrupt, 0); assert(not interrupt.active and not interrupt:GetScript('OnUpdate'))
end)
test('hidden cooldown circle does not disable aura countdown state', function()
    setup(); G.db.auraDisableCircle = true; A:AURA_GAIN('arena1', AURA_TYPE_DEBUFF, 12826, 'spell12826', 'icon', 10, 110, 1, 'Magic')
    assert(A.frames.arena1.active and not A.frames.arena1.cooldown:IsShown() and A.frames.arena1:GetScript('OnUpdate'))
end)
test('aura appearance writes alpha only when visibility priority changes', function()
    setup(); local frame = A.frames.arena1; local calls = 0
    frame.frame.SetAlpha = function() calls = calls + 1 end
    A:AURA_GAIN('arena1', AURA_TYPE_DEBUFF, 12826, 'spell12826', 'icon', 10, 110, 1, 'Magic'); local first = calls
    for i = 1, 60 do now = 100 + i / 120; frame:GetScript('OnUpdate')(frame, 0) end
    assert(calls == first)
end)
test('buff icon dynamic colors are not rewritten on every frame', function()
    setup(); B:AddAura('arena1', 123, AURA_TYPE_BUFF, 60, 60, 1, 'Magic', 'icon', 1)
    local icon = B.frames.arena1.auras[AURA_TYPE_BUFF][1]; local calls = counters(icon.cooldown)
    for i = 1, 60 do now = 100 + i / 120; icon:GetScript('OnUpdate')(icon, 0) end
    assert(calls.colors == 1 and calls.texts <= 2)
end)
test('permanent expired and pooled buff icons have no idle callbacks', function()
    setup(); B:AddAura('arena1', 123, AURA_TYPE_BUFF, 0, 0, 1, 'Magic', 'icon', 1)
    local icon = B.frames.arena1.auras[AURA_TYPE_BUFF][1]; assert(not icon:GetScript('OnUpdate'))
    B:AddOrRefreshAura('arena1', 123, AURA_TYPE_BUFF, 2, 2, 1, 'Magic', 'icon', 1); assert(icon:GetScript('OnUpdate'))
    now = 103; icon:GetScript('OnUpdate')(icon, 0); assert(not icon:GetScript('OnUpdate') and not icon:IsShown())
    B:ResetUnit('arena1'); assert(not icon:GetScript('OnUpdate'))
    B:AddAura('arena1', 456, AURA_TYPE_DEBUFF, 10, 10, 1, 'Magic', 'icon', 1); assert(B.frames.arena1.auras[AURA_TYPE_DEBUFF][1] == icon and icon:GetScript('OnUpdate'))
end)
test('shadowsight warning retains its supplied message and fires once across skipped seconds', function()
    setup(); local messages = {}; N.Send = function(_, message) messages[#messages + 1] = message end
    G.db.announcements.shadowsight = true; S:Start(61, S.timerFrame1)
    now = 147; S.timerFrame1:GetScript('OnUpdate')(S.timerFrame1, 0)
    assert(#messages == 1 and messages[1] == G.L['Shadowsight up in %ds']:format(14))
    now = 148; S.timerFrame1:GetScript('OnUpdate')(S.timerFrame1, 0); assert(#messages == 1)
    now = 162; S.timerFrame1:GetScript('OnUpdate')(S.timerFrame1, 0)
    assert(#messages == 2 and messages[2] == G.L['Shadowsight up!'] and not S.timerFrame1:GetScript('OnUpdate'))
end)
test('shadowsight text is not rewritten every frame and disable resume preserves deadline', function()
    setup(); S:Start(61, S.timerFrame1); local calls = counters(S.timerFrame1.font)
    for i = 1, 60 do now = 100 + i / 120; S.timerFrame1:GetScript('OnUpdate')(S.timerFrame1, 0) end
    assert(calls.texts <= 1 and calls.colors == 0)
    local ending = S.timerFrame1.endTime; G.db.shadowsightTimerEnabled = false; S:UpdateFrameOnce()
    assert(not S.timerFrame1:GetScript('OnUpdate') and not S:GetScript('OnEvent'))
    now = 150; G.db.shadowsightTimerEnabled = true; S:UpdateFrameOnce(); assert(S.timerFrame1.endTime == ending and S.timerFrame1.timeLeft == 11)
end)
test('ClearIcon by object or spell ID removes only the matching icon', function()
    local button = setup(); local a, b, c = C:CreateIcon(), C:CreateIcon(), C:CreateIcon()
    a.spellId, b.spellId, c.spellId = 1, 2, 3; button.spellCooldownFrame.icons = {a, b, c}
    C:ClearIcon(button, nil, nil, a); assert(#button.spellCooldownFrame.icons == 2 and button.spellCooldownFrame.icons[1] == b)
    C:ClearIcon(button, nil, 3); assert(#button.spellCooldownFrame.icons == 1 and button.spellCooldownFrame.icons[1] == b)
    C:ClearIcon(button, nil, 999); assert(#button.spellCooldownFrame.icons == 1)
end)
test('combat log passes effect identity through DR apply and removal', function()
    setup(); local E=G.modules.EventListener
    local function event(kind,source,id)
        E:COMBAT_LOG_EVENT_UNFILTERED(now,kind,source,source,0,'enemy-guid','Enemy',64,id,'spell'..id,16,AURA_TYPE_DEBUFF)
    end
    event('SPELL_AURA_APPLIED','mage',122);event('SPELL_AURA_APPLIED','pet',33395)
    local icon=D:FindLastIcon('arena1','root');event('SPELL_AURA_REMOVED','mage',122);assert(not icon.running)
    event('SPELL_AURA_REMOVED','pet',33395);assert(icon.running)
end)
test('configuration layout requested in combat is applied once after regen', function()
    setup(); local update=G.UpdateFrame;combat=true;update(G);assert(G.pendingUpdateFrame)
    local calls=0;G.UpdateFrame=function(self) calls=calls+1;self.pendingUpdateFrame=nil end
    combat=false;G:PLAYER_REGEN_ENABLED();G:PLAYER_REGEN_ENABLED();assert(calls==1 and not G.pendingUpdateFrame)
    G.UpdateFrame=update
end)
test('shared racial and trinket timer frames attach only while active', function()
    setup();local frame=G:CreateIconFrame(G.buttons.arena1,nil,{frameLevel=1,frameStrata='MEDIUM',fontScale=1,fontAlpha=1,fontOption='auraFont',fontEnabled=true})
    assert(not frame:GetScript('OnUpdate'));frame.endTime=101;frame:StartTimer();local update=frame:GetScript('OnUpdate')
    now=102;update(frame,0);assert(not frame.active and not frame:GetScript('OnUpdate'))
    frame.endTime=112;frame:StartTimer();assert(frame.active and frame:GetScript('OnUpdate'));frame:StopCooldown()
    assert(not frame:GetScript('OnUpdate') and not frame.endTime)
end)
test('custom debuff border uses the debuff color rather than buff color', function()
    setup();G.db.buffsBorderColorsEnabled=false;G.db.buffsDebuffsBorderColor={r=0.25,g=0.5,b=0.75,a=1}
    G.db.buffsBuffsBorderColor={r=1,g=0,b=0,a=1};B:AddAura('arena1',123,AURA_TYPE_DEBUFF,10,10,1,'Magic','icon',1)
    local color;local icon=B.frames.arena1.auras[AURA_TYPE_DEBUFF][1];icon.border.SetVertexColor=function(_,r,g,b) color={r,g,b} end
    B:AddAura('arena1',456,AURA_TYPE_DEBUFF,10,10,1,'Magic','icon',1);assert(color[1]==0.25 and color[2]==0.5 and color[3]==0.75)
end)
test('new audit paths report no swallowed errors', function() assert(#wow.errors == 0, table.concat(wow.errors, '\n')) end)
print('PASS: ' .. passed .. ' audit regression tests')
