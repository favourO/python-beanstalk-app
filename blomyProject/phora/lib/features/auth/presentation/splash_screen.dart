import 'package:phora/core/ui/phora_loading.dart';
import 'package:phora/core/ui/app_theme.dart';
import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.bg, colors.bgElevated],
          ),
        ),
        child: Center(child: PhoraLoadingView(size: 128)),
      ),
    );
  }
}
