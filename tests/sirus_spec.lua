-- Run from repository root: lua5.1 tests/sirus_spec.lua
local passed = 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if not ok then error(name .. ': ' .. tostring(err), 0) end
    passed = passed + 1
    print('ok ' .. passed .. ' - ' .. name)
end
local function eq(actual, expected)
    assert(actual == expected, tostring(actual) .. ' ~= ' .. tostring(expected))
end
local function noop() end
ceil = math.ceil
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
AURA_TYPE_BUFF, AURA_TYPE_DEBUFF = 'BUFF', 'DEBUFF'
COMBATLOG_OBJECT_REACTION_HOSTILE = 64
bit = {band = function(a, b) return a == b and b or 0 end}
local now = 1000
GetTime = function() return now end
GetLocale = function() return 'ruRU' end
GetSpellInfo = function(id) if id then return 'spell' .. id, '', 'icon' .. id end end
GetItemInfo = function() return nil end
local unitQueries=0
UnitExists = function(unit) unitQueries=unitQueries+1; return unit ~= nil and unit ~= 'missing' end
UnitName = function(unit) return unit end
UnitRace = function() return 'Human', 'Human' end
UnitClass = function() return 'Mage', 'MAGE' end
UnitGUID = function(unit) return unit end
UnitIsUnit = function(a, b) return a == b end
UnitCastingInfo, UnitChannelInfo = noop, noop
local auraProvider = noop
UnitAura = function(...) return auraProvider(...) end
CreateFrame = function()
    return {RegisterEvent=noop, SetScript=noop, UnregisterEvent=noop, UnregisterAllEvents=noop}
