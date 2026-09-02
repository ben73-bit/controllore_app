<#
.SYNOPSIS
  Script di avvio rapido per ControllOre.
  Uso: .\run.ps1          -> Android Emulator (default)
       .\run.ps1 web      -> Chrome
       .\run.ps1 windows  -> Windows Desktop
       .\run.ps1 edge     -> Microsoft Edge
#>
param([string]$Target = "emulator-5554")

switch ($Target.ToLower()) {
    "web"     { $device = "chrome" }
    "chrome"  { $device = "chrome" }
    "edge"    { $device = "edge" }
    "windows" { $device = "windows" }
    default   { $device = "emulator-5554" }
}

Write-Host "▶  flutter run -d $device" -ForegroundColor Cyan
flutter run -d $device
