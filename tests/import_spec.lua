local n=0
local function test(name,fn)
    local ok,err=pcall(fn); assert(ok,name..': '..tostring(err)); n=n+1; print('ok '..n..' - '..name)
end
local wow=dofile('tests/wow_ui_stub.lua'); wow.install()
dofile('Gladdy/Libs/Ace3/LibStub/LibStub.lua')
dofile('Gladdy/Libs/Ace3/CallbackHandler-1.0/CallbackHandler-1.0.lua')
dofile('Gladdy/Libs/Ace3/AceSerializer-3.0/AceSerializer-3.0.lua')
dofile('Gladdy/Libs/LibDeflate/LibDeflate.lua')
local function loadXML(path)
    local file=assert(io.open(path));local xml=file:read('*a');file:close();xml=xml:gsub('<!%-%-.-%-%->','')
    for kind,rel in xml:gmatch('<(%w+)%s+file="([^"]+)"') do
        local child=path:match('^(.*)/')..'/'..rel:gsub('\\','/')
        if kind=='Include' then loadXML(child) elseif kind=='Script' then dofile(child) end
    end
end
loadXML('Gladdy/Libs/Ace3/AceGUI-3.0/AceGUI-3.0.xml')
loadXML('Gladdy/Libs/Ace3/AceConfig-3.0/AceConfig-3.0.xml')
local G=LibStub:NewLibrary('Gladdy',1)
G.L=setmetatable({},{__index=function(_,k) return k end});G.expansion='Wrath';G.version_major_num=2
G.defaults={profile={scale=1,frameScale=1,newLayout=false,expansion='Wrath',appearance={r=1,g=1},cooldownCooldowns={['1']=true}}}
G.db={scale=1,frameScale=1,newLayout=false,expansion='Wrath',appearance={r=1,g=1},cooldownCooldowns={['1']=true}}
G.contains=function(_,key,list) for _,v in ipairs(list) do if key==v then return true end end return false end
local changes=0
G.Reset=function() changes=changes+1 end;G.HideFrame=function() end;G.ToggleFrame=function() end;G.Debug=function() end
local modules={}; G.NewModule=function(_,name) local module={};modules[name]=module;return module end
local gui=LibStub('AceGUI-3.0');local created={};local originalCreate=gui.Create
gui.Create=function(self,kind) local obj=originalCreate(self,kind);if kind=='Frame' then created[#created+1]=obj end;return obj end
local ser=LibStub('AceSerializer-3.0');local deflate=LibStub('LibDeflate')
local function encode(value) return deflate:EncodeForPrint(deflate:CompressZlib(ser:Serialize(value))) end
local function encodeRaw(raw) return deflate:EncodeForPrint(deflate:CompressZlib(raw)) end
dofile('Gladdy/Modules/ExportImport.lua');local module=modules['Export Import']
local valid=encode({version_major_num=2,scale=1.3,expansion='Wrath',appearance={r=0.5}})
test('file load and background decoding create no UI objects',function()
    assert(#created==0 and gui:GetWidgetCount('Frame')==0)
    local decoded=assert(module:Decode(valid));assert(decoded.scale==1.3 and decoded.version_major_num==nil)
    assert(module:Decode(false,true)==nil and #created==0)
end)
local options=module:GetOptions()
test('export window is created once on first use and reused',function()
    options.export.func();assert(#created==1 and created[1].eb:GetText()~='')
    options.export.func();assert(#created==1)
end)
local window
test('import window is created independently and reused',function()
    options.import.func();assert(#created==2);window=created[2]
    options.import.func();assert(#created==2 and window.button.disabled)
end)
test('invalid edits invalidate a previously valid pending import',function()
    window.eb:SetText(valid);window.eb:Fire('OnTextChanged');assert(window.deserializedTable and not window.button.disabled)
    window.eb:SetText('invalid');window.eb:Fire('OnTextChanged');assert(window.deserializedTable==nil and window.button.disabled)
    window.button:Fire('OnClick');assert(G.db.scale==1 and changes==0)
end)
test('clear and close discard pending import data',function()
    window.eb:SetText(valid);window.eb:Fire('OnTextChanged');window.clearButton:Fire('OnClick')
    assert(window.deserializedTable==nil and window.button.disabled)
    window.eb:SetText(valid);window.eb:Fire('OnTextChanged');window:Fire('OnClose')
    assert(window.deserializedTable==nil)
end)
test('valid import applies known values without retaining version metadata',function()
    options.import.func();window.eb:SetText(valid);window.eb:Fire('OnTextChanged');window.button:Fire('OnClick')
    assert(G.db.scale==1.3 and G.db.appearance.r==0.5 and G.db.version_major_num==nil and changes==1)
end)
test('root and version types are rejected without Lua exceptions',function()
    for _,root in ipairs({true,7,'profile',{scale=1},{version_major_num='2'},{version_major_num=0},{version_major_num=1.5},{version_major_num=3},{version_major_num=math.huge}}) do
        local ok,result=pcall(module.Decode,module,encode(root));assert(ok and result==nil)
    end
    assert(module:Decode(nil)==nil and module:Decode({})==nil)
end)
test('known nested field mismatches cannot partially modify a profile',function()
    local before=G.db.scale;local bad={scale=9,appearance={r='wrong'}}
    local ok,err=module:ApplyImport(bad,G.db);assert(not ok and err and G.db.scale==before and G.db.appearance.r==0.5)
    assert(module:Decode(encode({version_major_num=2,scale='wrong'}))==nil)
end)
test('validation leaves the source profile and version intact',function()
    local source={version_major_num=2,scale=1.1}
    assert(module:CheckDeserializedOptions(source,G.defaults.profile))
    assert(source.version_major_num==2 and source.scale==1.1)
end)
test('cycles table keys and non-finite values are rejected at apply boundary',function()
    local cyclic={};cyclic.loop=cyclic
    assert(not module:ApplyImport(cyclic,G.db))
    assert(not module:ApplyImport({[{}]=1},G.db))
    assert(not module:ApplyImport({scale=0/0},G.db))
    assert(not module:ApplyImport({custom=math.huge},G.db))
end)
test('nesting and encoded size limits reject before recursive deserialize',function()
    local root={version_major_num=2};local cursor=root
    for _=1,module.IMPORT_LIMITS.depth+1 do cursor.child={};cursor=cursor.child end
    assert(module:Decode(encode(root))==nil)
    assert(module:Decode(string.rep('x',module.IMPORT_LIMITS.encoded+1))==nil)
end)
test('serialized size entry and token limits are enforced',function()
    local limits=module.IMPORT_LIMITS;local old=limits.serialized;limits.serialized=20
    assert(module:Decode(valid)==nil);limits.serialized=old
    old=limits.entries;limits.entries=1;assert(not module:ApplyImport({a=1,b=2},G.db));limits.entries=old
    old=limits.tokens;limits.tokens=2;assert(module:Decode(valid)==nil);limits.tokens=old
end)
test('extra roots incomplete tables and corrupt compression are rejected',function()
    assert(module:Decode(encodeRaw(ser:Serialize({version_major_num=2},{second=true})))==nil)
    assert(module:Decode(encodeRaw('^1^T^Sversion_major_num^N2^^'))==nil)
    assert(module:Decode(deflate:EncodeForPrint('not zlib'))==nil)
end)
test('legacy scalar options remain compatible and deleted keys are not applied',function()
    assert(module:ApplyImport({legacyOption=true,castBarPos='old'},G.db))
    assert(G.db.legacyOption==true and G.db.castBarPos==nil)
end)
test('cross-expansion imports preserve current expansion-specific data',function()
    assert(module:ApplyImport({expansion='BCC',cooldownCooldowns={['1']=false},scale=1.4},G.db))
    assert(G.db.expansion=='Wrath' and G.db.cooldownCooldowns['1']==true and G.db.scale==1.4)
end)
test('same-expansion nested legacy field names are not filtered as root maps',function()
    local target={expansion='Wrath',appearance={cooldownCooldowns={['1']=true}}}
    assert(module:ApplyImport({expansion='Wrath',appearance={cooldownCooldowns={['1']=false}}},target))
    assert(target.appearance.cooldownCooldowns['1']==false)
end)
test('all nine bundled historical profiles decode within the limits',function()
    dofile('Gladdy/ImportStrings.lua')
    for _,name in ipairs({'GetKlimpProfile','GetClassicProfile','GetClassicProfileNoPet','GetKnallProfile','GetBlizzardProfile','GetRukkProfile','GetMirProfile','GetMirEditedProfile','GetLikeGladius'}) do
        local decoded,err=module:Decode(G[name](G));assert(decoded,name..': '..tostring(err))
    end
end)
test('import and export integration reports no swallowed UI errors',function() assert(#wow.errors==0,table.concat(wow.errors,'\n')) end)
print('PASS: '..n..' import hardening tests')
