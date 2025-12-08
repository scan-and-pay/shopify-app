# QR Scanner Testing Guide

## Overview

The app now includes a **QR Scanner** feature that allows users to scan payment QR codes and process payments. This is perfect for testing the end-to-end payment flow!

---

## 🎯 How It Works

### Flow:
1. **User A** (Merchant): Generates payment QR code
2. **User B** (Customer): Scans QR code with their device
3. **User B**: Confirms payment
4. **System**: Processes payment and updates status
5. **Both users**: See payment status update in real-time

---

## 📱 Features

### QR Scanner Screen
- ✅ Real-time camera scanning
- ✅ Flashlight toggle
- ✅ Payment confirmation dialog
- ✅ Amount and reference display
- ✅ Automatic navigation to payment status
- ✅ Error handling

### Security
- ✅ QR code format validation
- ✅ Payment ID verification
- ✅ Confirmation before payment
- ✅ Firebase Authentication required

---

## 🧪 Testing Guide

### Setup: Two Devices/Accounts

You need:
1. **Device A** (Merchant): Generate QR code
2. **Device B** (Customer): Scan QR code

### Step-by-Step Test

#### Device A (Merchant) - Generate Payment QR:

1. Open the app
2. On home screen, enter:
   - **Amount:** `50.00`
   - **Reference:** `Test Order #123`
3. Tap **"Generate Payment QR"**
4. QR code appears on screen
5. Keep this screen open for scanning

#### Device B (Customer) - Scan and Pay:

1. Open the app
2. Tap the **QR Scanner button** (top right, camera icon)
3. Allow camera permissions if prompted
4. Point camera at Device A's QR code
5. Wait for automatic scan
6. Review payment details:
   - Amount: $50.00
   - Reference: Test Order #123
7. Tap **"Pay Now"** to confirm
8. See "Processing payment..." message
9. Automatically navigate to Payment Status screen

#### Both Devices - Check Status:

1. **Device A**: Should show payment status update (pending → paid)
2. **Device B**: Shows payment status screen
3. Both see success animation when payment completes

---

## 🔍 QR Code Format

The app generates QR codes in this format:

```
payid://scan-and-pay?paymentId=TX_123456&amount=50.00&reference=Order%20123
```

### Parameters:
- `paymentId`: Unique transaction ID
- `amount`: Payment amount (decimal)
- `reference`: Payment description/reference

---

## 📲 UI Features

### Scanner Screen Elements

**Header:**
- Back button (top left)
- Flash toggle (top right)

**Center:**
- Camera view with overlay
- Scanning frame (highlights scannable area)

**Bottom:**
- Title: "Scan QR Code to Pay"
- Instructions
- Processing indicator (when scanning)
- Error messages (if scan fails)

### Payment Confirmation Dialog

Shows:
- Amount (large, formatted)
- Reference text
- "Cancel" button
- "Pay Now" button (green)

---

## 🐛 Troubleshooting

### Camera Not Working
**Problem:** Camera doesn't open or shows black screen

**Solutions:**
1. Check camera permissions in device settings
2. Make sure no other app is using the camera
3. Restart the app
4. Try on different device

### QR Code Not Scanning
**Problem:** Scanner doesn't detect QR code

**Solutions:**
1. Ensure good lighting
2. Hold steady for 2-3 seconds
3. Try adjusting distance (15-30cm works best)
4. Make sure QR code is in the frame
5. Toggle flashlight if too dark

### "Invalid QR Code" Error
**Problem:** Scanner detects QR but shows error

**Possible causes:**
- QR code is not from ScanPay app
- QR code format is incorrect
- QR code is expired

**Solution:** Generate new QR code from Device A

### Payment Fails
**Problem:** Payment confirmation shown but processing fails

**Check:**
1. Internet connection on both devices
2. Firebase authentication is active
3. Global Payments API is working
4. Check Firebase Functions logs

---

## 🔧 Permissions Required

### Android
Add to `AndroidManifest.xml` (already added):
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" />
```

### iOS
Add to `Info.plist` (needs to be added):
```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to scan payment QR codes</string>
```

---

## 💡 Testing Tips

### Test Different Scenarios

1. **Normal Payment:**
   - Amount: $10.00
   - Expected: Success

2. **Large Amount:**
   - Amount: $999.99
   - Expected: Confirmation dialog shows correctly

3. **Scan While Processing:**
   - Scan QR, then quickly scan another
   - Expected: Only first scan is processed

4. **Invalid QR Code:**
   - Scan non-payment QR (e.g., URL)
   - Expected: Error message shown

5. **Cancel Payment:**
   - Scan QR, then tap "Cancel"
   - Expected: Return to scanner, ready to scan again

### Test Camera Features

1. **Flash Toggle:**
   - Tap flash button
   - Expected: Light turns on/off

2. **Back Navigation:**
   - Tap back button
   - Expected: Return to home screen

3. **Auto-pause:**
   - Scan valid QR
   - Expected: Camera pauses during processing

---

## 📊 Expected Behavior

### Successful Scan Flow:
```
1. Camera opens
   ↓
