--
-- Updates WoW addons from CurseForge and Wowace on Linux systems.
-- Written by Phanx <phanx@phanx.net>
-- Released under the WTFPL - You just DO WHAT THE FUCK YOU WANT TO.
--

require("lfs") -- luafilesystem
local persistence = dofile("persistence.lua")

local export = {}

--
-- Script configuration
--

local DBFILE = "db.lua"

local BASEDIR = ".."
local TEMPDIR = "/tmp/curseupdater"

export.BASEDIR = BASEDIR
export.TEMPDIR = TEMPDIR

--
-- Project fetch configuration
--

local FILES_URL = {
	curseforge = "https://wow.curseforge.com/projects/%s/files",
	wowace = "https://www.wowace.com/projects/%s/files",
	wowinterface = "https://www.wowinterface.com/downloads/info%s",
}

export.FILES_URL = FILES_URL

--
-- Read and write the database to a file
--

local db = persistence.load(DBFILE) or {}

local function saveDB()
	persistence.store(DBFILE, db)
end

export.getDB = function() return db end
export.saveDB = saveDB

--
-- Print a formatted string
--

local function printf(str, ...)
	print(string.format(str, ...))
end

export.printf = printf

--
-- Do something with each folder in the given directory
--

local function withEachFolder(path, func)
	for dir in lfs.dir(path) do
		if not dir:match("^%.+$") then
			local full = path .. "/" .. dir
			local attr = lfs.attributes(full)
			if attr and attr.mode == "directory" then
				func(full, dir)
			end
		end
	end
end

export.withEachFolder = withEachFolder

--
-- Prompt for user input
--

local function prompt(text, options, constrain)
	if type(options) ~= "table" or #options == 0 then
		options = nil
	end

	local hint = ""
	if options then
		hint = " (" .. table.concat(options, "/") .. ")"
	end
	io.write(text .. hint)

	local reply = io.read()
	if options and constrain then
		while not options[reply:lower()] do
			reply = io.read()
		end
	end
	return reply
end

export.prompt = prompt

--
-- Merge tables
-- Last in has priority
--

local function table_merge(...)
	local into = {}
	for i = 1, select("#", ...) do
		local from = select(i, ...)
		if type(from) == "table" then
			for k, v in pairs(from) do
				into[k] = v
			end
		end
	end
	return into
end

export.table_merge = table_merge

--
-- URL-encode a string
--

local function urlencode(str)
	if (str) then
		str = string.gsub(str, "\n", "\r\n")
		str = string.gsub(str, "([^%w ])", function (c) return string.format("%%%02X", string.byte(c)) end)
		str = string.gsub(str, " ", "+")
	end
	return str
end

export.urlencode = urlencode

--
-- Get site and id from a URL
--

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
		or url:match("[/%.]wowinterface.com/downloads/download(%d+)")
	if id then
		return "wowinterface", id
	end
end

export.parseProjectURL = parseProjectURL

--
-- Retrieve documents and other files using wget
-- For some reason luasec can't talk to wow.curseforge.com or www.wowace.com
--

local function request(url, binary)
	if not lfs.attributes(TEMPDIR) then
		lfs.mkdir(TEMPDIR)
	end

	local outfile = TEMPDIR .. "/response"
	local logfile = TEMPDIR .. "/log"
	os.remove(outfile)
	os.remove(logfile)
	os.execute(string.format("wget -o %s -O %s %s", logfile, outfile, url))

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

export.request = request

--
-- Clean up temporary files
--

local function cleanup()
	lfs.rmdir(TEMPDIR)
end

export.cleanup = cleanup

--
-- Clean up a version string
--

local function fixVersionString(str, meta)
	if str then
		if meta and meta.dir then
			str = str:gsub(meta.dir, "")
		end
		if meta and meta.title then
			str = str:gsub(meta.title, "")
		end
		str = str:gsub("^%s*", "")
		str = str:gsub("%s*$", "")
		str = str:gsub("Version ", "")
		str = str:gsub("[rv] ?(%d+)", "%1")
		str = str:gsub("%-release", "")
	end
	return str
