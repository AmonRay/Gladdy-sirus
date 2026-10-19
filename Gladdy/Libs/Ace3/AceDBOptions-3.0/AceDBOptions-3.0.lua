--- AceDBOptions-3.0 provides a universal AceConfig options screen for managing AceDB-3.0 profiles.
-- @class file
-- @name AceDBOptions-3.0
-- @release $Id$
local ACEDBO_MAJOR, ACEDBO_MINOR = "AceDBOptions-3.0", 10015
local AceDBOptions = LibStub:NewLibrary(ACEDBO_MAJOR, ACEDBO_MINOR)

if not AceDBOptions then return end -- No upgrade needed

-- Lua APIs
local pairs, next = pairs, next

-- WoW APIs
local UnitClass = UnitClass

AceDBOptions.optionTables = AceDBOptions.optionTables or {}
AceDBOptions.handlers = AceDBOptions.handlers or {}

--[[
	Localization of AceDBOptions-3.0
]]

local L = {
	choose = "Existing Profiles",
	choose_desc = "You can either create a new profile by entering a name in the editbox, or choose one of the already existing profiles.",
	choose_sub = "Select one of your currently available profiles.",
	copy = "Copy From",
	copy_desc = "Copy the settings from one existing profile into the currently active profile.",
	current = "Current Profile:",
	default = "Default",
	delete = "Delete a Profile",
	delete_confirm = "Are you sure you want to delete the selected profile?",
	delete_desc = "Delete existing and unused profiles from the database to save space, and cleanup the SavedVariables file.",
	delete_sub = "Deletes a profile from the database.",
	intro = "You can change the active database profile, so you can have different settings for every character.",
	new = "New",
	new_sub = "Create a new empty profile.",
	profiles = "Profiles",
	profiles_sub = "Manage Profiles",
	reset = "Reset Profile",
	reset_desc = "Reset the current profile back to its default values, in case your configuration is broken, or you simply want to start over.",
	reset_sub = "Reset the current profile to the default",
}

local LOCALE = GetLocale()
if LOCALE == "ruRU" then
	L["choose"] = "Существующие профили"
	L["choose_desc"] = "Вы можете создать новый профиль, введя название в поле ввода, или выбрать один из уже существующих профилей."
	L["choose_sub"] = "Выбор одиного из уже доступных профилей"
	L["copy"] = "Скопировать из"
	L["copy_desc"] = "Скопировать настройки из выбранного профиля в активный."
	L["current"] = "Текущий профиль:"
	L["default"] = "По умолчанию"
	L["delete"] = "Удалить профиль"
	L["delete_confirm"] = "Вы уверены, что вы хотите удалить выбранный профиль?"
	L["delete_desc"] = "Удалить существующий и неиспользуемый профиль из БД для сохранения места, и очистить SavedVariables файл."
	L["delete_sub"] = "Удаление профиля из БД"
	L["intro"] = "Изменяя активный профиль, вы можете задать различные настройки модификаций для каждого персонажа."
	L["new"] = "Новый"
	L["new_sub"] = "Создать новый чистый профиль"
	L["profiles"] = "Профили"
	L["profiles_sub"] = "Управление профилями"
	L["reset"] = "Сброс профиля"
	L["reset_desc"] = "Сбросить текущий профиль к стандартным настройкам, если ваша конфигурация испорчена или вы хотите настроить всё заново."
	L["reset_sub"] = "Сброс текущего профиля на стандартный"
end

local defaultProfiles
local tmpprofiles = {}

-- Get a list of available profiles for the specified database.
-- You can specify which profiles to include/exclude in the list using the two boolean parameters listed below.
-- @param db The db object to retrieve the profiles from
-- @param common If true, getProfileList will add the default profiles to the return list, even if they have not been created yet
-- @param nocurrent If true, then getProfileList will not display the current profile in the list
-- @return Hashtable of all profiles with the internal name as keys and the display name as value.
local function getProfileList(db, common, nocurrent)
	local profiles = {}

	-- copy existing profiles into the table
	local currentProfile = db:GetCurrentProfile()
	for i,v in pairs(db:GetProfiles(tmpprofiles)) do
		if not (nocurrent and v == currentProfile) then
			profiles[v] = v
		end
	end

	-- add our default profiles to choose from ( or rename existing profiles)
	for k,v in pairs(defaultProfiles) do
		if (common or profiles[k]) and not (nocurrent and k == currentProfile) then
			profiles[k] = v
		end
	end

	return profiles
end

--[[
	OptionsHandlerPrototype
	prototype class for handling the options in a sane way
]]
local OptionsHandlerPrototype = {}

--[[ Reset the profile ]]
function OptionsHandlerPrototype:Reset()
	self.db:ResetProfile()
end

--[[ Set the profile to value ]]
function OptionsHandlerPrototype:SetProfile(info, value)
	self.db:SetProfile(value)
end

