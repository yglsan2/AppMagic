# Build APK release Table MTG (cible principale Android)
$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

$jdk25 = "C:\Program Files\Microsoft\jdk-25.0.4.101-hotspot"
if (-not (Test-Path "$jdk25\bin\java.exe")) {
  $jdk25 = "D:\Users\Super\Tools\jdk-25.0.4.1+1"
}
if (-not (Test-Path "$jdk25\bin\java.exe")) {
  Write-Error "JDK 25 introuvable. Installez Microsoft OpenJDK 25+."
  exit 1
}

$env:JAVA_HOME = $jdk25
$env:ANDROID_HOME = "D:\Android\Sdk"
$env:ANDROID_SDK_ROOT = "D:\Android\Sdk"
Write-Host "JAVA_HOME=$env:JAVA_HOME"
& "$env:JAVA_HOME\bin\java.exe" -version

Write-Host "flutter pub get..."
flutter pub get
Write-Host "flutter build apk --release..."
flutter build apk --release
$apk = "build\app\outputs\flutter-apk\app-release.apk"
if (Test-Path $apk) {
  Write-Host "OK → $((Resolve-Path $apk).Path)"
} else {
  Write-Error "APK introuvable. Vérifiez: flutter doctor (Android toolchain)."
}
