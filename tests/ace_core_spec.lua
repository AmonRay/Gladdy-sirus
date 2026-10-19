local passed=0
local function test(name,fn)
    local ok,err=pcall(fn); assert(ok,name..': '..tostring(err)); passed=passed+1; print('ok '..passed..' - '..name)
end
local wow=dofile('tests/wow_ui_stub.lua'); wow.install()
strlower=string.lower
GetRealmName=function() return 'Sirus' end
UnitName=function() return 'Ray' end
UnitClass=function() return 'Mage','MAGE' end
UnitRace=function() return 'Human','Human' end
UnitFactionGroup=function() return 'Alliance' end
GetFramerate=function() return 60 end
UnitInRaid=function() return true end
GetNumPartyMembers=function() return 1 end
GetNumRaidMembers=function() return 2 end
local sends={}
SendChatMessage=function() end
SendAddonMessage=function(...) sends[#sends+1]={...} end
dofile('Gladdy/Libs/Ace3/LibStub/LibStub.lua')
dofile('Gladdy/Libs/Ace3/CallbackHandler-1.0/CallbackHandler-1.0.lua')
dofile('Gladdy/Libs/Ace3/AceDB-3.0/AceDB-3.0.lua')
dofile('Gladdy/Libs/Ace3/AceDBOptions-3.0/AceDBOptions-3.0.lua')
dofile('Gladdy/Libs/Ace3/AceSerializer-3.0/AceSerializer-3.0.lua')
dofile('Gladdy/Libs/Ace3/AceHook-3.0/AceHook-3.0.lua')
dofile('Gladdy/Libs/Ace3/AceComm-3.0/ChatThrottleLib.lua')
dofile('Gladdy/Libs/Ace3/AceComm-3.0/AceComm-3.0.lua')
local db
test('AceDB preserves existing saved profile and defaults',function()
    GladdyXZ={profileKeys={['Ray - Sirus']='Existing'},profiles={Existing={scale=1.2,custom='retained'}}}
    db=LibStub('AceDB-3.0'):New('GladdyXZ',{profile={scale=1,font='Default'}},true)
    assert(db:GetCurrentProfile()=='Existing' and db.profile.scale==1.2 and db.profile.custom=='retained')
    assert(db.profile.font=='Default' and GladdyXZ.profiles.Existing==db.profile)
end)
test('AceDB profile copy switch and reset retain API behavior',function()
    db:SetProfile('Copy'); db:CopyProfile('Existing'); assert(db.profile.scale==1.2)
    db.profile.scale=2; db:SetProfile('Existing'); assert(db.profile.scale==1.2)
    db:SetProfile('Copy'); db:ResetProfile(); assert(db.profile.scale==1 and not db.profile.custom)
    db:SetProfile('Existing'); db:DeleteProfile('Copy'); assert(not GladdyXZ.profiles.Copy)
end)
test('AceDBOptions builds localized profile options',function()
    local opts=LibStub('AceDBOptions-3.0'):GetOptionsTable(db)
    assert(opts.type=='group' and opts.args.choose and opts.args.copyfrom and opts.args.reset)
end)
test('AceSerializer round trips profile values and nil argument slots',function()
    local ser=LibStub('AceSerializer-3.0'); local encoded=ser:Serialize({scale=1.25,font='Шрифт',binary='\000\030\255'},nil,3)
    local ok,profile,empty,third=ser:Deserialize(encoded)
    assert(ok and profile.scale==1.25 and profile.font=='Шрифт' and profile.binary=='\000\030\255' and empty==nil and third==3)
end)
test('AceHook restores a hooked method after unhook',function()
    local owner={}; LibStub('AceHook-3.0'):Embed(owner)
    local hits=0; local target={Run=function(_,v) return v+1 end}
    local original=target.Run; owner:Hook(target,'Run',function() hits=hits+1 end)
    assert(target:Run(2)==3 and hits==1); owner:Unhook(target,'Run'); assert(target.Run==original)
end)
local comm=LibStub('AceComm-3.0'); local owner={}; comm:Embed(owner)
ChatThrottleLib.avail=4000; ChatThrottleLib.HardThrottlingBeginTime=0
local received
owner.OnCommReceived=function(_,prefix,text,channel,sender) received={prefix,text,channel,sender} end
owner:RegisterComm('GladdyVCheck')
local function receive()
    for _,msg in ipairs(sends) do comm.frame.scripts.OnEvent(comm.frame,'CHAT_MSG_ADDON',msg[1],msg[2],msg[3],'Other') end
end
test('AceComm version-check payload remains compatible with legacy sends',function()
    local callback
    owner:SendCommMessage('GladdyVCheck','2.41','RAID','Ray','NORMAL',function(tag,sent,total,result) callback={tag,sent,total,result} end,'check')
    assert(#sends==1 and sends[1][1]=='GladdyVCheck' and sends[1][2]=='2.41')
    assert(callback[1]=='check' and callback[2]==4 and callback[3]==4)
    receive(); assert(received[1]=='GladdyVCheck' and received[2]=='2.41' and received[3]=='RAID' and received[4]=='Other')
end)
test('AceComm multipart protocol reassembles and clears receive buffers',function()
    wipe(sends); local text=string.rep('sirus',180)
    owner:SendCommMessage('GladdyVCheck',text,'RAID','Ray')
    assert(#sends>1)
    for _,msg in ipairs(sends) do assert(#msg[1]+#msg[2]<=254) end
    receive(); assert(received[2]==text and next(comm.multipart_spool)==nil)
    owner:UnregisterComm('GladdyVCheck')
end)
test('core integration reports no swallowed Lua errors',function() assert(#wow.errors==0,table.concat(wow.errors,'\n')) end)
print('PASS: '..passed..' Ace core tests')
