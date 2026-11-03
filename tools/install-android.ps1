# Installs what's needed to build the Hisaab Android app (no Android Studio needed):
#   1. Java 17 (Microsoft OpenJDK, via winget)
#   2. Android SDK command-line tools -> %LOCALAPPDATA%\Android\Sdk
#   3. platform-tools, Android platform, build-tools; accepts the licences
#   4. Tells Flutter where the SDK is
# Safe to run again: it skips anything already installed.

$ErrorActionPreference = 'Stop'
$Sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'

function Say($m, $c = 'White') { Write-Host $m -ForegroundColor $c }
function Step($m) { Write-Host ''; Write-Host "==> $m" -ForegroundColor Cyan }
function RefreshPath {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
}
function FindJdk {
    $roots = @("$env:ProgramFiles\Microsoft", "$env:ProgramFiles\Android\Android Studio", "$env:ProgramFiles\Eclipse Adoptium", "$env:ProgramFiles\Java")
    foreach ($r in $roots) {
        if (-not (Test-Path $r)) { continue }
        $hit = Get-ChildItem $r -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^(jdk-?(1[7-9]|2\d)|jbr)' } |
            Sort-Object Name -Descending | Select-Object -First 1
        if ($hit -and (Test-Path "$($hit.FullName)\bin\java.exe")) { return $hit.FullName }
    }
    return $null
}

try {
    Say 'Hisaab - Android setup' 'Green'
    Say 'This downloads about 1 GB. Keep the PC on and online.'

    # 1. Java 17
    Step 'Java 17'
    $jdk = FindJdk
    if (-not $jdk) {
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            throw 'winget (App Installer) is missing. Install "App Installer" from the Microsoft Store, then run this again.'
        }
        winget install --id Microsoft.OpenJDK.17 -e --source winget --accept-package-agreements --accept-source-agreements
        $jdk = FindJdk
        if (-not $jdk) { throw 'Java did not install.' }
    }
    Say "Java: $jdk"
    $env:JAVA_HOME = $jdk
    [Environment]::SetEnvironmentVariable('JAVA_HOME', $jdk, 'User')
    $env:Path = "$jdk\bin;$env:Path"

    # 2. Command-line tools
    Step "Android SDK -> $Sdk"
    $sdkManager = "$Sdk\cmdline-tools\latest\bin\sdkmanager.bat"
    if (-not (Test-Path $sdkManager)) {
        New-Item -ItemType Directory -Force -Path $Sdk | Out-Null
        $zip = Join-Path $env:TEMP 'android-cmdline-tools.zip'
        $ok = $false
        foreach ($v in @('13114758', '11076708')) {
            try {
                Say "Downloading command-line tools ($v)..."
                Invoke-WebRequest -UseBasicParsing -Uri "https://dl.google.com/android/repository/commandlinetools-win-${v}_latest.zip" -OutFile $zip
                $ok = $true; break
            } catch { Say "  not available, trying another version" 'Yellow' }
        }
        if (-not $ok) { throw 'Could not download the Android command-line tools.' }
        $tmp = Join-Path $env:TEMP 'android-cmdline-tools'
        if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
        Expand-Archive -Path $zip -DestinationPath $tmp -Force
        New-Item -ItemType Directory -Force -Path "$Sdk\cmdline-tools" | Out-Null
        if (Test-Path "$Sdk\cmdline-tools\latest") { Remove-Item "$Sdk\cmdline-tools\latest" -Recurse -Force }
        Move-Item "$tmp\cmdline-tools" "$Sdk\cmdline-tools\latest"
        Remove-Item $zip -Force
    } else {
        Say 'Command-line tools are already there.'
    }

    # 3. SDK parts + licences
    Step 'Android platform, build tools and licences'
    $env:ANDROID_HOME = $Sdk
    $env:ANDROID_SDK_ROOT = $Sdk
    [Environment]::SetEnvironmentVariable('ANDROID_HOME', $Sdk, 'User')
    $yes = (1..30 | ForEach-Object { 'y' }) -join "`n"
    $yes | & $sdkManager --sdk_root=$Sdk --licenses | Out-Null
    & $sdkManager --sdk_root=$Sdk 'platform-tools' 'platforms;android-35' 'build-tools;35.0.0'
    if ($LASTEXITCODE -ne 0) { throw 'Installing Android SDK parts failed.' }

    # 4. Flutter
    Step 'Telling Flutter where the SDK is'
    RefreshPath
    if (Test-Path 'C:\src\flutter\bin\flutter.bat') { $env:Path = "C:\src\flutter\bin;$env:Path" }
    & flutter config --android-sdk $Sdk | Out-Null
    $yes | & flutter doctor --android-licenses | Out-Null
    Say ''
    Say 'Android setup done.' 'Green'
    exit 0
} catch {
    Say ''
    Say "Android setup failed: $($_.Exception.Message)" 'Red'
    exit 1
}
