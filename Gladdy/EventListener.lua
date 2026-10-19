local select, string_gsub, tostring, pairs, ipairs = select, string.gsub, tostring, pairs, ipairs
local wipe = wipe
local unpack = unpack

local AURA_TYPE_DEBUFF = AURA_TYPE_DEBUFF
local AURA_TYPE_BUFF = AURA_TYPE_BUFF

local COMBATLOG_OBJECT_REACTION_HOSTILE	= COMBATLOG_OBJECT_REACTION_HOSTILE
local COMBATLOG_OBJECT_AFFILIATION_MINE = COMBATLOG_OBJECT_AFFILIATION_MINE

local UnitName, UnitAura, UnitRace, UnitClass, UnitGUID, UnitIsUnit, UnitExists = UnitName, UnitAura, UnitRace, UnitClass, UnitGUID, UnitIsUnit, UnitExists
local UnitCastingInfo, UnitChannelInfo = UnitCastingInfo, UnitChannelInfo
local GetSpellInfo = GetSpellInfo
local GetTime = GetTime

local Gladdy = LibStub("Gladdy")
local L = Gladdy.L
local Cooldowns = Gladdy.modules["Cooldowns"]
local Diminishings = Gladdy.modules["Diminishings"]

local PVP_TRINKET, NS, EM, POM, FD

local EventListener = Gladdy:NewModule("EventListener", 101, {
	test = true,
})

function EventListener:Initialize()
	if not self.spellsInitialized then
		PVP_TRINKET = GetSpellInfo(42292)
		NS = GetSpellInfo(16188)
		EM = GetSpellInfo(16166)
		POM = GetSpellInfo(12043)
		FD = GetSpellInfo(5384)
		self.spellsInitialized = true
	end

	self:RegisterMessage("JOINED_ARENA")
end

function EventListener.OnEvent(self, event, ...)
    local handler = self[event]
    if handler then
        handler(self, ...)
    end
end

function EventListener:Reset()
	self:UnregisterAllEvents()
	self:SetScript("OnEvent", nil)
end

function EventListener:JOINED_ARENA()
	Gladdy:Debug("INFO", "EventListener JOINED_ARENA")

	self:SetScript("OnEvent", EventListener.OnEvent)

	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	self:RegisterEvent("ARENA_OPPONENT_UPDATE")
	self:RegisterEvent("UNIT_AURA")
	self:RegisterEvent("UNIT_SPELLCAST_START")
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
	self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

	for i=1,Gladdy.curBracket do
		local unit = "arena"..i
		if Gladdy.buttons[unit] and Gladdy.buttons[unit].lastAuras then
			wipe(Gladdy.buttons[unit].lastAuras)
		end
		if UnitExists(unit) then
			Gladdy:SpotEnemy(unit, true)
		end
		if UnitExists("arenapet" .. i) then
			Gladdy:SendMessage("PET_SPOTTED", "arenapet" .. i)
		end
	end
end