end

export.fixVersionString = fixVersionString

--
-- Scan a TOC file for information about an addon
--

local tocfields = {
	["Author"] = "author",
	["Interface"] = "wow",
	["Title"] = "title",
	["Version"] = "version",
	["X-Website"] = "url",
}

local function getAddonMetadata(dir)
	local path = BASEDIR .. "/" .. dir .. "/"

	local toc = path .. dir .. ".toc"
	toc = io.open(toc)
	if not toc then
		-- print(dir .. " is not an addon")
		return
	end

	local meta = {
		dir = dir,
		title = dir
	}

	if lfs.attributes(path .. ".git") or lfs.attributes(path .. ".svn") then
		-- print(dir .. " is a working copy")
		meta.dev = true
	end

	for line in toc:lines() do
		local k, v = line:match("^##%s+(.+)%s*:%s+(.+%S)%s*$")
		local f = tocfields[k]
		if f then
			meta[f] = v
		end
	end
	toc:close()
	return meta
end

export.getAddonMetadata = getAddonMetadata

--
-- Clean up HTML for easier parsing
--

local function cleanHTML(str)
	if str then
		str = str:gsub("\r?\n", " ") -- remove linebreaks
		str = str:gsub("%s%s+", " ") -- collapse whitespace
	end
	return str
end

export.cleanHTML = cleanHTML

--
-- Get a list of available files for the addon
--

local function sortFilesByDate(a, b)
	return a.date > b.date
end

local function getProjectFiles(site, id)
	if not site or not id or not FILES_URL[site] then return end

	local url = FILES_URL[site]:format(id)
	-- print("Getting files from " .. url)

	local ok, size, data = request(url)
	if data then
		data = cleanHTML(data)
		-- print("Parsing files list")

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

		if #files > 0 then
			table.sort(files, sortFilesByDate)
			return files
		end
	end
	print("No data received")
end

export.getProjectFiles = getProjectFiles

--
-- Install an addon
--

local function installAddonFile(addon, file)
	local ok, size, path = request(file.link, true)
	assert(ok, "Error downloading file")

	-- Make sure temp dir is empty
	withEachFolder(TEMPDIR, function(path, dir)
		print("Deleting temp subdir " .. dir)
		os.execute(string.format("rm -rf '%s'", path))
	end)

	-- Unzip the download
	os.execute("unzip -qq -o " .. path .. " -d " .. TEMPDIR)

	-- Fix capitalization of folder name for addons with dumb/lazy authors
	-- eg. spew/Spew.toc
	withEachFolder(TEMPDIR, function(path, dir)
		for file in lfs.dir(path) do
			local toc = file:match("(.+)%.toc$")
			if toc then
				if toc ~= dir then
					print("Renaming bad folder: %s --> %s", dir, toc)
					os.execute("mv '%s' %s'", path, path:gsub(dir.."$", toc))
				end
				break
			end
		end
	end

	-- Copy extracted dirs to real dir
	local folders = {}
	withEachFolder(TEMPDIR, function(path, dir)
		print("Installing folder: " .. dir)
		table.insert(folders, dir)
		os.execute(string.format("gvfs-trash '%s/%s'", BASEDIR, dir))
		os.execute(string.format("mv '%s' '%s'", path, BASEDIR))
		os.execute(string.format("chmod -R 777 '%s/%s'", BASEDIR, dir))
	end)

	-- Update the installed version info in the db
	addon.installed = file.name

	return folders
end

export.installAddon = installAddon

--
-- Update a single addon
--

local function updateAddon(addon)
	-- print("Checking " .. addon.title)

	local files = getProjectFiles(addon.site, addon.id)
	if not files or #files == 0 then return end

	local installed = addon.installed or addon.version

	local newest = files[1]
	if installed == newest.name then
		return -- print("Already up to date")
	end

	printf("Updating %s: %s --> %s", addon.title, installed or "UNKNOWN", newest.name)
	installAddonFile(addon, newest)
end

export.updateAddon = updateAddon

--
-- Done!
--

return export

--[[

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

]]
