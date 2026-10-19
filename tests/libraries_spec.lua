local n=0
local function test(name, fn)
    local ok,err=pcall(fn)
    assert(ok,name..': '..tostring(err))
    n=n+1; print('ok '..n..' - '..name)
end
strmatch=string.match
local errors={}
geterrorhandler=function() return function(err) errors[#errors+1]=err end end
local now=0
GetTime=function() return now end
CreateFrame=function()
    return {scripts={},shown=true,SetScript=function(self,k,v) self.scripts[k]=v end,
        Show=function(self) self.shown=true end,Hide=function(self) self.shown=false end,
        UnregisterAllEvents=function() end}
end
LibStub=nil
dofile('Gladdy/Libs/Ace3/LibStub/LibStub.lua')
dofile('Gladdy/Libs/Ace3/CallbackHandler-1.0/CallbackHandler-1.0.lua')
local CH=LibStub('CallbackHandler-1.0')
test('callback dispatch and unregister preserve arguments',function()
    local target,object={},{}
    local registry=CH:New(target)
    local calls=0
    object.Handle=function(self,event,a,b,c) assert(self==object and event=='EVENT' and a==1 and b==nil and c==3); calls=calls+1 end
    target.RegisterCallback(object,'EVENT','Handle')
    registry:Fire('EVENT',1,nil,3); assert(calls==1)
    target.UnregisterCallback(object,'EVENT'); registry:Fire('EVENT',1,nil,3); assert(calls==1)
end)
test('callbacks registered during dispatch run on the next dispatch',function()
    local target,one,two={},{},{}
    local registry=CH:New(target); local calls=0
    one.Handle=function() target.RegisterCallback(two,'EVENT',function() calls=calls+1 end) end
    target.RegisterCallback(one,'EVENT','Handle')
    registry:Fire('EVENT'); assert(calls==0)
    registry:Fire('EVENT'); assert(calls==1)
end)
dofile('Gladdy/Libs/Ace3/AceTimer-3.0/AceTimer-3.0.lua')
local AT=LibStub('AceTimer-3.0')
local owner={}; AT:Embed(owner)
local function tick(time) now=time; AT.frame.scripts.OnUpdate(AT.frame) end
test('timer driver sleeps when idle and preserves nil arguments',function()
    assert(not AT.frame.shown)
    local calls=0
    owner:ScheduleTimer(function(a,b,c) assert(a==1 and b==nil and c==3); calls=calls+1 end,1,1,nil,3)
    assert(AT.frame.shown); tick(0.5); assert(calls==0); tick(1); assert(calls==1 and not AT.frame.shown)
end)
test('repeating timer can cancel itself without firing again',function()
    local calls=0; local handle
    handle=owner:ScheduleRepeatingTimer(function() calls=calls+1; owner:CancelTimer(handle) end,0.1)
    tick(1.11); tick(2); assert(calls==1 and not AT.frame.shown)
end)
test('timers scheduled inside callbacks do not execute in the same snapshot',function()
    local calls=0
    owner:ScheduleTimer(function() owner:ScheduleTimer(function() calls=calls+1 end,0.01) end,0.01)
    tick(2.02); assert(calls==0); tick(2.04); assert(calls==1)
end)
test('upgrade preserves existing timer handles and embedded methods',function()
    local calls=0; local handle=owner:ScheduleTimer(function() calls=calls+1 end,1)
    LibStub.minors['AceTimer-3.0']=1018
    dofile('Gladdy/Libs/Ace3/AceTimer-3.0/AceTimer-3.0.lua')
    assert(owner:TimeLeft(handle)>0)
    owner:CancelTimer(handle); tick(4); assert(calls==0)
end)
test('cancel all timers leaves no active owner timers',function()
    owner:ScheduleTimer(function() error('cancelled') end,1)
    owner:ScheduleRepeatingTimer(function() error('cancelled') end,1)
    owner:CancelAllTimers(); tick(6); assert(not AT.frame.shown and #errors==0)
end)
test('compression library registers numerically and round trips profile payloads',function()
    dofile('Gladdy/Libs/LibDeflate/LibDeflate.lua')
    local LD,minor=LibStub('LibDeflate')
    assert(minor==3 and LD._VERSION=='1.0.2-release')
    local source=string.rep('Gladdy profile data',200)..string.char(0,1,2,255)
    local compressed=LD:CompressZlib(source)
    assert(LD:DecompressZlib(compressed)==source)
    assert(LD:DecodeForPrint(LD:EncodeForPrint(compressed))==compressed)
    assert(LD:DecompressZlib('invalid')==nil)
end)
test('legacy 1.0.1 profile fixture decompresses with 1.0.2',function()
    local file=assert(io.open('tests/fixtures/profile-legacy.zlib.hex','r'))
    local hex=file:read('*a'); file:close()
    local compressed=hex:gsub('%s',''):gsub('%x%x',function(byte) return string.char(tonumber(byte,16)) end)
    local source=string.rep('Gladdy profile data',200)..string.char(0,1,2,255)
    assert(LibStub('LibDeflate'):DecompressZlib(compressed)==source)
end)
print('PASS: '..n..' library regression tests')
