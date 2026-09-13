import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CihuyAssetIcon extends StatelessWidget {
  const CihuyAssetIcon(this.asset, {super.key});

  static const calendar = 'assets/calendar-day.svg';
  static const profile = 'assets/user.svg';
  static const cravingResisted = 'assets/user-heart.svg';
  static const smoking = 'assets/smoking.svg';
  static const smokingBan = 'assets/smoking-ban.svg';

  final String asset;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final color = iconTheme.color ?? Colors.black;
    final size = iconTheme.size ?? 24;
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      excludeFromSemantics: true,
    );
  }
}
