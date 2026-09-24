@echo off
REM ===================================================
REM Enigma2 Cython Compiler v4.1 - Windows Launcher
REM Prints (and copies to clipboard) the exact one-liner
REM to compile / restore a plugin on your Enigma2 box.
REM ===================================================
setlocal
title Enigma2 Cython Compiler v4.1 - Launcher

set "BASE_URL=https://raw.githubusercontent.com/azroukarim/sos/main"

:ask_ip
set "DEVICE_IP="
set /p DEVICE_IP="Enter Enigma2 IP address [192.168.0.161]: "
if "%DEVICE_IP%"=="" set "DEVICE_IP=192.168.0.161"

:ask_choice
set "CHOICE="
set /p CHOICE="Action: [1] Compile   [2] Restore  (press Enter = 1): "
if "%CHOICE%"=="" set "CHOICE=1"

:ask_plugin
set "PLUGIN_NAME="
set /p PLUGIN_NAME="Plugin name or full path (example: XPortal): "
if "%PLUGIN_NAME%"=="" goto no_plugin

if "%CHOICE%"=="2" goto restore_mode

:compile_mode
set "MODE=COMPILE"
set "FILE=compile_tool.sh"
goto print_info

:restore_mode
set "MODE=RESTORE"
set "FILE=restore_backup.sh"
goto print_info

:no_plugin
echo.
echo ERROR: You must enter a plugin name.
pause
exit /b 1

:print_info
echo.
echo ==================================================
echo    %MODE% mode - plugin: %PLUGIN_NAME%
echo    Target IP : %DEVICE_IP%
echo ==================================================
echo.
echo 1) Open telnet to the box:
echo        telnet %DEVICE_IP%
echo    (login: root  /  password: leave empty)
echo.
echo 2) The command below was already copied to your
echo    clipboard - just paste it inside telnet:
echo.
if "%CHOICE%"=="2" goto show_restore

echo    [curl version]
echo        curl -kLs %BASE_URL%/compile_tool.sh -o /tmp/compile_tool.sh ^&^& /bin/sh /tmp/compile_tool.sh
echo    [wget version - if curl is missing on the box]
echo        wget --no-check-certificate %BASE_URL%/compile_tool.sh -O /tmp/compile_tool.sh ^&^& /bin/sh /tmp/compile_tool.sh
echo.
echo 3- The tool will then ask for the plugin name -
echo    type: %PLUGIN_NAME%
echo    It creates a backup of all .py files first, compiles
echo    them to .so, and shows how to restore them later.
goto make_clip

:show_restore
echo    [curl version]
echo        curl -kLs %BASE_URL%/restore_backup.sh -o /tmp/restore_backup.sh ^&^& /bin/sh /tmp/restore_backup.sh "%PLUGIN_NAME%"
echo    [wget version - if curl is missing on the box]
echo        wget --no-check-certificate %BASE_URL%/restore_backup.sh -O /tmp/restore_backup.sh ^&^& /bin/sh /tmp/restore_backup.sh "%PLUGIN_NAME%"
echo.
echo 3- Restores the original .py files from the backup.
goto make_clip

:make_clip
if "%CHOICE%"=="2" goto clip_restore
> "%TEMP%\e2cc_cmd.txt" echo curl -kLs %BASE_URL%/compile_tool.sh -o /tmp/compile_tool.sh ^&^& /bin/sh /tmp/compile_tool.sh
goto clip_done

:clip_restore
> "%TEMP%\e2cc_cmd.txt" echo curl -kLs %BASE_URL%/restore_backup.sh -o /tmp/restore_backup.sh ^&^& /bin/sh /tmp/restore_backup.sh "%PLUGIN_NAME%"

:clip_done
clip < "%TEMP%\e2cc_cmd.txt"
del "%TEMP%\e2cc_cmd.txt" >nul 2>&1

echo.
echo The command was copied to the clipboard. In telnet,
echo just right-click (or paste) and press Enter.
echo.
set "AUTOTELNET="
set /p AUTOTELNET="Try to open telnet automatically? y/N: "
if "%AUTOTELNET%"=="y" start telnet %DEVICE_IP%
if "%AUTOTELNET%"=="Y" start telnet %DEVICE_IP%

echo.
pause