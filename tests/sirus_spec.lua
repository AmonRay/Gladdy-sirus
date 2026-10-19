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
local guidProvider=function(unit) return unit end
UnitGUID = function(unit) return guidProvider(unit) end
UnitIsUnit = function(a, b) return a == b end
UnitCastingInfo, UnitChannelInfo = noop, noop
local auraProvider = noop
UnitAura = function(...) return auraProvider(...) end
CreateFrame = function()
    return {scripts={}, RegisterEvent=noop,
        SetScript=function(self,name,fn) self.scripts[name]=fn end,
        UnregisterEvent=noop, UnregisterAllEvents=noop}
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
local healthValue,healthMaximum=0,100
local healthQueries=0
UnitHealth=function() healthQueries=healthQueries+1; return healthValue end
UnitHealthMax=function() return healthMaximum end
UnitIsDeadOrGhost=function() return false end
SetPortraitTexture=noop
local scheduled,cancelled={},{}
G.ScheduleTimer=function(_,fn) local id={fn=fn}; scheduled[#scheduled+1]=id; return id end
G.ScheduleRepeatingTimer=G.ScheduleTimer
G.CancelTimer=function(_,id) cancelled[id]=true end
G.curBracket=1; G.frame={testing=false}
G.isFeignDeath=function() return false end
dofile('Gladdy/Modules/Healthbar.lua')
dofile('Gladdy/Modules/Powerbar.lua')
local H,P=G.modules['Health Bar'],G.modules['Power Bar']
local function bar()
    return {hp={SetStatusBarColor=noop,SetValue=noop,SetMinMaxValues=noop},
        nameText={SetText=noop},healthText={SetText=noop},portrait={SetTexture=noop},
        SetAlpha=noop,scripts={},SetScript=function(self,k,v) self.scripts[k]=v end}
end
H.frames={arena1=bar()}
H.SetText=noop; H.SetHealthStatusBarColor=noop
P.frames={arena1={energy={max=100,powerType=0}}}; P.SetPower=noop
test('zero health with known max is accepted without recursive retries',function()
    scheduled={}; healthValue=0; healthMaximum=100
    H:ENEMY_SPOTTED('arena1'); eq(#scheduled,0); eq(H.frames.arena1.hp.current,0)
end)
test('missing health retries are deduplicated and bounded to three',function()
    scheduled={}; healthMaximum=0; H.frames.arena1.healthRetryAttempts=0
    H:ENEMY_SPOTTED('arena1'); H:ENEMY_SPOTTED('arena1'); eq(#scheduled,1)
    scheduled[1].fn(); scheduled[2].fn(); scheduled[3].fn(); eq(#scheduled,3)
    eq(H.frames.arena1.healthRetry,nil)
end)
test('health retry cannot refresh a replacement GUID and reset cancels it',function()
    H.frames.arena1.healthRetryAttempts=0; scheduled={}
    H:ENEMY_SPOTTED('arena1'); eq(#scheduled,1)
    local before=healthQueries
    guidProvider=function(unit) return 'replacement-'..unit end
    scheduled[1].fn(); eq(healthQueries,before)
    guidProvider=function(unit) return unit end
    H.frames.arena1.healthRetryAttempts=0; H:ENEMY_SPOTTED('arena1')
    local pending=H.frames.arena1.healthRetry; H:ResetUnit('arena1'); eq(cancelled[pending],true)
end)
test('repeated death events enqueue no health or resource rescan',function()
    scheduled={}; H:UNIT_DEATH('arena1'); H:UNIT_DEATH('arena1'); P:UNIT_DEATH('arena1')
    eq(#scheduled,0)
end)
test('SpotEnemy removes stale GUID mapping on a reused arena slot',function()
    G.buttons.arena1.guid='old'; G.guids.old='arena1'
    G:SpotEnemy('arena1',false); eq(G.guids.old,nil); eq(G.guids.arena1,'arena1')
end)
dofile('Gladdy/Modules/Pets.lua')
local Pets=G.modules.Pets
Pets.frames={arenapet1={healthBar=bar()}}; local petBar=Pets.frames.arenapet1.healthBar
petBar.unit='arenapet1'; G.db.petEnabled=true; G.db.petHealthBarColor={}; G.SetColor=function() return 1,1,1,1 end
local rendered=0; Pets.SetHealthText=function() rendered=rendered+1 end
test('pet polling is throttled, updates max health, and renders only changes',function()
    healthValue=50; healthMaximum=100; Pets:PET_SPOTTED('arenapet1')
    eq(G.guids.arenapet1,'arenapet1'); eq(petBar.scripts.OnUpdate,Pets.OnUpdate)
    local before=healthQueries; rendered=0
    for i=1,600 do Pets.OnUpdate(petBar,1/60) end
    assert(healthQueries-before>=99 and healthQueries-before<=100)
    eq(rendered,0)
    healthMaximum=150; Pets.OnUpdate(petBar,0.1); eq(rendered,1)
end)
test('pet destruction and disabling clean GUIDs and polling handlers',function()
    Pets:PET_DESTROYED('arenapet1'); eq(G.guids.arenapet1,nil); eq(petBar.scripts.OnUpdate,nil)
    Pets:PET_SPOTTED('arenapet1'); G.db.petEnabled=false; Pets:UpdateFrameOnce()
    eq(petBar.scripts.OnUpdate,nil); eq(G.guids.arenapet1,nil); eq(Pets.active,false)
    Pets:PET_SPOTTED('unknown'); G.db.petEnabled=true
end)
dofile('Gladdy/Modules/RangeCheck.lua')
local Range=G.modules['Range Check']; Range.SetColor=noop
G.buttons.arena1.range={}; local rangeTimer=G.buttons.arena1.range
test('disabling range module cancels polling; reenabling restarts once',function()
    G.db.rangeCheckEnabled=false; Range:UpdateFrameOnce()
    eq(cancelled[rangeTimer],true); eq(G.buttons.arena1.range,nil)
    G.db.rangeCheckEnabled=true; scheduled={}; Range:UpdateFrameOnce(); eq(#scheduled,1)
    Range:UpdateFrameOnce(); eq(#scheduled,1)
end)
dofile('Gladdy/Modules/CombatIndicator.lua')
local CI=G.modules['Combat Indicator']; CI:Initialize(); G.db.ciEnabled=true
test('disabling combat indicator detaches OnUpdate and reenables safely',function()
    CI:JOINED_ARENA(); eq(CI.scripts.OnUpdate,CI.OnEvent)
    G.db.ciEnabled=false; CI:UpdateFrameOnce(); eq(CI.scripts.OnUpdate,nil)
    G.db.ciEnabled=true; CI:UpdateFrameOnce(); eq(CI.scripts.OnUpdate,CI.OnEvent)
    G.curBracket=nil; CI.OnEvent(CI,0.1); eq(CI.scripts.OnUpdate,nil)
end)
floor=math.floor; SlashCmdList={}
local savedDefaults=G.defaults
dofile('Gladdy/Options.lua'); G.defaults=savedDefaults
local function font()
    return {writes=0, text='',GetText=function(self) return self.text end,
        SetText=function(self,t) self.text=t; self.writes=self.writes+1 end}
end
test('timer preserves seconds, tenths, minutes, negative and externally reset text',function()
    local f=font(); G.db.timerFormat='seconds'
    G:FormatTimer(f,9.9); eq(f.text,'10')
    G:FormatTimer(f,9.1); eq(f.writes,1)
    G:FormatTimer(f,60); eq(f.text,'1m')
    G:FormatTimer(f,61,true,true); eq(f.text,'1:01')
    G.db.timerFormat='tenths'; G:FormatTimer(f,2.36,true); eq(f.text,'2.4')
    f.text='external'; G:FormatTimer(f,2.36,true); eq(f.text,'2.4')
    G:FormatTimer(f,-0.01); eq(f.text,'')
end)
test('600 timer ticks do not repeat identical UI text writes',function()
    local f=font(); G.db.timerFormat='seconds'
    for i=0,599 do G:FormatTimer(f,20-i/60) end
    eq(f.writes,10)
end)
local fake
fake=function()
    return setmetatable({scripts={},SetScript=function(self,k,v) self.scripts[k]=v end,
        GetAlpha=function() return 0.01 end,GetWidth=function() return 80 end,
        CreateTexture=function() return fake() end,CreateFontString=function() return fake() end},
        {__index=function() return noop end})
end
CreateFrame=fake; G.SMFetch=function() return 'font' end
test('icon expiry emits READY once and stops before rendering expired data',function()
    local f=G:CreateIconFrame(nil,nil,{frameLevel=1,fontScale=1,hasBackdrop=true})
    f.unit='arena1'; f.timeLeft=0.01; f.active=true; clear()
    f.scripts.OnUpdate(f,0.02); eq(f.active,false); eq(count('TRINKET_READY'),1)
    f.scripts.OnUpdate(f,0.02); eq(count('TRINKET_READY'),1)
end)
dofile('Gladdy/Modules/Castbar.lua')
local Cast=G.modules['Cast Bar']; local cb=fake()
cb.unit='arena1'; cb.bar=fake(); cb.icon=fake(); cb.icon.texture=fake()
cb.spellText=fake(); cb.timeText=fake(); cb.bg=fake(); cb.backdrop=fake(); cb.spark=fake(); cb.shield=fake()
Cast.frames={arena1=cb}; G.db.castBarColor={}
test('cast update runs only during a cast or fade and restarts on next cast',function()
    Cast:CAST_START('arena1','spell','icon',0,2,false,'cast'); eq(cb.scripts.OnUpdate,Cast.OnUpdate)
    cb.fadeOut=false; Cast:CAST_STOP('arena1'); eq(cb.scripts.OnUpdate,nil)
    Cast:CAST_START('arena1','spell','icon',0,2,false,'channel'); eq(cb.scripts.OnUpdate,Cast.OnUpdate)
    cb.casting=false; cb.channeling=false; cb.fadeOut=true; cb.holdTime=0
    Cast.OnUpdate(cb,0.1); eq(cb.scripts.OnUpdate,nil)
    Cast:CAST_START('arena1','spell','icon',0,2,false,'cast'); eq(cb.scripts.OnUpdate,Cast.OnUpdate)
end)
print('PASS: ' .. passed .. ' regression tests (Lua ' .. _VERSION .. ')')
