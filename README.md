# SD_Heli — Flyable Helicopter for SurrounDead

Adds a flyable helicopter to **SurrounDead**. The helicopter appears in the world, you can climb in and fly it anywhere, and it stays where you parked it between play sessions. It is not made for multiplayer and has not been tested there. Not compatible with SurrounSync co-op: the helicopter only exists for you. Each game save has its own helicopter, so it can be parked in a different place in each game.

## Features

- A flyable helicopter that you can enter, fly, land and leave.
- **It stays where you park it.** Its location is saved and restored when you restart the game.
- **Each save has its own helicopter.** Loading a different save brings back that save's helicopter, where you left it in that save.
- **Storage.** Look at the cabin and the game's prompt offers **Enter Helicopter** and **Open Storage**, like the game's own vehicles. Each save's helicopter has its own storage, saved with the game save.
- **A parked helicopter stays put.** Once you get out and it comes to rest, it's held in place, so it can't drop through the map when you reload a save or when terrain loads in.
- Doesn't change any game files. Remove the mod at any time by deleting its files.

## Requirements

- **SurrounDead** (Steam, UE 5.6 build)
- **[UE4SS experimental build](https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/experimental-latest)**
  > ⚠️ The stable UE4SS v3.0.1 does **not** work with SurrounDead (it fails with "PS scan timed out"). Use the experimental build.
  - UE4SS includes **BPModLoaderMod**, which loads this mod. It's on by default.

## Installation

