local passed = 0
local function test(name, fn)
    local ok, err = xpcall(fn, debug.traceback); assert(ok, name .. ': ' .. tostring(err))
    passed = passed + 1; print('ok ' .. passed .. ' - ' .. name)
end
local wow = dofile('tests/wow_ui_stub.lua'); wow.install()
local noop = function() end
GetLocale = function() return 'enUS' end
GetSpellInfo = function(id) return 'spell' .. id, '', 'icon' .. id end
GetItemInfo = noop; GetBindingKey = noop; ClearOverrideBindings = noop; SetOverrideBindingClick = noop
InCombatLockdown = function() return false end; UnitName = function() return 'Enemy' end
AURA_TYPE_BUFF, AURA_TYPE_DEBUFF = 'BUFF', 'DEBUFF'
format, tinsert, tremove = string.format, table.insert, table.remove
LOCALIZED_CLASS_NAMES_MALE = {MAGE = 'Mage', PALADIN = 'Paladin'}; CLASS_ICON_TCOORDS = {}; SlashCmdList = {}
AceGUIWidgetLSMlists = {font = {}, border = {}, statusbar = {}}
local libs = {}
LibStub = setmetatable({NewLibrary = function(_, name) libs[name] = libs[name] or {}; return libs[name] end}, {__call = function(_, name)
    libs[name] = libs[name] or {Embed = noop, RegisterOptionsTable = noop, AddToBlizOptions = noop, NotifyChange = noop, GetOptionsTable = function() return {} end}
    return libs[name]
end})
dofile('Gladdy/Gladdy.lua'); dofile('Gladdy/Lang.lua'); dofile('Gladdy/Util.lua'); dofile('Gladdy/Options.lua')
dofile('Gladdy/Constants_shared.lua'); dofile('Gladdy/Constants_Wrath.lua')
dofile('Gladdy/Libs/DRList-1.0/DRList-1.0.lua'); dofile('Gladdy/Libs/DRList-1.0/Spells.lua')
for _, name in ipairs({'Diminishings', 'Clicks', 'TotemPlates', 'XiconProfiles'}) do dofile('Gladdy/Modules/' .. name .. '.lua') end
local G = LibStub('Gladdy'); local C, T = G.modules.Clicks, G.modules['Totem Plates']
G.UpdateFrame = noop; G.db = G:DeepCopy(G.defaults.profile); G.dbi = {profile = G.db}
local function findOption(key)
    local function visit(node)
        if not node.args then return end
        if node.args[key] then return node.args[key] end
        for _, child in pairs(node.args) do local found = visit(child); if found then return found end end
    end
    return assert(visit(G.options), key)
