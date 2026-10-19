local passed=0
local function test(name,fn)
    local ok,err=pcall(fn); assert(ok,name..': '..tostring(err)); passed=passed+1; print('ok '..passed..' - '..name)
end
local mode=arg and arg[1] or 'before'
local wow=dofile('tests/wow_ui_stub.lua'); wow.install()
dofile('Gladdy/Libs/Ace3/LibStub/LibStub.lua')
dofile('Gladdy/Libs/Ace3/CallbackHandler-1.0/CallbackHandler-1.0.lua')
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
local common,commonTree,sharedHook
if mode=='before' then
    loadCommon(); common=LibStub('AceGUI-3.0'); commonTree=common:Create('TreeGroup')
    sharedHook=function() end; AceGUIEditBoxInsertLink=sharedHook
end
loadXML('Gladdy/Libs/Ace3/AceGUI-3.0/AceGUI-3.0.xml')
loadXML('Gladdy/Libs/Ace3/AceConfig-3.0/AceConfig-3.0.xml')
local media=LibStub:NewLibrary('LibSharedMedia-3.0',1)
function media:HashTable(kind) self[kind]=self[kind] or {Default='path'}; return self[kind] end
function media:Fetch(kind,name) return self:HashTable(kind)[name] or 'path' end
function media:List() return {'Default'} end
function media:RegisterCallback() end
loadXML('Gladdy/Libs/AceGUI-3.0-SharedMediaWidgets/widget.xml')
local gui=LibStub('AceGUI-3.0-Gladdy')
local reg=LibStub('AceConfigRegistry-3.0-Gladdy')
local dialog=LibStub('AceConfigDialog-3.0-Gladdy')
local tree=gui:Create('TreeGroup')
if mode=='after' then loadCommon(); common=LibStub('AceGUI-3.0'); commonTree=common:Create('TreeGroup') end
test('shared and private AceGUI have separate registries and pools',function()
    assert(gui~=common and gui.WidgetRegistry~=common.WidgetRegistry and gui.objPools~=common.objPools)
    assert(gui:GetWidgetVersion('TreeGroup')==50 and common:GetWidgetVersion('TreeGroup')==47)
    assert(commonTree.frame:GetName()==nil and tree.frame:GetName()=='GladdyTreeGroup1')
end)
test('tree buttons do not share frame globals or text',function()
    local own=tree:CreateButton(); local other=commonTree:CreateButton()
    own.text:SetText('Gladdy'); other.text:SetText('ElvUI')
    assert(own~=other and own.text~=other.text)
    assert(own.text:GetText()=='Gladdy' and other.text:GetText()=='ElvUI')
    assert(own:GetName()=='GladdyAceGUI30TreeButton1' and other:GetName()=='AceGUI30TreeButton1')
end)
test('tree supports DF Text alias without leaking to shared widgets',function()
    wow.templateText='Text'; local own=tree:CreateButton(); wow.templateText='text'
    assert(own.text==own.Text)
end)
test('all default and media widgets construct under the private GUI',function()
    for _,kind in ipairs({'BlizOptionsGroup','DropdownGroup','Frame','InlineGroup','ScrollFrame','SimpleGroup','TabGroup','Window','Button','CheckBox','ColorPicker','Dropdown','EditBox','Heading','Icon','InteractiveLabel','Keybinding','Label','MultiLineEditBox','Slider','LSM30_Font','LSM30_Sound','LSM30_Statusbar','LSM30_Border','LSM30_Background'}) do
        local widget=gui:Create(kind); assert(widget and widget.type==kind,kind)
        gui:Release(widget)
    end
end)
test('private edit link handlers preserve shared handlers',function()
    assert(type(GladdyAceGUIEditBoxInsertLink)=='function' and type(GladdyAceGUIMultiLineEditBoxInsertLink)=='function')
    if sharedHook then assert(AceGUIEditBoxInsertLink==sharedHook) end
    local widget=gui:Create('EditBox'); local edit=widget.editbox
    assert(edit:GetName():match('^GladdyAceGUI%-3%.0EditBox'))
    edit.HasFocus=function() return true end; local inserted
    edit.Insert=function(_,text) inserted=text end
    GladdyAceGUIEditBoxInsertLink('spell:123'); assert(inserted=='spell:123')
    edit.HasFocus=function() return false end; gui:Release(widget)
end)
test('media lists and dropdown item base remain private',function()
    assert(AceGUIWidgetLSMlists==nil and type(GladdyAceGUIWidgetLSMlists)=='table')
    assert(LibStub('AceGUI-3.0-Gladdy-DropDown-ItemBase'))
    assert(not LibStub('AceGUISharedMediaWidgets-1.0',true))
end)
test('options registration validation and dialog use private libraries',function()
    local value=true
    local options={type='group',name='Gladdy',args={general={type='group',name='General',args={enabled={type='toggle',name='Enabled',get=function() return value end,set=function(_,v) value=v end}}}}}
    LibStub('AceConfig-3.0-Gladdy'):RegisterOptionsTable('GladdyTest',options)
    reg:ValidateOptionsTable(options,'GladdyTest')
    dialog:Open('GladdyTest'); assert(dialog.OpenFrames.GladdyTest)
    reg:NotifyChange('GladdyTest'); dialog:Close('GladdyTest')
    assert(not LibStub('AceConfig-3.0',true) and not LibStub('AceConfigRegistry-3.0',true))
end)
test('Gladdy import and export dialogs use private AceGUI at file load',function()
    dofile('Gladdy/Libs/Ace3/AceSerializer-3.0/AceSerializer-3.0.lua')
    dofile('Gladdy/Libs/LibDeflate/LibDeflate.lua')
    local G=LibStub:NewLibrary('Gladdy',1); G.L={}; G.expansion='Wrath'; G.version_major_num=2
    G.defaults={profile={scale=1}}; G.Debug=function() end
    local modules={}; G.NewModule=function(_,name) local m={}; modules[name]=m; return m end
    local sharedFrames=common:GetWidgetCount('Frame')
    dofile('Gladdy/Modules/ExportImport.lua')
    assert(common:GetWidgetCount('Frame')==sharedFrames)
    local ser=LibStub('AceSerializer-3.0'); local deflate=LibStub('LibDeflate')
    local encoded=deflate:EncodeForPrint(deflate:CompressZlib(ser:Serialize({version_major_num=2,scale=1.2})))
    local decoded=modules['Export Import']:Decode(encoded,false)
    assert(decoded and decoded.scale==1.2)
end)
test('loading both UI stacks reports no swallowed Lua errors',function()
    assert(#wow.errors==0,table.concat(wow.errors,'\n'))
end)
print('PASS: '..passed..' Ace UI tests, ElvUI '..mode..' Gladdy')
