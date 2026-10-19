local tbl_sort, select, string_lower = table.sort, select, string.lower

local GetSpellInfo = GetSpellInfo
local GetItemInfo = GetItemInfo

local Gladdy = LibStub("Gladdy")
local L = Gladdy.L
local AURA_TYPE_DEBUFF, AURA_TYPE_BUFF = AURA_TYPE_DEBUFF, AURA_TYPE_BUFF

Gladdy.expansion = "Wrath"
Gladdy.CLASSES = { "MAGE", "PRIEST", "DRUID", "SHAMAN", "PALADIN", "WARLOCK", "WARRIOR", "HUNTER", "ROGUE", "DEATHKNIGHT" }
tbl_sort(Gladdy.CLASSES)

local specBuffs = Gladdy:FilterSpellTable({
	[Gladdy:SpellKey(56638)] = "Arms", -- Taste for Blood
	[Gladdy:SpellKey(64976)] = "Arms", -- Juggernaut
	[Gladdy:SpellKey(57522)] = "Arms", -- Enrage
	[Gladdy:SpellKey(52437)] = "Arms", -- Sudden Death
	[Gladdy:SpellKey(46857)] = "Arms", -- Trauma
	[Gladdy:SpellKey(56112)] = "Fury", -- Furious Attacks
	[Gladdy:SpellKey(29801)] = "Fury", -- Rampage
	[Gladdy:SpellKey(46916)] = "Fury", -- Slam!
	[Gladdy:SpellKey(50227)] = "Protection", -- Sword and Board
	[Gladdy:SpellKey(50720)] = "Protection", -- Vigilance
	[Gladdy:SpellKey(74347)] = "Protection", -- Silenced - Gag Order
	[Gladdy:SpellKey(20375)] = "Retribution", -- Seal of Command
	[Gladdy:SpellKey(59578)] = "Retribution", -- The Art of War
	[Gladdy:SpellKey(31836)] = "Holy", -- Light's Grace
	[Gladdy:SpellKey(53563)] = "Holy", -- Beacon of Light
	[Gladdy:SpellKey(54149)] = "Holy", -- Infusion of Light
	[Gladdy:SpellKey(63529)] = "Protection", -- Silenced - Shield of the Templar
	[Gladdy:SpellKey(36554)] = "Subtlety", -- Shadowstep
	[Gladdy:SpellKey(44373)] = "Subtlety", -- Shadowstep Speed
	[Gladdy:SpellKey(36563)] = "Subtlety", -- Shadowstep DMG
	[Gladdy:SpellKey(51713)] = "Subtlety", -- Shadow Dance
	[Gladdy:SpellKey(31665)] = "Subtlety", -- Master of Subtlety
	[Gladdy:SpellKey(14278)] = "Subtlety", -- Ghostly Strike
	[Gladdy:SpellKey(51690)] = "Combat", -- Killing Spree
	[Gladdy:SpellKey(13877)] = "Combat", -- Blade Flurry
	[Gladdy:SpellKey(13750)] = "Combat", -- Adrenaline Rush
	[Gladdy:SpellKey(14177)] = "Assassination", -- Cold Blood
	[Gladdy:SpellKey(47788)] = "Holy", -- Guardian Spirit
	[Gladdy:SpellKey(52800)] = "Discipline", -- Borrowed Time
	[Gladdy:SpellKey(63944)] = "Discipline", -- Renewed Hope
	[Gladdy:SpellKey(15473)] = "Shadow", -- Shadowform
	[Gladdy:SpellKey(15286)] = "Shadow", -- Vampiric Embrace
	[Gladdy:SpellKey(49222)] = "Unholy", -- Bone Shield
	[Gladdy:SpellKey(49016)] = "Blood", -- Hysteria
	[Gladdy:SpellKey(53138)] = "Blood", -- Abomination's Might
	[Gladdy:SpellKey(55610)] = "Frost", -- Imp. Icy Talons
	[Gladdy:SpellKey(43039)] = "Frost", -- Ice Barrier
	[Gladdy:SpellKey(74396)] = "Frost", -- Fingers of Frost
	[Gladdy:SpellKey(57761)] = "Frost", -- Fireball!
	[Gladdy:SpellKey(11129)] = "Fire", -- Combustion
	[Gladdy:SpellKey(64346)] = "Fire", -- Fiery Payback
	[Gladdy:SpellKey(48108)] = "Fire", -- Hot Streak
	[Gladdy:SpellKey(54741)] = "Fire", -- Firestarter
	[Gladdy:SpellKey(55360)] = "Fire", -- Living Bomb
	[Gladdy:SpellKey(31583)] = "Arcane", -- Arcane Empowerment
	[Gladdy:SpellKey(44413)] = "Arcane", -- Incanter's Absorption
	[Gladdy:SpellKey(30302)] = "Destruction", -- Nether Protection
	[Gladdy:SpellKey(63244)] = "Destruction", -- Pyroclasm
	[Gladdy:SpellKey(54277)] = "Destruction", -- Backdraft
	[Gladdy:SpellKey(47283)] = "Destruction", -- Empowered Imp
	[Gladdy:SpellKey(34936)] = "Destruction", -- Backlash
	[Gladdy:SpellKey(47193)] = "Demonology", -- Demonic Empowerment
	[Gladdy:SpellKey(64371)] = "Affliction", -- Eradication
	[Gladdy:SpellKey(57663)] = "Elemental", -- Totem of Wrath
	[Gladdy:SpellKey(65264)] = "Elemental", -- Lava Flows
	[Gladdy:SpellKey(51470)] = "Elemental", -- Elemental Oath
	[Gladdy:SpellKey(52179)] = "Elemental", -- Astral Shift
	[Gladdy:SpellKey(49284)] = "Restoration", -- Earth Shield
	[Gladdy:SpellKey(53390)] = "Restoration", -- Tidal Waves
	[Gladdy:SpellKey(30809)] = "Enhancement", -- Unleashed Rage
	[Gladdy:SpellKey(53817)] = "Enhancement", -- Maelstrom Weapon
	[Gladdy:SpellKey(63685)] = "Enhancement", -- Freeze (Frozen Power)
	[Gladdy:SpellKey(20895)] = "Beast Mastery", -- Spirit Bond
	[Gladdy:SpellKey(34471)] = "Beast Mastery", -- The Beast Within
	[Gladdy:SpellKey(75447)] = "Beast Mastery", -- Ferocious Inspiration
	[Gladdy:SpellKey(19506)] = "Marksmanship", -- Trueshot Aura
	[Gladdy:SpellKey(64420)] = "Survival", -- Sniper Training
	[Gladdy:SpellKey(24932)] = "Feral", -- Leader of the Pack
	[Gladdy:SpellKey(16975)] = "Feral", -- Predatory Strikes
	[Gladdy:SpellKey(50334, " Feral")] = "Feral", -- Berserk
	[Gladdy:SpellKey(24907)] = "Balance", -- Moonkin Aura
	[Gladdy:SpellKey(24858)] = "Balance", -- Moonkin Form
	[Gladdy:SpellKey(48504)] = "Restoration", -- Living Seed
	[Gladdy:SpellKey(45283)] = "Restoration", -- Natural Perfection
	[Gladdy:SpellKey(53251)] = "Restoration", -- Wild Growth
	[Gladdy:SpellKey(16188)] = "Restoration", -- Nature's Swiftness
	[Gladdy:SpellKey(33891)] = "Restoration", -- Tree of Life
})
function Gladdy:GetSpecBuffs()
	return specBuffs