1. **Install UE4SS (experimental):** extract it into
   `...\steamapps\common\SurrounDead\SurrounDead\Binaries\Win64\`
   so that `dwmapi.dll` and the `ue4ss` folder sit next to the game exe (SurrounDead-Win64-Shipping.exe).
2. **Download `SD_Heli_v1.2.1.zip`** from the [Releases](../../releases) page.
   > ⚠️ Don't use the green **Code → Download ZIP** button. It downloads the source project (`SD_Heli-main.zip`), not the mod.
3. **Extract it into**
   `...\steamapps\common\SurrounDead\SurrounDead\`
   (the folder that contains `Binaries` and `Content`). It installs two things:
   - `Content\Paks\LogicMods\SD_Heli.pak`: the helicopter itself
   - `Binaries\Win64\ue4ss\Mods\SD_Heli\`: small UE4SS scripts (`main.lua`, `storage.lua`, `parking.lua`) that give each save its own helicopter, add the storage and keep a parked helicopter in place. Its `enabled.txt` file turns them on.
4. Start the game and load your save.

> The pak works on its own, but without the scripts every save shares one helicopter (the v1.0.0 behavior) and there's no storage.

**Updating from v1.1.x:** extract the zip over your install and replace the files. Your helicopters stay where you parked them. Each save's storage is created the first time you load it.

**Updating from v1.1.0:** extract the zip over your install and replace the files. Your helicopters stay where you parked them.

**Updating from v1.0.0:** extract the zip over your install and replace `SD_Heli.pak`. Your parked helicopter moves to the first save you load after updating. Your other saves start with the helicopter on the helipad.

## Finding the helicopter

On first use, the helicopter spawns on the helipad at the airfield **X = -108050, Y = 44242**. It appears once you're within about 150 m of that spot.

After that, it appears wherever you last left it.

To fly it you approach it, press "F" to enter and then "Left shift" to start the engine and lift off. When you land press "O" to stop the engine and "F" to exit. You can not exit with the engine running (safety first!). 

## Controls

| Action | Key |
|---|---|
| Enter / exit helicopter | **F** |
| Enter helicopter / open storage | look at the cabin: the game's prompt shows both options |
| Climb / descend | **Left Shift** / **Left Ctrl** |
| Forward / back | **W** / **S** |
| Left / right | **A** / **D** |
| Turn in place | **Q** / **E** |
| Shut down engine | **O** |

Releasing the keys will make it auto-correct to upright. 

It does not take fuel and does not take damage. It has no weapons. 

## Storage

Look at the helicopter's cabin from outside and the game's interact prompt offers **Enter Helicopter** and **Open Storage**. Storage opens the same window as the utility truck's.

- Each save's helicopter has its own storage. It's an invisible storage crate attached to the cabin, so **its contents are saved with the game save**: save the game to keep them, like any other storage.
- The crate is created the first time you load a save with the helicopter. `<SaveName>_SDHeli_Storage.txt` (next to the helicopter file below) helps the script find it again.
- The storage moves with the helicopter.

You must be on the ground (or a roof) to shut down the engine and get out. 

## Saved position

Each game save gets its own helicopter file, next to the game's own save files:

```
%LOCALAPPDATA%\SurrounDead\Saved\SaveGames\<SaveName>_SDHeli.sav
```

- The helicopter's position is saved while you're near it, so it's kept even if you quit without saving the game.
- To **reset a save's helicopter** to the helipad, close the game and delete that save's `_SDHeli.sav` file. Its storage stays in the game save and attaches to the helicopter again on the helipad.
- A save with no `_SDHeli.sav` yet starts with the helicopter on the helipad.
- Without the UE4SS script, the mod uses a single shared file, `SD_Heli_Save.sav`, as in v1.0.0.

## Uninstall

Delete `Content\Paks\LogicMods\SD_Heli.pak` and the `Binaries\Win64\ue4ss\Mods\SD_Heli` folder. Optionally delete the `*_SDHeli.sav` and `*_SDHeli_Storage.txt` files (above).

> **Empty the helicopter's storage first.** The storage crate is part of your game save. Without the mod it shows up as a large, stretched storage crate where the helicopter was parked. Your items are still in it, and you can empty or dismantle it like any crate.

## Troubleshooting

- **The helicopter doesn't appear:** make sure UE4SS is the *experimental* build, and check `Binaries\Win64\ue4ss\UE4SS.log` for a line like `[BPModLoaderMod] Loading mod: SD_Heli`.
- **The game crashes on start:** remove the `ue4ss` folder and `dwmapi.dll` to confirm whether UE4SS is the cause, then re-download the latest experimental build.
- **It's stuck somewhere bad, or it fell under the map:** reset it by deleting that save's `_SDHeli.sav` file (see above).
- **No "Open Storage" prompt:** check that `UE4SS.log` shows `[SD_Heli] storage: helicopter storage ready for <your save>`. The storage needs the scripts from the zip, not just the pak.
- **A large crate appears in the world:** that's a helicopter storage crate without the scripts running (for example after uninstalling). Install the scripts again, or empty and dismantle it.
- **Every save shares one helicopter:** the UE4SS script isn't running. Check that `ue4ss\Mods\SD_Heli\enabled.txt` exists and that `UE4SS.log` shows `[SD_Heli] per-save helicopters enabled`.

## Building from source

This repo contains the Unreal Engine project for the mod: Blueprints, input assets, config, the build script and a debug script.

**Requirements:** Unreal Engine **5.6** (it must match the game's engine version; paks cooked with another version won't load).

### Assets not included

These files are third-party content and are **not** in this repo. The project won't cook without them, so you must supply your own replacements at the same paths:

| Path (under `Content/CustomMods/Vehicles/NewsHeli/`) | What it is |
|---|---|
| `Assets/HeliUndentedRigged` (+ `_Skeleton`, `_PhysicsAsset`) | Rigged helicopter skeletal mesh. It needs a main rotor bone named `b_MainRotor`. |
| `Audio/helicopter-hovering-01`, `Audio/MS_HeliEngine` | Rotor/engine sound and the MetaSound that plays it |
| `Materials/Mat_PolygonApocalypse_01_A`, `Textures/T_PolygonApocalypse_01_A` | Helicopter material and texture |

If an asset's name or skeleton differs, re-point the references in `BP_Heli` and `ABP_Heli`.

### Project layout

| Path | Purpose |
|---|---|
| `Content/Mods/SD_Heli/ModActor` | Spawned by BPModLoaderMod on map load. Loads the saved position for the current save (custom event `SDHeli_LoadForSave`), spawns `BP_Heli` when the player is in range, and saves its position only while the player is near it |
| `Content/Mods/SD_Heli/SG_HeliSave` | SaveGame class (`HeliTransform`, `bHasSaved`, `MapName`) |
| `Content/CustomMods/Vehicles/NewsHeli/Blueprints/BP_Heli` | The helicopter (a Chaos `WheeledVehiclePawn` with thrusters) |
| `Content/CustomMods/Vehicles/NewsHeli/Inputs/` | Enhanced Input actions and mapping contexts |
| `BuildModPak.ps1` | Cooks, packs `SD_Heli.pak` and installs it into the game |
| `Tools/ue4ss/SD_Heli/Scripts/main.lua` | UE4SS companion script, shipped in the release zip. Reads the loaded save's name, tells ModActor which `<SaveName>_SDHeli` slot to use, and loads the two scripts below |
| `Tools/ue4ss/SD_Heli/Scripts/storage.lua` | Shipped. The storage: an invisible `Buildable_StorageCrate` stretched over the cabin and attached to the helicopter, with the truck's storage window and an "Enter Helicopter / Open Storage" prompt. Also stops `BP_HeliEntry`'s range sphere from blocking traces |
| `Tools/ue4ss/SD_Heli/Scripts/parking.lua` | Shipped. Switches off a parked helicopter's physics (SurrounDead reloads a save without loading a new map, so a simulating helicopter can drop through the rebuilt ground) and removes a helicopter left over from a previously loaded save |
| `Tools/ue4ss/SD_Heli/Scripts/dev_helper.lua` | Optional dev helper, not shipped: F8 player location and spawn diagnostics, F7/F6 place and show the storage box, F2 collision dump. `main.lua` loads it if it's present |

### Build

1. Open `SD_Helicopter.uproject` in UE 5.6, add the missing assets, then compile and **Save All**.
2. Check the paths at the top of `BuildModPak.ps1` (engine install and game folder).
3. Run:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\BuildModPak.ps1
   ```
   Options: `-SkipCook` (repack without cooking) and `-NoInstall` (don't copy to the game).

The pak must be named `SD_Heli.pak`, and the mod actor must live at `/Game/Mods/SD_Heli/ModActor`, or BPModLoaderMod won't find it.

## License

The code, Blueprints and other files in this repository are released under the "Unlicense" version of Github's licensing.

Third-party content (the helicopter mesh, which comes from SurrounDead; the rotor sound; and the PolygonApocalypse material and texture) is **not** covered by this license and is not included in this repository. The release `.pak` contains cooked versions of these assets solely so the mod works in game.

## Disclaimer

This is an unofficial fan mod. It is not affiliated with or endorsed by the developers of SurrounDead. Use it at your own risk, and back up your saves.
