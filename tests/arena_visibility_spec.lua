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
local guid='enemy-guid'
GetTime=function() return now end
GetSpellInfo=function(id) return 'spell'..id,'','icon'..id end
GetItemInfo=function() return nil end
UnitExists=function(unit) return visible and unit=='arena1' end
UnitIsUnit=function(a,b) return (visible or identityWhileHidden) and a==b end
UnitGUID=function(unit) if UnitExists(unit) and not partial then return guid end end
UnitName=function(unit) if UnitExists(unit) and not partial then return 'Enemy' end end
UnitClass=function(unit) if UnitExists(unit) and not partial then return class,class end end
UnitRace=function(unit) if UnitExists(unit) and not partial then return 'Human','Human' end end
UnitAura=noop;UnitCastingInfo=noop;UnitChannelInfo=noop
UnitHealth=function() return visible and 80 or 0 end
UnitHealthMax=function() return visible and 100 or 0 end
UnitPower=function() return visible and 60 or 0 end
UnitPowerMax=function() return visible and 100 or 0 end
UnitPowerType=function() return 0 end
UnitIsDead=function() return false end;UnitIsDeadOrGhost=UnitIsDead
IsInInstance=function() return instance~='none',instance end
InCombatLockdown=function() return combat end
IsAddOnLoaded=function() return false end
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
dofile('Gladdy/Constants_shared.lua');dofile('Gladdy/Constants_Wrath.lua')
G.defaults={profile={}};G.specBuffs=G:GetSpecBuffs();G.specSpells=G:GetSpecSpells()
G.SMFetch=function() return 'font' end
G.SetColor=function(_,color,factor,alpha) return color.r,color.g,color.b,alpha or color.a end
G.FormatTimer=function(_,font,left) font:SetText(tostring(math.ceil(left))) end
G.isFeignDeath=function() return false end
G.ScheduleTimer=function(_,fn) return {fn=fn} end;G.CancelTimer=noop
for _,file in ipairs({'Cooldowns','Healthbar','Powerbar','Trinket','Racial'}) do dofile('Gladdy/Modules/'..file..'.lua') end
dofile('Gladdy/EventListener.lua')
local C,H,P,T,R,E=G.modules.Cooldowns,G.modules['Health Bar'],G.modules['Power Bar'],G.modules.Trinket,G.modules.Racial,G.modules.EventListener
local function copy(tbl) local result={};for k,v in pairs(tbl) do result[k]=type(v)=='table' and copy(v) or v end;return result end
local function setup(enemyClass)
    for _,name in ipairs(wow.names) do if name:match('^Gladdy') then _G[name]=nil end end
    class=enemyClass or 'ROGUE';now=100;visible=true;instance='arena';partial=false;combat=false;identityWhileHidden=false;guid='enemy-guid'
    G.db=copy(G.defaults.profile);G.db.locked=true;G.db.hideBlizzard='never'
    G.buttons={};G.guids={};G.curBracket=1;G.frame=CreateFrame('Frame');G.frame.testing=false
    G.showFrame=nil;G.hideFrame=nil;G.startTest=nil;G.pendingButtonCount=nil;G.pendingClique=nil
    for _,module in G:IterModules() do G:Call(module,'Initialize') end
    G:CreateButton(1)
    local button=G.buttons.arena1
    button.alpha=1;button.SetAlpha=function(self,alpha) self.alpha=alpha end
    button.healthBar.hp.current=80;button.healthBar.hp.max=100
    button.powerBar.energy.current=60;button.powerBar.energy.max=100
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
local function effectiveVisible(frame)
    while frame do if not frame:IsShown() then return false end;frame=frame:GetParent() end
    return true
end
local function advance(seconds)
    now=now+seconds
    for _,icon in ipairs(G.buttons.arena1.spellCooldownFrame.icons) do
        local update=icon:GetScript('OnUpdate');if update then update(icon,seconds) end
    end
    for _,module in ipairs({T,R}) do local frame=module.frames.arena1;frame:GetScript('OnUpdate')(frame,seconds) end
