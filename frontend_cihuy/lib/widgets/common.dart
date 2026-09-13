import 'package:flutter/material.dart';
import '../models/records.dart';
import '../utils/app_theme.dart';
import 'asset_icon.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 68});
  final double size;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * .25),
    child: Image.asset(
      'assets/icon-app.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
      semanticLabel: 'Logo CIHUY',
    ),
  );
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: CihuyColors.border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x08000000),
          blurRadius: 5,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(17),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleSmall),
      ),
      ?trailing,
    ],
  );
}

class IconTile extends StatelessWidget {
  const IconTile(
    this.icon, {
    super.key,
    this.color = CihuyColors.tealInk,
    this.background = CihuyColors.paleTeal,
    this.size = 34,
  }) : child = null;
  const IconTile.child(
    this.child, {
    super.key,
    this.color = CihuyColors.tealInk,
    this.background = CihuyColors.paleTeal,
    this.size = 34,
  }) : icon = null;
  final IconData? icon;
  final Widget? child;
  final Color color;
  final Color background;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Center(
      child: IconTheme(
        data: IconThemeData(color: color, size: size * .52),
        child: child ?? Icon(icon),
      ),
    ),
  );
}

Widget habitIcon(Habit habit) => habit == Habit.cigarette
    ? const CihuyAssetIcon(CihuyAssetIcon.smoking)
    : const Icon(Icons.air_rounded);

class HabitSelector extends StatelessWidget {
  const HabitSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final Habit value;
  final ValueChanged<Habit> onChanged;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final habit in Habit.values) ...[
        if (habit.index > 0) const SizedBox(width: 8),
        Expanded(
          child: ChoiceButton(
            selected: value == habit,
            label: habit.label,
            icon: habitIcon(habit),
            onTap: () => onChanged(habit),
          ),
        ),
      ],
    ],
  );
}

class ChoiceButton extends StatelessWidget {
  const ChoiceButton({
    super.key,
    required this.selected,
    required this.label,
    required this.onTap,
    this.icon,
    this.activeColor = CihuyColors.teal,
    this.activeText = Colors.white,
  });
  final bool selected;
  final String label;
  final VoidCallback onTap;
  final Widget? icon;
  final Color activeColor;
  final Color activeText;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        backgroundColor: selected ? activeColor : Colors.white,
        foregroundColor: selected ? activeText : CihuyColors.muted,
        side: BorderSide(color: selected ? activeColor : CihuyColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            IconTheme.merge(data: const IconThemeData(size: 17), child: icon!),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.optional = false});
  final String text;
  final bool optional;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text.rich(
      TextSpan(
        text: text,
        children: [
          if (optional)
            const TextSpan(
              text: ' (opsional)',
              style: TextStyle(color: CihuyColors.muted),
            ),
        ],
      ),
    ),
  );
}

class EmptyMessage extends StatelessWidget {
  const EmptyMessage(
    this.message, {
    super.key,
    this.icon = Icons.notes_rounded,
  });
  final String message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Column(
      children: [
        Icon(icon, size: 28, color: CihuyColors.muted.withValues(alpha: .5)),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

class ExceededBadge extends StatelessWidget {
  const ExceededBadge({
    super.key,
    required this.total,
    required this.limit,
    required this.habit,
  });
  final int total;
  final int limit;
  final Habit habit;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: CihuyColors.pink,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.close_rounded, size: 14, color: CihuyColors.red),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            'Melampaui batas · $total/$limit ${habit.unit}',
            style: const TextStyle(fontSize: 12, color: CihuyColors.red),
          ),
        ),
      ],
    ),
  );
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirm = 'Hapus',
  bool destructive = true,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: destructive
                  ? CihuyColors.red
                  : CihuyColors.tealInk,
            ),
            child: Text(confirm),
          ),
        ],
      ),
    ) ??
    false;

/// A single scrollable sheet, including its save action, stays above the keyboard.
Future<T?> openSheet<T>(BuildContext context, Widget child) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: Colors.black.withValues(alpha: .48),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
            child: child,
          ),
        ),
      ),
    );

class SheetHeading extends StatelessWidget {
  const SheetHeading(this.title, {super.key, this.subtitle});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Center(
        child: Container(
          width: 38,
          height: 4,
          margin: const EdgeInsets.only(bottom: 18),
          decoration: BoxDecoration(
            color: CihuyColors.border,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      if (subtitle != null) ...[
        const SizedBox(height: 5),
        Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
      ],
      const SizedBox(height: 18),
    ],
  );
}