2. User positions QR code
   ↓
3. Scanner detects QR (haptic feedback if available)
   ↓
4. Camera pauses
   ↓
5. Confirmation dialog appears
   ↓
6. User taps "Pay Now"
   ↓
7. Processing indicator shows
   ↓
8. Navigate to Payment Status screen
   ↓
9. Status updates automatically
```

### Error Flow:
```
1. Camera opens
   ↓
2. Invalid QR detected
   ↓
3. Error message shows (red box at bottom)
   ↓
4. Camera resumes
   ↓
5. Ready to scan again
```

---

## 🚀 Production Checklist

Before deploying scanner to production:

- [ ] Test on multiple devices (Android & iOS)
- [ ] Test in different lighting conditions
- [ ] Test camera permissions flow
- [ ] Test with various QR code sizes
- [ ] Test error handling
- [ ] Add iOS camera permission description
- [ ] Implement actual Global Payments processing
- [ ] Add analytics/logging
- [ ] Test payment status updates
- [ ] Security audit of QR code parsing

---

## 🔐 Security Considerations

### Current Implementation:
✅ QR code format validation
✅ Payment confirmation required
✅ Firebase Auth required
✅ Parameters extracted safely

### TODO for Production:
- [ ] Add QR code signature/HMAC
- [ ] Implement payment expiry check
- [ ] Add rate limiting
- [ ] Verify merchant ID
- [ ] Implement fraud detection
- [ ] Add maximum amount limits

---

## 📝 Code Files

### New Files Created:
- `lib/screens/qr_scanner_screen.dart` - Scanner screen UI and logic

### Modified Files:
- `lib/screens/kiosk_home_screen.dart` - Added scanner button

### Dependencies Used:
- `qr_code_scanner_plus: ^2.0.12` - Already in pubspec.yaml

---

## 🎨 UI Improvements (Future)

Possible enhancements:
- Haptic feedback on successful scan
- Sound effect on scan
- Animated scan line
- Multiple QR codes detection
- Gallery scanning (pick image)
- Manual entry option
- Recent scans history
- Favorite merchants

---

## 📱 Testing on Real Devices

### Recommended Test Devices:
1. **Android:** Any device with Android 6.0+ and camera
2. **iOS:** Any device with iOS 11.0+ and camera

### Emulator Testing:
❌ **Cannot test on emulators** - Camera access required

### Alternative: QR Code Image
If you only have one device:
1. Generate QR on Device A
2. Screenshot the QR code
3. Display on computer screen
4. Scan from Device B

---

## 📖 User Instructions

### For Merchants:
1. Open app
2. Enter amount and reference
3. Tap "Generate Payment QR"
4. Show QR to customer
5. Wait for payment confirmation

### For Customers:
1. Open app
2. Tap QR scanner icon (top right)
3. Point camera at merchant's QR
4. Review payment details
5. Tap "Pay Now"
6. Wait for confirmation

---

## 🎉 Success Criteria

Test is successful when:
✅ QR code scans quickly (< 2 seconds)
✅ Payment details display correctly
✅ Confirmation dialog works
✅ Payment processes without errors
✅ Status updates on both devices
✅ Camera pauses/resumes correctly
✅ Error handling works
✅ Flash toggle works

---

## 🆘 Getting Help

### Check Logs:
```bash
# Flutter logs
flutter logs

# Filter for payment
flutter logs | grep -i "payment\|qr\|scan"
```

### Debug Mode:
Look for these console messages:
- `📱 Scanned QR Code: ...`
- `💰 Processing payment: ...`
- `❌ Error processing QR code: ...`

### Common Issues:
1. **Camera permission denied**: Check device settings
2. **QR not scanning**: Lighting/distance/focus
3. **Invalid format**: Wrong QR code type
4. **Payment fails**: Check Firebase/API status

---

## ✅ Ready to Test!

**Next Steps:**
1. Build the app: `flutter run`
2. Open on two devices
3. Follow the testing guide above
4. Generate QR on Device A
5. Scan with Device B
6. Watch the magic happen! 🎉

**Happy Testing!** 🚀
