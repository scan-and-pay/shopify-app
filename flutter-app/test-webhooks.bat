@echo off
echo ========================================
echo Testing Shopify Webhook Endpoints
echo ========================================
echo.

echo Testing Firebase Functions directly...
echo.

echo 1. Testing appUninstalled...
curl -X POST https://us-central1-scan-and-pay-guihzm.cloudfunctions.net/appUninstalled -H "Content-Type: application/json" -d "{\"test\": \"data\"}"
echo.
echo.

echo 2. Testing customersDataRequest...
curl -X POST https://us-central1-scan-and-pay-guihzm.cloudfunctions.net/customersDataRequest -H "Content-Type: application/json" -d "{\"test\": \"data\"}"
echo.
echo.

echo 3. Testing customersRedact...
curl -X POST https://us-central1-scan-and-pay-guihzm.cloudfunctions.net/customersRedact -H "Content-Type: application/json" -d "{\"test\": \"data\"}"
echo.
echo.

echo 4. Testing shopRedact...
curl -X POST https://us-central1-scan-and-pay-guihzm.cloudfunctions.net/shopRedact -H "Content-Type: application/json" -d "{\"test\": \"data\"}"
echo.
echo.

echo ========================================
echo Expected Response: "Unauthorized - Invalid HMAC"
echo (This is CORRECT - HMAC verification working!)
echo ========================================
echo.

echo Testing through Cloud Run (after deployment)...
echo.

echo 1. Testing /webhooks/app/uninstalled...
curl -X POST https://merchants.scanandpay.com.au/webhooks/app/uninstalled -H "Content-Type: application/json" -d "{\"test\": \"data\"}"
echo.
echo.

echo 2. Testing /webhooks/customers/data_request...
curl -X POST https://merchants.scanandpay.com.au/webhooks/customers/data_request -H "Content-Type: application/json" -d "{\"test\": \"data\"}"
echo.
echo.

echo 3. Testing /webhooks/customers/redact...
curl -X POST https://merchants.scanandpay.com.au/webhooks/customers/redact -H "Content-Type: application/json" -d "{\"test\": \"data\"}"
echo.
echo.

echo 4. Testing /webhooks/shop/redact...
curl -X POST https://merchants.scanandpay.com.au/webhooks/shop/redact -H "Content-Type: application/json" -d "{\"test\": \"data\"}"
echo.
echo.

echo ========================================
echo Test Summary
echo ========================================
echo If you see "Unauthorized - Invalid HMAC" = SUCCESS!
echo If you see 404 Not Found = Routing problem
echo If you see 502 Bad Gateway = Firebase Functions URL incorrect
echo.
pause
