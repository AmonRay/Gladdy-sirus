local setmetatable = setmetatable
local type = type
local tostring = tostring
local select = select
local pairs = pairs
local tinsert = table.insert
local tsort = table.sort
local str_lower = string.lower
local GetTime = GetTime
local GetPhysicalScreenSize = GetPhysicalScreenSize
local InCombatLockdown = InCombatLockdown
local CreateFrame = CreateFrame
local DEFAULT_CHAT_FRAME = DEFAULT_CHAT_FRAME
local IsAddOnLoaded = IsAddOnLoaded
local GetBattlefieldStatus = GetBattlefieldStatus
local IsActiveBattlefieldArena = IsActiveBattlefieldArena
local IsInInstance = IsInInstance
local GetNumArenaOpponents = GetNumArenaOpponents
local RELEASE_TYPES = { alpha = "Alpha", beta = "Beta", release = "Release"}
local PREFIX = "Gladdy v"
local VERSION_REGEX = PREFIX .. "(%d+%.%d+)%-(%a)"
local LibStub = LibStub

if not C_CreatureInfo then
    C_CreatureInfo = {}
end

if not C_CreatureInfo._GetClassInfo then
    C_CreatureInfo._GetClassInfo = function(classID)
        local classData = {
            [1] = { className = "Warrior", classFile = "WARRIOR" },
            [2] = { className = "Paladin", classFile = "PALADIN" },
            [3] = { className = "Hunter", classFile = "HUNTER" },
            [4] = { className = "Rogue", classFile = "ROGUE" },
            [5] = { className = "Priest", classFile = "PRIEST" },
            [6] = { className = "Death Knight", classFile = "DEATHKNIGHT" },
            [7] = { className = "Shaman", classFile = "SHAMAN" },
            [8] = { className = "Mage", classFile = "MAGE" },
            [9] = { className = "Warlock", classFile = "WARLOCK" },
            [11] = { className = "Druid", classFile = "DRUID" },
        }
        local info = classData[classID]
        if info then
            info.classID = classID
        end
        return info
    end
end

if not C_CreatureInfo._GetRaceInfo then
    C_CreatureInfo._GetRaceInfo = function(raceID)
        local raceData = {
            [1] = { raceName = "Human", clientFileString = "Human" },
            [2] = { raceName = "Orc", clientFileString = "Orc" },
            [3] = { raceName = "Dwarf", clientFileString = "Dwarf" },
            [4] = { raceName = "Night Elf", clientFileString = "NightElf" },
            [5] = { raceName = "Undead", clientFileString = "Scourge" },
            [6] = { raceName = "Tauren", clientFileString = "Tauren" },
            [7] = { raceName = "Gnome", clientFileString = "Gnome" },
            [8] = { raceName = "Troll", clientFileString = "Troll" },
            [10] = { raceName = "Blood Elf", clientFileString = "BloodElf" },
            [11] = { raceName = "Draenei", clientFileString = "Draenei" },
        }
        return raceData[raceID]
    end
end

local MAJOR, MINOR = "Gladdy", 11
local Gladdy = LibStub:NewLibrary(MAJOR, MINOR)
local L = {}
Gladdy.L = L
Gladdy.version_major_num = 2
Gladdy.version_minor_num = 0.44
Gladdy.version_num = Gladdy.version_major_num + Gladdy.version_minor_num
Gladdy.version_releaseType = RELEASE_TYPES.release
Gladdy.version = PREFIX .. string.format("%.2f", Gladdy.version_num) .. "-" .. Gladdy.version_releaseType
Gladdy.VERSION_REGEX = VERSION_REGEX

Gladdy.debug = false

Gladdy.LOG_LEVELS = {
    ERROR = 1,
    WARN = 2,
    INFO = 3,
    DEBUG = 4
}

Gladdy.logLevel = Gladdy.LOG_LEVELS.INFO

