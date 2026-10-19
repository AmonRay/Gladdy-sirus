local noop=function() end
local reads,maxReads,writes=0,0,0
UnitHealth=function() reads=reads+1; return 50 end
UnitHealthMax=function() maxReads=maxReads+1; return 100 end
UnitExists=function() return true end
UnitGUID=function(unit) return unit end
SetPortraitTexture=noop
local G={L={},db={petEnabled=true,petHealthPercentage=true},guids={}}
G.NewModule=function() return {} end
G.SetColor=function() return 1,1,1,1 end
LibStub=setmetatable({NewLibrary=function() return G end},{__call=function(_,name) return name=="Gladdy" and G or {Embed=noop} end})
CreateFrame=function() return {RegisterEvent=noop,SetScript=noop} end
dofile("Gladdy/Gladdy.lua")
local Pets
G.NewModule=function() Pets={}; return Pets end
dofile(arg and arg[1] or 'Gladdy/Modules/Pets.lua')
local bar={unit='arenapet1',hp={SetValue=noop,SetMinMaxValues=noop,SetStatusBarColor=noop},
    healthText={SetText=function() writes=writes+1 end},SetAlpha=noop,
    SetScript=function(self,event,fn) self[event]=fn end}
Pets.frames={arenapet1={healthBar=bar}}
Pets:PET_SPOTTED('arenapet1')
reads,maxReads,writes=0,0,0
for i=1,600 do bar.OnUpdate(bar,1/60) end
print(string.format('callbacks=600 health_reads=%d maxhealth_reads=%d text_writes=%d',reads,maxReads,writes))
if not (arg and arg[1]) then assert(reads<=100 and maxReads<=100 and writes==0) end
