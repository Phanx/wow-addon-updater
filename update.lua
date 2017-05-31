--
-- Updates WoW addons from CurseForge and Wowace on Linux systems.
-- Written by Phanx <phanx@phanx.net>
-- Released under the WTFPL - You just DO WHAT THE FUCK YOU WANT TO.
--

require("lfs") -- luafilesystem

local core = dofile("common.lua")
local printf = core.printf
local db = core.getDB()

--
-- Try to match an addon to a project on CurseForge or Wowace
--

local function addSearchResults(site, body, t)
	t = t or {}

	if type(body) == "string" then
		body = common.cleanHTML(body)

		for tr in body:gmatch('<tr class="results">.-</tr>') do
			local id, name = tr:match('<div class="results-name">%s*<a href="/projects/([^"%?])[^"]*">(.-)</a>')
			name = name and name:gsub("<[^>]+>", "") -- remove <span>s used to highlight search terms
			local author = tr:match('<a href="/members/[^"]+">([^<]+)</a>')
			local date = tr:match(' data%-epoch="(%d+)"')

			if id and name and author then
				printf("Got search result on %s: %s (%s)", site, name, author)
				table.insert(t, {
					site = site,
					id = id,
					name = name,
					author = author,
					date = tonumber(date),
				})
			end
		end
	end

	return t
end

local function getSearchResults(term)
	local results = {}

	local _, _, curseResults = core.request("https://wow.curseforge.com/search?search=" .. common.urlencode(term))
	addSearchResults("curseforge", curseResults, results)

	local _, _, wowaceResults = core.request("https://www.wowace.com/search?search=" .. common.urlencode(term))
	addSearchResults("wowace", wowaceResults, results)

	return results
end

local function ignoreAddon(addon)
	print("Now ignoring " .. addon.title)
	addon.ignored = true
end

local function saveAddonMatch(addon, site, id)
	printf("Saving match: %s (%s @ %s)", addon.title, id, site)
	addon.site = site
	addon.id = id
end

local function matchAddon(addon)
	local results = getSearchResults(addon.title)
	printf("Found %d matches for %s (%s)", #results, addon.title, addon.author or "unknown")

	if #results > 0 then
		for i = 1, #results do
			local result = results[i]
			local lastUpdated = result.date and os.date("%x", result.date) or "<unknown>"
			printf("%d. %s (%s) %s", i, result.name, result.author, lastUpdated)
		end

		io.write("Pick a match (1-" .. #results .. ") or enter 0 if none are right:")
		local pick = io.read()
		pick = pick and results[tonumber(pick)]
		if pick then
			return saveAddonMatch(addon, pick.site, pick.id)
		end
	end

	io.write("Specify a manual match now? (y/n):")
	local reply = io.read():lower()
	if reply == "y" then
		io.write("Addon site ([c]urseforge, wow[a]ce, or wow[i]nterface) or URL:")
		reply = io.read()

		if reply:match("^https?://") then
			local site, id = core.parseProjectURL(reply)
			if site and id then
				return saveAddonMatch(addon, site, id)
			end
			print("Unrecognized URL")
			return ignoreAddon(addon)
		end

		reply = reply:lower()
		local site = reply == "c" and "curseforge" or reply == "a" and "wowace" or reply == "i" and "wowinterface"
		if not site then
			print("Invalid site")
			return ignoreAddon(addon)
		end

		io.write("Addon identifier:")
		local id = io.read()
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
		-- print("Scanning object " .. dir)
		local meta = core.getAddonMetadata(dir)
		if meta then
			-- print("Found addon")
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
				meta.deleted = true
			elseif not meta.site and not (meta.ignored or meta.dev) then
				print("New addon: " .. dir)
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
	for dir, meta in pairs(db) do
		if meta.site and meta.id and not meta.dev and not meta.ignore and not meta.deleted then
			core.updateAddon(meta) --[[
		else
			local reason = meta.dev and "Working Copy"
				or meta.ignore and "Ignored"
				or meta.deleted and "Deleted"
				or "Unidentified"
			print("Skipping " .. dir .. ": " .. reason) ]]
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
end

start()