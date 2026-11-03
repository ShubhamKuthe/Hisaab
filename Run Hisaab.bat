@echo off
title Hisaab
cd /d "%~dp0"
set "EXE=build\windows\x64\runner\Release\hisaab.exe"

if exist "C:\src\flutter\bin\flutter.bat" set "PATH=C:\src\flutter\bin;%PATH%"
where flutter >nul 2>nul || goto :noflutter

if not exist windows (
  echo First run: adding the Windows project files...
  call flutter config --enable-windows-desktop >nul
  call flutter create --platforms=windows,android --project-name hisaab --org com.shubhamkuthe . || goto :fail
)

if exist android powershell -NoProfile -ExecutionPolicy Bypass -File "tools\android-voice.ps1"
rem Rebuild only if the app was never built or the code / logo / icons changed since the last build.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$e = Get-Item -LiteralPath $env:EXE -ErrorAction SilentlyContinue; if (-not $e) { exit 1 }; $src = @('lib','assets','windows\runner','pubspec.yaml') | Where-Object { Test-Path $_ }; if (Get-ChildItem -LiteralPath $src -Recurse -File | Where-Object { $_.LastWriteTime -gt $e.LastWriteTime }) { exit 1 }; exit 0"
if errorlevel 1 (
  echo Building Hisaab - the first build takes a few minutes, later ones are quick...
  call flutter pub get || goto :fail
  call flutter build windows --release || goto :fail
)

rem Start Hisaab and make sure it stays open.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$p = Start-Process -FilePath $env:EXE -PassThru; Start-Sleep -Seconds 6; if ($p.HasExited -and $p.ExitCode -ne 0) { Write-Host ('Hisaab closed straight away. Error code: 0x{0:X8}' -f $p.ExitCode) -ForegroundColor Red; exit 1 }; exit 0"
if errorlevel 1 goto :crashed
exit /b 0

:crashed
echo.
echo Hisaab started but closed by itself. Send a screenshot of this window to Claude.
pause
exit /b 1

:noflutter
echo Flutter is not installed or not on PATH.
echo Install it from https://docs.flutter.dev/get-started/install/windows
pause
exit /b 1

:fail
echo.
echo Something went wrong. Copy the red text above and send it to Claude.
pause
exit /b 1
