@echo off
REM ============================================================
REM OpenCalc HarmonyOS HAP 打包脚本
REM 用 hvigorw 触发 entry 模块的 default 产物构建
REM ============================================================
setlocal
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"
set "HVIGORW=C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat"
if not exist "%HVIGORW%" (
  echo [ERROR] hvigorw.bat not found at "%HVIGORW%"
  exit /b 1
)
call "%HVIGORW%" --mode module -p product=default -p buildMode=debug assembleHap
exit /b %ERRORLEVEL%
