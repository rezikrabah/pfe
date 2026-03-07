import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'Homepage.dart';
class AnimatedSplashScreenWidget extends StatelessWidget {
  const AnimatedSplashScreenWidget({super.key,});
  @override
  Widget build(BuildContext context) {
    return AnimatedSplashScreen(
      nextScreen:Homepage(),
      splashIconSize: 200,
      splash: Center(
        child: Lottie.asset('assets/animation_12.json'),
      ),
    );
  }
}
