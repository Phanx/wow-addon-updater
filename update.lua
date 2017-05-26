--[[
Wat: Updates World of Warcraft addons from Curse
How: lua update.lua
Why: Linux
Who: Phanx <phanx@phanx.net>
Lic: WTFPL
]]

require("lfs") -- luafilesystem
require("socket") -- luasocket
local https = require("ssl.https") -- luasec
local persistence = loadfile("persistence.lua")()

local BASEDIR = ".."
local TEMPDIR = "/tmp/curseupdater"
local FILES_URL = "https://%s/projects/%s/files"

local db = persistence.load("db.lua") or {}

local function saveDB()
	persistence.store("db.lua", db)
end

local function initDB()
	local tocfields = {
		["Author"] = "author",
		["Interface"] = "wow",
		["Title"] = "title",
		["Version"] = "version",
		["X-Website"] = "url",
	}

	local function getAddonMetadata(dir)
		local toc = BASEDIR .. "/" .. dir .. "/" .. dir .. ".toc"
		toc = io.open(toc)
		if not toc then
			print(dir .. " is not an addon")
			return
		end

		local meta = {
			title = dir
		}

		if lfs.attributes(BASEDIR .. "/" .. dir .. "/.git") or lfs.attributes(BASEDIR .. "/" .. dir .. "/.svn") then
			print(dir .. " is a working copy")
			meta.dev = true
		end

		for line in toc:lines() do
			local k, v = line:match("##%s+(.+)%s*:%s+(.+%S)%s*$")
			local f = tocfields[k]
			if f then
				meta[f] = v:gsub("\\r$", "")
			end
		end
		toc:close()
		return meta
	end

	for dir in lfs.dir(BASEDIR) do
		print("Scanning object " .. dir)
		local meta = getAddonMetadata(dir)
		if meta then
			print("Found addon")
			local t = db[meta.title] or {}
			for k, v in pairs(meta) do
				t[k] = v
			end
			db[meta.title] = t
		end
	end

	saveDB()
end

local function sortFilesByDate(a, b)
	return a.date > b.date
end

local function request(url, binary)
	local outfile = TEMPDIR .. "/response"
	os.execute("wget -o " .. TEMPDIR .. "/log -O " .. outfile .. " " .. url)

	local attr = lfs.attributes(outfile)
	if not attr or attr.mode ~= "file" then
		return false, "No response"
	end

	if binary then
		return true, attr.size, outfile
	end

	outfile = io.open(outfile)
	local outbody = outfile:read("*a")
	outfile:close()
	return true, outbody:len(), outbody
end

local function getProjectFiles(domain, slug)
	if not domain or not slug then return end

	local url = FILES_URL:format(domain, slug)
	print("Getting files from " .. url)

	local ok, size, data = request(url)
	if data then
		print("Parsing files list")
		data = data:gsub("\r?\n", " ") -- remove line breaks
		data = data:gsub("%s%s+", " ") -- collapse whitespace

		local files = {}
		local host = url:match("https://[^/]+")

		for tr in data:gmatch('<tr class="project%-file%-list%-item">(.-)</tr>') do
			local name = tr:match('data%-action="file%-link" data%-id="[^"]+" data%-name="([^"]+)"')
			local link = tr:match('<a class="button tip fa%-icon%-download icon%-only" href="([^"]+)"')
			local date = tr:match('data%-epoch="(%d+)"')

			if name and link and date then
				table.insert(files, {
					name = name,
					link = host .. link,
					date = tonumber(date),
				})
			end
		end
		table.sort(files, sortFilesByDate)
		print("Found " .. #files .. " files")
		return files
	else
		print("No data received.")
	end
end

local function updateAddon(addon)
	print("Updating " .. addon.title)

	local files = getProjectFiles(addon.domain, addon.slug)
	if not files or #files == 0 then
		return print(addon.title .. " not found")
	end

	local installed = addon.installed or addon.version
	print("Installed version is " .. (installed or "UNKNOWN"))

	local newest = files[1]
	if installed == newest.name then
		return print(addon.title .. " is already up to date")
	end
	print("Downloading version " .. newest.name)

	local ok, size, path = request(newest.link, true)
	assert(ok, "Error downloading file")

	os.execute("unzip -qq -o " .. path .. " -d " .. TEMPDIR)
	for dir in lfs.dir(TEMPDIR) do
		local attr = lfs.attributes(TEMPDIR .. "/" .. dir)
		if attr and attr.mode == "directory" and not dir:match("^%.+$") then
			print("Includes folder: " .. dir)
			os.execute(string.format("rm -rf %s/%s", BASEDIR, dir))
			os.execute(string.format("mv %s/%s %s", TEMPDIR, dir, BASEDIR))
		end
	end

	db[addon.title].installed = newest.name
	saveDB()
end

do
	initDB()

	local addon = db["SilverDragon"]
	addon.domain = "www.wowace.com"
	addon.slug = "silver-dragon"

	lfs.mkdir(TEMPDIR)

	updateAddon(addon)

	lfs.rmdir(TEMPDIR)

	return
end




local function parseVersionString(v)
	v = v:gsub("^%s*r?v?(.-)%s*$", "%1")
	local a, b, c, d = v:match("^(%d+)%.?(%d*)%.?(%d*)%.?(%d*)$")
	if a then
		return {
			tonumber(a) or a,
			tonumber(b) or b,
			tonumber(c) or c,
			tonumber(d) or d,
		}
	end
	return {
		tonumber(v) or v
	}
end

-- returns true if a is newer than b,
-- false if b is newer than a,
-- or nil if no comparison could be made
local function compareVersions(a, b)
	for i = 1, #a do
		if not b[i] then
			return
		end
		if a[i] ~= b[i] then
			return a[i] > b[i]
		end
	end
end
