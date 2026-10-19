param(
    [string]$EnginePath = 'E:/GameDev/Engines/Godot/4.7.2-dot/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe',
    [string]$AndroidSdkPath = "$env:LOCALAPPDATA/Android/Sdk",
    [string]$JavaSdkPath = 'E:/Java/jdk-21',
    [switch]$CheckOnly
)
$ErrorActionPreference = 'Stop'
$projectPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$missing = [Collections.Generic.List[string]]::new()
if (-not (Test-Path -LiteralPath $EnginePath -PathType Leaf)) { $missing.Add("Godot executable: $EnginePath") }
if (-not (Test-Path -LiteralPath (Join-Path $JavaSdkPath 'bin/java.exe'))) { $missing.Add("JDK: $JavaSdkPath") }
if (-not (Test-Path -LiteralPath (Join-Path $AndroidSdkPath 'platform-tools/adb.exe'))) { $missing.Add("Android SDK platform-tools: $AndroidSdkPath") }
if (-not (Test-Path -LiteralPath (Join-Path $AndroidSdkPath 'build-tools/36.0.0/apksigner.bat'))) { $missing.Add("Android SDK Build Tools 36.0.0: $AndroidSdkPath") }
if (-not (Test-Path -LiteralPath (Join-Path $AndroidSdkPath 'platforms/android-36/android.jar'))) { $missing.Add("Android SDK Platform 36: $AndroidSdkPath") }
$templatePath = Join-Path $env:APPDATA 'Godot/export_templates/4.7.2.stable/android_debug.apk'
if (-not (Test-Path -LiteralPath $templatePath)) { $missing.Add("Matching Android export template: $templatePath") }
if ($missing.Count -gt 0) {
    foreach ($item in $missing) { Write-Output "MISSING: $item" }
    Write-Output 'Install the Android SDK and matching Godot Android templates; configure Editor Settings > Export > Android with the SDK and JDK paths.'
    exit 1
}
Write-Output 'Android build prerequisites found. Godot will validate SDK build-tools and debug signing during export.'
if ($CheckOnly) { exit 0 }
# The editor owns SDK/JDK settings; do not overwrite the user-wide editor configuration.
$outputPath = Join-Path $projectPath 'builds/android/LittleSwordSpirit-debug.apk'
New-Item -ItemType Directory -Path (Split-Path -Parent $outputPath) -Force | Out-Null
& $EnginePath --headless --path $projectPath --export-debug Android $outputPath
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) { throw 'Godot did not produce the APK.' }
$manifest = & (Join-Path $AndroidSdkPath 'build-tools/36.0.0/aapt.exe') dump xmltree $outputPath AndroidManifest.xml
if ($LASTEXITCODE -ne 0) { throw 'Could not read exported Android manifest.' }
# Godot 4.7.2 exports SCREEN_SENSOR_LANDSCAPE (4) as Android userLandscape (11).
if (-not ($manifest -match 'android:screenOrientation.*0xb\s*$')) { throw 'Exported APK is not restricted to landscape.' }
Write-Output 'Verified APK orientation: userLandscape (landscape only).'
Write-Output "APK: $outputPath"