LibStub("AceTimer-3.0"):Embed(Gladdy)
LibStub("AceComm-3.0"):Embed(Gladdy)
Gladdy.modules = {}
setmetatable(Gladdy, {
	__tostring = function()
		return MAJOR
	end
})

local missingSpellKey = {}
Gladdy.missingSpellIDs = {}

function Gladdy:SpellName(id, suffix, additionalID)
    local name = GetSpellInfo(id)
    if not name then self.missingSpellIDs[id] = true end
    if additionalID then
        local additional = GetSpellInfo(additionalID)
        if not additional then self.missingSpellIDs[additionalID] = true end
        if not name or not additional then return nil end
        return name .. (suffix or " ") .. additional
    end
    if not name then return nil end
    return suffix and (name .. suffix) or name
end

function Gladdy:SpellKey(id, suffix, additionalID)
    return self:SpellName(id, suffix, additionalID) or missingSpellKey
end

function Gladdy:FilterSpellTable(tbl)
    tbl[missingSpellKey] = nil
    return tbl
end

function Gladdy:Print(...)
	local text = "|cff0384fcGladdy|r:"
	local val
	for i = 1, select("#", ...) do
		val = select(i, ...)
		if (type(val) == 'boolean') then val = val and "true" or false end
		text = text .. " " .. tostring(val)
	end
	DEFAULT_CHAT_FRAME:AddMessage(text)
end

function Gladdy:Warn(...)
	local text = "|cfff29f05Gladdy|r:"
	local val
	for i = 1, select("#", ...) do
		val = select(i, ...)
		if (type(val) == 'boolean') then val = val and "true" or false end
		text = text .. " " .. tostring(val)
	end
	DEFAULT_CHAT_FRAME:AddMessage(text)
end

function Gladdy:Error(...)
	local text = "|cfffc0303Gladdy|r:"
	local val
	for i = 1, select("#", ...) do
		val = select(i, ...)
		if (type(val) == 'boolean') then val = val and "true" or false end
		text = text .. " " .. tostring(val)
	end
	DEFAULT_CHAT_FRAME:AddMessage(text)
end

function Gladdy:Debug(lvl, ...)
    if not Gladdy.debug then return end

    local level = Gladdy.LOG_LEVELS[lvl] or 0
    if level > Gladdy.logLevel then return end

    if lvl == "INFO" then
        Gladdy:Print("[INFO]", ...)
    elseif lvl == "WARN" then
        Gladdy:Warn("[WARN]", ...)
    elseif lvl == "ERROR" then
        Gladdy:Error("[ERROR]", ...)
    elseif lvl == "DEBUG" then
        Gladdy:Print("[DEBUG]", ...)
    end
end

Gladdy.events = CreateFrame("Frame")
Gladdy.events.registered = {}
Gladdy.events:RegisterEvent("PLAYER_LOGIN")
Gladdy.events:RegisterEvent("PLAYER_LOGOUT")
Gladdy.events:RegisterEvent("CVAR_UPDATE")
if type(VideoOptionsFrameOkay_OnClick) == "function" then
    hooksecurefunc("VideoOptionsFrameOkay_OnClick", function(self)
        if self and self:GetName() == "VideoOptionsFrameApply" then
            Gladdy:PixelPerfectScale(true)
        end
    end)
end
Gladdy.events:SetScript("OnEvent", function(self, event, ...)
	if (event == "PLAYER_LOGIN") then
		Gladdy:OnInitialize()
		Gladdy:OnEnable()
	elseif (event == "CVAR_UPDATE") then
		if (str_lower(select(1, ...)) == "uiscale") then
			Gladdy:PixelPerfectScale(true)
		end
	elseif (event == "PLAYER_LOGOUT") then
		Gladdy:DeleteUnknownOptions(Gladdy.db, Gladdy.defaults.profile)
	else
		local func = self.registered[event]

		if (type(Gladdy[func]) == "function") then
			Gladdy[func](Gladdy, event, ...)
		end
	end
end)

function Gladdy:RegisterEvent(event, func)
	self.events.registered[event] = func or event
	self.events:RegisterEvent(event)
