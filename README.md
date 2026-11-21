# sm-plugin-AFKBomb

### Drop the bomb, or hand it to another terrorist, when the bomb carrier is AFK in Counter-Strike: Source.

srcdslab port of **Afk Bomb** 1.5.0 by RedSword ([AlliedModders thread](https://forums.alliedmods.net/showthread.php?t=152329)).

## How it works

1. One second after `round_start`, the plugin finds the terrorist carrying the bomb and saves their state: money, armor, pressed buttons, weapons in slots 1 to 4, eye angles, angles, position and velocity.
2. `afkbomb` seconds later (plus `mp_freezetime` if `afkbomb_freezetime` is `1`), it compares the state again. If nothing changed, the carrier is AFK and `afkbomb_action` applies: drop the bomb (the carrier says it in team chat), or strip it and give a new one to a random alive terrorist, preferring terrorists that are moving.
3. Late checks: if the carrier was not AFK, or the bomb changed hands, the check is repeated every `afkbomb_latecheckdelay` seconds (position, angles, velocity and weapons only). After `afkbomb_latecheck` checks in a row without any change, `afkbomb_latecheckaction` applies.

The bomb is dropped with `CS_DropWeapon` (cstrike extension) and given with `GivePlayerItem` (sdktools). Both rely on the gamedata shipped with SourceMod (`sm-cstrike.games`, `sdktools.games`), which has `linux64` entries for Counter-Strike: Source: the plugin has no gamedata of its own.

## Requirements

- Counter-Strike: Source
- SourceMod 1.12 or newer

## Installation

Download `sm-plugin-AFKBomb-<version>-sm1.12.tar.gz` or `-sm1.13.tar.gz` from the [releases](https://github.com/srcdslab/sm-plugin-AFKBomb/releases) and extract it in `cstrike/`:

```
addons/sourcemod/plugins/AFKBomb.smx
addons/sourcemod/translations/AFKBomb.phrases.txt
```

## ConVars

| ConVar | Default | Description |
|---|---|---|
| `afkbomb` | `2` | Seconds before the first AFK check of the round. `0` disables the plugin. |
| `afkbomb_freezetime` | `0` | `1` adds `mp_freezetime` to the first check delay. |
| `afkbomb_action` | `0` | Action when the carrier is AFK at round start: `1` drop, `0` give to a random terrorist. |
| `afkbomb_msg` | `1` | Announce it: the carrier says it in team chat (drop), or a chat message to everyone (give). |
| `afkbomb_latecheck` | `2` | Number of late checks without change before acting. `0` disables late checks. |
| `afkbomb_latecheckdelay` | `5.0` | Seconds between two late checks (minimum `1`). |
| `afkbomb_latecheckaction` | `1` | Action after the late checks: `1` drop, `0` give to a random terrorist (can be abused by fake-AFK players). |
| `afkbombversion` | | Plugin version (public, shown in the server rules). |

The config file is `cfg/sourcemod/afkbomb.cfg` (created on first load).

## Credits

- [RedSword / Bob Le Ponge](https://forums.alliedmods.net/member.php?u=10216): Afk Bomb.
- dalto (bomb drop code), AltPluzF4, AtomicStryker, Dr!fter, psychonic, sinblaster, TnTSCS: see the header of `AFKBomb.sp` and the AlliedModders thread.
- Translations: noPASARAN (ru), away000 (pt), sajmon83 (pl), Groger (nl), Dr. Greg House (de), hleV (lt), Blowst (ko), RedSword (fr).

The first commit of this repository is the unmodified 1.5.0 source and translation file. See [CHANGELOG.md](CHANGELOG.md) for the srcdslab changes.
