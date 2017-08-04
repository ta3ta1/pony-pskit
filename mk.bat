@echo off
setlocal
cd %~dp0
if "x%1" == "x" (
    goto :all
) else if "x%1" == "xall" (
    goto :all
) else if "x%1" == "xclean" (
    goto :clean
) else if "x%1" == "xstub" (
    goto :stub
) else if "x%1" == "xtest" (
    goto :test
)

exit /b

:all
call :stub
call :test
exit /b

:clean
del /q bin\*.*
del /q testbin\checkenv.*
del /q testbin\hello.*
exit /b

:stub
ponyc -o testbin -d stub\checkenv
ponyc -o testbin -d stub\hello
exit /b

:test
set TESTOPT=--noprog
if "x%2" == "xseq" (
    set TESTOPT=%TESTOPT% --sequential
)
ponyc -o bin -d pskit\spawn\test && bin\test %TESTOPT%
exit /b