end
function Gladdy:UnregisterEvent(event)
	self.events.registered[event] = nil
	self.events:UnregisterEvent(event)
end
function Gladdy:UnregisterAllEvents()
	self.events.registered = {}
	self.events:UnregisterAllEvents()
end

function Gladdy:GetModuleOrder()
    if not self.moduleOrder then
        local ordered = {}
        for _, module in pairs(self.modules) do
            tinsert(ordered, module)
        end
        tsort(ordered, function(a, b) return a.priority > b.priority end)
        self.moduleOrder = ordered
    end
    return self.moduleOrder
end

function Gladdy:IterModules()
    local ordered = self:GetModuleOrder()
    local index = 0
    return function()
        index = index + 1
        local module = ordered[index]
        if module then return module.name, module end
    end
end

function Gladdy:Call(module, func, ...)
	if (type(module) == "string") then
		module = self.modules[module]
	end

	if (type(module[func]) == "function") then
		module[func](module, ...)
	end
end

function Gladdy:SendMessage(message, ...)
    local ordered = self:GetModuleOrder()
    for i = 1, #ordered do
        local module = ordered[i]
        self:Call(module, module.messages[message], ...)
    end
end

function Gladdy:NewModule(name, priority, defaults)
	local module = CreateFrame("Frame")
	module.name = name
	module.priority = priority or 0
	module.defaults = defaults or {}
	module.messages = {}

	module.RegisterMessages = function(self, ...)
		for _,message in pairs({...}) do
			self.messages[message] = message
		end
	end

	module.RegisterMessage = function(self, message, func)
		self.messages[message] = func or message
	end

	module.UnregisterMessage = function(self, message)
		self.messages[message] = nil
	end

	module.UnregisterMessages = function(self, ...)
		for _,message in pairs({...}) do
			self.messages[message] = nil
		end
	end

	module.UnregisterAllMessages = function(self)
		for msg,_ in pairs(self.messages) do
			self.messages[msg] = nil
		end
	end

	module.GetOptions = function()
		return nil
	end

	for k, v in pairs(module.defaults) do
		self.defaults.profile[k] = v
	end

	self.modules[name] = module
    self.moduleOrder = nil

	return module
end

function Gladdy:DeleteUnknownOptions(tbl, refTbl, str)
	if str == nil then
		str = "Gladdy.db"
	end
	for k,v in pairs(tbl) do
		if refTbl[k] == nil then
			Gladdy:Debug("INFO", "SavedVariable deleted:", str .. "." .. k, "not found!")
			tbl[k] = nil
		else
			if type(v) ~= type(refTbl[k]) then
				Gladdy:Debug("INFO", "SavedVariable deleted:", str .. "." .. k, "type error!", "Expected", type(refTbl[k]), "but found", type(v))
				tbl[k] = nil
			elseif type(v) == "table" then
				Gladdy:DeleteUnknownOptions(v, refTbl[k], str .. "." .. k)
			end
		end
	end
end

function Gladdy:PixelPerfectScale(update)
	local physicalWidth, physicalHeight = GetPhysicalScreenSize()
	local perfectUIScale = 768.0/physicalHeight
	if self.db and self.db.pixelPerfect and self.frame then
		self.frame:SetIgnoreParentScale(true)
		self.frame:SetScale(perfectUIScale)
		if update then
			self:UpdateFrame()
		end
	elseif self.frame then
		self.frame:SetScale(self.db.frameScale)
		self.frame:SetIgnoreParentScale(false)
	end
end

