--[[
Copyright (C) 2020, 2021 penguin0616

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

local Color = Color
--local GREEN = Color.fromHex("#00cc00")
--local RED = Color.fromHex("#dd5555")
-- https://i.stack.imgur.com/UgYCc.png
-- "#5B63D2"
local bottom = Color.fromHex("#66CC00") -- "#EEFC53" 
local top = Color.fromHex("#5B63D2")

-- weighable.lua
local function Describe(self, context)
	local description, alt_description = nil, nil

	if not context.config["display_weighable"] then
		return
	end

	local weight = self:GetWeight() 
	if not weight then
		return
	end

	local weight_percent
	local owner_name = (self.owner_name and "\t" .. string.format(context.lstr.weighable.owner_name, self.owner_name or "?")) or ""

	-- bounded
	if self.min_weight and self.max_weight then
		weight_percent = self:GetWeightPercent()
		local weight_color = bottom:Lerp(top, weight_percent)
		
		--local function ApplyColour(s) return s end;

		alt_description = string.format(context.lstr.weighable.weight_bounded, 
			ApplyColour(self.min_weight, bottom),
			ApplyColour(weight, weight_color),
			ApplyColour(Round(weight_percent * 100, 2) .. "%", weight_color),
			ApplyColour(self.max_weight, top)
		) .. owner_name
	end

	weight_percent = 0
	description = string.format(context.lstr.weighable.weight, weight, "?") .. owner_name

	return {
		priority = 0,
		description = description,
		alt_description = alt_description
	}
end



return {
	Describe = Describe
}