--
-- Clean up HTML for easier parsing
--

local function cleanHTML(str)
	if str then
		str = str:gsub(".+<body[^>]*>(.+)</body>.+", "%1", 1) -- just return body contents
		str = str:gsub("[\r\n]", " ") -- remove linebreaks
		str = str:gsub("%s%s+", " ") -- collapse whitespace
	end
	return str
end

return cleanHTML