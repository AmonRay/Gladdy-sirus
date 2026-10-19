local n=0
local function test(name,fn)
    local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));n=n+1;print('ok '..n..' - '..name)
end
local wow=dofile('tests/wow_ui_stub.lua');wow.install()
local mode=arg and arg[1] or 'mixed'
local function missing(id) return mode=='missing' or (mode=='mixed' and (id==50334 or id==56638 or id==8170)) end
GetSpellInfo=function(id) if not missing(id) then return 'spell'..id,'','icon'..id end end
GetItemInfo=function() return nil end
local G={}
LibStub=setmetatable({NewLibrary=function() return G end},{__call=function(_,name) if name=='Gladdy' then return G end return {Embed=function() end} end})
dofile('Gladdy/Gladdy.lua');dofile('Gladdy/Lang.lua')
G.AddEntriesToTable=function(_,target,source) for k,v in pairs(source) do if not target[k] then target[k]=v end end end
AURA_TYPE_DEBUFF,AURA_TYPE_BUFF='DEBUFF','BUFF'
dofile('Gladdy/Constants_shared.lua');dofile('Gladdy/Constants_Wrath.lua')
test('constant tables load even when spell information is unavailable',function()
    assert(type(G:GetSpecBuffs())=='table' and type(G:GetSpecSpells())=='table' and type(G:GetImportantAuras())=='table')
    assert(type(G:GetInterrupts())=='table' and type(G:GetTotemData())=='table')
end)
test('temporary missing keys are not exposed to consumers',function()
    local _,_,pulses=G:GetTotemData()
    for _,tbl in ipairs({G:GetSpecBuffs(),G:GetSpecSpells(),G:GetImportantAuras(),G:GetInterrupts(),pulses}) do
        for key in pairs(tbl) do assert(type(key)=='string' or type(key)=='number') end
    end
end)
test('available spell names and suffix keys remain unchanged',function()
    if mode=='available' then
        assert(G:GetSpecBuffs().spell56638=='Arms')
        assert(G:GetSpecSpells()['spell50334 Feral']=='Feral')
    elseif mode=='mixed' then
        assert(G:GetSpecSpells().spell47486=='Arms' and G:GetSpecSpells()['spell50334 Feral']==nil)
    else
        assert(next(G:GetSpecBuffs())==nil and next(G:GetSpecSpells())==nil)
    end
end)
test('unavailable IDs are deduplicated and numerical totem fallback survives',function()
    if mode=='available' then assert(next(G.missingSpellIDs)==nil)
    else assert(G.missingSpellIDs[56638] and G.missingSpellIDs[50334] and G.missingSpellIDs[8170]) end
    local _,_,pulses=G:GetTotemData();assert(pulses[8143]==3)
end)
G.defaults={profile={}}
tinsert=table.insert;tremove=table.remove;format=string.format
local dr={GetSpells=function() return {[50334]='stun',[8170]='stun',[56638]='stun'} end}
local oldIndex=getmetatable(LibStub).__call
getmetatable(LibStub).__call=function(self,name) if name=='DRList-1.0' then return dr end return oldIndex(self,name) end
dofile('Gladdy/Modules/Announcements.lua')
dofile('Gladdy/Modules/Diminishings.lua')
dofile('Gladdy/Modules/Cooldowns.lua')
dofile('Gladdy/Modules/TotemPlates.lua')
G.db=G.defaults.profile
LOCALIZED_CLASS_NAMES_MALE=setmetatable({},{__index=function(_,key) return key end})
CLASS_ICON_TCOORDS={}
test('resurrection initialization ignores unavailable spell names',function()
    local module=G.modules.Announcements;module:Initialize()
    for key in pairs(module.RES_SPELLS) do assert(type(key)=='string') end
    assert((next(module.RES_SPELLS)==nil)==(mode=='missing'))
end)
test('DR icon selector omits missing textures without nil keys',function()
    local icons=G.modules.Diminishings:GetDRIcons('stun')
    if mode=='available' then assert(icons.icon50334) else assert(next(icons)==nil) end
end)
test('cooldown option labels remain strings for unavailable IDs',function()
    local options=G.modules.Cooldowns:GetCooldownOptions()
    for _,class in pairs(options) do
        for _,spell in pairs(class.args) do assert(type(spell.args.toggle.name)=='string') end
    end
    assert(type(options.DRUID.args['50334'].args.toggle.name)=='string')
end)
print('PASS: '..n..' spell data tests ('..mode..')')
