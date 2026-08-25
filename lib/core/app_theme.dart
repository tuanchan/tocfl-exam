import 'package:flutter/material.dart';

abstract final class AppColors {
  static const red = Color(0xFFC62828);
  static const blue = Color(0xFF1557B0);
  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);
  static const darkBlue = Color(0xFF071A35);
  static const attemptedYellow = Color(0xFFFFD54F);
}

abstract final class AppTheme {
  static ThemeData get light => _create(Brightness.light);
  static ThemeData get dark => _create(Brightness.dark);

  static ThemeData _create(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final background = dark ? AppColors.black : AppColors.white;
    final foreground = dark ? AppColors.white : AppColors.darkBlue;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: AppColors.blue,
        onPrimary: AppColors.white,
        secondary: AppColors.red,
        onSecondary: AppColors.white,
        error: AppColors.red,
        onError: AppColors.white,
        surface: background,
        onSurface: foreground,
      ),
      dividerColor: AppColors.blue.withValues(alpha: 0.28),
      textTheme: ThemeData(brightness: brightness).textTheme.apply(
        bodyColor: foreground,
        displayColor: foreground,
        fontFamily: 'Arial',
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: foreground,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: foreground,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: background,
        border: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.blue),
        ),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.blue),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.red, width: 2),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.blue,
        inactiveTrackColor: AppColors.white,
        thumbColor: AppColors.red,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.blue
              : background,
        ),
        side: const BorderSide(color: AppColors.blue, width: 2),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.blue
              : foreground,
        ),
      ),
    );
  }
}

class AppTextButton extends StatelessWidget {
  const AppTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.danger = false,
    this.selected = false,
    this.expand = false,
    this.compact = false,
    this.filled = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool danger;
  final bool selected;
  final bool expand;
  final bool compact;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final solid = selected || filled;
    final accent = danger ? AppColors.red : AppColors.blue;
    final background = solid ? accent : Colors.transparent;
    final foreground = solid ? AppColors.white : accent;
    final button = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        backgroundColor: background,
        side: BorderSide(
          color: selected && filled ? AppColors.attemptedYellow : accent,
          width: selected && filled ? 2 : 1,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 18,
          vertical: compact ? 9 : 14,
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
      child: Text(label, textAlign: TextAlign.center),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class AppSection extends StatelessWidget {
  const AppSection({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border.all(color: AppColors.blue.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}
