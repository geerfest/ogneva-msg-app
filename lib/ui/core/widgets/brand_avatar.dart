import 'package:flutter/material.dart';
import 'package:ogneva_msg_app/ui/core/theme/app_colors.dart';

class BrandAvatar extends StatelessWidget {
  const BrandAvatar({
    super.key,
    required this.label,
    this.size = 44,
    this.icon,
  });

  final String label;
  final double size;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final initials = label
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.characters.first.toUpperCase())
        .join();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primaryBlue,
        borderRadius: BorderRadius.circular(size / 2),
      ),
      alignment: Alignment.center,
      child: icon == null
          ? Text(
              initials.isEmpty ? 'O' : initials,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.34,
              ),
            )
          : Icon(icon, color: Colors.white, size: size * 0.48),
    );
  }
}
