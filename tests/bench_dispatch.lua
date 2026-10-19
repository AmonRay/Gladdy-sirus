-- Synthetic dispatch benchmark, not a WoW/FPS benchmark.
-- lua5.1 tests/bench_dispatch.lua [path/to/Gladdy.lua]
local G={}
CreateFrame=function() return {RegisterEvent=function() end,SetScript=function() end} end
LibStub=setmetatable({NewLibrary=function() return G end},{__call=function()
    return {Embed=function() end}
end})
local sorts=0
local originalSort=table.sort
table.sort=function(...) sorts=sorts+1; return originalSort(...) end
dofile(arg and arg[1] or 'Gladdy/Gladdy.lua')
G.defaults={profile={}}
local received=0
for i=1,25 do
    local m=G:NewModule('module'..i,i)
    m.PING=function() received=received+1 end
    m:RegisterMessage('PING')
end
collectgarbage('collect'); collectgarbage('stop')
local before=collectgarbage('count')
local started=os.clock()
for i=1,2000 do G:SendMessage('PING', 'arena1', i) end
local duration=os.clock()-started
local growth=collectgarbage('count')-before
collectgarbage('restart')
assert(received==50000)
print(string.format('dispatches=2000 handlers=%d sorts=%d seconds=%.6f allocated_KiB=%.3f',received,sorts,duration,growth))
