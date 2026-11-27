# Build the WARAQ Android debug APK from the web app.
# The copy to C:\waraq-build avoids Gradle issues with non-ASCII user paths.
param([switch]$SkipSync)

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$BuildRoot = 'C:\waraq-build'
$BuildProject = Join-Path $BuildRoot 'project'
$Sdk = Join-Path $BuildRoot 'AndroidSdk'
$Jdk = Join-Path $BuildRoot 'jdk-21'
if (-not (Test-Path $Jdk)) { $Jdk = 'C:\Program Files\Microsoft\jdk-21.0.13.102-hotspot' }
$NodeDir = 'C:\Program Files\nodejs'

foreach ($p in @($Sdk, $Jdk, (Join-Path $NodeDir 'node.exe'))) {
  if (-not (Test-Path $p)) { throw "Missing build dependency: $p" }
}

Set-Location $Root
$env:Path = $NodeDir + ';' + (Join-Path $Jdk 'bin') + ';' + $env:Path

if (-not $SkipSync) {
  & (Join-Path $NodeDir 'npm.cmd') run build:web
  & (Join-Path $NodeDir 'node.exe') 'node_modules/@capacitor/cli/bin/capacitor' sync android
}

if (Test-Path $BuildProject) { & cmd /c rmdir /s /q "`"$BuildProject`"" | Out-Null }
New-Item -ItemType Directory -Force -Path $BuildProject | Out-Null
Copy-Item -Recurse -Force (Join-Path $Root 'android') -Destination $BuildProject
Copy-Item -Recurse -Force (Join-Path $Root 'www') -Destination $BuildProject
Copy-Item -Force (Join-Path $Root 'capacitor.config.json') -Destination $BuildProject

$capModule = Join-Path $Root 'node_modules\@capacitor\android\capacitor'
$capDest = Join-Path $BuildProject 'node_modules\@capacitor\android\capacitor'
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $capDest) | Out-Null
Copy-Item -Recurse -Force $capModule -Destination $capDest

Set-Content -Path (Join-Path $BuildProject 'android\local.properties') -Encoding ascii -Value 'sdk.dir=C\:\\waraq-build\\AndroidSdk'

$env:ANDROID_HOME = $Sdk
$env:ANDROID_SDK_ROOT = $Sdk
$env:JAVA_HOME = $Jdk
$env:Path = (Join-Path $Jdk 'bin') + ';' + $env:Path

Set-Location (Join-Path $BuildProject 'android')
& .\gradlew.bat assembleDebug --no-daemon
if ($LASTEXITCODE -ne 0) { throw "Gradle build failed with exit code $LASTEXITCODE" }

$apk = Join-Path $BuildProject 'android\app\build\outputs\apk\debug\app-debug.apk'
$outDir = Join-Path $Root 'apk'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$out = Join-Path $outDir 'WARAQ-debug.apk'
Copy-Item -Force $apk $out
Write-Host "APK ready: $out"
