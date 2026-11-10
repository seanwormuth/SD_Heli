# Cooks the SD_Helicopter mod content and packs it as SD_Heli.pak for SurrounDead (UE4SS BPModLoader).
# Usage:  powershell -ExecutionPolicy Bypass -File .\BuildModPak.ps1 [-SkipCook] [-NoInstall]
# Save All in the editor first: the cook reads assets from disk.

param(
    [switch]$SkipCook,
    [switch]$NoInstall
)

$ErrorActionPreference = 'Stop'

$Engine      = 'C:\Program Files\Epic Games\UE_5.6\Engine'
$Project     = Join-Path $PSScriptRoot 'SD_Helicopter.uproject'
$CookedRoot  = Join-Path $PSScriptRoot 'Saved\Cooked\Windows\SD_Helicopter\Content'
$OutDir      = Join-Path $PSScriptRoot 'Saved\ModPak'
$PakName     = 'SD_Heli.pak'                      # must match /Game/Mods/SD_Heli/ModActor
$MountPrefix = '../../../SurrounDead/Content/'    # the game's project name, not ours
$ModFolders  = @('Mods\SD_Heli', 'CustomMods')    # only these go in the pak
$GamePaks    = 'C:\Program Files (x86)\Steam\steamapps\common\SurrounDead\SurrounDead\Content\Paks\LogicMods'

if (-not $SkipCook) {
    Write-Host '== Cooking for Windows (this can take several minutes the first time)...'
    & "$Engine\Binaries\Win64\UnrealEditor-Cmd.exe" $Project -run=cook -targetplatform=Windows -unversioned -unattended -nop4 -nosplash -NoLogTimes -stdout -abslog="$PSScriptRoot\Saved\Logs\ModCook.log"
    if ($LASTEXITCODE -ne 0) { throw "Cook failed (exit $LASTEXITCODE). See Saved\Logs\ModCook.log" }
}

New-Item -ItemType Directory -Force $OutDir | Out-Null
$resp = Join-Path $OutDir 'filelist.txt'
$lines = foreach ($f in $ModFolders) {
    $dir = Join-Path $CookedRoot $f
    if (-not (Test-Path $dir)) { throw "Cooked folder missing: $dir" }
    Get-ChildItem $dir -Recurse -File | ForEach-Object {
        $rel = $_.FullName.Substring($CookedRoot.Length + 1).Replace('\', '/')
        '"{0}" "{1}{2}"' -f $_.FullName, $MountPrefix, $rel
    }
}
if (-not (Get-ChildItem (Join-Path $CookedRoot 'Mods\SD_Heli') -Filter 'ModActor.uasset')) { throw 'ModActor was not cooked' }
Set-Content -Path $resp -Value $lines -Encoding ascii
Write-Host "== Packing $($lines.Count) files"

$pak = Join-Path $OutDir $PakName
& "$Engine\Binaries\Win64\UnrealPak.exe" $pak "-create=$resp"
if ($LASTEXITCODE -ne 0) { throw "UnrealPak failed (exit $LASTEXITCODE)" }

if (-not $NoInstall) {
    New-Item -ItemType Directory -Force $GamePaks | Out-Null
    Copy-Item $pak $GamePaks -Force
    Write-Host "== Installed to $GamePaks\$PakName"
}
Write-Host "== Done: $pak ($([math]::Round((Get-Item $pak).Length / 1KB)) KB)"