end
IsInInstance = function() return true, 'arena' end
local hooks = {}
hooksecurefunc = function(name, fn) hooks[name] = fn end
CompactArenaFrame_Generate = noop
local G = {}
LibStub = setmetatable({NewLibrary=function() return G end}, {__call=function(_, name)
    if name == 'Gladdy' then return G end
    return {Embed=noop}
end})
dofile('Gladdy/Gladdy.lua')
local dispatch=G.SendMessage
local earlyL = G.L
dofile('Gladdy/Lang.lua')
test('localization keeps core table and initializes Russian before constants', function()
    eq(G.L, earlyL); eq(G.L['Holy'], 'Свет')
end)
G.GetSharedTotemData = function() return {}, {}, {} end
G.AddEntriesToTable = function(_, target, source) for k,v in pairs(source) do target[k]=v end end
dofile('Gladdy/Constants_Wrath.lua')
dofile('Gladdy/Frame.lua')
dofile('Gladdy/Util.lua')
local events, calls = {}, {}
G.SendMessage = function(_, name, ...) events[#events+1] = {name, ...} end
G.defaults = {profile={}}
G.buttons = {arena1={class='MAGE', race='Human', spec='Frost', auras={}, lastAuras={}}}
G.guids = {enemy='arena1', pet='arenapet1'}
G.specSpells, G.specBuffs, G.exceptionNames = {}, {}, {}
G.db = {cooldown=true, cooldownCooldowns={}, racialEnabled=true, trinketEnabled=true}
G.modules.Cooldowns = {cooldownSpellIds={}, CooldownUsed=function(_, ...) calls[#calls+1]={...} end}
G.modules.Diminishings = {AuraGain=noop, AuraFade=noop}
dofile('Gladdy/EventListener.lua')
local E = G.modules.EventListener
E:Initialize()
local C = G:Constellations()
local function clear() events={}; calls={} end
local function count(name)
    local n=0; for _,v in ipairs(events) do if v[1]==name then n=n+1 end end; return n
end
test('passive zodiac IDs and active IDs are distinct', function()
    eq(C[371796].auraID, 371796); eq(C[371796].id, 375015)
    eq(C[371796].sharedTrinketCD,90); eq(C[371804].sharedTrinketCD,60)
end)
test('Sirus native zodiac API translates raceID via ZODIAC_DEBUFFS', function()
    ZODIAC_DEBUFFS={[371796]=1}
    C_Unit={GetZodiacByDebuff=function() return 1, 'Human', 'Human', 'icon' end}
    eq(E:detectConstellation('arena1'),C[371796]); C_Unit=nil; ZODIAC_DEBUFFS=nil
end)
test('fallback finds constellation past aura 40', function()
    auraProvider=function(unit,index,filter)
        if index<=41 then return 'aura',nil,nil,nil,nil,nil,nil,nil,nil,nil,index==41 and 371790 or 1 end
    end
    eq(E:detectConstellation('arena1'),C[371790]); auraProvider=noop
    eq(E:detectConstellation('missing'),nil)
end)
test('legacy named trinket event ignores rank/castID', function()
    clear(); E:UNIT_SPELLCAST_SUCCEEDED('arena1',GetSpellInfo(42292),'Rank 1',123)
    eq(count('TRINKET_USED'),1); eq(#calls,0)
end)
test('numeric and Cast GUID trinket events', function()
    clear(); E:UNIT_SPELLCAST_SUCCEEDED('arena1',42292)
    E:UNIT_SPELLCAST_SUCCEEDED('arena1','Cast-123',42292)
    eq(count('TRINKET_USED'),2)
end)
test('all 23 zodiac abilities are recognized in legacy events', function()
    local n=0
    for _,constellation in pairs(C) do
        clear(); G.buttons.arena1.constellation=constellation
        E:UNIT_SPELLCAST_SUCCEEDED('arena1',GetSpellInfo(constellation.id),'',55)
        eq(count('RACIAL_USED'),1); n=n+1
    end
    eq(n,23)
end)
test('alternate zodiac ability is recognized by name and numeric ID',function()
    G.buttons.arena1.constellation=C[371788]; clear()
    E:UNIT_SPELLCAST_SUCCEEDED('arena1',GetSpellInfo(316421),'',99)
    E:UNIT_SPELLCAST_SUCCEEDED('arena1',316420)
    eq(count('RACIAL_USED'),2)
end)
test('pet and unknown unit casts do not consume owner cooldowns', function()
    clear(); E:UNIT_SPELLCAST_SUCCEEDED('arenapet1',42292)
    E:UNIT_SPELLCAST_SUCCEEDED('missing',42292); eq(#events,0)
end)
test('class cooldown uses canonical spell ID, not unit token or spell name', function()
    clear(); G.modules.Cooldowns.cooldownSpellIds[GetSpellInfo(2139)]=2139
    G.db.cooldownCooldowns['2139']=true
    E:UNIT_SPELLCAST_SUCCEEDED('arena1',GetSpellInfo(2139),'',123)
    eq(#calls,1); eq(calls[1][1],'arena1'); eq(calls[1][2],'MAGE'); eq(calls[1][3],2139)
end)
test('combat log trinket path works without UNIT_SPELLCAST_SUCCEEDED', function()
    clear(); E:COMBAT_LOG_EVENT_UNFILTERED(now,'SPELL_CAST_SUCCESS','enemy','Enemy',64,'other','Other',0,42292,GetSpellInfo(42292),1)
    eq(count('TRINKET_USED'),1)
end)
test('combat log handles pet and untracked hostile aura sources safely', function()
    E:COMBAT_LOG_EVENT_UNFILTERED(now,'SPELL_CAST_SUCCESS','pet','Pet',64,'other','Other',0,2139,GetSpellInfo(2139),1)
    E:COMBAT_LOG_EVENT_UNFILTERED(now,'SPELL_AURA_APPLIED','unknown','Enemy',64,'other','Other',0,51514,GetSpellInfo(51514),1)
    E:COMBAT_LOG_EVENT_UNFILTERED(now,'SPELL_AURA_APPLIED',nil,nil,nil,nil,nil,nil)
    E:ARENA_OPPONENT_UPDATE('missing','seen')
end)
test('late constellation is resolved once and spotted without an aura loop', function()
    G.buttons.arena1.constellation=nil; clear()
    C_Unit={GetZodiacByDebuff=function() return 1 end}; ZODIAC_DEBUFFS={[371796]=1}
    E:UNIT_AURA('arena1'); eq(G.buttons.arena1.constellation,C[371796]); eq(count('ENEMY_SPOTTED'),1)
    C_Unit=nil; ZODIAC_DEBUFFS=nil
end)
test('saved aura replay iterates spell-ID keys', function()
    local n=0
    G.modules.Auras={AURA_GAIN=function(_,unit,auraType,id) eq(id,12345); n=n+1 end}
    G.buttons.arena1.lastAuras={[12345]={'BUFF',12345,'name'}}
    E:UpdateAuras('arena1'); eq(n,1)
end)
dofile('Gladdy/Modules/Racial.lua')
dofile('Gladdy/Modules/Trinket.lua')
local R,T=G.modules.Racial,G.modules.Trinket
local function frame()
    return {cooldown={SetCooldown=noop},SetIcon=noop,Show=noop}
end
R.frames={arena1=frame()}; T.frames={arena1=frame()}
-- Test shared-CD decisions separately from rendering/font setup.
T.Used=function(self,unit,start,duration)
    self.frames[unit].active=true; self.frames[unit].timeLeft=duration/1000
end
test('human trinket shared CD then actual racial extends to full cooldown', function()
    G.buttons.arena1.constellation=C[371796]
    R:TRINKET_USED('arena1'); eq(R.frames.arena1.timeLeft,90)
    R:RACIAL_USED('arena1'); eq(R.frames.arena1.timeLeft,120)
    R:TRINKET_USED('arena1'); eq(R.frames.arena1.timeLeft,120)
end)
test('racial starts shared trinket cooldown without shortening full trinket', function()
    T:RACIAL_USED('arena1'); eq(T.frames.arena1.timeLeft,90)
    T.frames.arena1.timeLeft=120; T:RACIAL_USED('arena1'); eq(T.frames.arena1.timeLeft,120)
    G.buttons.arena1.constellation=C[371804]; T.frames.arena1.active=false
    T:RACIAL_USED('arena1'); eq(T.frames.arena1.timeLeft,60)
end)
test('racial handler safely ignores absent buttons', function() R:RACIAL_USED('missing') end)
test('reset clears race, constellation, specialization and aura state', function()
    local b=G.buttons.arena1; b.spec='Frost'; b.lastAuras={[123]={}}
    G:ResetButton('arena1'); eq(b.race,nil); eq(b.constellation,nil); eq(b.spec,nil); eq(next(b.lastAuras),nil)
end)
test('DF UI arena hiding does not require Blizzard_ArenaUI addon', function()
    CompactArenaFrame={SetAlpha=function(self,a) self.alpha=a end}
    ArenaEnemyFrames=CompactArenaFrame
    G:BlizzArenaSetAlpha(0); eq(CompactArenaFrame.alpha,0)
    G:BlizzArenaSetAlpha(1); eq(CompactArenaFrame.alpha,1)
    G.db.hideBlizzard='arena'; hooks.CompactArenaFrame_Generate(); eq(CompactArenaFrame.alpha,0)
    G.db.hideBlizzard='never'; hooks.CompactArenaFrame_Generate(); eq(CompactArenaFrame.alpha,1)
end)
test('message dispatch caches order but observes live subscription changes', function()
    local savedModules = G.modules
    G.modules={}; G.moduleOrder=nil
    local low=G:NewModule('low',1); local high=G:NewModule('high',10)
    local order={}
    low.Run=function() order[#order+1]='low' end
    high.Run=function() order[#order+1]='high'; low:UnregisterMessage('PING') end
    high:RegisterMessage('PING','Run'); low:RegisterMessage('PING','Run')
    local cached=G:GetModuleOrder()
    dispatch(G,'PING'); eq(#order,1); eq(order[1],'high')
    eq(G:GetModuleOrder(),cached)
    local highest=G:NewModule('highest',20)
    assert(G:GetModuleOrder()~=cached); eq(G:GetModuleOrder()[1],highest)
    G.modules=savedModules; G.moduleOrder=nil
end)
test('aura snapshots reuse tuples, detect removal and preserve public current map',function()
    local b=G.buttons.arena1; b.class='MAGE'; b.race='Human'; b.spec='Frost'
    b.constellation=C[371796]; b.auras={}; b.lastAuras={}; b.auraCache={}
    local present=true
    auraProvider=function(unit,index,filter)
        if present and filter=='HELPFUL' and index==1 then
            return 'tracked',nil,'icon',1,nil,10,now+10,nil,nil,nil,12345
        end
    end
    E:UNIT_AURA('arena1')
    local tuple=b.lastAuras[12345]; local firstMap=b.lastAuras
    E:UNIT_AURA('arena1')
    eq(b.lastAuras[12345],tuple); eq(b.auras,b.lastAuras); assert(b.lastAuras~=firstMap)
    local fades=0
    G.modules.Cooldowns.cooldownSpellIds.tracked=12345
    G.modules.Cooldowns.AURA_FADE=function(_,unit,id) eq(id,12345); fades=fades+1 end
    present=false; E:UNIT_AURA('arena1'); eq(fades,1); eq(next(b.lastAuras),nil)
    G.modules.Cooldowns.cooldownSpellIds.tracked=nil; auraProvider=noop
end)
test('irrelevant combat damage exits before querying tracked source visibility',function()
    local before=unitQueries
    clear(); E:COMBAT_LOG_EVENT_UNFILTERED(now,'SWING_DAMAGE','unknown','Enemy',64,'other','Other',0,50)
    eq(#events,0); eq(#calls,0); eq(unitQueries,before)
end)
test('damage spell can still identify a specialization',function()
    local b=G.buttons.arena1; b.class='MAGE'; b.race='Human'; b.spec=nil
    G.specSpells['spec-damage']='Frost'
    E:COMBAT_LOG_EVENT_UNFILTERED(now,'SPELL_DAMAGE','enemy','Enemy',64,'other','Other',0,123,'spec-damage',1)
    eq(b.spec,G.L['Frost']); G.specSpells['spec-damage']=nil
end)
test('event errors are not silently swallowed when debug is disabled',function()
    E.BROKEN=function() error('intentional-test-error') end
    local ok,err=pcall(E.OnEvent,E,'BROKEN')
    eq(ok,false); assert(err:find('intentional%-test%-error')); E.BROKEN=nil
end)
print('PASS: ' .. passed .. ' regression tests (Lua ' .. _VERSION .. ')')