--[[ returns the currently active profile ]]
function OptionsHandlerPrototype:GetCurrentProfile()
	return self.db:GetCurrentProfile()
end

--[[
	List all active profiles
	you can control the output with the .arg variable
	currently four modes are supported

	(empty) - return all available profiles
	"nocurrent" - returns all available profiles except the currently active profile
	"common" - returns all avaialble profiles + some commonly used profiles ("char - realm", "realm", "class", "Default")
	"both" - common except the active profile
]]
function OptionsHandlerPrototype:ListProfiles(info)
	local arg = info.arg
	local profiles
	if arg == "common" and not self.noDefaultProfiles then
		profiles = getProfileList(self.db, true, nil)
	elseif arg == "nocurrent" then
		profiles = getProfileList(self.db, nil, true)
	else
		profiles = getProfileList(self.db)
	end

	return profiles
end

function OptionsHandlerPrototype:HasNoProfiles(info)
	local profiles = self:ListProfiles(info)
	return ((not next(profiles)) and true or false)
end

--[[ Copy a profile ]]
function OptionsHandlerPrototype:CopyProfile(info, value)
	self.db:CopyProfile(value)
end

--[[ Delete a profile from the db ]]
function OptionsHandlerPrototype:DeleteProfile(info, value)
	self.db:DeleteProfile(value)
end

--[[ fill defaultProfiles with some generic values ]]
local function generateDefaultProfiles(db)
	defaultProfiles = {
		["Default"] = L["default"],
		[db.keys.char] = db.keys.char,
		[db.keys.realm] = db.keys.realm,
		[db.keys.class] = UnitClass("player")
	}
end

--[[ create and return a handler object for the db, or upgrade it if it already existed ]]
local function getOptionsHandler(db, noDefaultProfiles)
	if not defaultProfiles then
		generateDefaultProfiles(db)
	end

	local handler = AceDBOptions.handlers[db] or { db = db, noDefaultProfiles = noDefaultProfiles }

	for k,v in pairs(OptionsHandlerPrototype) do
		handler[k] = v
	end

	AceDBOptions.handlers[db] = handler
	return handler
end

--[[
	the real options table
]]
local optionsTable = {
	desc = {
		order = 1,
		type = "description",
		name = L["intro"] .. "\n",
	},
	descreset = {
		order = 9,
		type = "description",
		name = L["reset_desc"],
	},
	reset = {
		order = 10,
		type = "execute",
		name = L["reset"],
		desc = L["reset_sub"],
		func = "Reset",
	},
	current = {
		order = 11,
		type = "description",
		name = function(info) return L["current"] .. " " .. NORMAL_FONT_COLOR_CODE .. info.handler:GetCurrentProfile() .. FONT_COLOR_CODE_CLOSE end,
		width = "default",
	},
	choosedesc = {
		order = 20,
		type = "description",
		name = "\n" .. L["choose_desc"],
	},
	new = {
		name = L["new"],
		desc = L["new_sub"],
		type = "input",
		order = 30,
		get = false,
		set = "SetProfile",
	},
	choose = {
		name = L["choose"],
		desc = L["choose_sub"],
		type = "select",
		order = 40,
		get = "GetCurrentProfile",
		set = "SetProfile",
		values = "ListProfiles",
		arg = "common",
	},
	copydesc = {
		order = 50,
		type = "description",
		name = "\n" .. L["copy_desc"],
	},
	copyfrom = {
		order = 60,
		type = "select",
		name = L["copy"],
		desc = L["copy_desc"],
		get = false,
		set = "CopyProfile",
		values = "ListProfiles",
		disabled = "HasNoProfiles",
		arg = "nocurrent",
	},
	deldesc = {
		order = 70,
		type = "description",
		name = "\n" .. L["delete_desc"],
	},
	delete = {
		order = 80,
		type = "select",
		name = L["delete"],
		desc = L["delete_sub"],
		get = false,
		set = "DeleteProfile",
		values = "ListProfiles",
		disabled = "HasNoProfiles",
		arg = "nocurrent",
		confirm = true,
		confirmText = L["delete_confirm"],
	},
}

--- Get/Create a option table that you can use in your addon to control the profiles of AceDB-3.0.
-- @param db The database object to create the options table for.
-- @return The options table to be used in AceConfig-3.0
-- @usage
-- -- Assuming `options` is your top-level options table and `self.db` is your database:
-- options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
function AceDBOptions:GetOptionsTable(db, noDefaultProfiles)
	local tbl = AceDBOptions.optionTables[db] or {
			type = "group",
			name = L["profiles"],
			desc = L["profiles_sub"],
		}

	tbl.handler = getOptionsHandler(db, noDefaultProfiles)
	tbl.args = optionsTable

	AceDBOptions.optionTables[db] = tbl
	return tbl
end

-- upgrade existing tables
for db,tbl in pairs(AceDBOptions.optionTables) do
	tbl.handler = getOptionsHandler(db)
	tbl.args = optionsTable
end
