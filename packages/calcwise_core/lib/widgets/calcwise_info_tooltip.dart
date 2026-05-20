import 'package:flutter/material.dart';

/// A small info icon that opens a dialog with a title and body text.
/// Drop-in replacement for app-local InfoTooltip widgets across the portfolio.
class CalcwiseInfoTooltip extends StatelessWidget {
  final String title;
  final String body;
  final double iconSize;
  final String okLabel;

  const CalcwiseInfoTooltip({
    super.key,
    required this.title,
    required this.body,
    this.iconSize = 16,
    this.okLabel = 'OK',
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Information about $title',
      hint: 'Double tap for details',
      child: GestureDetector(
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            content: Text(body,
                style: const TextStyle(fontSize: 14, height: 1.5)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(okLabel),
              ),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Icon(Icons.info_outline,
              size: iconSize, color: const Color(0xFF94A3B8)),
        ),
      ),
    );
  }
}
