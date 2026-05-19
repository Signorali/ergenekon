@echo off
REM Reset and rebuild the entire Ergenekon system

setlocal enabledelayedexpansion

echo.
echo ============================================
echo. 🔄 ERGENEKON SYSTEM RESET ^& REBUILD
echo ============================================
echo.

REM Step 1: Stop all containers
echo. 📍 Step 1: Stopping all containers...
docker-compose down
echo. ✅ Containers stopped
echo.

REM Step 2: Remove volumes to clear databases
echo. 📍 Step 2: Clearing database volumes...
docker-compose down -v
echo. ✅ Volumes removed (clean slate)
echo.

REM Step 3: Rebuild all images
echo. 📍 Step 3: Rebuilding Docker images...
docker-compose build --no-cache
echo. ✅ Images rebuilt
echo.

REM Step 4: Start all services
echo. 📍 Step 4: Starting services...
docker-compose up -d
echo. ✅ Services started
echo.

REM Step 5: Wait for services
echo. 📍 Step 5: Waiting for services to be ready...
timeout /t 5 /nobreak

REM Check Umay backend
setlocal enabledelayedexpansion
for /L %%i in (1,1,30) do (
    curl -s http://localhost:1923/api/v1/setup/status >nul 2>&1
    if !errorlevel! equ 0 (
        echo. ✅ Umay backend is ready
        goto done
    )
    echo.    Checking... (%%i/30)
    timeout /t 2 /nobreak >nul
)

:done
echo.
echo ============================================
echo. ✨ RESET COMPLETE
echo ============================================
echo.
echo. 📚 Access URLs:
echo.    - Umay Frontend: http://localhost:1881
echo.    - Umay API Docs: http://localhost:1923/docs
echo.    - Ötüken Frontend: http://localhost:5174
echo.    - Ötüken API Docs: http://localhost:8080/docs
echo.
echo. 👤 Default Admin Credentials:
echo.    - Email: admin@umay.local
echo.    - Password: Admin2026!
echo.
echo. 🔑 Expected Groups After Setup:
echo.    - Arazi (ARAZI) — Created automatically for Ötüken integration
echo.    - Other groups — Create manually in Umay UI after login
echo.
echo. To monitor logs: docker-compose logs -f umay-backend
echo.

endlocal
pause
