--[[
Copyright (C) 2020 penguin0616

This file is part of Insight.

The source code of this program is shared under the RECEX
SHARED SOURCE LICENSE (version 1.0).
The source code is shared for referrence and academic purposes
with the hope that people can read and learn from it. This is not
Free and Open Source software, and code is not redistributable
without permission of the author. Read the RECEX SHARED
SOURCE LICENSE for details
The source codes does not come with any warranty including
the implied warranty of merchandise.
You should have received a copy of the RECEX SHARED SOURCE
LICENSE in the form of a LICENSE file in the root of the source
directory. If not, please refer to
<https://raw.githubusercontent.com/Recex/Licenses/master/SharedSourceLicense/LICENSE.txt>
]]

-- edible.lua
local cooking = require("cooking")

local function GetWereEaterData(inst, context)
	local wereeater = context.player.components.wereeater
	if not wereeater then
		return
	end

	if not inst:HasTag("monstermeat") then
		return
	end

	if wereeater.monster_count == 0 then
		return
	end

	local forget_time = wereeater.forget_task and GetTaskRemaining(wereeater.forget_task)

	if forget_time then
		forget_time = TimeToText(time.new(forget_time, context))
	else
		forget_time = "?"
	end

	return string.format(context.lstr.wereeater, wereeater.monster_count, 2, forget_time)
end

local function GetFoodUnits(inst, context)
	local ing = cooking.ingredients[inst.prefab]

	local units = {}

	if ing then
		for name, value in pairs(ing.tags) do
			local color = Insight.COLORS[name:upper()] and name:upper() or "FEATHER"
			local unit = context.lstr.edible_foodtype[name:lower()] or name .. "*"
			
			if context.usingIcons and PrefabHasIcon(unit) then
				table.insert(units, string.format(context.lstr.food_unit, color, value, unit))
			else
				table.insert(units, string.format(context.lstr.lang.food_unit, color, value, color, unit))
			end
			--[[
			local clr = name:upper()
			if Insight.COLORS[clr] == nil then
				clr = "FEATHER"
				-- you heard me. all unregistered food is now FEATHER. accept defeat.
			end

			local unit = context.lstr["edible_" .. name:lower()] or name
			table.insert(units, string.format(context.lstr.food_unit, clr, val, clr, unit))
			--]]
		end
	end

	if #units == 0 then
		return nil
	end

	return table.concat(units, ", ")
end

local function formatNumber(num)
	return FormatNumber(Round(num, 1))
end

local function formatDescription(hunger, sanity, health, context)

	-- for handling different styles
	local style = context.config["food_style"]
	local order = context.config["food_order"] -- interface (default), wiki

	local long = nil
	local short = nil

	local data = nil

	if order == "interface" then
		--long = "<color=HUNGER>Hunger</color>: <color=HUNGER>%s</color> / <color=SANITY>Sanity</color>: <color=SANITY>%s</color> / <color=HEALTH>Health</color>: <color=HEALTH>%s</color>"
		long = context.lstr.edible_interface --string.format("%s <color=HUNGER>%%s</color> / %s <color=SANITY>%%s</color> / %s <color=HEALTH>%%s</color>", hunger_str, sanity_str, health_str)
		data = {hunger, sanity, health}
		short = "<color=HUNGER>%s</color> / <color=SANITY>%s</color> / <color=HEALTH>%s</color>"
	elseif order == "wiki" then
		--long = "<color=HEALTH>Health</color>: <color=HEALTH>%s</color> / <color=HUNGER>Hunger</color>: <color=HUNGER>%s</color> / <color=SANITY>Sanity</color>: <color=SANITY>%s</color>"
		long = context.lstr.edible_wiki --string.format("%s <color=HEALTH>%%s</color> / %s <color=HUNGER>%%s</color> / %s <color=SANITY>%%s</color>", health_str, hunger_str, sanity_str)
		data = {health, hunger, sanity}
		short = "<color=HEALTH>%s</color> / <color=HUNGER>%s</color> / <color=SANITY>%s</color>"
	else
		error("unexpected order in food_order: " .. tostring(order))
	end

	if style == "short" then
		return string.format(short, data[1], data[2], data[3])
	elseif style == "long" then
		--local DEBUG_STR = "<color=SHALLOWS>hey there jimbo</color>\nhey there jimbo\n"
		return string.format(long, data[1], data[2], data[3])
	else
		return string.format(long, data[1], data[2], data[3]) .. string.format(" [%s]", tostring(style)) 
		--error("unexpected style in food_style: " .. tostring(style))
	end
