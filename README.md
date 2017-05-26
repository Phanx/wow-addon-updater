
**Simple personal updater for World of Warcraft addons written in Lua.**


## Usage

`lua updater.lua` updates all addons.

On first run, or when new addons are detected, the script will attempt to match
each addon to a project on CurseForge or Wowace, and ask you to confirm each
match, manually specify the project, or ignore the addon.

For new addons whose TOC files don't include a version number, or don't match
any version numbers listed on the project page, a fresh copy of the addon will
be downloaded and installed. It's the only way to be sure (tm).

To manually edit matches later, or ignore / un-ignore addons, edit the `db.lua`
file created in the script directory.

Local Git repositories and SVN working copies are ignored automatically.

`lua install.lua <url>` or `lua install.lua <site> <id>` installs the specified
addon, and saves the source info for frictionless future updates. Supports
CurseForge, Wowace, and WoWInterface URLs. `<id>` should be the URL slug for
Curse, and a numeric ID for WoWI.


## Future

- WoWInterface support
- Interactive update mode
- Interactive management features


## Installation

1. `cd` into your AddOns folder
2. `git clone <url> <folder>`
3. `cd <folder>`
4. See "Usage" above

If you install anywhere other than `AddOns\<something>` you'll need to edit
the `BASEDIR` value in `common.lua` accordingly.


## Requirements

- Linux
- gvfs-utils
- wget
- unzip
- Lua
- luafilesystem


## History

*TLDR version:* I should not need a virtual machine and a magnifying glass to
update my World of Warcraft addons.

*Long version:* The official Curse updater (a) doesn't run on Linux, including
under Wine, and (b) is an ever-increasingly bloated pile of social garbage that
(c) takes forever to launch and do anything in VirtualBox, and (d) is even worse
at detecting addons than the previous Curse Client was. 💩 🤢 😠

WoWInterface support will be coming soon, because while their official updater,
while it does run okay under Wine, has way too many bugs with addon and version
detection to be usable with 100+ addons. Also, no working copy detection. 😞

Also, both totally fail at usability for even the mildly visually impaired.


## License

This work is free. You can redistribute it and/or modify it under the
terms of the Do What The Fuck You Want To Public License, Version 2,
as published by Sam Hocevar. See the COPYING file for more details.