end

local specSpells = Gladdy:FilterSpellTable({
	[Gladdy:SpellKey(47486)] = "Arms", -- Mortal Strike
	[Gladdy:SpellKey(46924)] = "Arms", -- Bladestorm
	[Gladdy:SpellKey(23881)] = "Fury", -- Bloodthirst
	[Gladdy:SpellKey(12809)] = "Protection", -- Concussion Blow
	[Gladdy:SpellKey(47498)] = "Protection", -- Devastate
	[Gladdy:SpellKey(46968)] = "Protection", -- Shockwave
	[Gladdy:SpellKey(50720)] = "Protection", -- Vigilance
	[Gladdy:SpellKey(48827)] = "Protection", -- Avenger's Shield
	[Gladdy:SpellKey(48825)] = "Holy", -- Holy Shock
	[Gladdy:SpellKey(53563)] = "Holy", -- Beacon of Light
	[Gladdy:SpellKey(35395)] = "Retribution", -- Crusader Strike
	[Gladdy:SpellKey(66006)] = "Retribution", -- Divine Storm
	[Gladdy:SpellKey(20066)] = "Retribution", -- Repentance
	[Gladdy:SpellKey(48666)] = "Assassination", -- Mutilate
	[Gladdy:SpellKey(14177)] = "Assassination", -- Cold Blood
	[Gladdy:SpellKey(51690)] = "Combat", -- Killing Spree
	[Gladdy:SpellKey(13877)] = "Combat", -- Blade Flurry
	[Gladdy:SpellKey(13750)] = "Combat", -- Adrenaline Rush
	[Gladdy:SpellKey(36554)] = "Subtlety", -- Shadowstep
	[Gladdy:SpellKey(48660)] = "Subtlety", -- Hemorrhage
	[Gladdy:SpellKey(51713)] = "Subtlety", -- Shadow Dance
	[Gladdy:SpellKey(53007)] = "Discipline", -- Penance
	[Gladdy:SpellKey(10060)] = "Discipline", -- Power Infusion
	[Gladdy:SpellKey(33206)] = "Discipline", -- Pain Suppression
	[Gladdy:SpellKey(34861)] = "Holy", -- Circle of Healing
	[Gladdy:SpellKey(15487)] = "Shadow", -- Silence
	[Gladdy:SpellKey(48160)] = "Shadow", -- Vampiric Touch
	[Gladdy:SpellKey(55262)] = "Blood", -- Heart Strike
	[Gladdy:SpellKey(49203)] = "Frost", -- Hungering Cold
	[Gladdy:SpellKey(55268)] = "Frost", -- Frost Strike
	[Gladdy:SpellKey(51411)] = "Frost", -- Howling Blast
	[Gladdy:SpellKey(55271)] = "Unholy", -- Scourge Strike
	[Gladdy:SpellKey(44781)] = "Arcane", -- Arcane Barrage
	[Gladdy:SpellKey(55360)] = "Fire", -- Living Bomb
	[Gladdy:SpellKey(42950)] = "Fire", -- Dragon's Breath
	[Gladdy:SpellKey(42945)] = "Fire", -- Blast Wave
	[Gladdy:SpellKey(44572)] = "Frost", -- Deep Freeze
	[Gladdy:SpellKey(59164)] = "Affliction", -- Haunt
	[Gladdy:SpellKey(47843)] = "Affliction", -- Unstable Affliction
	[Gladdy:SpellKey(59672)] = "Demonology", -- Metamorphosis
	[Gladdy:SpellKey(47193)] = "Demonology", -- Demonic Empowerment
	[Gladdy:SpellKey(47996, " Felguard")] = "Demonology", -- Intercept Felguard
	[Gladdy:SpellKey(59172)] = "Destruction", -- Chaos Bolt
	[Gladdy:SpellKey(47847)] = "Destruction", -- Shadowfury
	[Gladdy:SpellKey(59159)] = "Elemental", -- Thunderstorm
	[Gladdy:SpellKey(16166)] = "Elemental", -- Elemental Mastery
	[Gladdy:SpellKey(51533)] = "Enhancement", -- Feral Spirit
	[Gladdy:SpellKey(30823)] = "Enhancement", -- Shamanistic Rage
	[Gladdy:SpellKey(17364)] = "Enhancement", -- Stormstrike
	[Gladdy:SpellKey(61301)] = "Restoration", -- Riptide
	[Gladdy:SpellKey(51886)] = "Restoration", -- Cleanse Spirit
	[Gladdy:SpellKey(19577)] = "Beast Mastery", -- Intimidation
	[Gladdy:SpellKey(34490)] = "Marksmanship", -- Silencing Shot
	[Gladdy:SpellKey(53209)] = "Marksmanship", -- Chimera Shot
	[Gladdy:SpellKey(60053)] = "Survival", -- Explosive Shot
	[Gladdy:SpellKey(49012)] = "Survival", -- Wyvern Sting
	[Gladdy:SpellKey(53201)] = "Balance", -- Starfall
	[Gladdy:SpellKey(61384)] = "Balance", -- Typhoon
	[Gladdy:SpellKey(24858)] = "Balance", -- Moonkin Form
	[Gladdy:SpellKey(48566)] = "Feral", -- Mangle (Cat)
	[Gladdy:SpellKey(48564)] = "Feral", -- Mangle (Bear)
	[Gladdy:SpellKey(50334, " Feral")] = "Feral", -- Berserk
	[Gladdy:SpellKey(18562)] = "Restoration", -- Swiftmend
	[Gladdy:SpellKey(17116)] = "Restoration", -- Nature's Swiftness
	[Gladdy:SpellKey(33891)] = "Restoration", -- Tree of Life
	[Gladdy:SpellKey(53251)] = "Restoration", -- Wild Growth
})
function Gladdy:GetSpecSpells()
	return specSpells
