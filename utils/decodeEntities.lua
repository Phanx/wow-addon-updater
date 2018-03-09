--
-- Update and install World of Warcraft addons from the command line.
-- Author : Phanx <phanx@phanx.net>
-- Website: https://gitlab.com/phanx/wow-addon-updater
-- License: Zlib - see LICENSE.txt for full text
--
-- Convert HTML entities to actual characters
--

local entities = {
	amp = "&",
}

local function replaceEntity(entity, name)
	return entities[name] or ""
end

local function decodeEntities(str)
	if (str) then
		str = string.gsub(str, "(&(%a+);)", replaceEntity)
	end
	return str
end

return decodeEntities
