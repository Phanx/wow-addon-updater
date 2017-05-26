--
-- Updates WoW addons from CurseForge and Wowace on Linux systems.
-- Written by Phanx <phanx@phanx.net>
-- Released under the WTFPL - You just DO WHAT THE FUCK YOU WANT TO.
--

local args = { ... }
local core = loadfile("common.lua")()
local db = core.getDB()

local function installAddon(site, id)
	print("Installing new addon " .. id .. "@" .. site)

	local files = getProjectFiles(site, id)
	if not files or #files == 0 then
		return print("No files found")
	end

	local file = files[1]
	local addon = {
		site = site,
		id = id,
	}

	-- Identify main directory
	local main = 1
	local folders = common.installAddonFile(addon, file)
	if #folders > 1 then
		print("Installed " .. #folders .. " folders:")

		table.sort(folders)
		for i = 1, #folders do
			print(string.format("%d. %s", i, folders[i]))
		end

		io.write("Select main folder for addon:")
		main = tonumber(io.read())
	end

	local dir = folders[main]

	-- Fetch base metadata from TOC file
	local meta = common.getAddonMetadata(dir)
	for k, v in pairs(meta) do
		addon[k] = v
	end

	-- Add to DB
	addon.dir = dir
	db[dir] = addon

	-- Ignore secondary folders
	for i = 1, #folders do
		if i ~= main then
			local other = folders[i]
			db[other] = {
				dir = other,
				ignore = true
			}
		end
	end

	-- Write to disk
	core.saveDB()
end

local site, id
if args[1] and args[1]:match("^http") then
	site, id = core.parseProjectURL(args[1])
elseif #args == 2 then
	site, id = args[1]:lower(), args[2]:lower()
end

if site and id then
	installAddon(site, id)
else
	print("Usage: `lua install.lua <url>` or `lua install.lua <site> <id>`")
end