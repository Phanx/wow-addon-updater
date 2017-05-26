Simple updater for World of Warcraft addons written in Lua.

### Usage:

`lua updater.lua`

On first run, or when new addons are detected, the script will attempt to match each
addon to a project on CurseForge or Wowace, and ask you to confirm each match. You can
also choose to manually specify the project, or ignore the addon.

For new addons whose TOC files don't include the version number, a fresh copy of the
addon will be downloaded and installed. It's the only way to be sure (tm).

To manually edit matches later, or ignore / un-ignore addons, edit the `db.lua` file
created in the script directory.

### Installation:

1. `cd` into your AddOns folder.
2. `git clone <url here> zz-updater`
3. `cd zz-updater`

### Requirements:

- Linux (or maybe macOS or Cygwin, but not tested)
- Lua
- luafilesystem
- luasec
- luasocket
- wget
- unzip

### License

This work is free. You can redistribute it and/or modify it under the
terms of the Do What The Fuck You Want To Public License, Version 2,
as published by Sam Hocevar. See the COPYING file for more details.