function Gladdy:OnInitialize()
	self.dbi = LibStub("AceDB-3.0"):New("GladdyXZ", self.defaults)
	self.dbi.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
	self.dbi.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
	self.dbi.RegisterCallback(self, "OnProfileReset", "OnProfileReset")
	self.db = self.dbi.profile

	self:ApplyLocalization()

	self.messageHandlers = {}

	self.LSM = LibStub("LibSharedMedia-3.0")
	self.LSM:Register("statusbar", "Gloss", "Interface\\AddOns\\Gladdy\\Images\\Gloss")
	self.LSM:Register("statusbar", "Smooth", "Interface\\AddOns\\Gladdy\\Images\\Smooth")
	self.LSM:Register("statusbar", "Minimalist", "Interface\\AddOns\\Gladdy\\Images\\Minimalist")
	self.LSM:Register("statusbar", "LiteStep", "Interface\\AddOns\\Gladdy\\Images\\LiteStep.tga")
	self.LSM:Register("statusbar", "Flat", "Interface\\AddOns\\Gladdy\\Images\\UI-StatusBar")
	self.LSM:Register("border", "Gladdy Tooltip round", "Interface\\AddOns\\Gladdy\\Images\\UI-Tooltip-Border_round_selfmade")
	self.LSM:Register("border", "Gladdy Tooltip squared", "Interface\\AddOns\\Gladdy\\Images\\UI-Tooltip-Border_square_selfmade")
	self.LSM:Register("border", "Border_Gloss", "Interface\\AddOns\\Gladdy\\Images\\Border_Gloss.tga")
	self.LSM:Register("border", "Border_squared_blp", "Interface\\AddOns\\Gladdy\\Images\\Border_squared_blp")
	self.LSM:Register("border", "Border_rounded_blp", "Interface\\AddOns\\Gladdy\\Images\\Border_rounded_blp")
	self.LSM:Register("font", "DorisPP", "Interface\\AddOns\\Gladdy\\Images\\DorisPP.TTF")
	self.LSM:Register("border", "Square Full White", "Interface\\AddOns\\Gladdy\\Images\\Square_FullWhite.tga")

	L = self.L

	if self.db.locale ~= "auto" then
		local AceDBOptions = LibStub("AceDBOptions-3.0")
		if AceDBOptions then
			if not AceDBOptions.L then
				AceDBOptions.L = {}
			end

			if self.db.locale == "enUS" then
				AceDBOptions.L.profiles = "Profiles"
				AceDBOptions.L.profiles_sub = "Manage Profiles"
				AceDBOptions.L.default = "Default"
				AceDBOptions.L.intro = "You can change the active database profile, so you can have different settings for every character."
				AceDBOptions.L.reset_desc = "Reset the current profile back to its default values."
				AceDBOptions.L.reset = "Reset Profile"
				AceDBOptions.L.reset_sub = "Reset the current profile to the default values."
				AceDBOptions.L.choose_desc = "You can either create a new profile by entering a name in the editbox, or choose one of the already existing profiles."
				AceDBOptions.L.new = "New"
				AceDBOptions.L.new_sub = "Create a new empty profile."
				AceDBOptions.L.choose = "Existing Profiles"
				AceDBOptions.L.choose_sub = "Select one of your currently available profiles."
				AceDBOptions.L.copy_desc = "Copy the settings from one existing profile into the currently active profile."
				AceDBOptions.L.copy = "Copy From"
				AceDBOptions.L.copy_sub = "Copy from another profile."
				AceDBOptions.L.delete_desc = "Delete existing and unused profiles from the database to save space, and cleanup the SavedVariables file."
				AceDBOptions.L.delete = "Delete a Profile"
				AceDBOptions.L.delete_sub = "Delete one of your currently available profiles."
				AceDBOptions.L.current = "Current Profile:"
				AceDBOptions.L.confirm_delete = "Are you sure you want to delete the selected profile?"
			elseif self.db.locale == "ruRU" then
				AceDBOptions.L.profiles = "Профили"
				AceDBOptions.L.profiles_sub = "Управление профилями"
				AceDBOptions.L.default = "По умолчанию"
				AceDBOptions.L.intro = "Вы можете изменить активный профиль, таким образом у вас могут быть разные настройки для каждого персонажа."
				AceDBOptions.L.reset_desc = "Сбросить текущий профиль до значений по умолчанию."
				AceDBOptions.L.reset = "Сбросить профиль"
				AceDBOptions.L.reset_sub = "Сбросить текущий профиль до значений по умолчанию."
				AceDBOptions.L.choose_desc = "Вы можете создать новый профиль, введя название в поле ввода, или выбрать один из уже существующих профилей."
				AceDBOptions.L.new = "Новый"
				AceDBOptions.L.new_sub = "Создать новый пустой профиль."
				AceDBOptions.L.choose = "Существующие профили"
				AceDBOptions.L.choose_sub = "Выберите один из доступных профилей."
				AceDBOptions.L.copy_desc = "Скопировать настройки из другого профиля в текущий активный профиль."
				AceDBOptions.L.copy = "Копировать из"
				AceDBOptions.L.copy_sub = "Копировать из другого профиля."
				AceDBOptions.L.delete_desc = "Удалить существующие и неиспользуемые профили из базы данных для экономии места и очистки файла сохраненных переменных."
				AceDBOptions.L.delete = "Удалить профиль"
				AceDBOptions.L.delete_sub = "Удалить один из доступных профилей."
				AceDBOptions.L.current = "Текущий профиль:"
				AceDBOptions.L.confirm_delete = "Вы уверены, что хотите удалить выбранный профиль?"
			end
		end
	end

	self.testData = {
		["arena1"] = { name = "Swift", raceLoc = L["NightElf"], classLoc = L["Druid"], class = "DRUID", health = 67, healthMax = 100, power = 76, powerMax = 100, powerType = 1, testSpec = L["Restoration"], race = "NightElf" },
		["arena2"] = { name = "Vilden", raceLoc = L["Undead"], classLoc = L["Mage"], class = "MAGE", health = 99, healthMax = 100, power = 7833, powerMax = 10460, powerType = 0, testSpec = L["Frost"], race = "Scourge" },
		["arena3"] = { name = "Krymu", raceLoc = L["Human"], classLoc = L["Rogue"], class = "ROGUE", health = 10, healthMax = 100, power = 45, powerMax = 110, powerType = 3, testSpec = L["Subtlety"], race = "Human" },
		["arena4"] = { name = "Talmon", raceLoc = L["Human"], classLoc = L["Warlock"], class = "WARLOCK", health = 40, healthMax = 100, power = 9855, powerMax = 9855, powerType = 0, testSpec = L["Demonology"], race = "Human" },
		["arena5"] = { name = "Hydra", raceLoc = L["Undead"], classLoc = L["Priest"], class = "PRIEST", health = 70, healthMax = 100, power = 2515, powerMax = 10240, powerType = 0, testSpec = L["Discipline"], race = "Human" },
	}

	self.cooldownSpellIds = {}
	self.spellTextures = {}
	self.specBuffs = self:GetSpecBuffs()
	self.specSpells = self:GetSpecSpells()
	self.buttons = {}
	self.guids = {}
	self.curBracket = nil
	self.curUnit = 1

	self:SetupOptions()

	for _, module in self:IterModules() do
		self:Call(module, "Initialize")
	end
	if Gladdy.db.hideBlizzard == "always" then
		Gladdy:BlizzArenaSetAlpha(0)
	end
	if not self.db.newLayout then
		self:ToggleFrame(3)
		self:HideFrame()
	end
