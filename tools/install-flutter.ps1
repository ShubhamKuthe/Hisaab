# Installs everything needed to build Hisaab on Windows:
#   1. Git            (via winget, if missing)
#   2. Flutter SDK    (stable, into C:\src\flutter) + adds it to your PATH
#   3. Visual Studio Build Tools with C++ (needed for Windows apps; asks for admin)
#   4. Reminds you to turn on Developer Mode (needed by Flutter plugins)
# Safe to run again: it skips anything already installed.

$ErrorActionPreference = 'Stop'
$FlutterDir = 'C:\src\flutter'

function Say($m, $c = 'White') { Write-Host $m -ForegroundColor $c }
function Step($m) { Write-Host ''; Write-Host "==> $m" -ForegroundColor Cyan }
function RefreshPath {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
}
function Finish($code) { Write-Host ''; Read-Host 'Press Enter to close'; exit $code }

try {
    Say 'Hisaab - Flutter setup' 'Green'
    Say 'This downloads a few GB (Flutter + C++ build tools). Keep the PC on and online.'

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Say 'winget (App Installer) is missing. Install "App Installer" from the Microsoft Store, then run this again.' 'Red'
        Finish 1
    }

    # 1. Git
    Step 'Git'
    if (Get-Command git -ErrorAction SilentlyContinue) {
        Say 'Git is already installed.'
    } else {
        winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
        RefreshPath
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'Git did not install.' }
    }

    # 2. Flutter SDK
    Step "Flutter SDK -> $FlutterDir"
    if (Test-Path "$FlutterDir\bin\flutter.bat") {
        Say 'Flutter is already there. Updating to the latest stable...'
        git -C $FlutterDir pull --ff-only
    } else {
        New-Item -ItemType Directory -Force -Path (Split-Path $FlutterDir) | Out-Null
        git clone https://github.com/flutter/flutter.git -b stable $FlutterDir
        if ($LASTEXITCODE -ne 0) { throw 'Downloading Flutter failed.' }
    }

    $bin = "$FlutterDir\bin"
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (($userPath -split ';') -notcontains $bin) {
        [Environment]::SetEnvironmentVariable('Path', ($userPath.TrimEnd(';') + ";$bin"), 'User')
        Say "Added $bin to your PATH."
    }
    RefreshPath

    # 3. Visual Studio C++ build tools
    Step 'Visual Studio C++ build tools (for Windows apps)'
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    $hasCpp = $false
    if (Test-Path $vswhere) {
        $found = & $vswhere -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
        $hasCpp = [bool]$found
    }
    if ($hasCpp) {
        Say 'C++ build tools are already installed.'
    } else {
        Say 'Installing (a Windows admin prompt will appear - click Yes). This can take 20-40 minutes...' 'Yellow'
        winget install --id Microsoft.VisualStudio.2022.BuildTools -e --source winget `
            --accept-package-agreements --accept-source-agreements `
            --override '--passive --wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended'
    }

    # 4. Flutter first run
    Step 'Preparing Flutter for Windows apps'
    & "$bin\flutter.bat" config --no-analytics --enable-windows-desktop
    & "$bin\flutter.bat" precache --windows
    & "$bin\flutter.bat" doctor

    # 5. Developer Mode (Flutter plugins need it; this is your choice in Windows Settings)
    Step 'One last thing: Developer Mode'
    Say 'Windows Settings will open. Turn ON "Developer Mode", then close Settings.' 'Yellow'
    Start-Process 'ms-settings:developers'

    Write-Host ''
    Say 'All done! Now double-click "Run Hisaab.bat".' 'Green'
    Finish 0
} catch {
    Say "Setup stopped: $($_.Exception.Message)" 'Red'
    Say 'Copy the red text above and send it to Claude.' 'Yellow'
    Finish 1
}