end
for _,enemyClass in ipairs({'ROGUE','MAGE','DRUID'}) do
    for _,reason in ipairs({'unseen','destroyed'}) do
        test(enemyClass..' '..reason..' keeps the same visible cooldown icons and running timers',function()
            local button,icon=setup(enemyClass)
            local frame=button.spellCooldownFrame;local icons=frame.icons;local count=#icons
            local cd,tc,rc=icon.timeLeft,T.frames.arena1.timeLeft,R.frames.arena1.timeLeft
            identityWhileHidden=reason=='destroyed';visible=false;E:ARENA_OPPONENT_UPDATE('arena1',reason);advance(5)
            assert(button.stealthed and button.alpha==1 and effectiveVisible(button))
            assert(frame==button.spellCooldownFrame and frame.icons==icons and #icons==count)
            assert(icon:GetParent()==frame and effectiveVisible(icon) and icon.active and icon.timeLeft==cd-5)
            assert(T.frames.arena1.active and T.frames.arena1.timeLeft==tc-5)
            assert(R.frames.arena1.active and R.frames.arena1.timeLeft==rc-5)
            assert(G.guids['enemy-guid']=='arena1' and button.guid=='enemy-guid' and button.name=='Enemy' and button.class==enemyClass)
            visible=true;E:ARENA_OPPONENT_UPDATE('arena1','seen')
            assert(not button.stealthed and #icons==count and icon:GetParent()==frame and icon.timeLeft==cd-5)
        end)
    end
end
test('canonical arena tokens resolve while UnitIsUnit returns false',function()
    setup();visible=false
    for i=1,5 do
        assert(G:GetArenaUnit('arena'..i)=='arena'..i)
        assert(G:GetArenaUnit('arenapet'..i)=='arenapet'..i)
        assert(G:GetArenaUnit('arenapet'..i,true)=='arena'..i)
    end
    assert(G:GetArenaUnit('arena6')==nil and G:GetArenaUnit('arena1target')==nil)
end)
test('repeated unseen destroyed seen cycles neither detach nor duplicate cooldown icons',function()
    local button,icon=setup();local frame=icon:GetParent();local count=#frame.icons;local left=icon.timeLeft
    for i=1,3 do
        visible=false;E:ARENA_OPPONENT_UPDATE('arena1','unseen');E:ARENA_OPPONENT_UPDATE('arena1','destroyed');advance(2)
        visible=true;E:ARENA_OPPONENT_UPDATE('arena1','seen');E:ARENA_OPPONENT_UPDATE('arena1','seen')
    end
    assert(#frame.icons==count and icon:GetParent()==frame and icon.timeLeft==left-6 and effectiveVisible(icon))
    assert(#C.iconCache==0)
end)
test('combat log from a cached hidden enemy still records new cooldowns',function()
    local button=setup('ROGUE');local id=31224
    local icon;for _,candidate in ipairs(button.spellCooldownFrame.icons) do if candidate.spellId==id then icon=candidate end end
    assert(icon and not icon.active)
    visible=false;E:ARENA_OPPONENT_UPDATE('arena1','destroyed')
    E:COMBAT_LOG_EVENT_UNFILTERED(now,'SPELL_CAST_SUCCESS','enemy-guid','Enemy',64,'other','Other',0,id,GetSpellInfo(id),1)
    assert(icon.active and icon.timeLeft>0 and effectiveVisible(icon))
end)
test('partial seen data cannot erase the cached GUID class race name or constellation',function()
    local button,icon=setup();local constellation=button.constellation
    partial=true;E:ARENA_OPPONENT_UPDATE('arena1','seen')
    assert(button.guid=='enemy-guid' and G.guids['enemy-guid']=='arena1')
    assert(button.name=='Enemy' and button.class=='ROGUE' and button.race=='Human' and button.constellation==constellation and icon.active)
end)
test('unavailable health power name and aura events leave last-known state intact',function()
    local button=setup();button.lastAuras={[123]={AURA_TYPE_BUFF,123,'saved'}};local saved=button.lastAuras
    visible=false;E:ARENA_OPPONENT_UPDATE('arena1','unseen')
    H.OnEvent(button.healthBar,'UNIT_HEALTH','arena1');H.OnEvent(button.healthBar,'UNIT_NAME_UPDATE','arena1')
    P.OnEvent(button.powerBar,'UNIT_MANA','arena1');E:UNIT_AURA('arena1')
    assert(button.healthBar.hp.current==80 and button.healthBar.hp.max==100 and button.name=='Enemy')
    assert(button.powerBar.energy.current==60 and button.powerBar.energy.max==100)
    assert(button.lastAuras==saved and button.lastAuras[123])
end)
test('PLAYER_ENTERING_WORLD inside arena does not reset frames GUIDs or cooldowns',function()
    local button,icon=setup();local left=icon.timeLeft
    visible=false;G:PLAYER_ENTERING_WORLD()
    assert(G.curBracket==1 and G.frame:IsShown() and button.alpha==1 and G.guids['enemy-guid']=='arena1')
    assert(icon.active and icon.timeLeft==left and effectiveVisible(icon))
end)
test('arena status refresh with no visible enemies preserves active cooldown icons',function()
    local button,icon=setup();local left=icon.timeLeft;local parent=icon:GetParent()
    visible=false;local original=G.UpdateFrame;G.UpdateFrame=noop
    G:UPDATE_BATTLEFIELD_STATUS(nil,1);G.UpdateFrame=original
    assert(G.curBracket==2 and icon.active and icon.timeLeft==left and icon:GetParent()==parent and button.alpha==1)
end)
test('real arena entry discards test-mode data rather than retaining simulated cooldowns',function()
    local button,icon=setup();G.frame.testing=true
    local original=G.UpdateFrame;G.UpdateFrame=noop;G:JoinedArena();G.UpdateFrame=original
    assert(not G.frame.testing and G.curBracket==1 and button.guid=='enemy-guid')
    for _,candidate in ipairs(button.spellCooldownFrame.icons) do assert(not candidate.active) end
    assert(not T.frames.arena1.active and not R.frames.arena1.active)
end)
test('unrelated UNIT_DESTROYED message cannot clear class cooldowns',function()
    local button,icon=setup();local count=#button.spellCooldownFrame.icons
    G:SendMessage('UNIT_DESTROYED','arena1')
    assert(icon.active and #button.spellCooldownFrame.icons==count and effectiveVisible(icon))
end)
test('death notification retains cooldown history until arena exit',function()
    local button,icon=setup();local count=#button.spellCooldownFrame.icons
    G:SendMessage('UNIT_DEATH','arena1')
    assert(icon.active and #button.spellCooldownFrame.icons==count and effectiveVisible(icon))
end)
test('natural cooldown expiry while hidden keeps the icon in its block',function()
    local button,icon=setup();local parent=icon:GetParent();local count=#parent.icons
    visible=false;E:ARENA_OPPONENT_UPDATE('arena1','destroyed');advance(icon.timeLeft+1)
    assert(not icon.active and #parent.icons==count and icon:GetParent()==parent and effectiveVisible(icon))
    assert(#C.iconCache==0)
end)
test('leaving arena clears cooldown icons GUIDs identity and trinket racial state',function()
    local button,icon=setup();visible=false;E:ARENA_OPPONENT_UPDATE('arena1','destroyed')
    instance='none';G:PLAYER_ENTERING_WORLD()
    assert(G.curBracket==nil and not G.frame:IsShown() and button.alpha==0 and next(G.guids)==nil)
    assert(button.guid==nil and button.class==nil and button.name==nil and #button.spellCooldownFrame.icons==0)
    assert(not icon.active and not icon:IsShown() and icon:GetParent()==nil and icon:GetScript('OnUpdate')==nil)
    assert(not T.frames.arena1.active and not R.frames.arena1.active and E:GetScript('OnEvent')==nil)
end)
test('exit during combat clears state immediately and defers hiding only',function()
    local button,icon=setup();instance='none';combat=true
    G:PLAYER_ENTERING_WORLD();assert(not icon.active and next(G.guids)==nil and G.hideFrame)
    combat=false;G:PLAYER_REGEN_ENABLED()
    assert(not G.frame:IsShown() and not G.hideFrame and #button.spellCooldownFrame.icons==0)
end)
test('pet disappearance stays separate from retained player cooldowns',function()
    local button,icon=setup();local destroyed=0
    local pets=G:NewModule('Pets',nil,{});pets.frames={arenapet1={}}
    pets:RegisterMessage('PET_DESTROYED');pets.PET_DESTROYED=function(_,unit) assert(unit=='arenapet1');destroyed=destroyed+1 end
    visible=false;E:ARENA_OPPONENT_UPDATE('arenapet1','destroyed')
    assert(destroyed==1 and icon.active and button.class=='ROGUE')
end)
test('visibility integration reports no swallowed UI errors',function() assert(#wow.errors==0,table.concat(wow.errors,'\n')) end)
print('PASS: '..passed..' arena visibility retention tests')
