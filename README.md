
**Install and update World of Warcraft addons from the command line on Linux.**


## Usage

`lua update.lua` updates all addons.

On first run, or when new addons are detected, the script will attempt to match
each addon to a project on CurseForge or Wowace, and ask you to confirm each
match, manually specify the project, or ignore the addon.

You should elect to ignore addons that you have locally modified, as the script
does not detect local changes and will overwrite them on update.

For new addons whose TOC files don't include a version number, or don't match
any version numbers listed on the project page, a fresh copy of the addon will
be downloaded and installed. *It's the only way to be sure (tm).*

To manually edit matches later, or ignore / un-ignore addons, edit the `db.lua`
file created in the script directory.

Local Git repositories and SVN working copies are ignored automatically.


### Installing new addons

`lua install.lua <url>` installs an addon from a CurseForge, Wowace, or
WoWInterface URL, and saves the source info for frictionless future updates.

For CurseForge, the `www.curseforge.com` domain (user site) is not supported;
click the link to view the addon's "project page" and use that URL, which will
either be on `wow.curseforge.com` or `www.wowace.com`.


## Future

- Auto-matching from WoWInterface
- Interactive update mode
- Interactive management features
- Post-install scripting to apply patches
- Hashing to detect local changes and avoid overwriting


## Installation

1. `cd` into your AddOns folder
2. `git clone https://gitlab.com/phanx/wow-addon-updater.git $INSTALLDIR`
3. `cd $INSTALLDIR`
4. See "Usage" above

If you install anywhere other than `AddOns\$INSTALLDIR` you'll need to edit
the `BASEDIR` value in `common.lua` accordingly.


## Requirements

- Linux
- gvfs-utils
- wget
- unzip
- Lua - `apt install lua5.1 luarocks`
- [luafilesystem](https://keplerproject.github.io/luafilesystem/) - `luarocks install luafilesystem`


## History

*TLDR version:* I should not need a virtual machine and a magnifying glass to
update my World of Warcraft addons.

*Long version:* The official application for updating addons from CurseForge
(a) doesn't run on Linux, including under Wine, and (b) is an ever-increasingly
bloated pile of social garbage that (c) takes forever to launch and do anything
in VirtualBox, and (d) is even worse at detecting addons than the original
Curse Client was.

WoWInterface support is included for convenience and because their official
updater (a) has way too many issues with addon identification and version
detection to be usable with 150+ addons hosted on multiple sites. Also (b) it
has no working copy detection and will happily erase my local Git repositories
if I forget to manually ignore all 40+ of them.

Also, both totally fail at usability for anyone even mildly visually impaired.


## License

This software is published under the terms of the zlib License. See the
included `LICENSE.txt` file for the full text of the license.
