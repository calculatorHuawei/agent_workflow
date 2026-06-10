@echo off
REM build_hap.bat - OpenCalc HarmonyOS build script
REM Must set DEVECO_SDK_HOME and JAVA_HOME first, otherwise hvigorw fails with "Invalid value of DEVECO_SDK_HOME"

setlocal

set "DEVECO_SDK_HOME=D:\Program Files\Huawei\DevEco Studio\sdk"
set "JAVA_HOME=D:\Program Files\Huawei\DevEco Studio\jbr"
set "PATH=%JAVA_HOME%\bin;%PATH%"

if not exist "%DEVECO_SDK_HOME%" (
    echo [ERROR] DEVECO_SDK_HOME not found: %DEVECO_SDK_HOME%
    exit /b 1
)

REM Run hvigorw
"D:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" %*
exit /b %ERRORLEVEL%
