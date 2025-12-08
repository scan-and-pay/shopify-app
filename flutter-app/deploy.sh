#!/bin/bash

# ScanPay Auto Deploy Script
# Increments version and deploys to Netlify

echo "🚀 Starting ScanPay deployment..."

# Read current version from pubspec.yaml
CURRENT_VERSION=$(grep "version:" pubspec.yaml | sed 's/version: //' | tr -d ' ')
VERSION_NAME=$(echo $CURRENT_VERSION | cut -d'+' -f1)
BUILD_NUMBER=$(echo $CURRENT_VERSION | cut -d'+' -f2)

echo "📋 Current version: $CURRENT_VERSION"

# Increment build number
NEW_BUILD_NUMBER=$((BUILD_NUMBER + 1))

# Increment patch version for minor updates
MAJOR=$(echo $VERSION_NAME | cut -d'.' -f1)
MINOR=$(echo $VERSION_NAME | cut -d'.' -f2)
PATCH=$(echo $VERSION_NAME | cut -d'.' -f3)
NEW_PATCH=$((PATCH + 1))
NEW_VERSION_NAME="$MAJOR.$MINOR.$NEW_PATCH"
NEW_VERSION="$NEW_VERSION_NAME+$NEW_BUILD_NUMBER"

echo "📈 New version: $NEW_VERSION"

# Update pubspec.yaml
sed -i.bak "s/version: $CURRENT_VERSION/version: $NEW_VERSION/" pubspec.yaml
rm pubspec.yaml.bak

echo "✅ Updated pubspec.yaml with version $NEW_VERSION"

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Build for web
echo "🔨 Building Flutter web app..."
flutter build web

if [ $? -eq 0 ]; then
    echo "✅ Build successful"
    
    # Deploy to Netlify
    echo "🌐 Deploying to Netlify..."
    netlify deploy --prod --dir=build/web
    
    if [ $? -eq 0 ]; then
        echo "🎉 Deployment successful!"
        echo "📱 Version: $NEW_VERSION"
        echo "🔗 URL: https://flutter-scanpay.netlify.app"
        
        # Get unique deploy URL from the output
        echo ""
        echo "ℹ️  Use 'netlify open' to see deployment details"
        
    else
        echo "❌ Deployment failed"
        exit 1
    fi
else
    echo "❌ Build failed"
    exit 1
fi