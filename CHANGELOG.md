## Release Notes

## [1.5.1-srcdslab]

### Changed

- srcdslab layout: `addons/sourcemod/scripting/AFKBomb.sp` and `addons/sourcemod/translations/AFKBomb.phrases.txt`.
- CI build for SourceMod 1.12 and 1.13 with release archives, translation lint, Dependabot.
- New syntax (`#pragma newdecls required`) and methodmaps (`ConVar`, `DataPack`, `Event`).
- ConVars are now written to `cfg/sourcemod/afkbomb.cfg` (`AutoExecConfig`).
- `myinfo` URL points to this repository.

### Added

- Translations: es, zho, chi, tr, it, ua, cze for both phrases, ru for the "given to a random terrorist" message.

### Fixed

- German "Drop Bomb" phrase said the bomb was being planted.
- `#format` of "StripNGive Bomb" uses the documented comma-separated form.
- Never reads the classname of a missing bomb entity when the bomb is given to another terrorist.

ConVar names, defaults and behaviour are unchanged.

## [1.5.0] (RedSword)

- `afkbomb_latecheckaction` split from `afkbomb_action`.
- Moving terrorists are preferred when the bomb is given to a random terrorist.
