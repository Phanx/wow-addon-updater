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
