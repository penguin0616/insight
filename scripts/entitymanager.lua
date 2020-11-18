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

local function SetEntitySleep(manager, inst, rmv)
	--manager.chests[inst] = nil
	if manager.active_entities[inst] == nil then
		return
	end

	
	--manager.active_entities[inst] = nil
	--manager.active_entity_lookup[inst.GUID] = nil
	manager.entity_count = manager.entity_count - 1
	 
	--mprint("sleep", inst, manager.entity_count)
	manager:PushEvent("sleep", inst)
end

local function SetEntityAwake(manager, inst)
	if manager.active_entities[inst] then
		--mprint(inst, 'rejected already awake')
		return
	end

	if inst:HasTag("fx") or inst:HasTag("DECOR") or inst:HasTag("CLASSIFIED") then -- or inst:HasTag("INLIMBO") , but inventory items are INLIMBO in DST || search EntityScript:IsInLimbo
		return
	elseif inst:HasTag("NOCLICK") then 
		if inst.replica then
			if inst.replica.inventoryitem == nil then
				return
			end
		else
			if inst.components.inventoryitem == nil then
				return
			end
		end
	end

	--mprint("awake", inst, manager.entity_count)

	inst:DoTaskInTime(0.01, function()
		if inst.replica.container and inst:IsValid() then
			manager.chests[inst] = true
		end
	end)
	
	manager.active_entities[inst] = true
	manager.active_entity_lookup[inst.GUID] = inst
	manager.entity_count = manager.entity_count + 1

	--table.insert(manager.active_entities, inst)
	manager:PushEvent("awake", inst)
end

local EntityManager = Class(function(self)
	self.active_entities = setmetatable(createTable(1000), { __mode="k" })
	self.active_entity_lookup = setmetatable(createTable(1000), { __mode="kv" })
	self.entity_count = 0
	self.listeners = {}
	self.chests = setmetatable(createTable(200), { __mode="k" })
end)

function EntityManager:Count()
	return self.entity_count
end

function EntityManager:LookupGUID(GUID)
	return self.active_entity_lookup[GUID]
end

function EntityManager:Manage(entity)
	if not entity then
		--return
	end

	entity:ListenForEvent("entitysleep", function()
		SetEntitySleep(self, entity)
	end)

	entity:ListenForEvent("entitywake", function()
		SetEntityAwake(self, entity)
	end)

	entity:ListenForEvent("onremove", function() -- preemptive strike
		SetEntitySleep(self, entity, true) -- preemptive strike
	end)

	if not entity:IsAsleep() then
		SetEntityAwake(self, entity)
	end
end

function EntityManager:IsEntityActive(entity)
	for _, ent in pairs(self.active_entities) do
		if ent == entity then
			return true
		end
	end

	return false
end

function EntityManager:AddListener(key, func)
	assert(self.listeners[key]==nil, "Unable to overwrite previous listener")

	self.listeners[key] = func
end

function EntityManager:RemoveListener(key)
	self.listeners[key] = nil
end

function EntityManager:PushEvent(name, ...)
	for key, fn in pairs(self.listeners) do
		fn(self, name, ...)
	end
end


return EntityManager