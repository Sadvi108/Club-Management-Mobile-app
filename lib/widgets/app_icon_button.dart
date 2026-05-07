import 'package:flutter/material.dart';

class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final double size;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
    this.size = 42,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(size / 2),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Icon(icon, color: foregroundColor, size: 20),
      ),
    );
  }
}

