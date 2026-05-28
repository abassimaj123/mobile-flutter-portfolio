import 'package:flutter/material.dart';
import '../theme/tokens/tokens.dart';

class CalcwiseSettingsScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? bottomNavigationBar;

  const CalcwiseSettingsScaffold({
    super.key,
    required this.title,
    required this.children,
    this.bottomNavigationBar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        scrolledUnderElevation: 0,
        elevation: 0,
      ),
      bottomNavigationBar: bottomNavigationBar,
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: children,
        ),
      ),
    );
  }
}

class CalcwiseSettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const CalcwiseSettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: AppTextSize.xs,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1.0,
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}

class CalcwiseSettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final String? trailing;       // e.g. "\$2.99" for price display
  final VoidCallback? onTap;
  final bool destructive;

  const CalcwiseSettingsTile({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: trailing == null
        ? const Icon(Icons.chevron_right_rounded, size: 20)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(trailing!, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
      onTap: onTap,
    );
  }
}
