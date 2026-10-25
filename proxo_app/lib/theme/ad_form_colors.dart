import 'package:flutter/material.dart';

/// Optional form palette. Shared controls keep their existing colors when the
/// extension is absent, including Meta, checkout, Auth, and receipts.
@immutable
class AdFormColors extends ThemeExtension<AdFormColors> {
  const AdFormColors({
    required this.primary,
    required this.ink,
    required this.muted,
    required this.line,
    required this.surface,
    required this.selectedFill,
    required this.selectedLine,
  });

  final Color primary, ink, muted, line, surface, selectedFill, selectedLine;

  static AdFormColors? of(BuildContext context) =>
      Theme.of(context).extension<AdFormColors>();

  @override
  AdFormColors copyWith({
    Color? primary,
    Color? ink,
    Color? muted,
    Color? line,
    Color? surface,
    Color? selectedFill,
    Color? selectedLine,
  }) =>
      AdFormColors(
        primary: primary ?? this.primary,
        ink: ink ?? this.ink,
        muted: muted ?? this.muted,
        line: line ?? this.line,
        surface: surface ?? this.surface,
        selectedFill: selectedFill ?? this.selectedFill,
        selectedLine: selectedLine ?? this.selectedLine,
      );

  @override
  AdFormColors lerp(AdFormColors? other, double t) {
    if (other == null) return this;
    return AdFormColors(
      primary: Color.lerp(primary, other.primary, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      line: Color.lerp(line, other.line, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      selectedFill: Color.lerp(selectedFill, other.selectedFill, t)!,
      selectedLine: Color.lerp(selectedLine, other.selectedLine, t)!,
    );
  }
}