end

function Gladdy:ApplyLocalization()
    local currentLocale = GetLocale()
    local userSelectedLocale = self.db and self.db.locale or "auto"

    local langToApply = "enUS"

    if userSelectedLocale == "enUS" then
        langToApply = "enUS"
        Gladdy:Debug("INFO", "Using English localization (forced)")
    elseif userSelectedLocale == "ruRU" then
        langToApply = "ruRU"
        Gladdy:Debug("INFO", "Using Russian localization (forced)")
    elseif userSelectedLocale == "auto" and currentLocale == "ruRU" then
        langToApply = "ruRU"
        Gladdy:Debug("INFO", "Using Russian localization (auto)")
    else
        langToApply = "enUS"
        Gladdy:Debug("INFO", "Using English localization (default)")
    end

    self:ApplyLanguage(langToApply)

    self:UpdateLocalization()

    Gladdy:Debug("INFO", "Localization applied", "Client locale:", currentLocale, "Selected locale:", userSelectedLocale)
end

function Gladdy:UpdateLocalization()
	if Gladdy.options then
		if Gladdy.options.args.lock then
			Gladdy.options.args.lock.name = Gladdy.db.locked and L["Unlock frame"] or L["Lock frame"]
			Gladdy.options.args.lock.desc = L["Toggle if frame can be moved"]
		end
		if Gladdy.options.args.showMover then
			Gladdy.options.args.showMover.name = Gladdy.db.showMover and L["Hide Mover"] or L["Show Mover"]
			Gladdy.options.args.showMover.desc = L["Toggle to show Mover Frames"]
		end
		if Gladdy.options.args.test then
			Gladdy.options.args.test.name = L["Test"]
			Gladdy.options.args.test.desc = L["Show Test frames"]
		end

		LibStub("AceConfigRegistry-3.0"):NotifyChange("Gladdy")
	end
