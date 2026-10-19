local passed=0
local function test(name,fn)
    local ok,err=pcall(fn); assert(ok,name..': '..tostring(err)); passed=passed+1; print('ok '..passed..' - '..name)
end
local mode=arg and arg[1] or 'before'
local wow=dofile('tests/wow_ui_stub.lua'); wow.install()
dofile('Gladdy/Libs/Ace3/LibStub/LibStub.lua')
dofile('Gladdy/Libs/Ace3/CallbackHandler-1.0/CallbackHandler-1.0.lua')
E={private={skins={ace3Enable=false}},Media={Textures={Plus='plus',Minus='minus'}},ClearTexture='clear'}; S={}
dofile('tests/fixtures/elvui-acegui/refresh.lua')
local function loadXML(path)
    local file=assert(io.open(path)); local xml=file:read('*a'); file:close()
    xml=xml:gsub('<!%-%-.-%-%->','')
    local parent=path:match('^(.*)/')
    for kind,rel in xml:gmatch('<(%w+)%s+file="([^"]+)"') do
        local child=parent..'/'..rel:gsub('\\','/')
        if kind=='Include' then loadXML(child) elseif kind=='Script' then dofile(child) end
    end
end
local function loadCommon()
    dofile('tests/fixtures/elvui-acegui/core.lua')
    dofile('tests/fixtures/elvui-acegui/tree.lua')
end
local original,originalRegistry,originalPools,stale
if mode=='before' then
    loadCommon(); original=LibStub('AceGUI-3.0'); originalRegistry=original.WidgetRegistry; originalPools=original.objPools
    stale=original:Create('TreeGroup')
    test('unpatched ElvUI tree reproduces a lost fromOnUpdate flag',function()
        stale.old_RefreshTree=stale.RefreshTree; stale.RefreshTree=S.Ace3_RefreshTree
        stale:SetTree({{text='Original',value='original'}})
        local update=assert(stale.frame:GetScript('OnUpdate')); update(stale.frame)
        assert(stale.frame:GetScript('OnUpdate')~=nil)
        stale.RefreshTree=stale.old_RefreshTree; stale.old_RefreshTree=nil
    end)
    original:Release(stale)
end
loadXML('Gladdy/Libs/Ace3/AceGUI-3.0/AceGUI-3.0.xml')
loadXML('Gladdy/Libs/Ace3/AceConfig-3.0/AceConfig-3.0.xml')
local media=LibStub:NewLibrary('LibSharedMedia-3.0',1)
function media:HashTable(kind) self[kind]=self[kind] or {Default='path'}; return self[kind] end
function media:Fetch(kind,name) return self:HashTable(kind)[name] or 'path' end
function media:List() return {'Default'} end
function media:RegisterCallback() end
loadXML('Gladdy/Libs/AceGUI-3.0-SharedMediaWidgets/widget.xml')
local gui=LibStub('AceGUI-3.0')
local reg=LibStub('AceConfigRegistry-3.0')
local dialog=LibStub('AceConfigDialog-3.0')
if mode=='after' then
    original=gui; originalRegistry=gui.WidgetRegistry; originalPools=gui.objPools; loadCommon()