end

local function IsEdible(owner, inst)
	if not owner then
		return false
	end
	
	if owner.components.eater then
		-- base game does not have :IsValidFood()
		if owner.components.eater.IsValidFood and owner.components.eater:IsValidFood(inst) then
			if owner.components.eater:AbleToEat(inst) then
				return true
			end
		elseif owner.components.eater:CanEat(inst) then
			return true
		end
	end

	if owner.components.souleater and inst.components.soul then
		return true
	end

	return false
end

local function GetFoodEffects(self)
	local bonuses = {}

	if GetWorldType() == 0 then
		return bonuses
	end

	-- temperature
	local delta_multiplier = 1
	local duration_multiplier = 1

	if IsDST() and self.spice and TUNING.SPICE_MULTIPLIERS[self.spice] then
		if TUNING.SPICE_MULTIPLIERS[self.spice].TEMPERATUREDELTA then
			delta_multiplier = delta_multiplier + TUNING.SPICE_MULTIPLIERS[self.spice].TEMPERATUREDELTA
		end

		if TUNING.SPICE_MULTIPLIERS[self.spice].TEMPERATUREDURATION then
			duration_multiplier = duration_multiplier + TUNING.SPICE_MULTIPLIERS[self.spice].TEMPERATUREDURATION
		end
	end

	-- @Reign of Giants & @Don't Starve Together
	-- Food is an implicit heater/cooler if it has temperature
	if self.temperaturedelta and self.temperatureduration and self.temperaturedelta ~= 0 and self.temperatureduration ~= 0 and (self.chill == nil or self.chill < 1) then
		bonuses.temperature = { 
			delta = self.temperaturedelta * (1 - (self.chill or 0)) * delta_multiplier,
			duration = self.temperatureduration * duration_multiplier
		}
	end

	-- @Shipwrecked
	-- Food is an implicit speed booster if it has caffeine
	if self.caffeinedelta and self.caffeineduration and self.caffeinedelta ~= 0 and self.caffeineduration ~= 0 then
		-- eater.components.locomotor:AddSpeedModifier_Additive("CAFFEINE", self.caffeinedelta, self.caffeineduration)
		bonuses.caffeine = {
			delta = self.caffeinedelta,
			duration = self.caffeineduration
		}
	end

	-- Other food based speed modifiers
	if self.surferdelta and self.surferduration and self.surferdelta ~= 0 and self.surferduration ~= 0 then
		--eater.components.locomotor:AddSpeedModifier_Additive("SURF", self.surferdelta, self.surferduration)
		bonuses.surf = {
			delta = self.surferdelta,
			duration = self.surferduration
		}
	end

	if self.autodrydelta and self.autodryduration and self.autodrydelta ~= 0 and self.autodryduration ~= 0 then
		--eater.components.locomotor:AddSpeedModifier_Additive("AUTODRY", self.autodrydelta, self.autodryduration)
		bonuses.autodry = {
			delta = self.autodrydelta,
			duration = self.autodryduration
		}
	end

	-- immediate cooling
	if self.autocooldelta and self.autocooldelta ~= 0 then
		bonuses.instant_temperature = {
			delta = self.autocooldelta, 
			duration = false,
		}
		--[[
		local current_temp = eater.components.temperature:GetCurrent()
		local new_temp = math.max(current_temp - self.autocooldelta, TUNING.STARTING_TEMP)
		eater.components.temperature:SetTemperature(new_temp)
		--]]
	end

	-- @Hamlet
	if self.antihistamine then
		bonuses.antihistamine = {
			delta = self.antihistamine,
			duration = false
		}
		--[[
		if eater.components.hayfever and eater.components.hayfever.enabled then
			eater.components.hayfever:SetNextSneezeTime(self.antihistamine)			
		end
		--]]
	end

	if self.temperaturebump and self.temperaturebump ~= 0 then
		assert(bonuses.instant_temperature == nil, "[Insight]: attempt to overwrite existing autocooldelta")
		bonuses.instant_temperature = {
			delta = self.temperaturebump,
			duration = false
		}
	end

	return bonuses
end

local SPECIAL_FOODS = {
	["petals_evil"] = {
		SANITY = -TUNING.SANITY_TINY,
	}
}

