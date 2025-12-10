#!/usr/bin/env node

/**
 * Secret Manager Verification Script
 *
 * This script helps verify that all required secrets are properly configured
 * in Google Secret Manager before deploying your Firebase Functions.
 *
 * Usage:
 *   node verify-secrets.js
 *
 * Prerequisites:
 *   - gcloud CLI installed and authenticated
 *   - Proper permissions to access Secret Manager
 */

const { execSync } = require('child_process');

// ANSI color codes for terminal output
const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m'
};

// Required secrets for this Firebase Functions project
const REQUIRED_SECRETS = [
  'FIREBASE_PROJECT_ID',
  'FIREBASE_API_KEY',
  'FIREBASE_STORAGE_BUCKET',
  'GLOBALPAYMENTS_MASTER_KEY',
  'GLOBALPAYMENTS_BASE_URL',
  'MAILGUN_API_KEY',
  'MAILGUN_DOMAIN',
  'BASIQ_API_KEY',
  'ENCRYPTION_KEY',
  'SHOPIFY_API_SECRET'
];

// Get Firebase project ID
function getProjectId() {
  try {
    const output = execSync('firebase use', { encoding: 'utf8' });
    const match = output.match(/Active Project:.*?\(([^)]+)\)/);
    if (match && match[1]) {
      return match[1];
    }
    throw new Error('Could not determine Firebase project ID');
  } catch (error) {
    console.error(`${colors.red}❌ Error getting Firebase project ID${colors.reset}`);
    console.error(`${colors.yellow}Make sure you're in the Firebase project directory and run 'firebase use'${colors.reset}`);
    process.exit(1);
  }
}

// Check if a secret exists in Secret Manager
function checkSecret(projectId, secretName) {
  try {
    const command = `gcloud secrets describe ${secretName} --project=${projectId} 2>&1`;
    execSync(command, { encoding: 'utf8', stdio: 'pipe' });
    return { exists: true, error: null };
  } catch (error) {
    const errorMessage = error.stderr || error.stdout || error.message;
    if (errorMessage.includes('NOT_FOUND')) {
      return { exists: false, error: 'Secret not found' };
    } else if (errorMessage.includes('Permission denied')) {
      return { exists: false, error: 'Permission denied' };
    } else {
      return { exists: false, error: errorMessage };
    }
  }
}

// Check if secret has a value
function checkSecretHasValue(projectId, secretName) {
  try {
    const command = `gcloud secrets versions list ${secretName} --project=${projectId} --limit=1 --format="value(name)" 2>&1`;
    const output = execSync(command, { encoding: 'utf8', stdio: 'pipe' }).trim();
    return output.length > 0;
  } catch (error) {
    return false;
  }
}

// Main verification function
function verifySecrets() {
  console.log(`\n${colors.cyan}╔═══════════════════════════════════════════════════════╗${colors.reset}`);
  console.log(`${colors.cyan}║  Firebase Functions Secret Manager Verification      ║${colors.reset}`);
  console.log(`${colors.cyan}╚═══════════════════════════════════════════════════════╝${colors.reset}\n`);

  // Get project ID
  console.log(`${colors.blue}📋 Detecting Firebase project...${colors.reset}`);
  const projectId = getProjectId();
  console.log(`${colors.green}✅ Project ID: ${projectId}${colors.reset}\n`);

  // Check each secret
  console.log(`${colors.blue}🔍 Checking secrets in Google Secret Manager...${colors.reset}\n`);

  const results = {
    found: [],
    missing: [],
    errors: []
  };

  REQUIRED_SECRETS.forEach((secretName) => {
    process.stdout.write(`  ${secretName}... `);

    const { exists, error } = checkSecret(projectId, secretName);

    if (exists) {
      const hasValue = checkSecretHasValue(projectId, secretName);
      if (hasValue) {
        console.log(`${colors.green}✅ Found (has value)${colors.reset}`);
        results.found.push(secretName);
      } else {
        console.log(`${colors.yellow}⚠️  Found (no versions/empty)${colors.reset}`);
        results.errors.push({ secretName, error: 'No secret versions found' });
      }
    } else {
      console.log(`${colors.red}❌ ${error}${colors.reset}`);
      results.missing.push(secretName);
    }
  });

  // Print summary
  console.log(`\n${colors.cyan}╔═══════════════════════════════════════════════════════╗${colors.reset}`);
  console.log(`${colors.cyan}║  Summary                                              ║${colors.reset}`);
  console.log(`${colors.cyan}╚═══════════════════════════════════════════════════════╝${colors.reset}\n`);

  console.log(`${colors.green}✅ Secrets found: ${results.found.length}/${REQUIRED_SECRETS.length}${colors.reset}`);

  if (results.missing.length > 0) {
    console.log(`${colors.red}❌ Missing secrets: ${results.missing.length}${colors.reset}`);
    console.log(`\n${colors.yellow}Missing secrets:${colors.reset}`);
    results.missing.forEach(secret => {
      console.log(`   - ${secret}`);
    });
    console.log(`\n${colors.yellow}To create missing secrets, run:${colors.reset}`);
    results.missing.forEach(secret => {
      console.log(`   echo "YOUR_VALUE_HERE" | gcloud secrets create ${secret} --data-file=- --project=${projectId}`);
    });
  }

  if (results.errors.length > 0) {
    console.log(`${colors.yellow}⚠️  Secrets with issues: ${results.errors.length}${colors.reset}`);
    console.log(`\n${colors.yellow}Secrets needing attention:${colors.reset}`);
    results.errors.forEach(({ secretName, error }) => {
      console.log(`   - ${secretName}: ${error}`);
    });
  }

  console.log('');

  // Final recommendation
  if (results.missing.length === 0 && results.errors.length === 0) {
    console.log(`${colors.green}╔═══════════════════════════════════════════════════════╗${colors.reset}`);
    console.log(`${colors.green}║  ✅ All secrets are properly configured!              ║${colors.reset}`);
    console.log(`${colors.green}║  You're ready to deploy:                              ║${colors.reset}`);
    console.log(`${colors.green}║  firebase deploy --only functions                     ║${colors.reset}`);
    console.log(`${colors.green}╚═══════════════════════════════════════════════════════╝${colors.reset}\n`);
    process.exit(0);
  } else {
    console.log(`${colors.yellow}╔═══════════════════════════════════════════════════════╗${colors.reset}`);
    console.log(`${colors.yellow}║  ⚠️  Some secrets need attention before deploying     ║${colors.reset}`);
    console.log(`${colors.yellow}║  Please create/fix missing secrets first             ║${colors.reset}`);
    console.log(`${colors.yellow}╚═══════════════════════════════════════════════════════╝${colors.reset}\n`);
    process.exit(1);
  }
}

// Run verification
try {
  verifySecrets();
} catch (error) {
  console.error(`\n${colors.red}❌ Unexpected error: ${error.message}${colors.reset}\n`);
  process.exit(1);
}
