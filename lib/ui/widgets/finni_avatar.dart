import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class FinniAvatar extends StatelessWidget {
  final double size;

  const FinniAvatar({super.key, this.size = 140});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/finni.svg',
      width: size,
      height: size,
    );
  }
}
