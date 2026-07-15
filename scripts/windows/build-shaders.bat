@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build-shaders.ps1" %*