end
local tree=gui:Create('TreeGroup')
test('ElvUI and Gladdy reuse the same library registry and pool tables',function()
    assert(gui==original and gui==LibStub('AceGUI-3.0'))
    assert(gui.WidgetRegistry==originalRegistry and gui.objPools==originalPools)
    assert(gui:GetWidgetVersion('TreeGroup')==51)
    if stale then assert(tree~=stale) end
end)
test('no private Gladdy UI libraries or frame wrappers remain',function()
    for name in pairs(LibStub.libs) do assert(not name:find('%-Gladdy'),name) end
    assert(gui.CreateFrame==nil and gui.CreateFont==nil)
    for _,name in ipairs(wow.names) do assert(not name:match('^GladdyAce') and not name:match('^GladdyTree')) end
end)
test('shared widget pool reuses the same object across consumers',function()
    local widget=gui:Create('Label'); gui:Release(widget)
    local fromOtherAddon=LibStub('AceGUI-3.0'):Create('Label')
    assert(fromOtherAddon==widget); gui:Release(fromOtherAddon)
end)
test('shared counters allocate unique tree buttons and canonical text',function()
    local one=tree:CreateButton(); local other=gui:Create('TreeGroup'); local two=other:CreateButton()
    one.text:SetText('Gladdy'); two.text:SetText('ElvUI')
    assert(one~=two and one.text~=two.text and one:GetName()~=two:GetName())
    assert(one.text==_G[one:GetName()..'Text'] and two.text:GetText()=='ElvUI')
    gui:Release(other)
end)
test('shared tree supports Text aliases without an extra font string',function()
    wow.templateText='Text'; local button=tree:CreateButton(); wow.templateText='text'
    assert(button.text==button.Text and #button.regions==2)
end)
test('ElvUI RefreshTree wrapper renders and finishes the deferred update',function()
    tree.old_RefreshTree=tree.RefreshTree; tree.RefreshTree=S.Ace3_RefreshTree
    tree:SetTree({{text='General',value='general'},{text='Profiles',value='profiles'}})
    local update=assert(tree.frame:GetScript('OnUpdate')); update(tree.frame)
    assert(tree.frame:GetScript('OnUpdate')==nil and tree.refreshFromOnUpdate==nil)
    assert(tree.buttons[1].text:GetText()=='General' and tree.buttons[2].text:GetText()=='Profiles')
    tree:RefreshTree(true); update=assert(tree.frame:GetScript('OnUpdate')); update(tree.frame)
    assert(tree.frame:GetScript('OnUpdate')==nil)
    E.private.skins.ace3Enable=true
    tree:RefreshTree(true); update=assert(tree.frame:GetScript('OnUpdate')); update(tree.frame)
    assert(tree.frame:GetScript('OnUpdate')==nil)
    E.private.skins.ace3Enable=false
end)
test('all default and media widgets construct and release on the shared GUI',function()
    for _,kind in ipairs({'BlizOptionsGroup','DropdownGroup','Frame','InlineGroup','ScrollFrame','SimpleGroup','TabGroup','Window','Button','CheckBox','ColorPicker','Dropdown','EditBox','Heading','Icon','InteractiveLabel','Keybinding','Label','MultiLineEditBox','Slider','LSM30_Font','LSM30_Sound','LSM30_Statusbar','LSM30_Border','LSM30_Background'}) do
        local widget=gui:Create(kind); assert(widget and widget.type==kind,kind); gui:Release(widget)
    end
end)
test('shared edit link handler resolves widgets using shared counters',function()
    local widget=gui:Create('EditBox'); local edit=widget.editbox
    assert(edit:GetName():match('^AceGUI%-3%.0EditBox'))
    edit.HasFocus=function() return true end; local inserted; edit.Insert=function(_,text) inserted=text end
    AceGUIEditBoxInsertLink('spell:123'); assert(inserted=='spell:123')
    edit.HasFocus=function() return false end; gui:Release(widget)
end)
test('media lists and dropdown item base use common registrations',function()
    assert(type(AceGUIWidgetLSMlists)=='table' and GladdyAceGUIWidgetLSMlists==nil)
    assert(LibStub('AceGUI-3.0-DropDown-ItemBase') and LibStub('AceGUISharedMediaWidgets-1.0'))
end)
test('options registration and open-close use the shared libraries',function()
    local options={type='group',name='Gladdy',args={enabled={type='toggle',name='Enabled',get=function() return true end,set=function() end}}}
    LibStub('AceConfig-3.0'):RegisterOptionsTable('GladdyTest',options)
    reg:ValidateOptionsTable(options,'GladdyTest'); dialog:Open('GladdyTest'); assert(dialog.OpenFrames.GladdyTest)
    reg:NotifyChange('GladdyTest'); dialog:Close('GladdyTest')
end)
test('Gladdy import-export dialogs reuse the shared stack',function()
    dofile('Gladdy/Libs/Ace3/AceSerializer-3.0/AceSerializer-3.0.lua'); dofile('Gladdy/Libs/LibDeflate/LibDeflate.lua')
    local G=LibStub:NewLibrary('Gladdy',1); G.L={}; G.expansion='Wrath'; G.version_major_num=2
    G.defaults={profile={scale=1}}; G.Debug=function() end
    local modules={}; G.NewModule=function(_,name) local m={}; modules[name]=m; return m end
    local count=gui:GetWidgetCount('Frame'); dofile('Gladdy/ImportValidation.lua'); dofile('Gladdy/Modules/ExportImport.lua')
    assert(gui:GetWidgetCount('Frame')==count)
    local ser=LibStub('AceSerializer-3.0'); local deflate=LibStub('LibDeflate')
    local encoded=deflate:EncodeForPrint(deflate:CompressZlib(ser:Serialize({version_major_num=2,scale=1.2})))
    local decoded=modules['Export Import']:Decode(encoded,false); assert(decoded and decoded.scale==1.2)
end)
test('integration reports no swallowed Lua errors',function() assert(#wow.errors==0,table.concat(wow.errors,'\n')) end)
print('PASS: '..passed..' shared Ace UI tests, ElvUI '..mode..' Gladdy')