function Gladdy:SpotEnemy(unit, auraScan)
	local button = self.buttons[unit]
	if not unit or not button then
		return
	end
	if UnitExists(unit) then
		button.raceLoc = UnitRace(unit)
		button.race = select(2, UnitRace(unit))
		button.constellation = EventListener:detectConstellation(unit)
		button.classLoc = select(1, UnitClass(unit))
		button.class = select(2, UnitClass(unit))
		button.name = UnitName(unit)
        local guid = UnitGUID(unit)
        if button.guid and button.guid ~= guid and Gladdy.guids[button.guid] == unit then
            Gladdy.guids[button.guid] = nil
        end
        button.guid = guid
        if guid then Gladdy.guids[guid] = unit end
	end
	if button.class and button.race then
		Gladdy:Debug("INFO", "SpotEnemy", "ENEMY_SPOTTED", unit)
		Gladdy:SendMessage("ENEMY_SPOTTED", unit)
	end
	if auraScan and not button.spec then
		Gladdy:SendMessage("AURA_FADE", unit, "HELPFUL")
		for n = 1, 40 do
			local spellName, rank, texture, count, dispelType, duration, expirationTime, unitCaster, _, _, spellID = UnitAura(unit, n, "HELPFUL")
			if ( not spellName ) then
				Gladdy:SendMessage("AURA_GAIN_LIMIT", unit, AURA_TYPE_BUFF, n - 1)
				break
			end

			if Gladdy.exceptionNames[spellID] then
				spellName = Gladdy.exceptionNames[spellID]
			end

			if Gladdy.specBuffs[spellName] and unitCaster then
				local unitPet = string_gsub(unit, "%d$", "pet%1")
				if UnitIsUnit(unit, unitCaster) or UnitIsUnit(unitPet, unitCaster) then
					EventListener:DetectSpec(unit, Gladdy.specBuffs[spellName])
				end
			end
			if Gladdy.cooldownBuffs[spellName] and unitCaster then
				for arenaUnit,v in pairs(self.buttons) do
					if (UnitIsUnit(arenaUnit, unitCaster)) then
						Cooldowns:CooldownUsed(arenaUnit, v.class, Gladdy.cooldownBuffs[spellName].spellId, Gladdy.cooldownBuffs[spellName].cd(expirationTime - GetTime()))
					end
				end
			end

			Gladdy:SendMessage("AURA_GAIN", unit, AURA_TYPE_BUFF, spellID, spellName, texture, duration, expirationTime, count, dispelType, n, unitCaster)
		end
	end
end

local combatEvents = {
    SPELL_AURA_APPLIED = true, SPELL_AURA_REMOVED = true,
    SPELL_AURA_REFRESH = true, SPELL_CAST_SUCCESS = true, SPELL_MISSED = true,
    SPELL_INTERRUPT = true, UNIT_DIED = true, PARTY_KILL = true,
    SPELL_INSTAKILL = true,
}

