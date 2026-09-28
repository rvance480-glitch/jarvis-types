@echo off
title Install Jarvis
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-jarvis.ps1" %*
