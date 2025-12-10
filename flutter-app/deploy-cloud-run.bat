@echo off
echo ========================================
echo Cloud Run Deployment Script
echo ========================================
echo.

echo This will rebuild and deploy the Flutter app with webhook proxying
echo.
pause

echo Step 1: Authenticate with Google Cloud
echo -----------------------------------
gcloud auth login
if %errorlevel% neq 0 (
    echo ERROR: Google Cloud login failed
    pause
    exit /b 1
)
echo.

echo Step 2: Set GCP Project
echo -----------------------------------
gcloud config set project scan-and-pay-guihzm
echo.

echo Step 3: Build Docker Image
echo -----------------------------------
docker build -t gcr.io/scan-and-pay-guihzm/flutter-app:latest .
if %errorlevel% neq 0 (
    echo ERROR: Docker build failed
    pause
    exit /b 1
)
echo.

echo Step 4: Configure Docker for GCR
echo -----------------------------------
gcloud auth configure-docker
echo.

echo Step 5: Push to Google Container Registry
echo -----------------------------------
docker push gcr.io/scan-and-pay-guihzm/flutter-app:latest
if %errorlevel% neq 0 (
    echo ERROR: Docker push failed
    pause
    exit /b 1
)
echo.

echo Step 6: Deploy to Cloud Run
echo -----------------------------------
gcloud run deploy flutter-app --image=gcr.io/scan-and-pay-guihzm/flutter-app:latest --platform=managed --region=us-central1 --allow-unauthenticated --port=8080 --memory=512Mi --cpu=1 --min-instances=0 --max-instances=10
if %errorlevel% neq 0 (
    echo ERROR: Cloud Run deployment failed
    pause
    exit /b 1
)
echo.

echo ========================================
echo SUCCESS! Cloud Run Deployed
echo ========================================
echo.
echo Service URL: https://merchants.scanandpay.com.au
echo.
echo Next steps:
echo 1. Test webhooks with: test-webhooks.bat
echo 2. Configure webhooks in Shopify Partner Dashboard
echo 3. Run Shopify automated compliance tests
echo.
pause