function EventListener:COMBAT_LOG_EVENT_UNFILTERED(...)
	local _, eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, spellID, spellName, spellSchool, extraSpellId, extraSpellName,extraSpellSchool = ...

    if not combatEvents[eventType] and not Gladdy.specSpells[spellName] then return end

    if Gladdy.debug and combatEvents[eventType] then
		Gladdy:Debug("INFO", "COMBAT_LOG_EVENT_UNFILTERED",
			"Event:", eventType,
			"Source:", sourceName or "nil",
			"Dest:", destName or "nil",
			"SpellName:", spellName or "nil",
			"SpellID:", spellID or "nil",
			"SpellSchool:", spellSchool or "nil",
			"ExtraSpellID:", extraSpellId or "nil",
			"ExtraSpellName:", extraSpellName or "nil",
			"ExtraSpellSchool:", extraSpellSchool or "nil"
		)
	end

	local srcUnit = Gladdy.guids[sourceGUID] -- can be a PET
	local destUnit = Gladdy.guids[destGUID] -- can be a PET

	if (Gladdy.db.shadowsightTimerEnabled and eventType == "SPELL_AURA_APPLIED" and spellID == 34709) then
		Gladdy.modules["Shadowsight Timer"]:AURA_GAIN(nil, nil, 34709)
	end

	if Gladdy.exceptionNames[spellID] then
		spellName = Gladdy.exceptionNames[spellID]
	end

	if destUnit then
		if Gladdy.buttons[destUnit] and Gladdy.db.drEnabled and extraSpellId == AURA_TYPE_DEBUFF then
			if (eventType == "SPELL_AURA_REMOVED") then
				Diminishings:AuraFade(destUnit, spellID)
			end
			if (eventType == "SPELL_AURA_REFRESH") then
				Diminishings:AuraGain(destUnit, spellID)
			end
			if (eventType == "SPELL_AURA_APPLIED") then
				Diminishings:AuraGain(destUnit, spellID)
			end
		end

		if (eventType == "UNIT_DIED" or eventType == "PARTY_KILL" or eventType == "SPELL_INSTAKILL") then
			if not Gladdy:isFeignDeath(destUnit) then
				Gladdy:SendMessage("UNIT_DEATH", destUnit)
			end
		end

		if Gladdy.buttons[destUnit] and (not Gladdy.buttons[destUnit].class or not Gladdy.buttons[destUnit].race) then
			Gladdy:SpotEnemy(destUnit, true)
		end

		if Gladdy.buttons[destUnit] and eventType == "SPELL_INTERRUPT" then
			Gladdy:SendMessage("SPELL_INTERRUPT", destUnit,spellID,spellName,spellSchool,extraSpellId,extraSpellName,extraSpellSchool)
		end
	end

	if srcUnit then
		if not Gladdy.buttons[srcUnit] or not UnitExists(srcUnit) then
			return
		end

		if not Gladdy.buttons[srcUnit].class or not Gladdy.buttons[srcUnit].race then
			Gladdy:SpotEnemy(srcUnit, true)
		end
		if not Gladdy.buttons[srcUnit].spec then
			self:DetectSpec(srcUnit, Gladdy.specSpells[spellName])
		end
		if (eventType == "SPELL_CAST_SUCCESS" or eventType == "SPELL_MISSED") then
			if Gladdy.db.cooldown and Cooldowns.cooldownSpellIds[spellName] then
				local unitClass
				local spellId = Cooldowns.cooldownSpellIds[spellName]
				if spellID == 16188 or spellID == 17116 then
					spellId = spellID
				end
				if Gladdy.db.cooldownCooldowns[tostring(spellId)] and (eventType == "SPELL_CAST_SUCCESS" or eventType == "SPELL_MISSED" or eventType == "SPELL_DODGED") then
					local classCooldowns = Gladdy:GetCooldownList()[Gladdy.buttons[srcUnit].class]
					if classCooldowns and classCooldowns[spellId] then
						unitClass = Gladdy.buttons[srcUnit].class
					else
						unitClass = Gladdy.buttons[srcUnit].race
					end
					if spellID ~= 16188 and spellID ~= 17116 and spellID ~= 16166 and spellID ~= 12043 and spellID ~= 5384 then
						Gladdy:Debug("INFO", eventType, "- CooldownUsed", srcUnit, "spellID:", spellID)
						Cooldowns:CooldownUsed(srcUnit, unitClass, spellId)
					end
				end
			end

            if eventType == "SPELL_CAST_SUCCESS" and spellID == 42292 then
                Gladdy:SendMessage("TRINKET_USED", srcUnit)
            end
            local button = Gladdy.buttons[srcUnit]
            local constellation = button.constellation
            if constellation and (constellation.id == spellID or (constellation.alt and constellation.alt[tostring(spellID)])) then
                Gladdy:Debug("INFO", "UNIT_SPELLCAST_SUCCEEDED - RACIAL_USED", srcUnit, spellID)
                Gladdy:SendMessage("RACIAL_USED", srcUnit)
            end
		end
		if (eventType == "SPELL_AURA_REMOVED" and (spellID == 16188 or spellID == 17116 or spellID == 16166 or spellID == 12043) and Gladdy.buttons[srcUnit].class) then
			Gladdy:Debug("INFO", "SPELL_AURA_REMOVED - CooldownUsed", srcUnit, "spellID:", spellID)
			Cooldowns:CooldownUsed(srcUnit, Gladdy.buttons[srcUnit].class, spellID)
		end
		if (eventType == "SPELL_AURA_REMOVED" and Gladdy.db.cooldown and Cooldowns.cooldownSpellIds[spellName]) then
			local unit = Gladdy:GetArenaUnit(srcUnit, true)
			local spellId = Cooldowns.cooldownSpellIds[spellName]
			if spellID == 16188 or spellID == 17116 then
				spellId = spellID
			end
			if unit then
				Cooldowns:AURA_FADE(unit, spellId)
			end
		end
	end

	if srcUnit and Gladdy.buttons[srcUnit] and sourceFlags and eventType == "SPELL_AURA_APPLIED"
		and bit.band(sourceFlags, COMBATLOG_OBJECT_REACTION_HOSTILE) == COMBATLOG_OBJECT_REACTION_HOSTILE then
		if( spellID == 51514 or spellID == 17928 ) then
			Gladdy:Debug("INFO", "SPELL_AURA_REMOVED - CooldownUsed", srcUnit, "spellID:", spellID)
			Cooldowns:CooldownUsed(srcUnit, Gladdy.buttons[srcUnit].class, spellID)
		end
	end
