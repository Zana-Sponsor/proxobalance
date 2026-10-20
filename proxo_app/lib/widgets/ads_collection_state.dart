import 'package:flutter/material.dart';
import 'package:solar_iconkit/solar_iconkit.dart';
import '../theme/proxo_ui.dart';
import 'proxo_empty_state.dart';

/// Shared with Pages, with separate copy/actions for a filter with no matches.
class AdsEmptyState extends StatelessWidget {
  final bool filtered;
  final VoidCallback onAction;
  const AdsEmptyState(
      {super.key, this.filtered = false, required this.onAction});
  @override
  Widget build(BuildContext context) => ProxoEmptyState(
        icon: const SolarIcon(SolarIcons.target,
            style: SolarIconStyle.linear, size: 32, color: ProxoUi.primary),
        title:
            filtered ? 'هیچ ئەنجامێک نەدۆزرایەوە' : 'هێشتا هیچ ڕیکلامێک نییە!',
        description: filtered
            ? 'لە ئەم دۆخەدا ڕیکلامێک نییە. هەموو ڕیکلامەکان ببینە.'
            : 'یەکەم ڕیکلامەکەت دروست بکە؛ ئەنجام و دۆخی کەمپەینەکانت لێرە ببینە.',
        actionLabel: filtered ? 'بینینی هەموو ڕیکلامەکان' : 'دروستکردنی ڕیکلام',
        onAction: onAction,
      );
}

class AdsErrorState extends StatelessWidget {
  final bool offline;
  final String message;
  final VoidCallback onRetry;
  const AdsErrorState(
      {super.key,
      this.offline = false,
      required this.message,
      required this.onRetry});
  @override
  Widget build(BuildContext context) => ProxoEmptyState(
        icon: const SolarIcon(SolarIcons.dangerTriangle,
            style: SolarIconStyle.linear, size: 32, color: Color(0xFFDC2626)),
        title: offline ? 'پەیوەندی نییە' : 'ڕیکلامەکان بار نەبوون',
        description: message,
        actionLabel: 'دووبارە هەوڵ بدەرەوە',
        onAction: onRetry,
      );
}
