--
-- Update and install World of Warcraft addons from the command line.
-- Author : Phanx <phanx@phanx.net>
-- Website: https://gitlab.com/phanx/wow-addon-updater
-- License: Zlib - see LICENSE.txt for full text
--
-- URL-encode a string
--

local function encodeChar(c)
	return string.format("%%%02X", string.byte(c)) 
end

local function encodeURL(str)
	if (str) then
		str = string.gsub(str, "\n", "\r\n")
		str = string.gsub(str, "([^%w ])", encodeChar)
		str = string.gsub(str, " ", "+")
	end
	return str
end

return encodeURL
