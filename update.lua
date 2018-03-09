--
-- Update and install World of Warcraft addons from the command line.
-- Author : Phanx <phanx@phanx.net>
-- Website: https://gitlab.com/phanx/wow-addon-updater
-- License: Zlib - see LICENSE.txt for full text
--

require("lfs") -- luafilesystem

local cleanHTML = dofile("utils/cleanHTML.lua")
local sites = dofile("sites.lua")
local core = dofile("common.lua")
local db = core.getDB()

local args = core.parseArguments(...)

--
-- Logging and message output
--

local function formatMessage(str, ...)
	str = tostring(str)
	if str:find("%%[dsf%d%.]") then
		str = str:format(...)
	elseif select("#", ...) > 0 then
		for i = 1, select("#", ...) do
			str = str .. " " .. tostring(select(i, ...))
		end
	end
	return str
end

local logLines = {}

local function writeLog()
	local file = io.open("log.txt", "w")
	if not file then return end
	file:write(table.concat(logLines, "\n") .. "\n")
	file:close()
end

local function log(str, ...)
	table.insert(logLines, formatMessage(str, ...))
end

local _print = print
function print(str, ...)
	log(formatMessage(str, ...))
	_print(formatMessage(str, ...))
end

--
-- Try to match an addon to a project on CurseForge or Wowace
--

local function addSearchResults(site, html, t)
	t = t or {}

	local parser = sites.parseSearchResults[site]
	if parser and type(html) == "string" then
		html = cleanHTML(html)
		parser(html, t)
	end

	return t
end

local function getSearchResults(term)
	local results = {}

	for site, getSearchURL in pairs(sites.getSearchURL) do
		local _, _, html = core.request(getSearchURL(term))
		addSearchResults(site, html, results)
	end

	return results
end

local function ignoreAddon(addon)
	print("Now ignoring", addon.title)
	addon.ignored = true
end

local function saveAddonMatch(addon, site, id)
	print("Saving match: %s (%s @ %s)", addon.title, id, site)
	addon.site = site
	addon.id = id
end

local function matchAddon(addon)
	local results = getSearchResults(addon.title)
	print("Found %d matches for %s by %s", #results, addon.title, addon.author or "<unknown>")

	if #results > 0 then
		for i = 1, #results do
			local result = results[i]
			local lastUpdated = result.date and os.date("%x", result.date) or "<unknown>"
			print("%d. %s (%s) %s", i, result.name, result.author, lastUpdated)
		end

		local pick = tonumber(core.prompt("Pick a match (1" .. (#results > 1 and ("-" .. #results) or "") .. ") or enter 0 if none are right:")) or 0
		local result = results[pick]
		if result then
			return saveAddonMatch(addon, result.site, result.id)
		end
	end

	local reply = string.lower(core.prompt("Specify a manual match now? (y/n):"))
	if reply == "y" then
		local options = ""
		for i = 1, #sites.info do
			if i > 1 then
				options = options .. ", "
			elseif i == #sites.info then
				options = options .. ", or "
			end
			options = options .. sites.info[i].id:gsub(sites.info[i].key, "[" .. sites.info[i].key .. "]", 1)
		end
		reply = core.prompt("Addon site (" .. options ..") or URL:")

		if reply:match("^https?://") then
			local site, id = core.parseProjectURL(reply)
			if site and id then
				return saveAddonMatch(addon, site, id)
			end
			print("Could not parse URL")
			return ignoreAddon(addon)
		end

		reply = reply:lower()
		local site = sites.info[reply]
		if not site then
			print("Invalid site")
			return ignoreAddon(addon)
		end

		local id = core.prompt("Addon slug or ID:")
		if id:len() == 0 then
			print("Missing ID")
			return ignoreAddon(addon)
		end

		return saveAddonMatch(addon, site, id)
	end

	print("Failed to find a match")
	return ignoreAddon(addon)
end

--
-- Scan for added or removed addons, and refresh metadata from TOC files
--

local function scanAddons()
	-- Scan for added or changed addons and add them to the DB
	for dir in lfs.dir(core.BASEDIR) do
		log("Scanning object", dir)
		local meta = core.getAddonMetadata(dir)
		if meta then
			log("Found addon")
			local t = db[dir] or {}
			for k, v in pairs(meta) do
				t[k] = v
			end
			t.deleted = nil
			db[dir] = t
		end
	end

	-- Scan for removed addons and flag them in the DB
	for dir, meta in pairs(db) do
		if not meta.deleted then
			local attr = lfs.attributes(core.BASEDIR .. "/" .. dir)
			if not attr or attr.mode ~= "directory" then
				log("Deleted:", name)
				meta.deleted = true
			elseif not meta.site and not (meta.ignored or meta.dev) then
				log("New:", dir)
				local action = string.lower(core.prompt("New addon '" .. dir .. "' -- [m]atch, [i]gnore, or [s]kip? "))
				if action == "m" then
					matchAddon(meta)
				elseif action == "i" then
					ignoreAddon(meta)
				else
					print("Skipped")
				end
			end
		end
	end

	-- Write to disk
	core.saveDB()
end

--
-- Update all addons
--

local function updateAllAddons()
	local dirs = {}
	for dir, meta in pairs(db) do
		table.insert(dirs, dir)
	end
	table.sort(dirs)

	for i = 1, #dirs do
		local dir = dirs[i]
		local meta = db[dir]

		if meta.site and meta.id and not (meta.dev or meta.ignore or meta.deleted) then
			core.updateAddon(meta)
		else
			local reason = meta.dev and "Working Copy"
				or meta.ignore and "Ignored"
				or meta.deleted and "Deleted"
				or "Unidentified"
			log("%s skipped (%s)", dir, reason)
		end
	end

	-- Write to disk
	core.saveDB()
end

--
-- Get the party started
--

local function start()
	-- Scan for added/removed/updated addons
	scanAddons()
	-- Check for and download any available updates
	updateAllAddons()
	-- Clean up any temporary files
	core.cleanup()
	-- Write the log file
	writeLog()
end

start()