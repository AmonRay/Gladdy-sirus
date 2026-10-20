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
test('decode delegates directly to LibDeflate and AceSerializer in the original order',function()
    local decode, decompress, deserialize = deflate.DecodeForPrint, deflate.DecompressZlib, ser.Deserialize
    local calls = {}
    deflate.DecodeForPrint = function(...) calls[#calls + 1] = 'decode'; return decode(...) end
    deflate.DecompressZlib = function(...) calls[#calls + 1] = 'decompress'; return decompress(...) end
    ser.Deserialize = function(...) calls[#calls + 1] = 'deserialize'; return deserialize(...) end
    assert(module:Decode(valid))
    deflate.DecodeForPrint, deflate.DecompressZlib, ser.Deserialize = decode, decompress, deserialize
    assert(table.concat(calls, ',') == 'decode,decompress,deserialize')
    assert(module.IMPORT_LIMITS == nil and G.ValidateZlibSize == nil)
end)
test('library failures report their stage without modifying the active profile',function()
    local before = G.db.scale
    for _,case in ipairs({
        {deflate, 'DecodeForPrint', 'LibDeflate:DecodeForPrint'},
        {deflate, 'DecompressZlib', 'LibDeflate:DecompressZlib'},
        {ser, 'Deserialize', 'AceSerializer:Deserialize'},
    }) do
        local original = case[1][case[2]]
        for _,replacement in ipairs({function() return nil end, function() error('library failure') end}) do
            case[1][case[2]] = replacement
            local result, err = module:Decode(valid)
            assert(result == nil and err:find(case[3], 1, true), tostring(err))
        end
        case[1][case[2]] = original
    end
    assert(G.db.scale == before and changes == 0 and module:Decode(valid))
end)
test('profiles are not constrained by the removed custom size and depth limits',function()
    local profile = {version_major_num = 2, customText = string.rep('a', 2097153)}
    local cursor = profile
    for _ = 1, 35 do cursor.child = {}; cursor = cursor.child end
    local decoded = assert(module:Decode(encode(profile)))
    assert(#decoded.customText == 2097153)
    cursor = decoded
    for _ = 1, 35 do cursor = assert(cursor.child) end
    local original = deflate.DecodeForPrint
    local largeInput = string.rep('a', 524289)
    deflate.DecodeForPrint = function(self, input)
        assert(input == largeInput)
        return original(self, valid)
    end
    assert(module:Decode(largeInput))
    deflate.DecodeForPrint = original
end)
test('legacy field types are not rejected by custom schema validation',function()
    local decoded = assert(module:Decode(encode({version_major_num = 2, scale = 'legacy', appearance = {r = 'legacy'}})))
    assert(decoded.scale == 'legacy' and decoded.appearance.r == 'legacy')
    local target = {scale = 1, appearance = {r = 1}}
    assert(module:ApplyImport(decoded, target) and target.scale == 'legacy' and target.appearance.r == 'legacy')
end)
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
    for _,root in ipairs({true,7,'profile',{scale=1},{version_major_num='2'},{version_major_num=3},{version_major_num=math.huge}}) do
        local ok,result=pcall(module.Decode,module,encode(root));assert(ok and result==nil)
    end
    assert(module:Decode(nil)==nil and module:Decode({})==nil)
end)
test('validation leaves the source profile and version intact',function()
    local source={version_major_num=2,scale=1.1}
    assert(module:CheckDeserializedOptions(source,G.defaults.profile))
    assert(source.version_major_num==2 and source.scale==1.1)
end)
test('library deserializer and decompressor reject malformed data',function()
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
test('texture fields accept numeric IDs and string paths across defaults',function()
    local target={expansion='Wrath',trinketIcon='Interface\\Icons\\INV_Jewelry_TrinketPVP_02',drCategories={root={icon='root-path'}}}
    assert(module:ApplyImport({expansion='Wrath',trinketIcon=133452,drCategories={root={icon=135848}}},target))
    assert(target.trinketIcon==133452 and target.drCategories.root.icon==135848)
    assert(module:ApplyImport({expansion='Wrath',trinketIcon='trinket-path',drCategories={root={icon='root-path'}}},target))
    assert(target.trinketIcon=='trinket-path' and target.drCategories.root.icon=='root-path')
end)
test('all nine bundled historical profiles decode through the original library pipeline',function()
    dofile('Gladdy/ImportStrings.lua')
    for _,name in ipairs({'GetKlimpProfile','GetClassicProfile','GetClassicProfileNoPet','GetKnallProfile','GetBlizzardProfile','GetRukkProfile','GetMirProfile','GetMirEditedProfile','GetLikeGladius'}) do
        local decoded,err=module:Decode(G[name](G));assert(decoded,name..': '..tostring(err))
    end
end)
test('legacy profiles decode unchanged under both supported profile languages',function()
    dofile('Gladdy/Lang.lua')
    for _,name in ipairs({'GetKlimpProfile','GetClassicProfile','GetClassicProfileNoPet','GetKnallProfile','GetBlizzardProfile','GetRukkProfile','GetMirProfile','GetMirEditedProfile','GetLikeGladius'}) do
        local encoded=G[name](G)
        G:ApplyLanguage('enUS');local english=assert(module:Decode(encoded))
        G:ApplyLanguage('ruRU');local russian=assert(module:Decode(encoded))
        local function same(a,b)
            if type(a)~='table' then return a==b end
            if type(b)~='table' then return false end
            for k,v in pairs(a) do if not same(v,b[k]) then return false end end
            for k in pairs(b) do if a[k]==nil then return false end end
            return true
        end
        assert(same(english,russian),name)
    end
end)
test('language changes preserve imported numeric cooldown maps and custom user text',function()
    G.defaults.profile.cooldownCooldowns={MAGE={['44572']=true,['45438']=true}}
    G.defaults.profile.cooldownCooldownsOrder={MAGE={['44572']=1,['45438']=2}}
    local target={expansion='Wrath',cooldownCooldowns={MAGE={['44572']=true,['45438']=true}},cooldownCooldownsOrder={MAGE={['44572']=1,['45438']=2}}}
    assert(module:ApplyImport({expansion='Wrath',cooldownCooldowns={MAGE={['44572']=false,['45438']=true}},cooldownCooldownsOrder={MAGE={['44572']=2,['45438']=1}},customText='Лёд'},target))
    G.db=target;G:ApplyLanguage('enUS');G:ApplyLanguage('ruRU')
    assert(target.cooldownCooldowns.MAGE['44572']==false and target.cooldownCooldowns.MAGE['45438']==true)
    assert(target.cooldownCooldownsOrder.MAGE['44572']==2 and target.cooldownCooldownsOrder.MAGE['45438']==1 and target.customText=='Лёд')
end)
test('exported configuration round-trips through the original library pipeline',function()
    options.export.func()
    local output = assert(created[1].eb:GetText())
    local decoded = assert(module:Decode(output))
    local function same(a, b)
        if type(a) ~= 'table' then return a == b end
        if type(b) ~= 'table' then return false end
        for key, value in pairs(a) do if not same(value, b[key]) then return false end end
        for key in pairs(b) do if a[key] == nil then return false end end
        return true
    end
    assert(same(G.db, decoded) and G.db.version_major_num == nil)
end)
test('cached import-export dialogs refresh Russian labels and keep shared widget instances',function()
    G:ApplyLanguage('ruRU'); options.export.func(); options.import.func()
    assert(#created == 2 and created[1].titletext:GetText() == 'Экспорт')
    assert(created[1].eb.label:GetText() == 'Строка экспорта')
    assert(window.titletext:GetText() == 'Импорт' and window.eb.label:GetText() == 'Строка импорта')
    assert(window.clearButton.text:GetText() == 'Очистить')
    assert(window.button.text:GetText():find('перезаписан', 1, true))
    window.eb:SetText(valid); window.eb:Fire('OnTextChanged')
    assert(window.statustext:GetText() == 'Успешно' and not window.button.disabled)
    G:ApplyLanguage('enUS'); options.export.func(); options.import.func()
    assert(#created == 2 and created[1].titletext:GetText() == 'Export' and window.titletext:GetText() == 'Import')
end)
test('Russian import error preserves the library stage and discards pending data',function()
    G:ApplyLanguage('ruRU'); options.import.func()
    window.eb:SetText(valid); window.eb:Fire('OnTextChanged'); assert(window.deserializedTable)
    local original = deflate.DecompressZlib; deflate.DecompressZlib = function() return nil end
    window.eb:Fire('OnTextChanged'); deflate.DecompressZlib = original
    assert(window.statustext:GetText():find('Ошибка распаковки профиля:', 1, true))
    assert(window.statustext:GetText():find('LibDeflate:DecompressZlib', 1, true))
    assert(window.deserializedTable == nil and window.button.disabled)
    G:ApplyLanguage('enUS')
end)
test('import and export integration reports no swallowed UI errors',function() assert(#wow.errors==0,table.concat(wow.errors,'\n')) end)
print('PASS: '..n..' import compatibility tests')
