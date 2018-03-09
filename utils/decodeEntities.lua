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
