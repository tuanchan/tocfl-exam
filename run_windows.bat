@echo off
if not defined TOCFL_CMD_KEEP_OPEN (
    set "TOCFL_CMD_KEEP_OPEN=1"
    cmd.exe /d /k call "%~f0" %*
    exit /b
)

setlocal
title TOCFL Full Exam - Windows

cd /d "%~dp0"

set "TOCFL_LOG=%~dp0run_windows_last.log"
set "TOCFL_FLUTTER="
for /f "delims=" %%F in ('where flutter.bat 2^>nul') do (
    if not defined TOCFL_FLUTTER set "TOCFL_FLUTTER=%%F"
)
if not defined TOCFL_FLUTTER (
    if exist "D:\FLUTTER\flutter\bin\flutter.bat" (
        set "TOCFL_FLUTTER=D:\FLUTTER\flutter\bin\flutter.bat"
    ) else (
        echo [LOI] Khong tim thay Flutter trong PATH.
        echo Hay them thu muc Flutter\bin vao PATH roi chay lai file nay.
        > "%TOCFL_LOG%" echo [%DATE% %TIME%] Khong tim thay Flutter.
        pause
        exit /b 1
    )
)

if not exist ".dart_tool\package_config.json" (
    echo [LOI] Du an chua co package_config.json.
    echo Hay tu chay "flutter pub get" mot lan, sau do mo lai file BAT nay.
    > "%TOCFL_LOG%" echo [%DATE% %TIME%] Thieu .dart_tool\package_config.json.
    pause
    exit /b 1
)

> "%TOCFL_LOG%" echo [%DATE% %TIME%] Bat dau chay Windows.
>> "%TOCFL_LOG%" echo Flutter: %TOCFL_FLUTTER%
>> "%TOCFL_LOG%" echo Project: %CD%

echo Dang chay TOCFL Full Exam tren Windows...
echo Thu muc: %CD%
echo Flutter: %TOCFL_FLUTTER%
echo.

call "%TOCFL_FLUTTER%" run -d windows --no-pub %*
set "TOCFL_EXIT_CODE=%ERRORLEVEL%"
>> "%TOCFL_LOG%" echo [%DATE% %TIME%] ExitCode=%TOCFL_EXIT_CODE%

echo.
if not "%TOCFL_EXIT_CODE%"=="0" (
    echo [LOI] Flutter ket thuc voi ma %TOCFL_EXIT_CODE%.
) else (
    echo Ung dung da dung.
)
pause
exit /b %TOCFL_EXIT_CODE%