end

function Gladdy:OnProfileReset()
	self.db = self.dbi.profile
	Gladdy:Debug("INFO", "OnProfileReset")

	self:ApplyLocalization()

	self:HideFrame()
	self:ToggleFrame(3)
	Gladdy.options.args.lock.name = Gladdy.db.locked and L["Unlock frame"] or L["Lock frame"]
	Gladdy.options.args.showMover.name = Gladdy.db.showMover and L["Hide Mover"] or L["Show Mover"]
	LibStub("AceConfigRegistry-3.0"):NotifyChange("Gladdy")
end

function Gladdy:OnProfileChanged()
	self.db = self.dbi.profile

	self:ApplyLocalization()

	self:HideFrame()
	self:ToggleFrame(3)
	Gladdy.options.args.lock.name = Gladdy.db.locked and L["Unlock frame"] or L["Lock frame"]
	Gladdy.options.args.showMover.name = Gladdy.db.showMover and L["Hide Mover"] or L["Show Mover"]
	LibStub("AceConfigRegistry-3.0"):NotifyChange("Gladdy")
end

function Gladdy:OnEnable()
    local missing = {}
    for id in pairs(self.missingSpellIDs) do missing[#missing + 1] = id end
    if #missing > 0 then
        table.sort(missing)
        self:Warn("Unavailable spell data; skipped spell IDs:", table.concat(missing, ", "))
    end
	self:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("PLAYER_REGEN_ENABLED")

    if IsAddOnLoaded("Clique") then self:RegisterCliqueFrames() end

	if (not self.db.locked and self.db.x == 0 and self.db.y == 0) then
		self:Print(L["Welcome to Gladdy!"])
		self:Print(L["First run has been detected, displaying test frame."])
		self:Print(L["If this is not your first run please lock or move the frame to prevent this from happening."])
		self:Print(L["Valid slash commands are:"])
		self:Print("/gladdy ui")
		self:Print("/gladdy test")
		self:Print("/gladdy test [1-5]")
		self:Print("/gladdy hide")
		self:Print("/gladdy reset")
		self:Print("/gladdy debug")
		self:Print("/gladdy debug [error|warn|info]")

		self:HideFrame()
		self:ToggleFrame(3)
		self.showConfig = true
	end
end

function Gladdy:GetIconStyles()
	return {
        ["Interface\\AddOns\\Gladdy\\Images\\Border_rounded_blp.blp"] = L["Gladdy Tooltip round"],
        ["Interface\\AddOns\\Gladdy\\Images\\Border_squared_blp.blp"] = L["Gladdy Tooltip squared"],
        ["Interface\\AddOns\\Gladdy\\Images\\Border_Gloss.tga"] = L["Gloss (black border)"],
		["None"] = L["None"],
	}
end

function Gladdy:RegisterCliqueFrames()
    self.pendingClique = true
    if not self:EnsureButtons(5) then return end
    ClickCastFrames = ClickCastFrames or {}
    for i = 1, 5 do ClickCastFrames[self.buttons["arena" .. i].secure] = true end
    self.pendingClique = nil
end

function Gladdy:Test()
    if InCombatLockdown() then
        self.hideFrame = nil
        self.showFrame = true
        self.startTest = true
        return
    end
    self:EnsureButtons(self.curBracket or 0)
	self.frame.testing = true
	if self.curBracket then
		for i = 1, self.curBracket do
			local unit = "arena" .. i
			if (not self.buttons[unit]) then
				self:CreateButton(i)
			end
			local button = self.buttons[unit]

			for k, v in pairs(self.testData[unit]) do
				button[k] = v
			end

			for _, module in self:IterModules() do
				self:Call(module, "Test", unit)
			end

			button:SetAlpha(1)
		end
		for _, module in self:IterModules() do
			self:Call(module, "TestOnce")
		end
	end
end

function Gladdy:PLAYER_ENTERING_WORLD()
	if self.showConfig then
		LibStub("AceConfigDialog-3.0"):Open("Gladdy", nil, LibStub("AceConfigDialog-3.0"):SelectGroup("Gladdy", "XiconProfiles"))
		self.showConfig = nil
	end
    if select(2, IsInInstance()) == "arena" then return end
    if self.curBracket or self.showFrame or next(self.guids)
        or (self.frame and self.frame:IsVisible()) then
		self:Reset()
		self:HideFrame()
	end
end

function Gladdy:UPDATE_BATTLEFIELD_STATUS(_, index)
	local status, mapName, instanceID, levelRangeMin, levelRangeMax, teamSize, isRankedArena, suspendedQueue, bool, queueType = GetBattlefieldStatus(index)
	local instanceType = select(2, IsInInstance())
	Gladdy:Debug("INFO", "UPDATE_BATTLEFIELD_STATUS", instanceType, status, teamSize)
	if ((instanceType == "arena" or GetNumArenaOpponents() > 0) and status == "active") then
		self.curBracket = teamSize

		if ( teamSize > 0 ) then
			self:JoinedArena()
		end
	end
end

function Gladdy:PLAYER_REGEN_ENABLED()
    if InCombatLockdown() then return end
    local count = self.pendingButtonCount
    self.pendingButtonCount = nil
    if count then self:EnsureButtons(count) end
    if self.pendingClique then self:RegisterCliqueFrames() end
	if self.showFrame and not self.hideFrame then
        if self.startTest then
            self:EnsureButtons(self.curBracket or 0)
            self:UpdateFrame()
            self:Test()
            self.startTest = nil
            self.frame:Show()
            self:SendMessage("JOINED_ARENA")
        else
            self:JoinedArena()
        end
        self.showFrame = nil
    end
	if self.hideFrame then
		self:Reset()
		if self.frame then self.frame:Hide() end
		self.hideFrame = nil
	end
end

function Gladdy:Reset()
    self.showFrame = nil
    self.startTest = nil
    if not self.pendingClique then self.pendingButtonCount = nil end
	if type(self.guids) == "table" then
		for k,_ in pairs(self.guids) do
			self.guids[k] = nil
		end
	end
	self.guids = {}
	self.curBracket = nil
	self.curUnit = 1

	for _, module in self:IterModules() do
		self:Call(module, "Reset")
	end

	for unit in pairs(self.buttons) do
		self:ResetUnit(unit)
	end
	if Gladdy.db.hideBlizzard == "never" or Gladdy.db.hideBlizzard == "arena" then
		Gladdy:BlizzArenaSetAlpha(1)
	end
end

function Gladdy:ResetUnit(unit)
	local button = self.buttons[unit]
	if (not button) then
		return
	end

	button:SetAlpha(0)
	self:ResetButton(unit)

	for _, module in self:IterModules() do
		self:Call(module, "ResetUnit", unit)
	end
end

function Gladdy:ResetButton(unit)
	local button = self.buttons[unit]
	if (not button) then
		return
	end
	for k1, v1 in pairs(self.BUTTON_DEFAULTS) do
		if (type(v1) == "string") then
			button[k1] = nil
		elseif (type(v1) == "number") then
			button[k1] = 0
		elseif (type(v1) == "table") then
			button[k1] = {}
		elseif (type(v1) == "boolean") then
			button[k1] = false
		end
	end
end

function Gladdy:JoinedArena()
    Gladdy:Debug("INFO", "JoinedArena", "Start", "curBracket:", self.curBracket)

    if self.frame and self.frame.testing then
        local bracket = self.curBracket
        self:Reset()
        self.curBracket = bracket
        self.frame.testing = nil
    end

    if not self.curBracket then
        self.curBracket = 2
    end

    if InCombatLockdown() then
        self.showFrame = true
        self.startTest = nil
        self.hideFrame = nil
        return
    end
    self.hideFrame = nil

    for i = 1, self.curBracket do
        if not self.buttons["arena" .. i] then
            self:CreateButton(i)
        end
    end

    Gladdy:Debug("INFO", "JoinedArena", "Showing frames immediately")
    self:UpdateFrame()
    self.frame:Show()
    self:SendMessage("JOINED_ARENA")

    for i = 1, self.curBracket do
        local button = self.buttons["arena" .. i]
        if button then
            button:SetAlpha(1)
            Gladdy:Debug("INFO", "JoinedArena", "Set alpha for arena" .. i)
        end
    end

    if self.db.hideBlizzard == "arena" or self.db.hideBlizzard == "always" then
        self:BlizzArenaSetAlpha(0)
    end
end

function Gladdy:BlizzArenaSetAlpha(alpha)
    if ArenaEnemyFrames then ArenaEnemyFrames:SetAlpha(alpha) end
    if CompactArenaFrame and CompactArenaFrame ~= ArenaEnemyFrames then
        CompactArenaFrame:SetAlpha(alpha)
    end
    for i = 1, 5 do
        local frame = _G["ArenaEnemyFrame" .. i]
        local pet = _G["ArenaEnemyFrame" .. i .. "PetFrame"]
        if frame then frame:SetAlpha(alpha) end
        if pet then pet:SetAlpha(alpha) end
    end
end

if type(CompactArenaFrame_Generate) == "function" then
    hooksecurefunc("CompactArenaFrame_Generate", function()
        if not Gladdy.db then return end
        local mode = Gladdy.db.hideBlizzard
        local inArena = select(2, IsInInstance()) == "arena"
        Gladdy:BlizzArenaSetAlpha((mode == "always" or (mode == "arena" and inArena)) and 0 or 1)
    end)
end

local defaults = {["statusbar"] = "Smooth", ["border"] = "Gladdy Tooltip round", ["font"] = "DorisPP"}

local lastWarning = {}
function Gladdy:SMFetch(lsmType, key)
    local styleValue = Gladdy.db[key]
    if not styleValue then
        return self.LSM:Fetch(lsmType, defaults[lsmType])
    end

    if type(styleValue) == "string" and styleValue:find("^Interface\\") then
        for _, name in pairs(self.LSM:List(lsmType)) do
            if self.LSM:Fetch(lsmType, name) == styleValue then
                return styleValue
            end
        end

        local baseName = styleValue:match("([^\\]+)%.%w+$") or "CustomBorder"
        self.LSM:Register(lsmType, baseName, styleValue)
        return styleValue
    end

    local smMediaType = self.LSM:Fetch(lsmType, styleValue)
    if (smMediaType == nil and styleValue ~= "None") then
        if not lastWarning[key] or GetTime() - lastWarning[key] > 120 then
            lastWarning[key] = GetTime()
            Gladdy:Warn("Could not find", "\"" .. lsmType .. "\" \"", styleValue, " \" for", "\"" .. key .. "\"", "- setting it to", "\"" .. defaults[lsmType] .. "\"")
        end
        return self.LSM:Fetch(lsmType, defaults[lsmType])
    end
    return smMediaType
end
