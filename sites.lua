--
-- Update and install World of Warcraft addons from the command line.
-- Author : Phanx <phanx@phanx.net>
-- Website: https://gitlab.com/phanx/wow-addon-updater
-- License: Zlib - see LICENSE.txt for full text
--

local cleanHTML = dofile("utils/cleanHTML.lua")
local decodeEntities = dofile("utils/decodeEntities.lua")
local encodeURL = dofile("utils/encodeURL.lua")

local exports = {}

local function getTimestamp(y, m, d, hh, mm)
	return os.time({
		year = tonumber(y) or 2099,
		month = tonumber(m) or 1,
		day = tonumber(d) or 1,
		hour = tonumber(hh) or 12,
		minute = tonumber(mm) or 0,
	})
end

--[[
	info
	Maps CLI acesskey to site name
--]]
local info = {
	{ key = "c", id = "curseforge" },
	{ key = "a", id = "wowace" },
	{ key = "i", id = "wowinterface" },
}
for i = 1, #info do
	local site = info[i]
	info[site.key] = site.id
end
exports.info = info

--[[
	getFilesListURL
--]]
local getFilesListURL = {}
exports.getFilesListURL = getFilesListURL

getFilesListURL["curseforge"] = function(id) return "https://wow.curseforge.com/projects/" .. id .. "/files" end
getFilesListURL["wowace"] = function(id) return "https://www.wowace.com/projects/" .. id .. "/files" end
getFilesListURL["wowinterface"] = function(id) return "https://www.wowinterface.com/downloads/fileinfo.php?id=" .. id end

--[[
	parseFilesList
--]]
local parseFilesList = {}
exports.parseFilesList = parseFilesList

local function sortFilesByDate(a, b)
	return (a.date or 0) > (b.date or 0)
end

parseFilesList["curseforge"] = function(url, html, t)
	html = cleanHTML(html)
	t = t or {}

	local host = url:match("https://[^/]+")

	for tr in html:gmatch('<tr class="project%-file%-list%-item">(.-)</tr>') do
		local name = tr:match('data%-action="file%-link" data%-id="[^"]+" data%-name="([^"]+)"')
		local link = tr:match('<a class="button tip fa%-icon%-download icon%-only" href="([^"]+)"')
		local date = tr:match('data%-epoch="(%d+)"')

		if name and link and date then
			table.insert(t, {
				name = name,
				link = host .. link,
				date = tonumber(date),
			})
		end
	end

	if #t > 0 then
		table.sort(t, sortFilesByDate)
	end

	return t
end

parseFilesList["wowace"] = parseFilesList["curseforge"]

parseFilesList["wowinterface"] = function(url, html, t)
	html = cleanHTML(html)
	t = t or {}

	local host = url:match("https://[^/]+")

	if url:find("/downloads/landing\.php") then
		local file = t[1]
		if file then
			local link = html:match('<div class="manuallink">.- <a href="(.-)">Click here</a>')
			file.link = decodeEntities(link)
			file.middleman = false
		end
		return t
	end

	do
		local name = html:match('<div id="version">Version: ([^<]+)</div>')
		local link = decodeEntities(html:match('<a[^>]* href="(/downloads/[^"]+)">Download</a>'))
		local d, m, y, hh, mm, am = html:match('<div id="safe">Updated: (%d+)%-(%d+)%-(%d+) (%d+):(%d+) ([AP]M)</div>')
		if am == "PM" then hh = tonumber(hh) + 12 end
		local updated = getTimestamp(y, m, d, hh, mm)

		if name and link and updated then
			table.insert(t, {
				name = name,
				link = host .. link,
				date = updated,
				middleman = true,
			})
		end
	end
--[[
	for tr in html:gmatch('<tr class="project%-file%-list%-item">(.-)</tr>') do
		local name = tr:match('data%-action="file%-link" data%-id="[^"]+" data%-name="([^"]+)"')
		local link = tr:match('<a class="button tip fa%-icon%-download icon%-only" href="([^"]+)"')
		local date = tr:match('<div id="safe">Updated: 06-18-17 02:46 AM</div>')

		if name and link and date then
			table.insert(t, {
				name = name,
				link = host .. link,
				date = tonumber(date),
			})
		end
	end
]]
	if #t > 0 then
		table.sort(t, sortFilesByDate)
	end

	return t
end

--[[
	getSearchURL
	Construct a search URL for the given query term
--]]
local getSearchURL = {}
exports.getSearchURL = getSearchURL

getSearchURL["curseforge"] = function(term)
	return "https://wow.curseforge.com/search?search=" .. encodeURL(term)
end

getSearchURL["wowace"] = function(term)
	return "https://www.wowace.com/search?search=" .. encodeURL(term)
end

getSearchURL["wowinterface"] = function(term)
	-- TODO: it should be POST to match the actual site
	return "https://www.wowinterface.com/downloads/search.php?search=" .. encodeURL(term)
end

--[[
	parseProjectURL
	Parse URL for an addon site and ID/slug
--]]
local function parseProjectURL(url)
	if type(url) ~= "string" then return end

	local id = url:match("//wow.curseforge.com/projects/([^/]+)")
	if id then
		return "curseforge", id
	end

	id = url:match("//www.wowace.com/projects/([^/]+)")
	if id then
		return "wowace", id
	end

	-- WoWInterface usually has a "www" subdomain, but can also have
	-- an author name subdomain if coming from an Author Portal page.
	id = url:match("[/%.]wowinterface.com/downloads/info(%d+)")
		or url:match("[/%.]wowinterface.com/downloads/fileinfo\.php\?id=(%d+)")
		or url:match("[/%.]wowinterface.com/downloads/download(%d+)")
	if id then
		return "wowinterface", id
	end
end

exports.parseProjectURL = parseProjectURL

--[[
	parseSearchResults
	Parse an HTML document and return a list of search results

	parser = parseSearchResults[site]
	- site: string

	parser(html, t)
	- html: string
	- t: optional, table into which to insert results
--]]
local parseSearchResults = {}
exports.parseSearchResults = parseSearchResults

parseSearchResults["curseforge"] = function(html, t)
	t = t or {}

	for tr in cleanHTML(html):gmatch('<tr class="results">.-</tr>') do
		local id, name = tr:match('<a href="/projects/([^"?/]+)[^"]*">(.-)</a>')
		name = name and name:gsub("<[^>]+>", "") -- remove <span>s used to highlight search terms
		local author = tr:match('<a href="/members/[^"]+">([^<]+)</a>')
		local date = tr:match(' data%-epoch="(%d+)"')

		if id and name and author then
			table.insert(t, {
				site = site,
				id = id,
				name = name,
				author = author,
				date = tonumber(date),
			})
		end
	end

	return t
end

parseSearchResults["wowace"] = parseSearchResults["curseforge"]

parseSearchResults["wowinterface"] = function(html, t)
	t = t or {}
	for tr in cleanHTML(html):gmatch('<tr>(.-)</tr>') do
		local id, name = tr:match('<a href="fileinfo.php\?[^"]*id=(%d+)[^"]*">(.-)</a>')
		local author = tr:match('<a href="/forums/member.php[^"]+">(.-)</a>')
		local updated = tr:match('<td align="center" class="alt%d">(%d%d%-%d%d%-%d%d)</td>')
		if updated then
			local m, d, y = tr:match("(%d%d)%-(%d%d)%-(%d%d)")
			if m and d and y then
				updated = getTimestamp("20"..y, m, d)
			end
		end
	end
	return t
end

return exports