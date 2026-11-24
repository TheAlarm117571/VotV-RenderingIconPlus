# RenderingIconPlus

**Stops VotV from rendering every item icon again each time your mod list changes.**

> **Is this for you?** Only if you install, remove or update mods often. If your mod list rarely changes, the game's own icon cache already does the job and this mod gains you nothing.
>
> **This is not a performance mod.** It does not raise FPS or optimize anything. It only keeps the game's icons separate from the modded ones, so a mod change no longer makes the game render its own icons again.

## Why

VotV keeps a cache of its item icons, but it only checks *how many* items there are. Install, remove or update a single mod and that number changes, so the game renders every icon again, its own included.

RenderingIconPlus keeps the game's own icons in a separate cache, so a mod change only renders the items that come from mods.

## What changes

| Situation | Game alone | With RenderingIconPlus |
| --- | --- | --- |
| Start, no mod changes | Loads all icons from its cache | Loads the game icons from cache and renders the modded ones. With **Cache modded icons** on, the modded ones load from cache too. |
| Mod installed, removed or updated | Renders **every** icon again | Renders **only** the modded icons |

## Features

* Game item icons are rendered once, then always loaded from the cache.
* Optional setting **Cache modded icons** (off by default, in ModMenu): also saves the icons of modded items, so they are not rendered again on every start.
* Items are checked by their model, so a mod that changes a model gets that icon rendered again.
* Short hints on the main menu show how many icons were loaded and rendered, with game and modded icons listed separately.
* Works on VotV 0.9 and 0.10 with the same files; it detects the game version itself.
* On a VotV version it does not support yet, it shows a warning and changes nothing.

## First start

The first start renders every icon once to fill the cache, the same wait as the game after a mod change. After that, only the modded icons are rendered. With **Cache modded icons** on, only new or changed modded icons are rendered.

## Clearing the cache

The cache is the `RenderingIconPlusCache` folder in `VotV\Binaries\Win64`. Delete it and it is rebuilt on the next start. Uninstalling the mod leaves this folder behind.

## Repository

* `mod/scripts/main.lua` is the whole UE4SS Lua mod, for VotV 0.9 and 0.10.
* `unreal/Content/Mods/RenderingIconPlus` holds the uncooked Unreal Engine 4.27 assets that make `RenderingIconPlus.pak`: the ModMenu entry (`manifest`), the Config Menu entry (`ConfigMenuEntry`) and the icon.
* `manifest.json`, `CHANGELOG.md` and `icon.png` are the Thunderstore package files.

To build the pak, copy the `RenderingIconPlus` assets folder into `Content/Mods` of a UE 4.27 project, cook for Windows and pack the cooked files with UnrealPak to `VotV/Content/Mods/RenderingIconPlus`. `ConfigMenuEntry` needs Config Menu's base class in the project; without Config Menu, leave that asset out.

## Credits

Inspired by [QuickLoadMod](https://thunderstore.io/c/voices-of-the-void/p/deezhizyu/QuickLoadMod/) by deezhizyu.

## Why this mod exists

Every time a mod is installed, removed or updated, the game renders all of its icons again. For me that takes 3 to 5 minutes each time. Once is fine, but it adds up fast, especially when you are making a mod and updating it all day.

## AI disclosure

This mod was made with help from AI (Claude). It was tested in game on VotV 0.9 and 0.10.
