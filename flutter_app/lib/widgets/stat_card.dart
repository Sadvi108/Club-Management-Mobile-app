import 'package:flutter/material.dart';

class StatCell extends StatelessWidget {
  final String value, label;
  const StatCell({super.key, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 10, letterSpacing: 0.5)),
        ],
      ),
    );
  }
}
