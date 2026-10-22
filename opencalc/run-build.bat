@echo off
setlocal
set "DEVECO_SDK_HOME=D:\Program Files\Huawei\DevEco Studio\sdk"
set "JAVA_HOME=D:\Program Files\Huawei\DevEco Studio\jbr"
set "PATH=D:\Program Files\Huawei\DevEco Studio\jbr\bin;D:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin;%PATH%"
cd /d "%~dp0"
echo JAVA_HOME=%JAVA_HOME%
echo PATH=%PATH%
where java
java -version
call "D:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" --stop-daemon
call "D:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" assembleHap
endlocal
