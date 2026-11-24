@echo off
setlocal
echo ========================================================
echo   Starting BioScope-Lite in Docker...
echo ========================================================

:: Check Docker status
docker info >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Docker is not running. Please launch Docker Desktop first.
    pause
    exit /b 1
)

:: Ensure clean start
docker rm -f bioscope-local >nul 2>&1

:: Run container on port 8080
echo Starting container on http://localhost:8080 ...
docker run -d -p 8080:80 --name bioscope-local bioscope-lite:local >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Local image not found. Building bioscope-lite:local ...
    docker build -t bioscope-lite:local .
    docker run -d -p 8080:80 --name bioscope-local bioscope-lite:local
)

echo.
echo ========================================================
echo   [SUCCESS] App running at: http://localhost:8080
echo ========================================================
echo.
echo Opening browser...
start http://localhost:8080
echo.
echo Press any key when you are finished to stop the container...
pause >nul

echo Stopping bioscope-local container...
docker rm -f bioscope-local >nul 2>&1
echo [DONE] Container stopped cleanly.
