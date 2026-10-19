@echo off
setlocal
cd /d "%~dp0"
if errorlevel 1 (
  echo Could not open the Pokemon Arena folder.
  pause
  exit /b 1
)
set "POKEMON_GODOT=%USERPROFILE%\Downloads\Godot_v4.3-stable_win64.exe\Godot_v4.3-stable_win64.exe"
if not exist "%POKEMON_GODOT%" (
  echo Godot was not found at: %POKEMON_GODOT%
  pause
  exit /b 1
)
rem A relative path avoids a trailing backslash escaping the closing quote.
start "Pokemon Arena" "%POKEMON_GODOT%" --path . --log-file arena-launch.log
if errorlevel 1 (
  echo Pokemon Arena could not start. See arena-launch.log for details.
  pause
  exit /b 1
)

