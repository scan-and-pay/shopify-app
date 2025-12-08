import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

class SecondScreenService {
  static const platform = MethodChannel('au.com.scanandpay.app/second_screen');
  static bool _initialized = false;
  static bool _available = false;

  static Future<bool> initialize() async {
    if (_initialized) return _available;
    try {
      final bool result = await platform.invokeMethod('initialize');
      _initialized = true;
      _available = result;
      return result;
    } catch (e) {
      debugPrint('Second screen init error: $e');
      return false;
    }
  }

  static Future<void> showQR({required String qrData, String? title, String? amount}) async {
    if (!await initialize()) return;
    try {
      final qrBytes = await _generateQRImage(qrData);
      await platform.invokeMethod('showQR', {
        'qrImage': qrBytes,
        'title': title,
        'amount': amount,
      });
    } catch (e) {
      debugPrint('Error displaying QR: $e');
    }
  }

  static Future<void> clear() async {
    if (!_available) return;
    try {
      await platform.invokeMethod('clear');
    } catch (e) {
      debugPrint('Error clearing screen: $e');
    }
  }

  static Future<Uint8List> _generateQRImage(String data) async {
    final validation = QrValidator.validate(
      data: data,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
    );
    if (validation.status != QrValidationStatus.valid) throw Exception('Invalid QR');

    final painter = QrPainter.withQr(
      qr: validation.qrCode!,
      color: const Color(0xFF000000),
      emptyColor: const Color(0xFFFFFFFF),
      gapless: false,
    );

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    painter.paint(canvas, const Size(300, 300));
    final picture = recorder.endRecording();
    final img = await picture.toImage(300, 300);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}
