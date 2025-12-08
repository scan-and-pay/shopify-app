import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:scan__pay/theme.dart';

class AnimatedQRCode extends StatefulWidget {
  final String data;
  final double size;
  final bool isDemo;
  
  const AnimatedQRCode({
    super.key,
    required this.data,
    this.size = 200,
    this.isDemo = false,
  });
  
  @override
  State<AnimatedQRCode> createState() => _AnimatedQRCodeState();
}

class _AnimatedQRCodeState extends State<AnimatedQRCode>
    with SingleTickerProviderStateMixin {
  late AnimationController _borderController;
  late Animation<Color?> _borderColorAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _borderController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    _borderColorAnimation = ColorTween(
      begin: LightModeColors.lightPrimary,
      end: LightModeColors.lightSecondary,
    ).animate(CurvedAnimation(
      parent: _borderController,
      curve: Curves.easeInOut,
    ));
    
    if (widget.isDemo) {
      _borderController.repeat(reverse: true);
    } else {
      _borderController.stop();
      _borderController.reset();
    }
  }
  
  @override
  void didUpdateWidget(AnimatedQRCode oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isDemo != oldWidget.isDemo) {
      if (widget.isDemo) {
        _borderController.repeat(reverse: true);
      } else {
        _borderController.stop();
        _borderController.reset();
      }
    }
  }
  
  @override
  void dispose() {
    _borderController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _borderColorAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            border: Border.all(
              color: widget.isDemo 
                  ? (_borderColorAnimation.value ?? LightModeColors.lightPrimary)
                  : LightModeColors.lightPrimary,
              width: 3,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: QrImageView(
              data: widget.data,
              version: QrVersions.auto,
              size: widget.size,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.all(16),
              errorCorrectionLevel: QrErrorCorrectLevel.M,
              embeddedImage: widget.isDemo ? null : null, // Could add logo here
              embeddedImageStyle: const QrEmbeddedImageStyle(
                size: Size(40, 40),
              ),
              gapless: false,
              semanticsLabel: widget.isDemo 
                  ? 'Demo QR Code for Scan & Pay'
                  : 'Payment QR Code',
            ),
          ),
        );
      },
    );
  }
}