import 'package:flutter/material.dart';

/// The Hisaab logo (shop awning + ₹ + khata book, tiranga colours).
class HisaabLogo extends StatelessWidget {
  const HisaabLogo({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/logo.png',
        width: size,
        height: size,
        filterQuality: FilterQuality.medium,
        semanticLabel: 'Hisaab',
      );
}