end

function EventListener:ARENA_OPPONENT_UPDATE(unit, updateReason)

	unit = Gladdy:GetArenaUnit(unit)
	if not unit then
		Gladdy:Debug("WARN", "ARENA_OPPONENT_UPDATE", "Invalid unit after GetArenaUnit")
        return
	end

	local button = Gladdy.buttons[unit]
	if not button then
		Gladdy:Debug("WARN", "ARENA_OPPONENT_UPDATE", "No button for unit:", unit)
	end

	local pet = Gladdy.modules["Pets"] and Gladdy.modules["Pets"].frames and Gladdy.modules["Pets"].frames[unit]
	if not pet then
		Gladdy:Debug("WARN", "ARENA_OPPONENT_UPDATE", "No pet for unit:", unit)
	end

	if button or pet then
		if updateReason == "seen" then
			if button then
				button.stealthed = false
				Gladdy:SendMessage("ENEMY_STEALTH", unit, false)
				if not button.class or not button.race then
					Gladdy:Debug("INFO", "ARENA_OPPONENT_UPDATE", "SpotEnemy", unit)
					Gladdy:SpotEnemy(unit, true)
				end
			end
			if pet then
				Gladdy:SendMessage("PET_SPOTTED", unit)
			end
		elseif updateReason == "unseen" then
			if button then
				button.stealthed = true
				Gladdy:SendMessage("ENEMY_STEALTH", unit, true)
			end
			if pet then
				Gladdy:SendMessage("PET_STEALTH", unit)
			end
		elseif updateReason == "destroyed" then
			if button then
				Gladdy:SendMessage("UNIT_DESTROYED", unit)
			end
			if pet then
				Gladdy:SendMessage("PET_DESTROYED", unit)
			end
		end
	end
end

