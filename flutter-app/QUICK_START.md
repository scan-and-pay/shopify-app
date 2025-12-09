# Quick Start Guide - Cloud Run Deployment

## What Was Fixed
Your Flutter app deployment to Google Cloud Run was failing because the Dockerfile used Flutter's **master channel** (unstable) which had compatibility issues with the `google_fonts` package.

**Fixed**: Dockerfile now uses Flutter **stable channel**.

## Files Modified/Created

### Modified:
- ✅ `Dockerfile` - Now uses stable Flutter channel

### Created:
- ✅ `.dockerignore` - Optimizes Docker build
- ✅ `.github/workflows/deploy-cloud-run.yml` - Automated deployment
- ✅ `DEPLOYMENT.md` - Full deployment guide
- ✅ `CLOUD_RUN_FIX_SUMMARY.md` - Detailed fix explanation
- ✅ `QUICK_START.md` - This file

## Test Locally Right Now

```bash
# Navigate to the flutter-app directory
cd C:\dev\shopify-app\flutter-app

# Build Docker image
docker build -t flutter-app:test .

# Run container
docker run -p 8080:8080 flutter-app:test

# Open browser to http://localhost:8080
```

**Expected**: Build should complete in ~5-8 minutes without errors.

## Deploy to Cloud Run

### Option 1: Automatic (via GitHub Actions)

1. **Commit and push** the changes:
   ```bash
   git add .
   git commit -m "Fix: Use Flutter stable channel for Cloud Run deployment"
   git push origin main
   ```

2. **Watch the deployment** in GitHub Actions tab

3. **Get the URL** from the workflow output

### Option 2: Manual Deployment

```bash
# Set your project ID
gcloud config set project YOUR_PROJECT_ID

# Build and deploy in one command
gcloud run deploy flutter-app \
  --source . \
  --region=us-central1 \
  --allow-unauthenticated \
  --port=8080 \
  --memory=512Mi
```

## Required GitHub Secrets

Before automatic deployment works, add these secrets in GitHub:
- `GCP_PROJECT_ID` - Your Google Cloud project ID
- `GCP_WORKLOAD_IDENTITY_PROVIDER` - Workload Identity Provider path
- `GCP_SERVICE_ACCOUNT` - Service account email

**See `DEPLOYMENT.md` for detailed setup instructions.**

## Verify the Fix Worked

### During Docker Build:
```
Step 3/15 : RUN git clone ... && git checkout stable
✅ Should see "Switched to branch 'stable'"

Step 6/15 : RUN flutter doctor -v
✅ Should see "Flutter (Channel stable, 3.24.x or 3.27.x...)"
   NOT "Channel master, 3.40.0-1.0.pre-84"

Step 10/15 : RUN flutter build web --release
✅ Should complete without FontWeight errors
```

### Success Indicators:
- ✅ No `FontWeight` compilation errors
- ✅ Build completes successfully
- ✅ Nginx container starts on port 8080
- ✅ App accessible in browser

## Common Issues

### Issue: Docker build still fails
**Solution**: Make sure you're using the updated Dockerfile
```bash
# Check if stable channel is specified
grep "git checkout stable" Dockerfile
```

### Issue: Build is slow
**Expected**: First build takes 5-8 minutes (downloads Flutter SDK)
**Solution**: This is normal. Subsequent builds will be faster if layers are cached.

### Issue: Port 8080 not accessible
**Solution**:
- Check if container is running: `docker ps`
- Check if port is available: `netstat -ano | findstr 8080`
- Try different port: `docker run -p 9090:8080 flutter-app:test`

## Next Steps After Successful Build

1. ✅ **Test locally** - Verify app works on localhost:8080
2. ✅ **Commit changes** - Push to GitHub
3. ✅ **Configure secrets** - Add GCP secrets to GitHub
4. ✅ **Deploy to Cloud Run** - Push to main branch or deploy manually
5. ✅ **Monitor logs** - Check Cloud Run logs for any runtime issues

## Need Help?

- **Full deployment guide**: See `DEPLOYMENT.md`
- **Detailed fix explanation**: See `CLOUD_RUN_FIX_SUMMARY.md`
- **GitHub Actions workflow**: Check `.github/workflows/deploy-cloud-run.yml`

## Commands Cheat Sheet

```bash
# Local test
docker build -t flutter-app:test . && docker run -p 8080:8080 flutter-app:test

# Manual Cloud Run deploy
gcloud run deploy flutter-app --source . --region=us-central1 --allow-unauthenticated

# View Cloud Run logs
gcloud run services logs read flutter-app --region=us-central1

# List Cloud Run services
gcloud run services list

# Get service URL
gcloud run services describe flutter-app --region=us-central1 --format='value(status.url)'

# Delete service (if needed)
gcloud run services delete flutter-app --region=us-central1
```

## Support

If you encounter any issues:
1. Check `DEPLOYMENT.md` troubleshooting section
2. Review Cloud Build logs in GCP Console
3. Verify all GitHub secrets are configured correctly
4. Test Docker build locally first
