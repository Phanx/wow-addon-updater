--
-- Update and install World of Warcraft addons from the command line.
-- Author : Phanx <phanx@phanx.net>
-- Website: https://gitlab.com/phanx/wow-addon-updater
-- License: Zlib - see LICENSE.txt for full text
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