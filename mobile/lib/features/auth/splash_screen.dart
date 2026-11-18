import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:clac_mobile/core/app_theme.dart';
import 'package:clac_mobile/shared/widgets.dart';

/// Branded launch screen shown while the stored session is restored,
/// before the welcome/login screens.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: SizedBox.expand(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [pineDark, pine],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 112,
                    height: 112,
                    child: CustomPaint(painter: ClacMarkPainter()),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'CLAC',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Consommateurs Liés Aux Collecteurs',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFD3E4D8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 56),
                  const Text(
                    'Developped By',
                    style: TextStyle(
                      color: Color(0xFFB2C9BA),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'GreenMinds',
                    style: TextStyle(
                      color: Color(0xFFF5C77C),
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