Gladdy.cooldownBuffs = {
	[GetSpellInfo(6346)] = { cd = function(expTime) -- 180s uptime == cd
		return expTime
	end, spellId = 6346 }, -- Fear Ward
	[GetSpellInfo(11305)] = { cd = function(expTime) -- 15s uptime
		return 300 - (15 - expTime)
	end, spellId = 11305 }, -- Sprint
	[36554] = { cd = function(expTime) -- 3s uptime
		return 30 - (3 - expTime)
	end, spellId = 36554 }, -- Shadowstep speed buff
	[36563] = { cd = function(expTime) -- 10s uptime
		return 30 - (10 - expTime)
	end, spellId = 36554 }, -- Shadowstep dmg buff
	[GetSpellInfo(26889)] = { cd = function(expTime) -- 3s uptime
		return 180 - (10 - expTime)
	end, spellId = 26889 }, -- Vanish
	racials = {
		[GetSpellInfo(20600)] = { cd = function(expTime) -- 20s uptime
			return GetTime() - (20 - expTime)
		end, spellId = 20600 }, -- Perception
	}
}
function EventListener:UNIT_AURA(unit)
	local button = Gladdy.buttons[unit]
	if not button then return end

    local previous = button.lastAuras or {}
    local current = button.auras or {}
    if current == previous then current = button.auraCache or {} end
    wipe(current)
    button.auras = current
    button.lastAuras = previous

	Gladdy:SendMessage("AURA_FADE", unit, AURA_TYPE_BUFF)
	Gladdy:SendMessage("AURA_FADE", unit, AURA_TYPE_DEBUFF)

    if not button.constellation then
        button.constellation = self:detectConstellation(unit)
        if button.constellation then Gladdy:SendMessage("ENEMY_SPOTTED", unit) end
    end

	for i = 1, 2 do
		if not Gladdy.buttons[unit].class or not Gladdy.buttons[unit].race then
			Gladdy:SpotEnemy(unit, false)
		end
		local filter = (i == 1 and "HELPFUL" or "HARMFUL")
		local auraType = i == 1 and AURA_TYPE_BUFF or AURA_TYPE_DEBUFF

		for n = 1, 40 do
			local spellName, rank, texture, count, dispelType, duration, expirationTime, unitCaster, _, shouldConsolidate, spellID = UnitAura(unit, n, filter)

			if not spellID then
				Gladdy:SendMessage("AURA_GAIN_LIMIT", unit, auraType, n - 1)
				break
			end

			if Gladdy.exceptionNames[spellID] then
				spellName = Gladdy.exceptionNames[spellID]
			end

            local aura = previous[spellID] or {}
            aura[1], aura[2], aura[3], aura[4] = auraType, spellID, spellName, texture
            aura[5], aura[6], aura[7], aura[8] = duration, expirationTime, count, dispelType
            current[spellID] = aura

			if not button.spec and Gladdy.specBuffs and Gladdy.specBuffs[spellName] and unitCaster then
				local unitPet = string_gsub(unit, "%d$", "pet%1")
				if UnitIsUnit(unit, unitCaster) or UnitIsUnit(unitPet, unitCaster) then
					self:DetectSpec(unit, Gladdy.specBuffs[spellName])
				end
			end

			if Gladdy.cooldownBuffs and (Gladdy.cooldownBuffs[spellName] or Gladdy.cooldownBuffs[spellID]) and unitCaster then
				local cooldownBuff = Gladdy.cooldownBuffs[spellID] or Gladdy.cooldownBuffs[spellName]
				for arenaUnit,v in pairs(Gladdy.buttons) do
					if UnitIsUnit(arenaUnit, unitCaster) then
						Cooldowns:CooldownUsed(arenaUnit, v.class, cooldownBuff.spellId, cooldownBuff.cd(expirationTime - GetTime()))
					end
				end
			end

			if Gladdy.cooldownBuffs.racials[spellName] then
				Gladdy:SendMessage("RACIAL_USED", unit, spellName, Gladdy.cooldownBuffs.racials[spellName].cd(expirationTime - GetTime()), spellName)
			end

			Gladdy:SendMessage("AURA_GAIN", unit, auraType, spellID, spellName, texture, duration, expirationTime, count, dispelType, n, unitCaster)
		end
	end

	for spellID,v in pairs(button.lastAuras) do
		if not button.auras[spellID] then
			if Gladdy.db.cooldown and Cooldowns.cooldownSpellIds[v[3]] then
				local spellId = Cooldowns.cooldownSpellIds[v[3]]
				if spellID == 16188 or spellID == 17116 then
					spellId = spellID
				end
				Cooldowns:AURA_FADE(unit, spellId)
				if spellID == 5384 then
					Cooldowns:CooldownUsed(unit, Gladdy.buttons[unit].class, 5384)
				end
			end
		end
	end

    button.lastAuras = current
    button.auraCache = previous
    wipe(previous)

end

function EventListener:UpdateAuras(unit)
	local button = Gladdy.buttons[unit]
	if not button or not button.lastAuras then
		return
	end
	for _, aura in pairs(button.lastAuras) do
		Gladdy.modules["Auras"]:AURA_GAIN(unit, unpack(aura))
	end
end

function EventListener:UNIT_SPELLCAST_START(unit)
	if Gladdy.buttons[unit] then
		local spellName = UnitCastingInfo(unit)
		if Gladdy.specSpells[spellName] and not Gladdy.buttons[unit].spec then
			self:DetectSpec(unit, Gladdy.specSpells[spellName])
		end
	end
end

function EventListener:UNIT_SPELLCAST_CHANNEL_START(unit)
	if Gladdy.buttons[unit] then
		local spellName = UnitChannelInfo(unit)
		if Gladdy.specSpells[spellName] and not Gladdy.buttons[unit].spec then
			self:DetectSpec(unit, Gladdy.specSpells[spellName])
		end
	end
end

