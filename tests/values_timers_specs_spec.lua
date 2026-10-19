local passed=0
local function test(name,fn)
    local ok,err=xpcall(fn,debug.traceback);assert(ok,name..': '..tostring(err));passed=passed+1;print('ok '..passed..' - '..name)
end
local wow=dofile('tests/wow_ui_stub.lua');wow.install()
local noop=function() end
local now,visible,instance,class=100,true,'arena','ROGUE'
local identityWhileHidden=false
local partial=false
local combat=false
local party,raid,chat,printed,notices,combatText,loaded=0,0,{},{},{},{},{}
local guid='enemy-guid'
local castName
GetTime=function() return now end
GetSpellInfo=function(id) return 'spell'..id,'','icon'..id end
GetItemInfo=function() return nil end
UnitExists=function(unit) return visible and unit=='arena1' end
UnitIsUnit=function(a,b) return (visible or identityWhileHidden) and a==b end
UnitGUID=function(unit) if UnitExists(unit) and not partial then return guid end end
UnitName=function(unit) if UnitExists(unit) and not partial then return 'Enemy' end end
UnitClass=function(unit) if UnitExists(unit) and not partial then return class,class end end
UnitRace=function(unit) if UnitExists(unit) and not partial then return 'Human','Human' end end
UnitAura=noop;UnitCastingInfo=function() return castName end;UnitChannelInfo=noop
SetPortraitTexture=noop;GetNumPartyMembers=function() return party end;GetNumRaidMembers=function() return raid end
SendChatMessage=function(msg,dest) chat[#chat+1]={msg,dest} end
RaidNotice_AddMessage=function(_,msg) notices[#notices+1]=msg end
CombatText_AddMessage=function(msg) combatText[#combatText+1]=msg end
UnitHealth=function() return visible and 80 or 0 end
UnitHealthMax=function() return visible and 100 or 0 end
UnitPower=function() return visible and 60 or 0 end
UnitPowerMax=function() return visible and 100 or 0 end
UnitPowerType=function() return 0 end
UnitIsDead=function() return false end;UnitIsDeadOrGhost=UnitIsDead
IsInInstance=function() return instance~='none',instance end
InCombatLockdown=function() return combat end
IsAddOnLoaded=function(name) return loaded[name] or false end
GetNumArenaOpponents=function() return visible and 1 or 0 end
GetBattlefieldStatus=function() return 'active',nil,nil,nil,nil,2 end
AURA_TYPE_BUFF,AURA_TYPE_DEBUFF='BUFF','DEBUFF'
COMBATLOG_OBJECT_REACTION_HOSTILE=64
bit={band=function(a,b) return a==b and b or 0 end}
tinsert=table.insert;tremove=table.remove;format=string.format;mod=math.fmod
RAID_CLASS_COLORS=setmetatable({},{__index=function() return {r=1,g=1,b=1} end})
local G={}
LibStub=setmetatable({NewLibrary=function() return G end},{__call=function(_,name)
    if name=='Gladdy' then return G end
    return {Embed=noop,PixelGlow_Stop=noop,PixelGlow_Start=noop}
end})
dofile('Gladdy/Gladdy.lua');dofile('Gladdy/Lang.lua');dofile('Gladdy/Frame.lua');dofile('Gladdy/Util.lua')
SlashCmdList={};dofile('Gladdy/Options.lua')
dofile('Gladdy/Constants_shared.lua');dofile('Gladdy/Constants_Wrath.lua')
G.specBuffs=G:GetSpecBuffs();G.specSpells=G:GetSpecSpells()
G.SMFetch=function() return 'font' end
G.isFeignDeath=function() return false end
G.ScheduleTimer=function(_,fn) return {fn=fn} end;G.CancelTimer=noop
for _,file in ipairs({'Cooldowns','Healthbar','Powerbar','Trinket','Racial','Classicon','Pets','Announcements'}) do dofile('Gladdy/Modules/'..file..'.lua') end
dofile('Gladdy/EventListener.lua')
local C,H,P,T,R,E=G.modules.Cooldowns,G.modules['Health Bar'],G.modules['Power Bar'],G.modules.Trinket,G.modules.Racial,G.modules.EventListener
local function copy(tbl) local result={};for k,v in pairs(tbl) do result[k]=type(v)=='table' and copy(v) or v end;return result end
G.UpdateFrame=noop
local A=G.modules.Announcements;local originalSend=A.Send
G.Print=function(_,msg) printed[#printed+1]=msg end
local function setup(enemyClass,unknown)
    for _,name in ipairs(wow.names) do if name:match('^Gladdy') then _G[name]=nil end end
    party,raid,chat,printed,notices,combatText,loaded=0,0,{},{},{},{},{};A.Send=originalSend;MikSBT=nil
    class=enemyClass or 'ROGUE';now=100;visible=not unknown;instance='arena';partial=false;combat=false;identityWhileHidden=false;guid='enemy-guid'
    G.db=copy(G.defaults.profile);G.db.locked=true;G.db.hideBlizzard='never';G.db.announcements.enemy=false
    G.buttons={};G.guids={};G.curBracket=1;G.frame=CreateFrame('Frame');G.frame.testing=false
    G.showFrame=nil;G.hideFrame=nil;G.startTest=nil;G.pendingButtonCount=nil;G.pendingClique=nil
    for _,module in G:IterModules() do G:Call(module,'Initialize') end
    G:CreateButton(1)
    local button=G.buttons.arena1
    button.alpha=1;button.SetAlpha=function(self,alpha) self.alpha=alpha end
    button.healthBar.hp.current=80;button.healthBar.hp.max=100
    button.powerBar.energy.current=60;button.powerBar.energy.max=100
    if unknown then G:JoinedArena();return button end
    E:JOINED_ARENA()
    button.constellation=G:Constellations()[371796]
    G:SendMessage('ENEMY_SPOTTED','arena1')
    local id=class=='ROGUE' and 26889 or class=='MAGE' and 2139 or 22812
    C:CooldownUsed('arena1',class,id)
    local icon
    for _,candidate in ipairs(button.spellCooldownFrame.icons) do if candidate.spellId==id then icon=candidate end end
    assert(icon and icon.active)
    T:TRINKET_USED('arena1');R:RACIAL_USED('arena1')
    return button,icon,id
end
local function fontCounter(font)
    local counter={fonts=0,colors=0,texts=0}
    local setFont,setColor,setText=font.SetFont,font.SetTextColor,font.SetText
    font.SetFont=function(self,...) counter.fonts=counter.fonts+1;return setFont(self,...) end
    font.SetTextColor=function(self,...) counter.colors=counter.colors+1;counter.color={...};return setColor(self,...) end
    font.SetText=function(self,...) counter.texts=counter.texts+1;return setText(self,...) end
    return counter
end
test('ratios reject zero negative missing and non-finite maxima',function()
    for _,maximum in ipairs({0,-1,math.huge,-math.huge,0/0,'100'}) do assert(G:ValueRatio(50,maximum)==nil) end
    assert(G:ValueRatio(nil,100)==nil and G:ValueRatio(50,nil)==nil)
    assert(G:ValueRatio(0/0,100)==nil and G:ValueRatio(math.huge,100)==nil)
end)
test('valid ratios clamp to 0..1 including real zero health',function()
    assert(G:ValueRatio(0,100)==0 and G:ValueRatio(50,100)==0.5 and G:ValueRatio(100,100)==1)
    assert(G:ValueRatio(-5,100)==0 and G:ValueRatio(150,100)==1)
end)
test('health percent text is blank for unknown max and preserves valid zero',function()
    local button=setup();local bar=button.healthBar
    H:SetHealthText(bar,0,0);assert(bar.healthText:GetText()=='')
    H:SetHealthText(bar,0,nil);assert(bar.healthText:GetText()=='')
    H:SetHealthText(bar,0,100);assert(bar.healthText:GetText()=='0%')
    H:SetHealthText(bar,200,100);assert(bar.healthText:GetText()=='100%')
end)
test('health gradient never writes invalid values for unknown maximum',function()
    local button=setup();local bar=button.healthBar;G.db.healthBarClassColored=false;G.db.healthBarColoredByCurrentHp=true
    local calls=0;bar.hp.SetStatusBarColor=function(_,r,g,b) assert(r==r and g==g and b==b);calls=calls+1 end
    H:SetHealthStatusBarColor('arena1',50,0);assert(calls==0)
    H:SetHealthStatusBarColor('arena1',50,100);assert(calls==1)
end)
test('resource percent text safely handles zero nil and over-range maxima',function()
    local button=setup();G.db.powerActual=false;G.db.powerMax=false;G.db.powerPercentage=true
    for _,maximum in ipairs({0,-1,math.huge}) do P:SetText('arena1',50,maximum);assert(button.powerBar.powerText:GetText()=='') end
    P:SetText('arena1',0,nil);assert(button.powerBar.powerText:GetText()=='')
    P:SetText('arena1',0,100);assert(button.powerBar.powerText:GetText()=='0%')
    P:SetText('arena1',200,100);assert(button.powerBar.powerText:GetText()=='100%')
end)
test('custom percent tags and fallback tags handle unknown data',function()
    setup()
    assert(G:SetTag('arena1','[percent]',0,0)=='')
    assert(G:SetTag('arena1','[percent]',50,nil)=='')
    assert(G:SetTag('arena1','[percent]',50,100)=='50%')
    assert(G:SetTag('arena1','[current]',50,nil)=='50')
    assert(G:SetTag('arena1','[percent|status]',0,0,'UNKNOWN')=='UNKNOWN')
end)
test('pet percentages and low-health announcements reject unknown maxima',function()
    local button=setup();local Pets=G.modules.Pets;local bar={healthText=CreateFrame('Frame'):CreateFontString()}
    G.db.petHealthPercentage=true;Pets:SetHealthText(bar,0,nil);assert(bar.healthText:GetText()=='')
    Pets:SetHealthText(bar,50,100);assert(bar.healthText:GetText()=='50%')
    local A=G.modules.Announcements;G.db.announcements.health=true;local sent=0;A.Send=function() sent=sent+1 end
    button.healthMax=0;A:UNIT_HEALTH('arena1',1);assert(sent==0)
    button.healthMax=100;A:UNIT_HEALTH('arena1',1);assert(sent==1)
end)
test('class cooldown deadline survives a long gap without relying on elapsed',function()
    local button,icon=setup();local ending=icon.endTime;now=now+35
    icon:GetScript('OnUpdate')(icon,0.001)
    assert(icon.timeLeft==ending-now and icon.active)
    now=ending+1;icon:GetScript('OnUpdate')(icon,0)
    assert(not icon.active and icon.endTime==nil and icon:GetScript('OnUpdate')==nil and icon:GetParent()==button.spellCooldownFrame)
end)
test('class cooldown style and text are not written each frame',function()
    local _,icon=setup();local count=fontCounter(icon.cooldownFont);icon.cooldownFont.timerFont=nil;icon.cooldownFont.timerR=nil
    for i=1,60 do now=100+i/120;icon:GetScript('OnUpdate')(icon,1/120) end
    assert(count.fonts==1 and count.colors==1 and count.texts<=1)
end)
test('class timer style changes only at actual color boundaries',function()
    local _,icon=setup();local count=fontCounter(icon.cooldownFont);icon.endTime=now+12;icon.cooldownFont.timerR=nil
    icon:GetScript('OnUpdate')(icon,0);assert(count.color[2]==1)
    now=icon.endTime-10;icon:GetScript('OnUpdate')(icon,0);assert(count.color[2]==0.7)
    now=icon.endTime-4;icon:GetScript('OnUpdate')(icon,0);assert(count.color[2]==0)
    assert(count.colors==3)
end)
test('shared cooldown timers use absolute deadlines and cache formatting styles',function()
    setup();local trinket=T.frames.arena1;local count=fontCounter(trinket.cooldownFont)
    for i=1,60 do now=100+i/120;trinket:GetScript('OnUpdate')(trinket,0) end
    assert(trinket.timeLeft==trinket.endTime-now and count.fonts==1 and count.colors==1)
    assert(count.texts<=2)
    now=trinket.endTime+1;trinket:GetScript('OnUpdate')(trinket,0)
    assert(not trinket.active and trinket.endTime==nil)
end)
test('configuration refresh invalidates the cached font without resetting cooldown',function()
    local _,icon=setup();local ending=icon.endTime;local count=fontCounter(icon.cooldownFont)
    G.db.cooldownFontScale=2;C:UpdateIcon(icon);local before=count.fonts
    icon:GetScript('OnUpdate')(icon,0);assert(icon.endTime==ending and count.fonts==before+1)
    icon:GetScript('OnUpdate')(icon,0);assert(count.fonts==before+1)
end)
test('all class specialization keys accept English and Russian legacy names',function()
    setup()
    local classes={WARRIOR={'Arms','Fury','Protection'},PALADIN={'Holy','Protection','Retribution'},HUNTER={'Beast Mastery','Marksmanship','Survival'},ROGUE={'Assassination','Combat','Subtlety'},PRIEST={'Discipline','Holy','Shadow'},DEATHKNIGHT={'Blood','Frost','Unholy'},SHAMAN={'Elemental','Enhancement','Restoration'},MAGE={'Arcane','Fire','Frost'},WARLOCK={'Affliction','Demonology','Destruction'},DRUID={'Balance','Feral','Restoration'}}
    for className,keys in pairs(classes) do
        for _,key in ipairs(keys) do
            G:ApplyLanguage('ruRU');local russian=G:GetSpecName(key,className)
            G:ApplyLanguage('enUS');assert(G:NormalizeSpec(russian,className)==key and G:NormalizeSpec(key,className)==key)
        end
    end
    assert(G:NormalizeSpec('Frost','PALADIN')==nil and G:NormalizeSpec('unknown','MAGE')==nil)
end)
test('detecting specialization stores a canonical key after either language switch',function()
    local button=setup('MAGE');button.spec=nil;G:ApplyLanguage('ruRU');local russian=G.L.Frost
    G:ApplyLanguage('enUS');E:DetectSpec('arena1',russian);assert(button.spec=='Frost')
    G:ApplyLanguage('ruRU');assert(button.spec=='Frost' and G:GetSpecName(button.spec,button.class)==russian)
end)
test('runtime migration normalizes only known specialization fields',function()
    local button=setup('MAGE');G:ApplyLanguage('ruRU');button.spec=G.L.Frost;button.testSpec=G.L.Fire
    local unknown='custom user text';button.notes=unknown;local saved=G.db.cooldownCooldowns
    G:ApplyLanguage('enUS');assert(button.spec=='Frost' and button.testSpec=='Fire' and button.notes==unknown)
    assert(G.db.cooldownCooldowns==saved)
end)
test('spec-specific cooldown durations and filters survive language changes',function()
    local button=setup('MAGE');button.spec='Frost';C:UpdateCooldowns(button)
    G:ApplyLanguage('enUS');C:CooldownUsed('arena1','MAGE',45438)
    local ice;for _,icon in ipairs(button.spellCooldownFrame.icons) do if icon.spellId==45438 then ice=icon end end
    assert(ice and ice.timeLeft==240)
    G:ApplyLanguage('ruRU');assert(G:GetCooldownList().MAGE[45438].Frost==240)
    assert(G:GetCooldownList().MAGE[44572].spec=='Frost')
    assert(ice.timeLeft==240 and button.spec=='Frost')
end)
test('spec icons and tag labels translate at display time only',function()
    local button=setup('MAGE');button.spec='Frost';G.db.classIconSpecIcon=true;local icon=G.modules['Class Icon'].frames.arena1
    local texture;icon.texture.SetTexture=function(_,value) texture=value end
    G:ApplyLanguage('enUS');G.modules['Class Icon']:UNIT_SPEC('arena1','Frost');assert(texture=='icon116')
    assert(G:SetTag('arena1','[spec]',50,100)=='Frost')
    G:ApplyLanguage('ruRU');G.modules['Class Icon']:UNIT_SPEC('arena1','Frost');assert(texture=='icon116')
    assert(G:SetTag('arena1','[spec]',50,100)==G.L.Frost and button.spec=='Frost')
end)
test('canonical spec constants do not change when reloaded under another locale',function()
    setup();G:ApplyLanguage('enUS');local first=G:GetSpecSpells()['spell44572']
    G:ApplyLanguage('ruRU');dofile('Gladdy/Constants_Wrath.lua')
    assert(G:GetSpecSpells()['spell44572']==first and first=='Frost')
end)
test('unknown opponents stay hidden on entry and before their first seen event',function()
    local button=setup(nil,true)
    assert(not button.opponentKnown and button.alpha==0 and #button.spellCooldownFrame.icons==0)
    for _,reason in ipairs({'unseen','destroyed','seen'}) do
        E:ARENA_OPPONENT_UPDATE('arena1',reason)
        assert(not button.opponentKnown and button.alpha==0)
    end
end)
test('empty identity on a seen unit does not reveal an unknown opponent',function()
    local button=setup(nil,true);visible=true;partial=true
    E:ARENA_OPPONENT_UPDATE('arena1','seen')
    assert(not button.opponentKnown and button.alpha==0 and #button.spellCooldownFrame.icons==0)
end)
test('first identification reveals the frame and subsequent invisibility retains it',function()
    local button=setup(nil,true);visible=true
    E:ARENA_OPPONENT_UPDATE('arena1','seen');assert(button.opponentKnown and button.alpha==1)
    C:CooldownUsed('arena1','ROGUE',26889)
    local icons=button.spellCooldownFrame.icons;local active
    for _,icon in ipairs(icons) do if icon.spellId==26889 then active=icon end end
    local ending=active.endTime;visible=false
    E:ARENA_OPPONENT_UPDATE('arena1','destroyed');G:JoinedArena()
    assert(button.alpha==1 and button.opponentKnown and button.spellCooldownFrame.icons==icons and active.endTime==ending)
end)
test('leaving an arena clears known state before the next match',function()
    local button=setup();assert(button.opponentKnown)
    instance='none';G:PLAYER_ENTERING_WORLD();assert(not button.opponentKnown)
    instance='arena';visible=false;G.curBracket=1;G:JoinedArena()
    assert(button.alpha==0 and not button.opponentKnown and #button.spellCooldownFrame.icons==0)
end)
test('announcements send to party or raid and never spam the group in test mode',function()
    setup();party=1;A:Send('party');assert(#chat==1 and chat[1][2]=='PARTY')
    raid=2;A:Send('raid');assert(#chat==2 and chat[2][2]=='RAID')
    G.frame.testing=true;A:Send('test');assert(#chat==2 and printed[#printed]=='test')
    G.frame.testing=false;party=0;raid=0;A:Send('alone');assert(#chat==2)
end)
test('announcement throttle expires exactly at its deadline',function()
    setup();G.db.announcements.dest='self'
    A:Send('message',3,nil,'arena1');A:Send('message',3,nil,'arena1');assert(#printed==1)
    now=103;A:Send('message',3,nil,'arena1');assert(#printed==2)
    A:Send('message',3,nil,'arena2');assert(#printed==3)
end)
test('announcement destinations tolerate missing optional addons',function()
    setup();G.db.announcements.dest='msbt';loaded.MikScrollingBattleText=true;A:Send('missing')
    MikSBT={};A:Send('partial');local msbt=0
    MikSBT={Animations={DisplayMessage=function() msbt=msbt+1 end}};A:Send('available');assert(msbt==1)
    G.db.announcements.dest='rw';A:Send('notice');assert(notices[1]=='notice')
    G.db.announcements.dest='fct';A:Send('missing');assert(#combatText==0)
    loaded.Blizzard_CombatText=true;A:Send('available');assert(combatText[1]=='available')
end)
test('resurrection drinking and specialization announcements respect toggles and translations',function()
    local button=setup('MAGE');G.db.announcements.dest='self';printed={};G:ApplyLanguage('ruRU')
    A:CAST_START('arena1','spell50769');assert(#printed==1)
    G.db.announcements.resurrections=false;now=110;A:CAST_START('arena1','spell50769');assert(#printed==1)
    A.DRINK_AURA=nil;A:AURA_GAIN('arena1');assert(#printed==1)
    A.DRINK_AURA='drink';A:AURA_GAIN('arena1',nil,nil,'drink');assert(#printed==2)
    A:UNIT_SPEC('arena1','Frost');assert(#printed==3 and printed[3]:find(G.L.Frost,1,true))
    assert(G.defaults.profile.announcements.shadowsight==false)
    G.db.announcements.shadowsight=true;A:SHADOWSIGHT();assert(#printed==4)
end)
test('resurrection announcements do not depend on an enabled cast bar',function()
    setup();G.db.announcements.dest='self';G.db.castBarEnabled=false;printed={}
    castName='spell50769'
    E:UNIT_SPELLCAST_START('arena1');assert(#printed==1)
    E:UNIT_SPELLCAST_START('party1');assert(#printed==1)
    castName=nil
end)
test('live health publication updates maximum and announces only valid low health',function()
    local button=setup();G.db.announcements.dest='self';G.db.announcements.health=true;printed={}
    H:PublishHealth('arena1',10,100);assert(button.healthMax==100 and #printed==1)
    H:PublishHealth('arena1',10,100);assert(#printed==1)
    now=111;H:PublishHealth('arena1',0,100);assert(#printed==1)
    H:PublishHealth('arena1',10,0);assert(button.health==0 and button.healthMax==100 and #printed==1)
    H:PublishHealth('arena1',10,200);assert(button.healthMax==200 and #printed==2)
end)
test('new value timer and specialization paths report no swallowed UI errors',function() assert(#wow.errors==0,table.concat(wow.errors,'\n')) end)
print('PASS: '..passed..' value timer and specialization tests')
