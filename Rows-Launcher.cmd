@echo off
set "RowsLocation=%~dp0\Resources\Rows.ps1"

if "%OS%" NEQ "Windows_NT" call :error "Unsupported OS" "Only Windows NT-based OSes are supported."
if not exist "%RowsLocation%" call :error "Rows Missing" "Update the path in variable RowsLocation in %~dpf0"

echo Press [R] key if prompted below.
powershell.exe -File "%RowsLocation%"
exit /b

:error
echo Error: %~1
echo(
echo %~2
echo Please press any key to exit
>nul pause
exit /b