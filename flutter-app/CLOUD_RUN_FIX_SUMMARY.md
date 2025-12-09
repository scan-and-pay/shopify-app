# Cloud Run Deployment Fix Summary

## Problem
Deployment to Google Cloud Run was failing with the following error:
```
Error: Constant evaluation error:
const _fontWeightToFilenameWeightParts = {
The key 'FontWeight {value: 100.0}' does not have a primitive operator '=='.
```

Build failed at: `flutter build web` in Dockerfile
Flutter version: 3.40.0-1.0.pre-84 (master channel)
Package: google_fonts 6.2.1

## Root Cause
The Dockerfile was cloning Flutter from GitHub without specifying a branch, which defaulted to the **master channel** (bleeding-edge, unstable). The master channel had breaking changes in Flutter's `FontWeight` class that broke compatibility with the `google_fonts` package.

## Solution Applied

### 1. Updated Dockerfile (C:\dev\shopify-app\flutter-app\Dockerfile)

**Before:**
```dockerfile
RUN git clone https://github.com/flutter/flutter.git /usr/local/flutter
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"
RUN flutter config --enable-web
RUN flutter doctor -v
```

**After:**
```dockerfile
RUN git clone https://github.com/flutter/flutter.git /usr/local/flutter && \
    cd /usr/local/flutter && \
    git checkout stable
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"
RUN flutter config --enable-web && \
    flutter doctor -v
```

**Changes:**
- Added `git checkout stable` to use stable Flutter version
- Combined RUN commands to reduce Docker layers
- Added explicit `flutter pub get` before build
- Changed to `flutter build web --release` for production optimization

### 2. Created .dockerignore file
Optimizes Docker build by excluding:
- Build outputs (build/, .dart_tool/)
- IDE files (.idea/, .vscode/)
- Platform-specific code (android/, ios/)
- Test files and documentation
- Git repository

### 3. Created GitHub Actions Workflow
**File:** `.github/workflows/deploy-cloud-run.yml`

Features:
- Automatic deployment on push to main branch
- Workload Identity Federation for secure authentication
- Docker image build and push to GCR
- Cloud Run deployment with optimized settings
- Displays deployment URL after success

### 4. Created Documentation
**File:** `DEPLOYMENT.md`

Includes:
- Complete setup instructions
- GCP service account configuration
- Workload Identity Federation setup
- GitHub secrets configuration
- Troubleshooting guide
- Cost optimization tips

## Files Changed/Created

1. **Modified:**
   - `Dockerfile` - Fixed Flutter version to stable channel

2. **Created:**
   - `.dockerignore` - Docker build optimization
   - `.github/workflows/deploy-cloud-run.yml` - Automated deployment
   - `DEPLOYMENT.md` - Complete deployment guide
   - `CLOUD_RUN_FIX_SUMMARY.md` - This file

## Expected Flutter Version
The stable channel will use Flutter 3.24.x or 3.27.x (latest stable), which is compatible with:
- Dart SDK ^3.6.0 (from pubspec.yaml)
- google_fonts ^6.1.0
- All other dependencies

## Testing the Fix

### Local Build Test
```bash
cd C:\dev\shopify-app\flutter-app
docker build -t flutter-app:test .
docker run -p 8080:8080 flutter-app:test
# Access http://localhost:8080
```

### Cloud Build Test
```bash
gcloud builds submit --tag gcr.io/PROJECT_ID/flutter-app
```

### Full Deployment
Push to GitHub main branch to trigger automatic deployment

## Next Steps

1. **Verify GitHub Secrets** are configured:
   - GCP_PROJECT_ID
   - GCP_WORKLOAD_IDENTITY_PROVIDER
   - GCP_SERVICE_ACCOUNT

2. **Test the deployment** by pushing to main branch

3. **Monitor the build** in GitHub Actions tab

4. **Verify Cloud Run service** is running:
   ```bash
   gcloud run services describe flutter-app --region=us-central1
   ```

## Expected Build Time
- **Docker build**: ~5-8 minutes (includes Flutter SDK download)
- **Total deployment**: ~10-12 minutes

## Cost Estimate (Cloud Run)
- **Minimum**: $0/month (with min-instances=0)
- **Per request**: ~$0.0000024 per request
- **512Mi memory**: Sufficient for Flutter web app
- **Auto-scaling**: 0-10 instances

## Rollback Plan
If issues occur:
```bash
# Revert to previous revision
gcloud run services update-traffic flutter-app \
  --to-revisions=PREVIOUS_REVISION=100 \
  --region=us-central1
```

## Success Criteria
- ✅ Docker build completes without FontWeight error
- ✅ Flutter build web succeeds with stable channel
- ✅ Nginx serves static files on port 8080
- ✅ Cloud Run deployment succeeds
- ✅ App is accessible via Cloud Run URL
- ✅ GitHub Actions workflow passes

## Additional Optimizations Considered

### Future Improvements:
1. **Multi-stage build caching**: Cache Flutter SDK layer
2. **Artifact Registry**: Migrate from GCR to Artifact Registry
3. **Cloud CDN**: Add CDN for static asset caching
4. **Custom domain**: Configure custom domain with Cloud Run
5. **Environment variables**: Use Secret Manager for runtime configs
