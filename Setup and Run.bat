@echo off
title Hisaab - setup and run
cd /d "%~dp0"
rem Full fresh build (release mode, same as Run Hisaab.bat), then start the app.
if exist "C:\src\flutter\bin\flutter.bat" set "PATH=C:\src\flutter\bin;%PATH%"
where flutter >nul 2>nul || (echo Flutter is not installed or not on PATH. & pause & exit /b 1)
if not exist windows (
  echo First run: adding Windows and Android project files...
  call flutter create --platforms=windows,android --project-name hisaab --org com.shubhamkuthe .
)
if exist "build\windows\x64\runner\Release\hisaab.exe" del /q "build\windows\x64\runner\Release\hisaab.exe"
call "%~dp0Run Hisaab.bat"
