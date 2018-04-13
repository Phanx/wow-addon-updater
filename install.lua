--
-- Update and install World of Warcraft addons from the command line.
-- Author : Phanx <phanx@phanx.net>
-- Website: https://gitlab.com/phanx/wow-addon-updater
-- License: Zlib - see LICENSE.txt for full text
--

local args = { ... }
local core = dofile("common.lua")
local sites = dofile("sites.lua")
local db = core.getDB()

local function installAddon(site, id)
	print("Installing new addon " .. id .. "@" .. site)

	local files = core.getProjectFiles(site, id)
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
	local folders = core.installAddonFile(addon, file)
	if #folders > 1 then
		print("Installed " .. #folders .. " folders:")

		table.sort(folders)
		for i = 1, #folders do
			print(string.format("%d. %s", i, folders[i]))
		end

		main = tonumber(core.prompt("Select main folder for addon:"))
	end

	local dir = folders[main]

	-- Fetch base metadata from TOC file
	local meta = core.getAddonMetadata(dir)
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
				parent = dir,
				ignore = true,
                site = site
			}
		end
	end

	-- Write to disk
	core.saveDB()

	core.printf("Successfully installed %s!", addon.title or dir)
end

local site, id
if args[1] and args[1]:match("^http") then
	site, id = sites.parseProjectURL(args[1])
elseif #args == 2 then
	site, id = args[1]:lower(), args[2]:lower()
end

if site and id then
	installAddon(site, id)
else
	print("Usage: `lua install.lua <url>` or `lua install.lua <site> <id>`")
end