local function Describe(self, context)
	local description, alt_description = nil, nil

	local owner = context.player --GetPlayer()
	local foodmemory = owner.components.foodmemory
	local stats = context.stats
	local alt_description = nil
	local world_type = GetWorldType()

	if context.config["display_food"] == nil or context.config["display_food"] then
		local hunger, sanity, health
		if type(stats) == 'table' then
			hunger, sanity, health = stats.hunger, stats.sanity, stats.health
		else
			hunger, sanity, health = self:GetHunger(), self:GetSanity(), self:GetHealth() 
		end

		hunger = (hunger >= 0 and "+" or "") .. hunger
		sanity = (sanity >= 0 and "+" or "") .. sanity
		health = (health >= 0 and "+" or "") .. health
		alt_description = formatDescription(hunger, sanity, health, context)
	end

	if IsEdible(owner, self.inst) and context.config["display_food"] == nil or context.config["display_food"] then -- i think this filters out wurt's meat stats.
		local eater = owner.components.eater

		local hunger, sanity, health
		if type(stats) == 'table' then
			hunger, sanity, health = stats.hunger, stats.sanity, stats.health
		else
			hunger, sanity, health = self:GetHunger(owner), self:GetSanity(owner), self:GetHealth(owner) -- DST's food affinity is included in all 3

			if world_type ~= 0 then -- accounting for strong stomach in anywhere except base game since no one cares there
				if sanity < 0 and eater:DoFoodEffects(self.inst) == false then
					sanity = 0
				end
				if health < 0 and eater:DoFoodEffects(self.inst) == false then
					health = 0
				end
			end
		end	

		local base_mult = foodmemory ~= nil and foodmemory:GetFoodMultiplier(self.inst.prefab) or 1 -- warly? added while was doing food stat modifiers
		if not stats or (type(stats) == 'table' and not stats.fixed) then
			hunger, sanity, health = hunger * base_mult * eater.hungerabsorption, 
				sanity * base_mult * eater.sanityabsorption, 
				health * base_mult * eater.healthabsorption
		end

		if health < 0 and owner.components.health.absorb then
			if world_type > 0 then -- RoG+
				health = health - (health * owner.components.health.absorb)
			elseif world_type == -1 then -- DST
				health = health * math.clamp(1 - owner.components.health.absorb, 0, 1) * math.clamp(1 - owner.components.health.externalabsorbmodifiers:Get(), 0, 1)
			end
		end

		local special_stats = SPECIAL_FOODS[self.inst.prefab] 
		if special_stats then
			if special_stats.SANITY then
				sanity = special_stats.SANITY
			end
		end
		
		hunger, sanity, health = formatNumber(hunger), formatNumber(sanity), formatNumber(health)
		description = formatDescription(hunger, sanity, health, context) -- .. "\nHunger: +25 / Sanity: +15 / Health: +20\nHunger: +25 / Sanity: +15 / Health: +20"
	end

	local foodunit_data = nil
	if context.config["food_units"] then
		local foodunits = GetFoodUnits(self.inst, context)
		if foodunits then
			foodunit_data = {
				name = "edible_foodunit",
				priority = 0.11
			}
		end
	end

	local foodmemory_data = nil
	if context.config["food_memory"] then
		local mem = foodmemory and foodmemory.foods[foodmemory:GetBaseFood(self.inst.prefab)]
		if mem then
			local recently_eaten, time_to_forget = mem.count, GetTaskRemaining(mem.task)
			foodmemory_data = {
				name = "edible_foodmemory",
				priority = 0.1,
				description = string.format(context.lstr.foodmemory, recently_eaten, #foodmemory.mults, TimeToText(time.new(time_to_forget, context)))
			}
		end
	end

	local wereeater_data = context.player.components.wereeater and GetWereEaterData(self.inst, context)
	if wereeater_data then
		wereeater_data = {
			name = "edible_wereeater",
			priority = 0.1,
			description = wereeater_data
		}
	end

	local effect_table = nil
	if context.config["food_effects"] then
		local effects = GetFoodEffects(self)
		local effect_description = {}

		for name, data in pairs(effects) do
			table.insert(effect_description, string.format(context.lstr.edible_foodeffect[name], data.delta and FormatNumber(Round(data.delta, 1)) or ("MISSING DELTA FOR [" .. name .. "]"), data.duration and TimeToText(time.new(data.duration, context), "realtime_short") or "[YOU SHOULDN'T SEE THIS]"))
		end

		if #effect_description > 0 then
			effect_table = {
				name = "edible_foodeffects",
				priority = 0,
				description = table.concat(effect_description, "\n")
			}
		end
	end

	return {
		name = "edible",
		priority = 5,
		description = description,
		alt_description = alt_description,
	}, foodunit_data, effect_table, foodmemory_data, wereeater_data
end



return {
	Describe = Describe
}