end
local function build(lang) G:ApplyLanguage(lang); G:SetupOptions() end
test('forced Russian translates click values after loading on an English client', function()
    assert(C:GetOptions()['1'].args.button.values['1'] == 'Left button'); build('ruRU')
    local a = C:GetOptions()['1'].args
    assert(a.button.values['1'] == 'Левая кнопка' and a.modifier.values[''] == G.L['None'])
    assert(a.action.values.macro == 'Макрос' and a.action.values.disabled == 'Отключено')
    assert(a.action.values.target == G.L['Target'] and a.action.values.focus == G.L['Focus'])
end)
test('binding labels follow both language switches without changing identifiers', function()
    G:ApplyLanguage('ruRU'); assert(BINDING_NAME_GLADDYBUTTON1_LEFT == 'ЛКМ по врагу 1')
    G:ApplyLanguage('enUS'); assert(BINDING_NAME_GLADDYBUTTON1_LEFT == 'Left Click Enemy 1')
    G:ApplyLanguage('ruRU'); assert(BINDING_NAME_GLADDYBUTTON5_BUTTON5 == G.L['Button5 Click Enemy 5'])
end)
test('user action names and spell text are preserved', function()
    G.db.attributes[1].name = 'My action'; G.db.attributes[1].spell = '/cast Custom Spell'
    build('enUS'); build('ruRU'); assert(C:GetOptions()['1'].name == 'My action')
    assert(G.db.attributes[1].spell == '/cast Custom Spell')
end)
test('module display titles translate without changing internal keys', function()
    assert(G.options.args.Clicks.name == 'Действия мыши')
    assert(G.options.args['Totem Plates'].name == 'Неймплейты тотемов')
    assert(G.options.args.XiconProfiles.name == 'Готовые профили')
end)
test('profile language changes refresh all sections and preserve the registered root', function()
    build('enUS'); local root, profiles = G.options, G.options.plugins.profiles
    G.db.locale = 'ruRU'; G:ApplyLocalization()
    assert(G.options == root and G.options.plugins.profiles == profiles)
    assert(G.options.args.locale.name == G.L['Language'])
    assert(G.options.args['Totem Plates'].name == 'Неймплейты тотемов')
    assert(G.options.args.Clicks.args['1'].args.action.values.spell == G.L['Cast Spell'])
    G.db.locale = 'enUS'; G:ApplyLocalization(); assert(G.options == root and G.options.args['Totem Plates'].name == 'Totem Plates')
    G.db.locale = 'ruRU'; G:ApplyLocalization()
end)
test('language refresh neither registers duplicate categories nor reruns migration', function()
    local registers, panels = 0, 0
    local config, dialog = LibStub('AceConfig-3.0'), LibStub('AceConfigDialog-3.0')
    local register, add = config.RegisterOptionsTable, dialog.AddToBlizOptions
    config.RegisterOptionsTable = function() registers = registers + 1 end
    dialog.AddToBlizOptions = function() panels = panels + 1 end
    G.db.npTotemPlatesBorderStyle = 'keep-current-style'
    G.db.locale = 'enUS'; G:ApplyLocalization(); G.db.locale = 'ruRU'; G:ApplyLocalization()
    assert(registers == 0 and panels == 0 and G.db.npTotemPlatesBorderStyle == 'keep-current-style')
    config.RegisterOptionsTable, dialog.AddToBlizOptions = register, add
end)
test('timer format choices translate without changing saved values', function()
    local v = findOption('timerFormat').values
    assert(v.tenths == G.L['xx:xx Miliseconds'] and v.seconds == 'xx секунд' and G.db.timerFormat == 'tenths')
end)
test('concatenated macro and tag tooltips resolve complete translation keys', function()
    local tag = G:GetTagOption('Text', 1, nil, function(t) return t end, true)
    assert(tag.desc:find('Пользовательские теги:', 1, true) and tag.desc:find('[percent|status]', 1, true))
    local macro = C:GetOptions()['1'].args.spell.desc
    assert(macro:find('Введите название заклинания.', 1, true))
    assert(macro:find('*arena*', 1, true) and macro:find('"PARTY"', 1, true))
end)
test('totem controls translate formatted enable tooltips', function()
    local function visit(node)
        if node.args then
            if node.args.enabled and node.args.enabled.desc and node.args.enabled.desc:find('Включить ', 1, true) then return node.args.enabled end
            for _, v in pairs(node.args) do local found = visit(v); if found then return found end end
        end
    end
    local enabled = assert(visit({args = T:GetOptions()}))
    assert(enabled.desc:find('|T', 1, true) and enabled.desc:find('spell', 1, true))
end)
test('DR labels use stable category identifiers independently of the library locale', function()
    local categories = G.modules.Diminishings:CategoryOptions(); local count = 0
    assert(categories.fear.name == 'Страх' and categories.horror.name == 'Ужас')
    assert(categories.scatter.name == 'Дезориентирующий выстрел' and categories.opener_stun.name == 'Оглушения при открытии боя')
    for key in pairs(LibStub('DRList-1.0'):GetCategories()) do
        count = count + 1; assert(categories[key] and not categories[key].name:match('^[%a ]+$'), key)
    end
    assert(count == 15)
end)
test('DR language changes do not modify the shared library or stored category table', function()
    local shared = LibStub('DRList-1.0'); local original, profile = shared:GetCategoryName('fear'), G.db.drCategories
    G:ApplyLanguage('enUS'); assert(G.modules.Diminishings:CategoryOptions().fear.name == 'Fears')
    G:ApplyLanguage('ruRU'); assert(G.modules.Diminishings:CategoryOptions().fear.name == 'Страх')
    assert(shared:GetCategoryName('fear') == original and G.db.drCategories == profile)
end)
test('all bundled profile display names translate', function()
    for key, option in pairs(G.modules.XiconProfiles:GetOptions()) do
        if option.name then assert(not option.name:find('Profile', 1, true), key) end
        if option.desc then assert(not option.desc:find('Profile', 1, true), key) end
    end
end)
test('module reset deep-copies nested defaults and does not corrupt future resets', function()
    G:SetupModule('Clicks', C, 6); G.options.args.Clicks.args.reset.func()
    assert(G.db.attributes ~= C.defaults.attributes and G.db.attributes[1] ~= C.defaults.attributes[1])
    local original = C.defaults.attributes[1].name; G.db.attributes[1].name = 'changed after reset'
    assert(C.defaults.attributes[1].name == original)
    G.options.args.Clicks.args.reset.func(); assert(G.db.attributes[1].name == original)
end)
local groups = {
    fontColor = {'healthBarFontColor','powerBarFontColor','castBarFontColor','petHealthBarFontColor'},
    fontColorCD = {'auraFontColor','buffsFontColor','cooldownFontColor','drFontColor'},
    buttonBorderColor = {'auraBuffBorderColor','auraDebuffBorderColor','buffsBorderColor','castBarIconColor','classIconBorderColor','ciBorderColor','cooldownBorderColor','drBorderColor','trinketBorderColor','racialBorderColor'},
    statusbarBorderColor = {'castBarBorderColor','healthBarBorderColor','powerBarBorderColor','petHealthBarBorderColor'},
}
for key, fields in pairs(groups) do
    test(key .. ' setter keeps colors independent across modules', function()
        findOption(key).set(nil, 0.2, 0.3, 0.4, 0.5)
        for i, field in ipairs(fields) do
            local c = G.db[field]; assert(c.r == 0.2 and c.g == 0.3 and c.b == 0.4 and c.a == 0.5)
            if i > 1 then assert(c ~= G.db[fields[1]]) end
        end
        G.db[fields[1]].r = 0.9
        for i = 2, #fields do assert(G.db[fields[i]].r == 0.2) end
    end)
    test(key .. ' mixed getter returns four numbers for AceConfig', function()
        local values = {findOption(key).get()}; assert(#values == 4)
        for _, value in ipairs(values) do assert(type(value) == 'number') end
    end)
    test(key .. ' matching getter preserves configured RGBA', function()
        local o = findOption(key); o.set(nil, 0.1, 0.2, 0.3, 0.4)
        local r, g, b, a = o.get(); assert(r == 0.1 and g == 0.2 and b == 0.3 and a == 0.4)
    end)
end
test('localized placeholders accept expected argument types', function()
    for _, lang in ipairs({'enUS', 'ruRU'}) do
        G:ApplyLanguage(lang)
        assert(string.format(G.L['Enable %s'], 'spell'))
        assert(string.format(G.L['Action #%d'], 3))
        assert(string.format(G.L['TRINKET READY: %s (%s)'], 'Enemy', 'Rogue'))
        assert(string.format(G.L['Current version %s is outdated. Most recent version is %s'], '2.44', '2.45'))
    end
end)
test('localization tests report no swallowed errors', function() assert(#wow.errors == 0, table.concat(wow.errors, '\n')) end)
print('PASS: ' .. passed .. ' localization and option regression tests')