end

function Gladdy:SpecEnabled(class, specRequired, unit)
	return true
end

local importantAuras = Gladdy:FilterSpellTable({
    [Gladdy:SpellKey(33786)] = {  -- Cyclone
        track = AURA_TYPE_DEBUFF,
        priority = 40,
        spellID = 33786,
    },
	[Gladdy:SpellKey(18658)] = { -- Hibernate
		track = AURA_TYPE_DEBUFF,
		priority = 40,
		spellID = 18658,
	},
	[Gladdy:SpellKey(14309)] = { -- Freezing Trap Effect
		track = AURA_TYPE_DEBUFF,
		priority = 40,
		spellID = 14309,
	},
	[Gladdy:SpellKey(60210)] = { -- Freezing arrow effect
		track = AURA_TYPE_DEBUFF,
		priority = 40,
		spellID = 60210,
	},
	[Gladdy:SpellKey(6770)] = { -- Sap
		track = AURA_TYPE_DEBUFF,
		priority = 40,
		spellID = 6770,
	},
	[Gladdy:SpellKey(2094)] = { -- Blind
		track = AURA_TYPE_DEBUFF,
		priority = 40,
		spellID = 2094,
	},
	[Gladdy:SpellKey(5782)] = { -- Fear
		track = AURA_TYPE_DEBUFF,
		priority = 40,
		spellID = 5782,
	},
	[Gladdy:SpellKey(47860)] = { -- Death Coil Warlock
		track = AURA_TYPE_DEBUFF,
		priority = 40,
		spellID = 47860,
	},
	[Gladdy:SpellKey(6358)] = { -- Seduction
		track = AURA_TYPE_DEBUFF,
		priority = 40,
		spellID = 6358,
	},
	[Gladdy:SpellKey(5484)] = { -- Howl of Terror
		track = AURA_TYPE_DEBUFF,
		priority = 40,
		spellID = 5484,
	},
	[Gladdy:SpellKey(5246)] = { -- Intimidating Shout
		track = AURA_TYPE_DEBUFF,
		priority = 40,
		spellID = 5246,
	},
	[Gladdy:SpellKey(8122)] = { -- Psychic Scream
		track = AURA_TYPE_DEBUFF,
		priority = 40,
		spellID = 8122,
	},
	[Gladdy:SpellKey(64044)] = { -- Psychic Horror
		track = AURA_TYPE_DEBUFF,
		priority = 40,
		spellID = 64044,
	},
	[Gladdy:SpellKey(12826)] = { -- Polymorph
		track = AURA_TYPE_DEBUFF,
		priority = 40,
		spellID = 12826,
		texture = select(3, GetSpellInfo(12826)),
	},
	[Gladdy:SpellKey(51514)] = { -- Hex
		track = AURA_TYPE_DEBUFF,
		priority = 40,
		spellID = 51514,
	},
	[Gladdy:SpellKey(18647)] = { -- Banish
		track = AURA_TYPE_DEBUFF,
		priority = 40,
		spellID = 18647,
	},
	[Gladdy:SpellKey(605)] = { -- Mind Control
		track = AURA_TYPE_DEBUFF,
		priority = 40,
		spellID = 605,
	},
	[Gladdy:SpellKey(14327)] = { -- Scare Beast
		track = AURA_TYPE_DEBUFF,
		priority = 40,
		spellID = 14327,
	},

	[Gladdy:SpellKey(26989)] = {
		track = AURA_TYPE_DEBUFF,
		priority = 30,
		spellID = 26989,
	},
	[Gladdy:SpellKey(27010, " ", 16689)] = {
		track = AURA_TYPE_DEBUFF,
		priority = 30,
		spellID = 27010,
		altName = Gladdy:SpellName(27010, " ", 16689),
	},
	[Gladdy:SpellKey(42917)] = { -- Frost Nova
		track = AURA_TYPE_DEBUFF,
		priority = 30,
		spellID = 42917,
	},
	[Gladdy:SpellKey(33395)] = { -- Freeze (Water Elemental)
		track = AURA_TYPE_DEBUFF,
		priority = 30,
		spellID = 33395,
	},
	[Gladdy:SpellKey(55080)] = { -- Shattered Barrier
		track = AURA_TYPE_DEBUFF,
		priority = 30,
		spellID = 55080,
	},
	[Gladdy:SpellKey(16979)] = { -- Feral Charge
		track = AURA_TYPE_DEBUFF,
		priority = 30,
		spellID = 16979,
	},
	[Gladdy:SpellKey(23694)] = { -- Improved Hamstring
		track = AURA_TYPE_DEBUFF,
		priority = 30,
		spellID = 23694,
	},
	[Gladdy:SpellKey(4167)] = { -- Web (Hunter Pet)
		track = AURA_TYPE_DEBUFF,
		priority = 30,
		spellID = 4167,
	},
	[Gladdy:SpellKey(47168)] = { -- Improved Wingclip
		track = AURA_TYPE_DEBUFF,
		priority = 30,
		spellID = 47168,
	},

	[Gladdy:SpellKey(8983)] = { -- Bash
		track = AURA_TYPE_DEBUFF,
		priority = 40,
		spellID = 8983,
	},
	[Gladdy:SpellKey(1833)] = { -- Cheap Shot
		track = AURA_TYPE_DEBUFF,
		priority = 40,
		spellID = 1833,
	},
	[Gladdy:SpellKey(8643)] = { -- Kidney Shot
		track = AURA_TYPE_DEBUFF,
		priority = 40,
		spellID = 8643,
	},
	[Gladdy:SpellKey(1776)] = { -- Gouge
		track = AURA_TYPE_DEBUFF,
		priority = 40,
		spellID = 1776,
	},
	[Gladdy:SpellKey(44572)] = { -- Deep Freeze
		track = AURA_TYPE_DEBUFF,
		priority = 40,
		spellID = 44572,
	},
	[Gladdy:SpellKey(49012)] = { -- Wyvern Sting
		track = AURA_TYPE_DEBUFF,
		priority = 40,
		spellID = 49012,
	},
	[Gladdy:SpellKey(19503)] = { -- Scatter Shot
		track = AURA_TYPE_DEBUFF,
		priority = 40,
		spellID = 19503,
	},
	[Gladdy:SpellKey(49803)] = { -- Pounce
		track = AURA_TYPE_DEBUFF,
		priority = 40,
		spellID = 49803,
	},
	[Gladdy:SpellKey(49802)] = { -- Maim
		track = AURA_TYPE_DEBUFF,
		priority = 40,
		spellID = 49802,
	},
	[Gladdy:SpellKey(10308)] = { -- Hammer of Justice
		track = AURA_TYPE_DEBUFF,
		priority = 40,
		spellID = 10308,
	},
	[Gladdy:SpellKey(20066)] = { -- Repentance
		track = AURA_TYPE_DEBUFF,
		priority = 40,
		spellID = 20066,
	},
	[Gladdy:SpellKey(46968)] = { -- Shockwave
		track = AURA_TYPE_DEBUFF,
		priority = 40,
		spellID = 46968,
	},
	[Gladdy:SpellKey(49203)] = { -- Hungering Cold
		track = AURA_TYPE_DEBUFF,
		priority = 40,
		spellID = 49203,
	},
	[Gladdy:SpellKey(47481)] = { -- Gnaw (dk pet stun)
		track = AURA_TYPE_DEBUFF,
		priority = 40,
		spellID = 47481,
	},
	[Gladdy:SpellKey(47847)] = { -- Shadowfury Stun
		track = AURA_TYPE_DEBUFF,
		priority = 40,
		spellID = 47847,
	},
	[Gladdy:SpellKey(16922)] = { -- Imp Starfire Stun
		track = AURA_TYPE_DEBUFF,
		priority = 40,
		spellID = 16922,
	},
	[Gladdy:SpellKey(5530)] = { -- Mace Stun Effect
		track = AURA_TYPE_DEBUFF,
		priority = 40,
		texture = select(3, GetSpellInfo(12284)),
		spellID = 5530,
	},
	[Gladdy:SpellKey(20549)] = { -- War Stomp
		track = AURA_TYPE_DEBUFF,
		priority = 40,
		spellID = 20549,
	},
	[Gladdy:SpellKey(7922)] = { -- Charge Stun
		track = AURA_TYPE_DEBUFF,
		priority = 40,
		spellID = 7922,
		texture = select(3, GetSpellInfo(100))
	},
	[Gladdy:SpellKey(25274)] = { -- Intercept Stun
		track = AURA_TYPE_DEBUFF,
		priority = 40,
		spellID = 25274,
		texture = select(3, GetSpellInfo(25272))
	},
	[Gladdy:SpellKey(12809)] = { -- Concussion Blow
		track = AURA_TYPE_DEBUFF,
		priority = 40,
		spellID = 12809,
	},
	[Gladdy:SpellKey(12355)] = { -- Impact
		track = AURA_TYPE_DEBUFF,
		priority = 40,
		spellID = 12355,
	},
	[Gladdy:SpellKey(19577)] = {-- Intimidation
		track = AURA_TYPE_DEBUFF,
		priority = 40,
		spellID = 19577,
	},
	[Gladdy:SpellKey(31661)] = { -- Dragon's Breath
		track = AURA_TYPE_DEBUFF,
		priority = 40,
		spellID = 31661,
	},
	[Gladdy:SpellKey(10955)] = { -- Shackle Undead
		track = AURA_TYPE_DEBUFF,
		priority = 40,
		spellID = 10955,
	},

	[Gladdy:SpellKey(18469)] = { -- Improved Counterspell
		track = AURA_TYPE_DEBUFF,
		priority = 20,
		spellID = 18469,
	},
	[Gladdy:SpellKey(15487)] = { -- Silence
		track = AURA_TYPE_DEBUFF,
		priority = 20,
		spellID = 15487,
	},
	[Gladdy:SpellKey(34490)] = { -- Silencing Shot
		track = AURA_TYPE_DEBUFF,
		priority = 20,
		spellID = 34490,
	},
	[Gladdy:SpellKey(18425)] = { -- Improved Kick
		track = AURA_TYPE_DEBUFF,
		priority = 20,
		spellID = 18425,
	},
	[Gladdy:SpellKey(49916)] = { -- Strangulate
		track = AURA_TYPE_DEBUFF,
		priority = 20,
		spellID = 49916,
	},
	[Gladdy:SpellKey(74347)] = { -- Silenced - Gag Order
		track = AURA_TYPE_DEBUFF,
		priority = 20,
		spellID = 74347,
	},
	[Gladdy:SpellKey(63529)] = { -- Silenced - Shield of the Templar
		track = AURA_TYPE_DEBUFF,
		priority = 20,
		spellID = 63529,
	},
	[Gladdy:SpellKey(31117, " Silence")] = {
		track = AURA_TYPE_DEBUFF,
		altName = Gladdy:SpellName(31117, " Silence"),
		priority = 20,
		spellID = 31117,
	},
	[Gladdy:SpellKey(24259)] = { -- Spell Lock (Felhunter)
		track = AURA_TYPE_DEBUFF,
		priority = 20,
		spellID = 24259,
	},

	[Gladdy:SpellKey(1330)] = { -- Garrote - Silence
		track = AURA_TYPE_DEBUFF,
		priority = 20,
		spellID = 1330,
	},

	[Gladdy:SpellKey(676)] = { -- Disarm
		track = AURA_TYPE_DEBUFF,
		priority = 20,
		spellID = 676,
	},
	[Gladdy:SpellKey(51722)] = { -- Dismantle
		track = AURA_TYPE_DEBUFF,
		priority = 20,
		spellID = 51722,
	},
	[Gladdy:SpellKey(53359)] = { -- Chimera Shot - Scorpid
		track = AURA_TYPE_DEBUFF,
		priority = 20,
		spellID = 53359,
	},
	[Gladdy:SpellKey(64058)] = { -- Psychic Horror Disarm
		track = AURA_TYPE_DEBUFF,
		priority = 20,
		spellID = 64058,
	},

	[Gladdy:SpellKey(1022)] = { -- Hand of Protection
		track = AURA_TYPE_BUFF,
		priority = 20,
		spellID = 1022,
	},
	[Gladdy:SpellKey(1044)] = { -- Hand of Freedom
		track = AURA_TYPE_BUFF,
		priority = 20,
		spellID = 1044,
	},
	[Gladdy:SpellKey(6940)] = { -- Hand of Sacrifice
		track = AURA_TYPE_BUFF,
		priority = 20,
		spellID = 6940,
	},
	[Gladdy:SpellKey(64205)] = { -- Divine Sacrifice
		track = AURA_TYPE_BUFF,
		priority = 20,
		spellID = 64205,
	},
	[Gladdy:SpellKey(53271)] = {
		track = AURA_TYPE_BUFF,
		priority = 20,
		spellID = 53271,
	},
	[Gladdy:SpellKey(2825)] = { -- Bloodlust
		track = AURA_TYPE_BUFF,
		priority = 9,
		spellID = 2825,
	},
	[Gladdy:SpellKey(32182)] = { -- Heroism
		track = AURA_TYPE_BUFF,
		priority = 20,
		spellID = 32182,
	},
	[Gladdy:SpellKey(33206)] = { -- Pain Suppression
		track = AURA_TYPE_BUFF,
		priority = 20,
		spellID = 33206,
	},
	[Gladdy:SpellKey(29166)] = { -- Innervate
		track = AURA_TYPE_BUFF,
		priority = 20,
		spellID = 29166,
	},
	[Gladdy:SpellKey(18708)] = { -- Fel Domination
		track = AURA_TYPE_BUFF,
		priority = 20,
		spellID = 18708,
	},
	[Gladdy:SpellKey(54428)] = { -- Divine Plea
		track = AURA_TYPE_BUFF,
		priority = 15,
		spellID = 54428,
	},
	[Gladdy:SpellKey(31821)] = { -- Aura mastery
		track = AURA_TYPE_BUFF,
		priority = 21,
		spellID = 31821,
	},
	[Gladdy:SpellKey(51713)] = { -- Shadow Dance
		track = AURA_TYPE_BUFF,
		priority = 20,
		spellID = 51713,
	},
	[Gladdy:SpellKey(12292)] = { -- Death Wish
		track = AURA_TYPE_BUFF,
		priority = 15,
		spellID = 12292,
	},
	[Gladdy:SpellKey(23920)] = { -- Spell Reflection
		track = AURA_TYPE_BUFF,
		priority = 40,
		spellID = 23920,
	},
	[Gladdy:SpellKey(6346)] = {-- Fear Ward
		track = AURA_TYPE_BUFF,
		priority = 9,
		spellID = 6346,
	},
	[Gladdy:SpellKey(50334, " Feral")] = {-- Berserk
		track = AURA_TYPE_BUFF,
		priority = 20,
		spellID = 50334,
	},
	[Gladdy:SpellKey(46924)] = { -- Bladestorm
		track = AURA_TYPE_BUFF,
		priority = 20,
		spellID = 46924,
	},

	[Gladdy:SpellKey(871)] = { -- Shield Wall
		track = AURA_TYPE_BUFF,
		priority = 25,
		spellID = 871,
	},
	[Gladdy:SpellKey(48707)] = { -- Anti-Magic Shell
		track = AURA_TYPE_BUFF,
		priority = 25,
		spellID = 48707,
	},
	[Gladdy:SpellKey(31224)] = { -- Cloak of Shadows
		track = AURA_TYPE_BUFF,
		priority = 25,
		spellID = 31224,
	},
	[Gladdy:SpellKey(19263)] = { -- Deterrence
		track = AURA_TYPE_BUFF,
		priority = 25,
		spellID = 19263,
	},
	[Gladdy:SpellKey(26669)] = { -- Evasion
		track = AURA_TYPE_BUFF,
		priority = 10,
		spellID = 26669,
	},

	[Gladdy:SpellKey(34471)] = { -- The Beast Within (CC Immune)
		track = AURA_TYPE_BUFF,
		priority = 20,
		spellID = 34471,
	},
	[Gladdy:SpellKey(45438)] = { -- Ice Block
		track = AURA_TYPE_BUFF,
		priority = 30,
		spellID = 45438,
	},
	[Gladdy:SpellKey(41425)] = { -- Hypothermia (Ice Block Immune
		track = AURA_TYPE_DEBUFF,
		priority = 8,
		spellID = 41425,
	},
	[Gladdy:SpellKey(642)] = { -- Divine Shield
		track = AURA_TYPE_BUFF,
		priority = 30,
		spellID = 642,
	},
	[Gladdy:SpellKey(18499)] = { -- Berserker Rage (Flee Immune)
		track = AURA_TYPE_BUFF,
		priority = 30,
		spellID = 18499,
	},
	[Gladdy:SpellKey(1719)] = { -- Recklessness (Flee Immune)
		track = AURA_TYPE_BUFF,
		priority = 30,
		spellID = 1719,
	},
	[Gladdy:SpellKey(48792)] = { -- Icebound Fortitude
		track = AURA_TYPE_BUFF,
		priority = 15,
		spellID = 48792,
	},
	[Gladdy:SpellKey(49039)] = { -- Lichborne
		track = AURA_TYPE_BUFF,
		priority = 15,
		spellID = 49039,
	},

	[Gladdy:SpellKey(34709)] = { -- Shadowsight Buff
		track = AURA_TYPE_DEBUFF,
		duration = 15,
		priority = 9,
		magic = true,
		spellID = 34709,
	},
	[Gladdy:SpellKey(50461)] = { -- ЗОНА АНТИМАГИИ ЫЫЫ
		track = AURA_TYPE_BUFF,
		duration = 0,
		priority = 15,
		spellID = 50461,
	},
	[Gladdy:SpellKey(8178)] = { -- Grounding Totem Effect
		track = AURA_TYPE_BUFF,
		duration = 0,
		priority = 15,
		spellID = 8178
	},
	[Gladdy:SpellKey(5024)] = { -- Flee (Skull of impending Doom) -- 5024
		track = AURA_TYPE_BUFF,
		priority = 15,
		spellID = 5024,
		altName = Gladdy:SpellName(5024, " - " .. (select(1, GetItemInfo(4984)) or "Skull of Impending Doom")),
	},
})

function Gladdy:GetImportantAuras()
	return importantAuras
end

local interrupts = Gladdy:FilterSpellTable({
	[Gladdy:SpellKey(19675)] = { duration = 4, spellID = 19675, track = AURA_TYPE_DEBUFF, texture = select(3, GetSpellInfo(19675)), priority = 15 }, -- Feral Charge Effect (Druid)
	[Gladdy:SpellKey(2139)] = { duration = 8, spellID = 2139, track = AURA_TYPE_DEBUFF, texture = select(3, GetSpellInfo(2139)), priority = 15 }, -- Counterspell (Mage)
	[Gladdy:SpellKey(1766)] = { duration = 5, spellID = 1766, track = AURA_TYPE_DEBUFF, texture = select(3, GetSpellInfo(1766)), priority = 15 }, -- Kick (Rogue)
	[Gladdy:SpellKey(6552)] = { duration = 4, spellID = 6552, track = AURA_TYPE_DEBUFF, texture = select(3, GetSpellInfo(6552)), priority = 15 }, -- Pummel (Warrior)
	[Gladdy:SpellKey(72)] = { duration = 6, spellID = 72, track = AURA_TYPE_DEBUFF, texture = select(3, GetSpellInfo(72)), priority = 15 }, -- Shield Bash (Warrior)
	[Gladdy:SpellKey(57994)] = { duration = 2, spellID = 57994, track = AURA_TYPE_DEBUFF, texture = select(3, GetSpellInfo(57994)), priority = 15 }, -- Wind Shear (Shaman)
	[Gladdy:SpellKey(19244)] = { duration = 5, spellID = 19244, track = AURA_TYPE_DEBUFF, texture = select(3, GetSpellInfo(19244)), priority = 15 }, -- Spell Lock (Warlock
	[Gladdy:SpellKey(47528)] = { duration = 5, spellID = 47528, track = AURA_TYPE_DEBUFF, texture = select(3, GetSpellInfo(47528)), priority = 15 }, -- Mind Freeze (Deathknight)
})
function Gladdy:GetInterrupts()
	return interrupts
end

local cooldownList = {
	["MAGE"] = {
		[1953] = 15, -- Blink
		[42917] = 25, -- Frost Nova
		[2139] = 24, -- Counterspell
		[55342] = 180, -- Mirror Image
		[12051] = 480, --Evocation
		[45438] = { cd = 300, ["Frost"] = 240, }, -- Ice Block
		[44572] = { cd = 30, spec = "Frost", }, -- Deep Freeze
		[12472] = { cd = 180, spec = "Frost", }, -- Icy Veins
		[31687] = { cd = 180, spec = "Frost", }, -- Summon Water Elemental
		[12043] = { cd = 120, spec = "Arcane", }, -- Presence of Mind
		[12042] = { cd = 180, spec = "Arcane", }, -- Arcane Power
		[42950] = { cd = 20, spec = "Fire" }, -- Dragon's Breath
		[11129] = { cd = 120, spec = "Fire" }, -- Combustion
		[11958] = { cd = 480, spec = "Frost", -- Coldsnap
					resetCD = {
						[12472] = true,
						[45438] = true,
						[42917] = true,
						[31687] = true,
						[44572] = true,
					},
		},
	},

	["PRIEST"] = {
		[10890] = { cd = 27, ["Shadow"] = 23, }, -- Psychic Scream
		[34433] = { cd = 300, ["Shadow"] = 180, }, -- Shadowfiend
		[15487] = { cd = 45, spec = "Shadow", }, -- Silence
		[64044] = { cd = 120, spec = "Shadow", }, -- Psychic Horror
		[64843] = 480, -- Divine Hymn
		[64901] = 360, -- Hymn of Hope
		[32379] = 12, -- Shadow Word: Death
		[6346] = 180, -- Fear Ward
		[47585] = { cd = 75, spec = "Shadow", }, -- Dispersion (+ Glyph)
		[10060] = { cd = 120, spec = "Discipline", }, -- Power Infusion
		[33206] = { cd = 180, spec = "Discipline", }, -- Pain Suppression
	},

	["DEATHKNIGHT"] = {
		[47476] = 120, -- Strangulate
		[47528] = 10, -- Mind Freeze
		[48707] = 45, -- Anti-Magic Shell
		[48792] = 120, -- Icebound Fortitude
		[49576] = 35, -- Death Grip
		[47568] = 300, -- Empower Rune Weapon
		[48743] = 120, -- Death Pact
		[49039] = 120, -- Lichborne
		[47481] = { cd = 60, spec = "Unholy", }, -- Pet Gnaw
		[51052] = { cd = 120, spec = "Unholy", }, -- Anti-Magic Zone
		[46584] = { cd = 180, notSpec = "Unholy", }, -- Raise Dead
		[49206] = { cd = 180, spec = "Unholy", }, -- Summon Gargoyle
		[49028] = { cd = 90, spec = "Blood", }, -- Dancing Rune Weapon
		[49203] = { cd = 60, spec = "Frost", }, -- Hungering Cold
	},

	["DRUID"] = {
		[22812] = 60, -- Barkskin
		[29166] = 180, -- Innervate
		[8983] = 60, -- Bash
		[53312] = 60, -- Natures Grasp
		[48505] = { cd = 90, spec = "Balance", }, -- Starfall
		[50334] = { cd = 180, spec = "Feral", altName = Gladdy:SpellName(50334, " Feral") }, -- Berserk
		[17116] = { cd = 120, spec = "Restoration", }, -- Natures Swiftness
		[18562] = { cd = 15, spec = "Restoration", }, -- Swiftmend
		[33831] = { cd = 180, spec = "Balance", }, -- Force of Nature
		[61384] = { cd = 20, spec = "Balance", }, -- Typhoon
	},

	["SHAMAN"] = {
		[57994] = 6, -- Wind Shear
		[51514] = 45, -- Hex
		[8177] = 15, -- Grounding Totem
		[30823] = { cd = 60, spec = "Enhancement", }, -- Shamanistic Rage
		[16166] = { cd = 180, spec = "Elemental", }, -- Elemental Mastery
		[59159] = { cd = 45, spec = "Elemental", }, -- Thunderstorm
		[16188] = { cd = 120, spec = "Restoration", }, -- Natures Swiftness
		[51533] = { cd = 180, spec = "Enhancement", }, -- Feral Spirit
		[16190] = { cd = 300, spec = "Restoration", }, -- Mana Tide Totem
	},

	["PALADIN"] = {
		[10278] = 300, -- Hand of Protection
		[1044] = 25, -- Hand of Freedom
		[54428] = 60, -- Divine Plea
		[6940] = 120, -- Hand of Sacrifice
		[64205] = 120, -- Divine Sacrifice
		[10308] = { cd = 60, ["Protection"] = 40, ["Retribution"] = 40, }, -- Hammer of Justice
		[642] = { cd = 300, -- Divine Shield
				  sharedCD = {
					  cd = 30,
					  [31884] = true,
				  },
		},
		[31884] = { cd = 180, -- Avenging Wrath
					sharedCD = {
						cd = 30,
						[642] = true,
					},
					["Retribution"] = 120,
		},
		[31821] = { cd = 120, spec = "Holy", }, -- Aura Mastery
		[20066] = { cd = 60, spec = "Retribution", }, -- Repentance
		[20216] = { cd = 120, spec = "Holy", }, -- Divine Favor
		[31842] = { cd = 180, spec = "Holy", }, -- Divine Illumination
		[31935] = { cd = 30, spec = "Protection", }, -- Avengers Shield

	},

	["WARLOCK"] = {
		[17928] = 40, -- Howl of Terror
		[47860] = 120, -- Death Coil
		[18708] = 180, -- Feldom
		[48020] = 30, -- Demonic Circle: Port
		[19647] = { cd = 24, pet = true, }, -- Spell Lock
		[27277] = { cd = 8, pet = true, },  -- Devour Magic
		[61290] = 15,  -- Shadowflame
		[47847] = { cd = 20, spec = "Destruction", }, -- Shadowfury
		[17877] = { cd = 15, spec = "Destruction", }, -- Shadowburn
		[17962] = { cd = 10, spec = "Destruction", }, -- Conflagrate
		[59172] = { cd = 12, spec = "Destruction", }, -- Chaos Bolt
		[47241] = { cd = 180, spec = "Demonology", }, -- Metamorphosis
		[47996] = { cd = 30, spec = "Demonology", pet = true, altName = Gladdy:SpellName(47996, " Felguard") }, -- Intercept
		[1122] = { cd = 600, spec = "Demonology", }, -- Inferno
	},

	["WARRIOR"] = {
		[6552] = { cd = 10, -- Pummel
				   sharedCD = {
					   [72] = true,
				   },
		},
		[72] = { cd = 12, -- Shield Bash
				 sharedCD = {
					 [6552] = true,
				 },
		},
		[18499] = 30, -- Berserker Rage
		[23920] = 10, -- Spell Reflection
		[3411] = 30, -- Intervene
		[20252] = { cd = 30, ["Arms"] = 20, }, -- Intercept
		[676] = 60, -- Disarm
		[5246] = 120, -- Intimidating Shout
		[2565] = 60, -- Shield Block
		[55694] = 180, -- Enraged Regeneration
		[20230] = 300, -- Retaliation
		[1719] = 300, -- Recklessness
		[871] = 300, -- Shield Wall
		[64382] = 300, -- Shattering Throw
		[12292] = { cd = 180, spec = "Fury", }, -- Death Wish
		[46924] = { cd = 90, spec = "Arms", }, -- Bladestorm
		[46968] = { cd = 20, spec = "Protection", }, -- Shockwave
		[12975] = { cd = 180, spec = "Protection", }, -- Last Stand
		[12809] = { cd = 30, spec = "Protection", }, -- Concussion Blow

	},

	["HUNTER"] = {

		[19503] = 30, -- Scatter Shot
		[19263] = 90, -- Deterrence
		[781] = 15, -- Disengage
		[5384] = 30, -- Feign Death
		[3045] = 20, -- Rapid Fire
		[60192] = { cd = 28, -- Freezing Arrow
					sharedCD = {
						[14311] = true, -- Freezing Trap
						[13809] = true, -- Frost Trap
					},
		},
		[14311] = { cd = 28, -- Freezing Trap
					sharedCD = {
						[60192] = true, -- Freezing Arrow
						[13809] = true, -- Frost Trap
					},
		},
		[13809] = { cd = 28, -- Frost Trap
					sharedCD = {
						[14311] = true, -- Freezing Trap
						[60192] = true, -- Freezing Arrow
					},
		},
		[34600] = { cd = 28, }, -- Snake Trap
		[34490] = { cd = 20, spec = "Marksmanship", }, -- Silencing Shot
		[19386] = { cd = 60, spec = "Survival", }, -- Wyvern Sting
		[53271] = { cd = 60, pet = true, }, -- Masters Call
		[19577] = { cd = 60, pet = true, }, -- Intimidation
		[19574] = { cd = 120, pet = true, }, -- Bestial Wrath
		[23989] = { cd = 180, -- Readiness
					resetCD = {
						[19503] = true, -- Scatter Shot
						[19263] = true, -- Deterrence
						[781] = true, -- Disengage
						[60192] = true, -- Freezing Arrow
						[14311] = true, -- Freezing Trap
						[13809] = true, -- Frost Trap
						[34600] = true, -- Snake Trap
						[34490] = true, -- Silencing Shot
						[19386] = true, -- Wyvern Sting
						[53271] = true, -- Masters call
						[19577] = true, -- Intimidation
					},
		},
	},

	["ROGUE"] = {
		[1766] = 10, -- Kick
		[8643] = 20, -- Kidney Shot
		[26669] = 180, -- Evasion
		[31224] = 60, -- Cloak of Shadow
		[26889] = 180, -- Vanish
		[2094] = 180, -- Blind
		[51722] = 60, -- Dismantle
		[11305] = 180, -- Sprint
		[14177] = { cd = 180, spec = "Assassination", }, -- Cold Blood
		[51713] = { cd = 60, spec = "Subtlety", }, -- Shadow Dance
		[13750] = { cd = 180, spec = "Combat", }, -- Adrenaline Rush
		[13877] = { cd = 120, spec = "Combat", }, -- Blade Flurry
		[51690] = { cd = 120, spec = "Combat", }, -- Killing Spree
		[36554] = { cd = 30, spec = "Subtlety", }, -- Shadowstep
		[14185] = { cd = 480, spec = "Subtlety", -- Preparation
					resetCD = {
						[26669] = true,
						[11305] = true,
						[26889] = true,
						[14177] = true,
						[36554] = true,
					},
		},
	},
	["Scourge"] = {

	},
	["BloodElf"] = {

	},
	["Tauren"] = {

	},
	["Orc"] = {

	},
	["Troll"] = {

	},
	["NightElf"] = {

	},
	["Draenei"] = {

	},
	["Human"] = {

	},
	["Gnome"] = {
	},
	["Dwarf"] = {

	},
}
function Gladdy:GetCooldownList()
	return cooldownList
end

local racials = {
	["Scourge"] = {
		[7744] = true, -- Will of the Forsaken
		duration = 120,
		spellName = select(1, GetSpellInfo(7744)),
		texture = select(3, GetSpellInfo(7744))
	},
	["BloodElf"] = {
		[28730] = true, -- Arcane Torrent
		duration = 120,
		spellName = select(1, GetSpellInfo(28730)),
		texture = select(3, GetSpellInfo(28730))
	},
	["Tauren"] = {
		[20549] = true, -- War Stomp
		duration = 120,
		spellName = select(1, GetSpellInfo(20549)),
		texture = select(3, GetSpellInfo(20549))
	},
	["Orc"] = {
		[20572] = true,
		[33697] = true,
		[33702] = true,
		duration = 120,
		spellName = select(1, GetSpellInfo(20572)),
		texture = select(3, GetSpellInfo(20572))
	},
	["Troll"] = {
		[26297] = true,
		duration = 180,
		spellName = select(1, GetSpellInfo(26297)),
		texture = select(3, GetSpellInfo(26297))
	},
	["NightElf"] = {
		[58984] = true,
		duration = 120,
		spellName = select(1, GetSpellInfo(58984)),
		texture = select(3, GetSpellInfo(58984))
	},
	["Draenei"] = {
		[28880] = true,
		duration = 180,
		spellName = select(1, GetSpellInfo(28880)),
		texture = select(3, GetSpellInfo(28880))
	},
	["Human"] = {
		[59752] = true, -- Perception
		duration = 120,
		spellName = select(1, GetSpellInfo(59752)),
		texture = select(3, GetSpellInfo(59752))
	},
	["Gnome"] = {
		[20589] = true, -- Escape Artist
		duration = 105,
		spellName = select(1, GetSpellInfo(20589)),
		texture = select(3, GetSpellInfo(20589))
	},
	["Dwarf"] = {
		[20594] = true, -- Stoneform
		duration = 180,
		spellName = select(1, GetSpellInfo(20594)),
		texture = select(3, GetSpellInfo(20594))
	},
}
function Gladdy:Racials()
	return racials
end

local constellations = {
	[371796] = {
        id = 375015,
        icon = select(3, GetSpellInfo(375015)),
        cd = 120,
    },
    [371804] = {
        id = 374992,
        icon = select(3, GetSpellInfo(374992)),
        cd = 120,
    },
    [371798] = {
        id = 374999,
        icon = select(3, GetSpellInfo(374999)),
        cd = 120,
    },
    [371808] = {
        id = 375038,
        icon = select(3, GetSpellInfo(375038)),
        cd = 120,
    },
    [371795] = {
        id = 374997,
        icon = select(3, GetSpellInfo(374997)),
        cd = 120,
    },
    [371791] = {
        id = 375020,
        icon = select(3, GetSpellInfo(375020)),
        cd = 120,
    },
    [371801] = {
        id = 374988,
        icon = select(3, GetSpellInfo(374988)),
        cd = 120,
    },
    [371803] = {
        id = 375024,
        icon = select(3, GetSpellInfo(375024)),
        cd = 120,
    },
    [371788] = { --синд
        id = 375001,
        alt = {["316421"] = 1, ["302387"] = 1, ["316419"] = 1, ["316420"] = 1},
        icon = select(3, GetSpellInfo(375001)),
        cd = 120,
    },
    [371805] = {
        id = 374994,
        icon = select(3, GetSpellInfo(374994)),
        cd = 120,
    },
    [371806] = {
        id = 374996,
        icon = select(3, GetSpellInfo(374996)),
        cd = 120,
    },
    [371800] = {
        id = 375018,
        icon = select(3, GetSpellInfo(375018)),
        cd = 120,
    },
    [371802] = {
        id = 375035,
        icon = select(3, GetSpellInfo(375035)),
        cd = 120,
    },
    [371792] = {
        id = 375016,
        icon = select(3, GetSpellInfo(375016)),
        cd = 120,
    },
    [371794] = {
        id = 375019,
        icon = select(3, GetSpellInfo(375019)),
        cd = 120,
    },
    [371809] = {
        id = 375022,
        icon = select(3, GetSpellInfo(375022)),
        cd = 120,
    },
    [371799] = {
        id = 375006,
        icon = select(3, GetSpellInfo(375006)),
        cd = 120,
    },
    [371807] = {
        id = 375026,
        icon = select(3, GetSpellInfo(375026)),
        cd = 120,
    },
    [371789] = {
        id = 375029,
        icon = select(3, GetSpellInfo(375029)),
        cd = 120,
    },
    [371793] = {
        id = 375010,
        icon = select(3, GetSpellInfo(375010)),
        cd = 120,
    },
    [371810] = {
        id = 375013,
        icon = select(3, GetSpellInfo(375013)),
        cd = 120,
    },
    [371797] = {
        id = 375033,
        icon = select(3, GetSpellInfo(375033)),
        cd = 120,
    },
    [371790] = {
        id = 375040,
        icon = select(3, GetSpellInfo(375040)),
        cd = 120,
    }
}

for auraID, constellation in pairs(constellations) do
    constellation.auraID = auraID
end
constellations[371796].sharedTrinketCD = 90
constellations[371804].sharedTrinketCD = 60

function Gladdy:Constellations()
	return constellations
end

local totemData = {
	[string_lower("Disease Cleansing Totem")] = {id = 8170,texture = select(3, GetSpellInfo(8170)), color = {r = 0, g = 0, b = 0, a = 1}, pulse = 3},
	[string_lower("Mana Spring Totem")] = { id = 5675, texture = select(3, GetSpellInfo(5675)), color = { r = 0, g = 0, b = 0, a = 1 } },
}

local totemSpellIdToPulse = Gladdy:FilterSpellTable({
	[Gladdy:SpellKey(totemData[string_lower("Disease Cleansing Totem")].id)] = totemData[string_lower("Disease Cleansing Totem")].pulse,
	[8170] = totemData[string_lower("Disease Cleansing Totem")].pulse,
})

local totemDataShared, totemNameTotemData, totemSpellIdToPulseShared = Gladdy:GetSharedTotemData()
Gladdy:AddEntriesToTable(totemData, totemDataShared)
Gladdy:AddEntriesToTable(totemSpellIdToPulse, totemSpellIdToPulseShared)

function Gladdy:GetTotemData()
	return totemData, totemNameTotemData, totemSpellIdToPulse
end
