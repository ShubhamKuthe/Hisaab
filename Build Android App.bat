@echo off
title Hisaab - build the Android app
cd /d "%~dp0"
rem Builds Hisaab.apk (the phone app) into this folder.
rem First time: installs Java + the Android SDK by itself (about 1 GB).

if exist "C:\src\flutter\bin\flutter.bat" set "PATH=C:\src\flutter\bin;%PATH%"
where flutter >nul 2>nul || (echo Flutter is not installed. Run "Install Flutter.bat" first. & pause & exit /b 1)

if not exist android (
  echo Adding the Android project files...
  call flutter create --platforms=android --project-name hisaab --org com.shubhamkuthe . || goto :fail
)
powershell -NoProfile -ExecutionPolicy Bypass -File "tools\android-voice.ps1"

rem Android SDK missing? Install it (Java 17 + command-line tools).
set "SDK=%LOCALAPPDATA%\Android\Sdk"
if defined ANDROID_HOME set "SDK=%ANDROID_HOME%"
if not exist "%SDK%\platform-tools\adb.exe" (
  echo.
  echo The Android SDK is not installed yet. Installing it now - this takes a while...
  powershell -NoProfile -ExecutionPolicy Bypass -File "tools\install-android.ps1" || goto :fail
  set "SDK=%LOCALAPPDATA%\Android\Sdk"
)
set "ANDROID_HOME=%SDK%"
for /f "usebackq tokens=*" %%j in (`powershell -NoProfile -Command "[Environment]::GetEnvironmentVariable('JAVA_HOME','User')"`) do if not "%%j"=="" set "JAVA_HOME=%%j"
if defined JAVA_HOME set "PATH=%JAVA_HOME%\bin;%PATH%"

echo.
echo Building the Android app - the first build downloads Gradle and takes 5-15 minutes...
call flutter pub get || goto :fail
call flutter build apk --release || goto :fail

copy /y "build\app\outputs\flutter-apk\app-release.apk" "Hisaab.apk" >nul || goto :fail
echo.
echo ============================================================
echo  Done!  Hisaab.apk is in this folder.
echo.
echo  To put it on a phone:
echo   1. Send Hisaab.apk to the phone (WhatsApp to yourself,
echo      Google Drive, or a USB cable).
echo   2. Tap it on the phone and press Install.
echo      If asked, allow "Install unknown apps" for that app.
echo ============================================================
explorer /select,"%~dp0Hisaab.apk"
pause
exit /b 0

:fail
echo.
echo Something went wrong. Copy the red text above and send it to Claude.
pause
exit /b 1
