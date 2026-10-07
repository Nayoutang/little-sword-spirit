param(
    [switch]$Offline,
    [switch]$Continuous,
    [switch]$Multi,
    [string]$EnginePath = 'E:/GameDev/Engines/Godot/4.7.2-dot/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path -LiteralPath $EnginePath -PathType Leaf)) { throw 'Godot engine not found; pass -EnginePath with the executable path.' }
$launchArgs = @('--path',$projectRoot,'--script','res://tools/shield_playtest.gd','--','--cooperation-sim')
if ($Offline) { $launchArgs += '--offline-companion' }
if ($Continuous) { $launchArgs += '--playtest-continuous' }
if ($Multi) { $launchArgs += '--playtest-multi' }
& $EnginePath @launchArgs
