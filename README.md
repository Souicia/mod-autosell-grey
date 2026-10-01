# AzerothCore Auto-Sell Grey

A small quality-of-life system for **AzerothCore 3.3.5a + Eluna** that automatically converts safe grey-quality loot into its normal vendor value.

The core patch integrates Auto Sell into the normal loot-storage path so eligible greys can still be sold when the player's bags are full. Normal inventory validation runs first, and only the specific `EQUIP_ERR_INVENTORY_FULL` result may be bypassed for an otherwise eligible grey item.

## Features

- Automatically sells eligible poor-quality (grey) loot for its normal vendor `SellPrice`.
- Works even when the player's inventory is full.
- Keeps normal inventory/storage restrictions authoritative for every error except inventory-full.
- Per-character persistent toggle:
  - `.autosell on`
  - `.autosell off`
  - `.autosell` to show current status
- `.autosell now` sells eligible grey items already in the character's bags.
- Auto Sell unlocks at level 6 and defaults to enabled for newly initialized eligible characters.
- Bots are excluded.
- Clean transaction message: `Sold [Item] for Xg Ys Zc.`
- Avoids auto-selling potentially important grey items.

## Safety exclusions

An item is not auto-sold when any of the following applies:

- It is not poor quality.
- It has no vendor value.
- It starts a quest.
- It belongs to the Quest or Key item classes.
- It contains loot.
- It has the `NO_USER_DESTROY` flag.
- It is currently required by an active quest.
- It is represented as quest/conditional loot in the current loot container.
- Its full sale value cannot be credited without exceeding the money cap.

The manual `.autosell now` path applies the corresponding item-template and quest checks before removing anything from the player's bags.

## Requirements

- AzerothCore 3.3.5a
- ElunaLuaEngine / an AzerothCore build with Eluna enabled
- Access to the `acore_characters` database

This release contains a small core patch to support Auto Sell directly in the loot-storage path, including when the player's inventory is full. Cloning this repository into `modules/` alone does not install the feature; the included core patch, SQL, and Eluna script must also be installed as described below.

## Repository layout

```text
lua/
  auto_sell_grey.lua
sql/
  character_autosell_settings.sql
patches/
  autosell-grey-core.patch
```

## Installation

### 1. Apply the core patch

From the root of your AzerothCore source tree:

```bash
git apply modules/mod-autosell-grey/patches/autosell-grey-core.patch
```

If you cloned this repository elsewhere, provide the full path to the patch instead.

The patch changes only:

```text
src/server/game/Entities/Player/Player.cpp
```

and only inside `Player::StoreLootItem()`.

Because AzerothCore changes over time, a future core revision may require manually merging the small patch if `git apply` can no longer match its surrounding context.

### 2. Import the character database table

Import:

```text
sql/character_autosell_settings.sql
```

into `acore_characters`.

The `chat_enabled` column is retained for compatibility with the development version of this system. Version 1.0.0 uses a single player-facing setting: Auto Sell enabled/disabled.

### 3. Install the Eluna script

Copy:

```text
lua/auto_sell_grey.lua
```

to your server's Eluna script directory, for example:

```text
lua_scripts/auto_sell_grey.lua
```

### 4. Rebuild and restart

Rebuild `worldserver` after applying the C++ patch, then restart the server.

## Player commands

```text
.autosell
.autosell on
.autosell off
.autosell now
```

`autosell now` only scans the character's backpack and equipped bag contents. It does not sell equipped gear, bank contents, or equipped bags.

## Behavior notes

Auto Sell becomes available at level 6. When a character reaches level 6, the Lua script enables it and explains the available commands. Existing characters at or above level 6 receive a settings row when they log in; an existing explicit ON/OFF choice is preserved.

The automatic corpse-loot path is handled in C++ so an eligible grey item does not need a free inventory slot before it can be converted into money.


## Credits

- [AzerothCore](https://github.com/azerothcore/azerothcore-wotlk) and its contributors
- Eluna / ElunaLuaEngine contributors
- Developed and packaged by [Souicia](https://github.com/Souicia)

## License

The core patch modifies AzerothCore code derived from GPL-licensed sources. This repository is distributed under the **GNU General Public License v2.0**. See `LICENSE`.