function EventListener:UNIT_SPELLCAST_SUCCEEDED(unit, spell, rank, castID, spellID)
    unit = Gladdy:GetArenaUnit(unit)
    local button = unit and Gladdy.buttons[unit]
    if not button then return end

    if type(spell) == "number" then
        spellID = spell
    elseif type(rank) == "number" and type(spell) == "string" and spell:match("^Cast%-") then
        spellID = rank
    end
    local spellName = type(spellID) == "number" and GetSpellInfo(spellID) or spell
    spellName = Gladdy.exceptionNames[spellID] or spellName
    if not spellName then return end

    if not button.spec then self:DetectSpec(unit, Gladdy.specSpells[spellName]) end
    if spellID == 42292 or spellName == PVP_TRINKET then
        Gladdy:SendMessage("TRINKET_USED", unit)
    end

    local constellation = button.constellation
    if constellation then
        local racialUsed = spellID == constellation.id or spellName == GetSpellInfo(constellation.id)
        if not racialUsed and constellation.alt then
            for id in pairs(constellation.alt) do
                if tonumber(id) == spellID or spellName == GetSpellInfo(tonumber(id)) then
                    racialUsed = true
                    break
                end
            end
        end
        if racialUsed then Gladdy:SendMessage("RACIAL_USED", unit) end
    end

    local cooldownId = Cooldowns.cooldownSpellIds[spellName]
    if not Gladdy.db.cooldown or not cooldownId or not Gladdy.db.cooldownCooldowns[tostring(cooldownId)] then return end
    if spellName == NS or spellName == EM or spellName == POM or spellName == FD then return end
    local classCooldowns = Gladdy:GetCooldownList()[button.class]
    local unitClass = classCooldowns and classCooldowns[cooldownId] and button.class or button.race
    Cooldowns:CooldownUsed(unit, unitClass, cooldownId)
end

function EventListener:DetectSpec(unit, spec)
	local button = Gladdy.buttons[unit]
	if (not button or not spec or button.spec) then return end
    spec = L[spec]
	if button.class == "PALADIN" and not Gladdy:contains(spec, {L["Holy"], L["Retribution"], L["Protection"]}) or
	   button.class == "SHAMAN" and not Gladdy:contains(spec, {L["Restoration"], L["Enhancement"], L["Elemental"]}) or
	   button.class == "ROGUE" and not Gladdy:contains(spec, {L["Subtlety"], L["Assassination"], L["Combat"]}) or
	   button.class == "WARLOCK" and not Gladdy:contains(spec, {L["Demonology"], L["Destruction"], L["Affliction"]}) or
	   button.class == "PRIEST" and not Gladdy:contains(spec, {L["Shadow"], L["Discipline"], L["Holy"]}) or
	   button.class == "MAGE" and not Gladdy:contains(spec, {L["Frost"], L["Fire"], L["Arcane"]}) or
	   button.class == "DRUID" and not Gladdy:contains(spec, {L["Restoration"], L["Feral"], L["Balance"]}) or
	   button.class == "HUNTER" and not Gladdy:contains(spec, {L["Beast Mastery"], L["Marksmanship"], L["Survival"]}) or
	   button.class == "WARRIOR" and not Gladdy:contains(spec, {L["Arms"], L["Protection"], L["Fury"]}) or
	   button.class == "DEATHKNIGHT" and not Gladdy:contains(spec, {L["Unholy"], L["Blood"], L["Frost"]}) then
		return
	end

	if not button.spec then
		button.spec = spec
		Gladdy:SendMessage("UNIT_SPEC", unit, spec)
	end
end

function EventListener:Test(unit)
	local button = Gladdy.buttons[unit]
	if (button and Gladdy.testData[unit].testSpec) then
		button.spec = nil
		Gladdy:SpotEnemy(unit, false)
		self:DetectSpec(unit, button.testSpec)
	end
end

function EventListener:detectConstellation(unit)
    if not unit or not UnitExists(unit) then return end
    local constellations = Gladdy:Constellations()
    if C_Unit and C_Unit.GetZodiacByDebuff and ZODIAC_DEBUFFS then
        local raceID = C_Unit.GetZodiacByDebuff(unit)
        if raceID then
            for auraID, zodiacRaceID in pairs(ZODIAC_DEBUFFS) do
                if raceID == zodiacRaceID and constellations[auraID] then
                    return constellations[auraID]
                end
            end
        end
    end
    local index = 1
    while true do
        local name, _, _, _, _, _, _, _, _, _, auraID = UnitAura(unit, index, "HARMFUL")
        if not name then return end
        if constellations[auraID] then return constellations[auraID] end
        index = index + 1
    end
end
