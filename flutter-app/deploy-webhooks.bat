@echo off
echo ========================================
echo Shopify Webhook Deployment Script
echo ========================================
echo.

echo Step 1: Authenticate with Firebase
echo -----------------------------------
firebase login --reauth
if %errorlevel% neq 0 (
    echo ERROR: Firebase login failed
    pause
    exit /b 1
)
echo.

echo Step 2: Set Shopify API Secret
echo -----------------------------------
cd functions
firebase functions:config:set shopify.api_secret="YOUR_SHOPIFY_API_SECRET_HERE"
if %errorlevel% neq 0 (
    echo ERROR: Failed to set API secret
    pause
    exit /b 1
)
echo.

echo Step 3: Verify Config
echo -----------------------------------
firebase functions:config:get
echo.

echo Step 4: Deploy Firebase Functions
echo -----------------------------------
firebase deploy --only functions:appUninstalled,functions:customersDataRequest,functions:customersRedact,functions:shopRedact
if %errorlevel% neq 0 (
    echo ERROR: Function deployment failed
    pause
    exit /b 1
)
echo.

echo ========================================
echo SUCCESS! Firebase Functions Deployed
echo ========================================
echo.
echo Next steps:
echo 1. Test functions with: test-webhooks.bat
echo 2. Deploy Cloud Run with: deploy-cloud-run.bat
echo.
pause
