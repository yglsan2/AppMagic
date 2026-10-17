# Pointe Flutter + l'environnement utilisateur vers le SDK sur D:
# et force JDK 25+ (pas de Java 17).

$ErrorActionPreference = "Stop"
$sdk = "D:\Android\Sdk"
$jdk25 = "C:\Program Files\Microsoft\jdk-25.0.4.101-hotspot"
if (-not (Test-Path "$jdk25\bin\java.exe")) {
  $jdk25 = "D:\Users\Super\Tools\jdk-25.0.4.1+1"
}
if (-not (Test-Path "$jdk25\bin\java.exe")) {
  Write-Error "JDK 25+ requis. Installé: winget install Microsoft.OpenJDK.25"
  exit 1
}
if (-not (Test-Path "$sdk\platform-tools")) {
  Write-Error "SDK introuvable dans $sdk. Installez d'abord les packages sdkmanager."
  exit 1
}

[Environment]::SetEnvironmentVariable("ANDROID_HOME", $sdk, "User")
[Environment]::SetEnvironmentVariable("ANDROID_SDK_ROOT", $sdk, "User")
[Environment]::SetEnvironmentVariable("JAVA_HOME", $jdk25, "User")
$env:ANDROID_HOME = $sdk
$env:ANDROID_SDK_ROOT = $sdk
$env:JAVA_HOME = $jdk25

flutter config --android-sdk $sdk

$proj = Split-Path $PSScriptRoot -Parent
$flutterSdk = "C:\src\flutter"
if (-not (Test-Path $flutterSdk)) { $flutterSdk = "D:\src\flutter" }

@"
sdk.dir=D:\\Android\\Sdk
flutter.sdk=$($flutterSdk -replace '\\','\\')
"@ | Set-Content -Path "$proj\android\local.properties" -Encoding UTF8

# Gradle → JDK 25
$gp = Join-Path $proj "android\gradle.properties"
$line = "org.gradle.java.home=$($jdk25 -replace '\\','\\\\')"
if (Test-Path $gp) {
  $txt = Get-Content $gp -Raw
  if ($txt -match 'org\.gradle\.java\.home=') {
    $txt = $txt -replace 'org\.gradle\.java\.home=.*', $line
  } else {
    $txt = $txt.TrimEnd() + "`n$line`n"
  }
  Set-Content $gp $txt -Encoding UTF8
}

Write-Host "OK — ANDROID_HOME=$sdk"
Write-Host "OK — JAVA_HOME=$jdk25"
& "$jdk25\bin\java.exe" -version
flutter doctor 2>&1 | Select-String -Pattern "Android toolchain"
