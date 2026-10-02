@echo off
setlocal
where cl.exe >nul 2>nul
if errorlevel 1 (
    echo Run this from an x86 MSVC Developer Command Prompt.
    exit /b 1
)
cl.exe /nologo /LD /EHsc /std:c++17 /W3 PanoramaBridge.cpp minhook\src\buffer.c minhook\src\hook.c minhook\src\trampoline.c minhook\src\hde\hde32.c /link /OUT:PanoramaBridge32.dll user32.lib
if errorlevel 1 exit /b 1
cl.exe /nologo /EHsc /std:c++17 /W3 injector.cpp /link /OUT:panorama-inject32.exe advapi32.lib
if errorlevel 1 exit /b 1
echo Built PanoramaBridge32.dll and panorama-inject32.exe
