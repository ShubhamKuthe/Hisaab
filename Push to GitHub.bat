@echo off
title Hisaab - push to GitHub
cd /d "%~dp0"
rem Double-click to save everything to https://github.com/ShubhamKuthe/Hisaab
rem The first time, Git opens a GitHub sign-in window - sign in and it remembers.

set "REPO=https://github.com/ShubhamKuthe/Hisaab.git"

where git >nul 2>nul || (
  echo Git is not installed. Installing it now...
  winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
  set "PATH=%ProgramFiles%\Git\cmd;%PATH%"
)
where git >nul 2>nul || (echo Git could not be installed. Install it from https://git-scm.com and try again. & pause & exit /b 1)

if not exist ".git" (
  echo First time: setting up Git in this folder...
  git init -b main || goto :fail
  git remote add origin %REPO% || goto :fail
) else (
  git remote get-url origin >nul 2>nul || git remote add origin %REPO%
)

rem Who the commits are from (only set for this folder, only if missing).
git config user.name >nul 2>nul || git config user.name "Shubham Kuthe"
git config user.email >nul 2>nul || git config user.email "shubhamkuthe113@gmail.com"

echo.
echo Saving changes...
git add -A || goto :fail
git diff --cached --quiet && (echo Nothing new to save.) || (
  git commit -m "Update Hisaab - %date% %time:~0,5%" || goto :fail
)

rem If GitHub already has commits (e.g. made on another PC), add ours on top.
git fetch origin main >nul 2>nul && git rebase origin/main

echo.
echo Uploading to GitHub...
git push -u origin main || goto :fail

echo.
echo ============================================================
echo  Done! Your code is on GitHub:
echo  https://github.com/ShubhamKuthe/Hisaab
echo ============================================================
start "" "https://github.com/ShubhamKuthe/Hisaab"
pause
exit /b 0

:fail
echo.
echo Something went wrong. Copy the red text above and send it to Claude.
pause
exit /b 1
