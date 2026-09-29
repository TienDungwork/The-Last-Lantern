@echo off
rem Bấm đúp để chơi thử bản Godot. Mở editor: play.bat editor
if /i "%1"=="editor" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\play.ps1" -editor
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\play.ps1"
)
