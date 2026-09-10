@echo off
setlocal
set "GAME_EXE=%~dp0build\Artefakt Imperium.exe"

if not exist "%GAME_EXE%" (
    echo Die Spiel-EXE wurde nicht gefunden:
    echo %GAME_EXE%
    echo.
    echo Bitte den Windows-Export erneut erstellen.
    pause
    exit /b 1
)

start "Artefakt Imperium" /D "%~dp0build" "%GAME_EXE%"
