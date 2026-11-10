# SD_Heli — Flyable Helicopter for SurrounDead

Adds a flyable helicopter to **SurrounDead**. The helicopter appears in the world, you can climb in and fly it anywhere, and it stays where you parked it between play sessions. It is not made for multiplayer and has not been tested there. 

## Features

- A flyable helicopter that you can enter, fly, land and leave.
- **It stays where you park it.** Its location is saved and restored when you restart the game.
- Doesn't change any game files. Remove the mod at any time by deleting one file.

## Requirements

- **SurrounDead** (Steam, UE 5.6 build)
- **[UE4SS experimental build](https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/experimental-latest)**
  > ⚠️ The stable UE4SS v3.0.1 does **not** work with SurrounDead (it fails with "PS scan timed out"). Use the experimental build.
  - UE4SS includes **BPModLoaderMod**, which loads this mod. It's on by default.

## Installation

1. **Install UE4SS (experimental):** extract it into
   `...\steamapps\common\SurrounDead\SurrounDead\Binaries\Win64\`
   so that `dwmapi.dll` and the `ue4ss` folder sit next to the game exe (SurrounDead-Win64-Shipping.exe).
2. **Download `SD_Heli.pak`** from the [Releases](../../releases) page.
3. **Copy it to**
   `...\steamapps\common\SurrounDead\SurrounDead\Content\Paks\LogicMods\`
   (create the `LogicMods` folder if it doesn't exist).
4. Start the game and load your save.

## Finding the helicopter

On first use, the helicopter spawns on the helipad at the airfield **X = -108050, Y = 44242**. It appears once you're within about 150 m of that spot.

After that, it appears wherever you last left it.

To fly it you approach it, press "F" to enter and then "Left shift" to start the engine and lift off. When you land press "O" to stop the engine and "F" to exit. You can not exit with the engine running (safety first!). 

## Controls

| Action | Key |
|---|---|
| Enter / exit helicopter | **F** |
| Climb / descend | **Left Shift** / **Left Ctrl** |
| Forward / back | **W** / **S** |
| Left / right | **A** / **D** |
| Turn in place | **Q** / **E** |
| Shut down engine | **O** |

Releasing the keys will make it auto-correct to upright. 

It does not take fuel and does not take damage. It has no weapons. 

It does not have storage (yet).

You must be on the ground (or a roof) to shut down the engine and get out. 

## Saved position

The helicopter's position is stored in its own file. It's separate from the game's saves:

```
%LOCALAPPDATA%\SurrounDead\Saved\SaveGames\SD_Heli_Save.sav
```

- To **reset the helicopter** to its starting spot, close the game and delete that file.
- This file is shared by all game saves. Loading an older save does not move the helicopter back.

## Uninstall

Delete `Content\Paks\LogicMods\SD_Heli.pak`, and optionally `SD_Heli_Save.sav` (above).

## Troubleshooting

- **The helicopter doesn't appear:** make sure UE4SS is the *experimental* build, and check `Binaries\Win64\ue4ss\UE4SS.log` for a line like `[BPModLoaderMod] Loading mod: SD_Heli`.
- **The game crashes on start:** remove the `ue4ss` folder and `dwmapi.dll` to confirm whether UE4SS is the cause, then re-download the latest experimental build.
- **It's stuck somewhere bad:** reset it by deleting the save file (see above).

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
| `Content/Mods/SD_Heli/ModActor` | Spawned by BPModLoaderMod on map load. Loads the saved position, spawns `BP_Heli` when the player is in range, and saves its position every 15 s |
| `Content/Mods/SD_Heli/SG_HeliSave` | SaveGame class (`HeliTransform`, `bHasSaved`, `MapName`) |
| `Content/CustomMods/Vehicles/NewsHeli/Blueprints/BP_Heli` | The helicopter (a Chaos `WheeledVehiclePawn` with thrusters) |
| `Content/CustomMods/Vehicles/NewsHeli/Inputs/` | Enhanced Input actions and mapping contexts |
| `BuildModPak.ps1` | Cooks, packs `SD_Heli.pak` and installs it into the game |
| `Tools/ue4ss/SD_Heli/Scripts/main.lua` | Optional UE4SS dev helper: press F8 for player location and spawn diagnostics |

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

The code, Blueprints and other files in this repository are released under the [MIT License](LICENSE).

Third-party content (the helicopter mesh, which comes from SurrounDead; the rotor sound; and the PolygonApocalypse material and texture) is **not** covered by this license and is not included in this repository. The release `.pak` contains cooked versions of these assets solely so the mod works in game.

## Disclaimer

This is an unofficial fan mod. It is not affiliated with or endorsed by the developers of SurrounDead. Use it at your own risk, and back up your saves.
