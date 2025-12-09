# Google Cloud Run Deployment Guide

This guide explains how to deploy the Flutter web app to Google Cloud Run using GitHub Actions.

## Prerequisites

1. **Google Cloud Project** with billing enabled
2. **GitHub repository** with the flutter-app code
3. **Workload Identity Federation** configured between GitHub and GCP

## Fixed Issues

### Flutter Version Compatibility
The Dockerfile was updated to use Flutter's **stable channel** instead of the master channel. The master channel (3.40.0-1.0.pre-84) had compatibility issues with `google_fonts` package causing build failures:
```
Error: The key 'FontWeight {value: 100.0}' does not have a primitive operator '=='.
```

**Solution**: Changed Dockerfile to checkout stable channel:
```dockerfile
RUN git clone https://github.com/flutter/flutter.git /usr/local/flutter && \
    cd /usr/local/flutter && \
    git checkout stable
```

## Setup Instructions

### 1. Enable Required GCP APIs

```bash
gcloud services enable \
  run.googleapis.com \
  containerregistry.googleapis.com \
  cloudbuild.googleapis.com \
  secretmanager.googleapis.com
```

### 2. Create Service Account

```bash
# Create service account
gcloud iam service-accounts create github-actions-sa \
  --display-name="GitHub Actions Service Account"

# Grant necessary roles
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:github-actions-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:github-actions-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.admin"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:github-actions-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"
```

### 3. Configure Workload Identity Federation

```bash
# Create Workload Identity Pool
gcloud iam workload-identity-pools create "github-pool" \
  --project="PROJECT_ID" \
  --location="global" \
  --display-name="GitHub Actions Pool"

# Create Workload Identity Provider
gcloud iam workload-identity-pools providers create-oidc "github-provider" \
  --project="PROJECT_ID" \
  --location="global" \
  --workload-identity-pool="github-pool" \
  --display-name="GitHub Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
  --issuer-uri="https://token.actions.githubusercontent.com"

# Bind service account to Workload Identity
gcloud iam service-accounts add-iam-policy-binding \
  github-actions-sa@PROJECT_ID.iam.gserviceaccount.com \
  --project=PROJECT_ID \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/attribute.repository/YOUR_GITHUB_USERNAME/shopify-app"
```

### 4. GitHub Secrets Configuration

Add the following secrets to your GitHub repository (Settings → Secrets and variables → Actions):

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `GCP_PROJECT_ID` | your-project-id | Google Cloud Project ID |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/providers/github-provider | Workload Identity Provider resource name |
| `GCP_SERVICE_ACCOUNT` | github-actions-sa@PROJECT_ID.iam.gserviceaccount.com | Service account email |

### 5. Store Firebase Secrets (if needed)

```bash
# Store Firebase API keys in Secret Manager
echo -n "your-web-api-key" | gcloud secrets create FIREBASE_API_KEY_WEB --data-file=-
echo -n "your-mobile-api-key" | gcloud secrets create FIREBASE_API_KEY_MOBILE --data-file=-
echo -n "your-firebase-project-id" | gcloud secrets create FIREBASE_PROJECT_ID --data-file=-

# Grant access to service account
gcloud secrets add-iam-policy-binding FIREBASE_API_KEY_WEB \
  --member="serviceAccount:github-actions-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

## Dockerfile Changes

The updated Dockerfile includes:

1. **Stable Flutter Channel**: Uses `stable` branch instead of `master`
2. **Explicit Dependencies**: Runs `flutter pub get` before build
3. **Release Build**: Uses `--release` flag for optimized production build
4. **Empty .env File**: Creates placeholder .env to prevent build errors
5. **Optimized Layers**: Combines RUN commands to reduce image layers

## Deployment

### Automatic Deployment (GitHub Actions)

Push changes to the `main` branch:
```bash
git add .
git commit -m "Deploy to Cloud Run"
git push origin main
```

The workflow will:
1. Build Docker image with stable Flutter
2. Push to Google Container Registry (GCR)
3. Deploy to Cloud Run
4. Output the deployment URL

### Manual Deployment

```bash
# Build and push image
gcloud builds submit --tag gcr.io/PROJECT_ID/flutter-app

# Deploy to Cloud Run
gcloud run deploy flutter-app \
  --image=gcr.io/PROJECT_ID/flutter-app \
  --platform=managed \
  --region=us-central1 \
  --allow-unauthenticated \
  --port=8080 \
  --memory=512Mi
```

## Local Testing

Test the Docker build locally:

```bash
# Build image
docker build -t flutter-app:test .

# Run container
docker run -p 8080:8080 flutter-app:test

# Access at http://localhost:8080
```

## Troubleshooting

### Build Fails with FontWeight Error
- **Cause**: Using Flutter master channel with incompatible packages
- **Solution**: Ensure Dockerfile uses `git checkout stable`

### Docker Build Timeout
- **Cause**: Cloning Flutter and downloading dependencies takes time
- **Solution**: Increase Cloud Build timeout or use a cached Flutter image

### Memory Issues
- **Cause**: Flutter web build requires significant memory
- **Solution**: Increase Cloud Run memory allocation (--memory=1Gi)

### .env File Missing
- **Cause**: App expects .env file at build time
- **Solution**: Dockerfile creates empty .env with `touch .env`

## Monitoring

View logs:
```bash
gcloud run services logs read flutter-app --region=us-central1
```

Monitor deployment:
```bash
gcloud run services describe flutter-app --region=us-central1
```

## Cost Optimization

- **Min Instances**: Set to 0 for pay-per-use
- **Max Instances**: Limit to 10 for cost control
- **Memory**: Start with 512Mi, increase only if needed
- **CPU**: Use 1 CPU for most Flutter web apps

## Security Considerations

1. **Secrets**: Use Secret Manager for sensitive data
2. **Authentication**: Enable IAM authentication for internal apps
3. **HTTPS**: Cloud Run provides automatic HTTPS
4. **CORS**: Configure in Nginx if serving API endpoints
