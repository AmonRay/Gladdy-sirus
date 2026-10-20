local n=0
local function test(name,fn)
    local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));n=n+1;print('ok '..n..' - '..name)
end
local wow=dofile('tests/wow_ui_stub.lua');wow.install()
local combat=false; local instance='arena';local creations=0
InCombatLockdown=function() return combat end
IsInInstance=function() return true,instance end
IsAddOnLoaded=function() return false end
local realCreateFrame=CreateFrame
CreateFrame=function(...) assert(not combat,'UI creation during combat');creations=creations+1;return realCreateFrame(...) end
local G={}
LibStub=setmetatable({NewLibrary=function() return G end},{__call=function(_,name) if name=='Gladdy' then return G end return {Embed=function() end} end})
dofile('Gladdy/Gladdy.lua');dofile('Gladdy/Frame.lua')
G.L=setmetatable(G.L,{__index=function(_,key) return key end})
G.SetColor=function() return 0,0,0,1 end
local events={};G.SendMessage=function(_,event) events[#events+1]=event end
G.UpdateFrame=function(self) assert(not combat);if not self.frame then self:CreateFrame() end end
local function setup()
    combat=false;instance='arena'
    for _,name in ipairs(wow.names) do if name:match('^Gladdy') then _G[name]=nil end end
    G.buttons={};G.guids={};G.frame=nil;G.anchor=nil;G.curBracket=nil;G.showFrame=nil;G.hideFrame=nil;G.startTest=nil
    G.pendingButtonCount=nil;G.pendingClique=nil;ClickCastFrames=nil;G.modules={};G.moduleOrder=nil
    G.db={locked=true,x=1,y=1,hideBlizzard='never',backgroundColor={r=0,g=0,b=0,a=1}}
    G.testData={arena1={},arena2={},arena3={},arena4={},arena5={}};events={};creations=0
end
test('arena join in combat creates no UI and resumes after regen',function()
    setup();combat=true;G.curBracket=2;G:JoinedArena();assert(creations==0 and G.showFrame and not G.frame)
    combat=false;G:PLAYER_REGEN_ENABLED();assert(G.buttons.arena1.secure and G.buttons.arena2.secure and G.frame:IsShown())
    assert(#events==1 and events[1]=='JOINED_ARENA' and not G.showFrame)
end)
test('repeated queued joins create each button once',function()
    setup();combat=true;G.curBracket=2;G:JoinedArena();G:JoinedArena();assert(creations==0)
    combat=false;G:PLAYER_REGEN_ENABLED();local count=creations;G:PLAYER_REGEN_ENABLED();G:EnsureButtons(2)
    assert(creations==count and #events==1)
end)
test('cancelled pending test allocates no frames after combat',function()
    setup();combat=true;G:ToggleFrame(3);assert(creations==0 and G.startTest)
    G:HideFrame();combat=false;G:PLAYER_REGEN_ENABLED();assert(creations==0 and not G.showFrame and G.curBracket==nil)
end)
test('last queued test bracket wins and creates buttons before Test',function()
    setup();combat=true;G:ToggleFrame(3);G:ToggleFrame(5);assert(creations==0 and G.curBracket==5)
    combat=false;G:PLAYER_REGEN_ENABLED();assert(G.buttons.arena5.secure and G.frame.testing and G.frame:IsShown())
    assert(not G.startTest and not G.showFrame)
end)
test('repeating the same queued test request cancels it',function()
    setup();combat=true;G:ToggleFrame(3);G:ToggleFrame(3);combat=false;G:PLAYER_REGEN_ENABLED();assert(creations==0)
end)
test('Clique registration defers all five secure buttons until regen',function()
    setup();combat=true;G:RegisterCliqueFrames();assert(creations==0 and G.pendingClique and ClickCastFrames==nil)
    combat=false;G:PLAYER_REGEN_ENABLED();local count=0;for _ in pairs(ClickCastFrames) do count=count+1 end
    assert(count==5 and not G.pendingClique and G.buttons.arena5.secure)
end)
test('direct protected creation is guarded and deferred',function()
    setup();combat=true;G:CreateFrame();G:CreateButton(2);assert(creations==0 and not G.frame)
    combat=false;G:PLAYER_REGEN_ENABLED();assert(G.buttons.arena2.secure)
    local count=creations;assert(G:CreateButton(2)==G.buttons.arena2 and creations==count)
end)
test('spurious regen while locked down performs no UI creation',function()
    setup();combat=true;G:ToggleFrame(2);G:PLAYER_REGEN_ENABLED();assert(creations==0 and G.showFrame)
end)
test('leaving arena cancels a queued arena show before regen',function()
    setup();combat=true;G.curBracket=2;G:JoinedArena();instance='none';G:PLAYER_ENTERING_WORLD()
    combat=false;G:PLAYER_REGEN_ENABLED();assert(creations==0 and not G.showFrame and G.curBracket==nil)
end)
test('arena join supersedes a queued test without running test mode',function()
    setup();combat=true;G:ToggleFrame(3);G.curBracket=2;G:JoinedArena();combat=false;G:PLAYER_REGEN_ENABLED()
    assert(G.buttons.arena2 and not G.frame.testing and not G.startTest)
end)
test('deferred arena join restores alpha and applies Blizzard hiding',function()
    setup();G.curBracket=2;G:EnsureButtons(2);G.buttons.arena1.opponentKnown=true;G.buttons.arena1:SetAlpha(0)
    local alpha;local original=G.BlizzArenaSetAlpha;G.BlizzArenaSetAlpha=function(_,value) alpha=value end
    G.db.hideBlizzard='arena';combat=true;G:JoinedArena();combat=false;G:PLAYER_REGEN_ENABLED()
    assert(G.buttons.arena1:GetAlpha()==1 and alpha==0 and #events==1)
    G.BlizzArenaSetAlpha=original
end)
setup();WorldFrame=CreateFrame('Frame','WorldFrame')
G.defaults={profile={}};G.SMFetch=function() return 'font' end
G.GetTotemData=function() return {},{totem={id=1}} end
dofile('Gladdy/Modules/TotemPlates.lua');local T=G.modules['Totem Plates']
G.db.npTotemPlatesSize=32;G.db.npTotemPlatesWidthFactor=1;G.db.npTremorFontSize=12
G.db.npTremorFontXOffset=0;G.db.npTremorFontYOffset=0;G.db.npTotemColors={}
test('unsupported nameplate structures are rejected before UI allocation',function()
    local count=creations;assert(T:CreateTotemFrame(nil)==nil)
    assert(T:CreateTotemFrame({})==nil)
    local plate=CreateFrame('Frame');count=creations;assert(T:CreateTotemFrame(plate)==nil and creations==count and plate.gladdyTotemFrame==nil)
end)
local plate
test('validated legacy plate is attached once without duplicate hooks',function()
    plate=CreateFrame('Frame');local health=CreateFrame('StatusBar',nil,plate)
    health.GetStatusBarColor=function() return 0,1,0 end
    for i=1,11 do if i==7 or i==8 then plate:CreateFontString() else plate:CreateTexture() end end
    T:CreateTotemFrame(plate);assert(plate.gladdyTotemFrame and plate.scripts.OnShow and plate.scripts.OnHide)
    local count=creations;local obj=plate.gladdyTotemFrame;T:CreateTotemFrame(plate)
    assert(plate.gladdyTotemFrame==obj and creations==count)
end)
test('empty name text and absent per-totem options do not throw',function()
    G.db.npTotems=true;local totem=plate.gladdyTotemFrame
    totem.nametext:SetText('');T:NAME_PLATE_UNIT_ADDED(plate)
    totem.nametext:SetText('totem');G.db.npTotemsShowFriendly=true
    T:NAME_PLATE_UNIT_ADDED(plate);assert(not totem.active)
end)
local function elvui(enabled, extra)
    ElvUI = {{private = {nameplates = {enable = enabled}}}}
    IsAddOnLoaded = function(name) return name == 'ElvUI' or name == extra end
end
local cvarWrites = 0
SetCVar = function() cvarWrites = cvarWrites + 1 end
test('ElvUI nameplates block both initialization and repeated settings refreshes', function()
    elvui(true); G.db.npTotems = true; G.db.npTotemsShowEnemy = true; G.db.npTotemsShowFriendly = true
    local events = {}; T.RegisterEvent = function(_, event) events[event] = true end
    T.UnregisterAllEvents = function() for event in pairs(events) do events[event] = nil end end
    cvarWrites = 0; T:Initialize(); T:UpdateFrameOnce(); T:UpdateFrameOnce()
    assert(not T:GetScript('OnEvent') and not T:GetScript('OnUpdate') and not next(events) and cvarWrites == 0)
end)
test('ElvUI disabled nameplates allow the original scanner and events', function()
    elvui(false); T:Initialize(); T:UpdateFrameOnce()
    assert(T:GetScript('OnEvent') and T:GetScript('OnUpdate') and cvarWrites == 2)
end)
test('enabling ElvUI nameplates stops an already running Gladdy scanner', function()
    elvui(false); T:Initialize(); T:UpdateFrameOnce(); assert(T:GetScript('OnUpdate'))
    elvui(true); cvarWrites = 0; T:UpdateFrameOnce()
    assert(not T:GetScript('OnUpdate') and not T:GetScript('OnEvent') and cvarWrites == 0)
end)
test('ElvUI guard prevents new nameplate allocations and preview frames', function()
    elvui(true); local count = creations; local candidate = CreateFrame('Frame'); count = creations
    assert(T:CreateTotemFrame(candidate, true) == nil and creations == count)
    local preview = CreateFrame('Frame'); T.testFrame = preview; T:TestOnce()
    assert(not preview:IsShown() and not candidate.gladdyTotemFrame)
    T.testFrame = nil
end)
test('existing nameplate hooks cannot redraw Gladdy icons when ElvUI nameplates are enabled', function()
    elvui(true); local totem = plate.gladdyTotemFrame
    totem.active = {id = 1}; totem:Show(); totem:SetScript('OnUpdate', function() end)
    T:NAME_PLATE_UNIT_ADDED(plate)
    assert(not totem:IsShown() and not totem.active and not totem:GetScript('OnUpdate'))
end)
test('ElvUI guard also takes precedence when Kui or TidyPlates is loaded', function()
    for _, name in ipairs({'Kui_Nameplates', 'TidyPlates'}) do
        elvui(true, name); T:Initialize(); T:UpdateFrameOnce()
        assert(not T:GetScript('OnUpdate') and not T:GetScript('OnEvent'))
    end
end)
test('turning ElvUI nameplates off restores the Gladdy scanner without reinitialization', function()
    elvui(true); T:Initialize(); assert(not T:GetScript('OnUpdate'))
    elvui(false); T:UpdateFrameOnce(); assert(T:GetScript('OnUpdate') and T:GetScript('OnEvent'))
end)
test('partially initialized ElvUI configuration does not throw', function()
    IsAddOnLoaded = function(name) return name == 'ElvUI' end
    for _, data in ipairs({{}, {private = {}}, {private = {nameplates = {}}}}) do
        ElvUI = {data}; T:Initialize(); T:UpdateFrameOnce(); assert(not T:IsBlockedByElvUI())
    end
    IsAddOnLoaded = function() return false end
end)
test('ElvUI guard restores an already attached world nameplate and hides its preview', function()
    elvui(false); plate:SetParent(WorldFrame); WorldFrame.children[#WorldFrame.children + 1] = plate
    local totem = plate.gladdyTotemFrame
    totem.active = {id = 1}; totem:Show(); totem:SetScript('OnUpdate', function() end)
    local preview = CreateFrame('Frame'); T.testFrame = preview
    elvui(true); T:UpdateFrameOnce()
    assert(not totem.active and not totem:IsShown() and not totem:GetScript('OnUpdate') and not preview:IsShown())
    T.testFrame = nil
end)
test('supported Kui and Tidy adapters remain selected when ElvUI nameplates are disabled', function()
    for _, name in ipairs({'Kui_Nameplates', 'TidyPlates'}) do
        elvui(false, name); T:Initialize(); assert(T.addon == name)
    end
    IsAddOnLoaded = function() return false end
end)
test('lifecycle and nameplate guards report no swallowed errors',function() assert(#wow.errors==0,table.concat(wow.errors,'\n')) end)
print('PASS: '..n..' lifecycle and nameplate tests')
