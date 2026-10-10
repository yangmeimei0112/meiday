@echo off
chcp 65001 >nul
title ChronoHub - 智慧行事曆與時間中樞
cd /d "C:\Users\yaco9\.gemini\antigravity\scratch\smart_calendar_hub"

echo ================================================================
echo    ChronoHub 跨平台雙引擎智慧行事曆與時間中樞
echo ================================================================
echo.

:: 檢查 Windows 開發人員模式 (Symlink 支援)
powershell -NoProfile -Command "$val = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' -ErrorAction SilentlyContinue).AllowDevelopmentWithoutDevLicense; if ($val -ne 1) { exit 1 } else { exit 0 }"
if %ERRORLEVEL% NEQ 0 (
    echo [溫馨提示] 首次在 Windows 運行 Flutter 桌面應用，需要開啟「開發人員模式」以支援外掛符號連結 (Symlink)。
    echo 正在為您開啟 Windows 設定頁面...
    start ms-settings:developers
    echo.
    echo 請在設定頁面中將【開發人員模式】開啟後，返回此視窗按任意鍵繼續...
    pause >nul
)

echo.
echo 正在編譯並啟動 ChronoHub 桌面端應用程式...
echo 首次啟動約需 1~2 分鐘建置，請稍候...
echo.

"C:\Users\yaco9\Downloads\flutter\bin\flutter.bat" run -d windows

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ================================================================
    echo 應用程式已關閉或啟動中斷。
    echo ================================================================
    pause
)
