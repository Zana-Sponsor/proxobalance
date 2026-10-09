import 'package:flutter/material.dart';

import '../models/proxo_card.dart';
import '../models/proxolink_page_type.dart';
import '../services/proxolink_service.dart';
import 'ad_form_components.dart';
import 'proxo_text.dart';

String pageDate(DateTime date) {
  final d = date.toLocal();
  return '${d.year}/${d.month}/${d.day}';
}

/// A small owner-authorized image request, never a WebView or template source.
class ProxoLinkPageImage extends StatefulWidget {
  final ProxoCard page;
  final ProxoLinkRepository repository;
  const ProxoLinkPageImage({
    super.key,
    required this.page,
    required this.repository,
  });
  @override
  State<ProxoLinkPageImage> createState() => _ProxoLinkPageImageState();
}

class _ProxoLinkPageImageState extends State<ProxoLinkPageImage> {
  late Future<Uri?> _image;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _image = widget.repository.avatar(widget.page);
  }

  @override
  void didUpdateWidget(covariant ProxoLinkPageImage old) {
    super.didUpdateWidget(old);
    if (old.page.id != widget.page.id ||
        old.page.updatedAt != widget.page.updatedAt ||
        old.repository != widget.repository)
      _load();
  }

  Widget get _fallback => Icon(switch (widget.page.pageType) {
    ProxoPageType.contact => Icons.person_outline,
    ProxoPageType.order => Icons.restaurant_outlined,
    ProxoPageType.download => Icons.apps_outlined,
  }, color: AdUi.secondary);
  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 24,
    backgroundColor: AdUi.controlSurface,
    child: ClipOval(
      child: FutureBuilder<Uri?>(
        future: _image,
        builder: (context, snapshot) => snapshot.data == null
            ? _fallback
            : Image.network(
                snapshot.data.toString(),
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback,
              ),
      ),
    ),
  );
}

/// Quiet value-only owner card. No per-row image, provider or WebView requests.
class ProxoLinkPageCard extends StatelessWidget {
  final ProxoCard page;
  final bool busy;
  final VoidCallback onPreview, onDelete;
  const ProxoLinkPageCard({super.key, required this.page, this.busy = false,
    required this.onPreview, required this.onDelete});
  @override
  Widget build(BuildContext context) => Container(
    padding: AdUi.cardPadding,
    decoration: const BoxDecoration(color: Colors.white, borderRadius: AdUi.radius,
      boxShadow: AdUi.cardShadow),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ProxoText(page.name, maxLines: 3, overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w400)),
      const SizedBox(height: 10),
      Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        ProxoText(page.pageType.label, style: AdUi.text(context, color: AdUi.secondary)),
        if (page.moderationLabel.isNotEmpty) _ModerationBadge(page: page),
      ]),
      const SizedBox(height: 16),
      Semantics(label: page.id, child: Text(page.id, textDirection: TextDirection.ltr,
        maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall!
          .copyWith(color: AdUi.secondary))),
      const SizedBox(height: 6),
      Wrap(spacing: 14, runSpacing: 4, children: [
        Text(pageDate(page.createdAt), textDirection: TextDirection.ltr,
          style: AdUi.text(context, color: AdUi.secondary)),
        Text(_time(page.createdAt), textDirection: TextDirection.ltr,
          style: AdUi.text(context, color: AdUi.secondary)),
      ]),
      const SizedBox(height: 20),
      LayoutBuilder(builder: (context, box) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final stacked = box.maxWidth < 240 * scale;
        final preview = FilledButton(onPressed: busy ? null : onPreview,
          child: const ProxoText('پێشبینین'));
        final delete = OutlinedButton(onPressed: busy ? null : onDelete,
          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFB74956)),
          child: const ProxoText('سڕینەوە'));
        return stacked ? Column(crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [preview, const SizedBox(height: 10), delete]) : Row(children: [
            Expanded(child: preview), const SizedBox(width: 12), Expanded(child: delete)]);
      }),
    ]),
  );
  static String _time(DateTime value) {
    final t = value.toLocal();
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}
class _ModerationBadge extends StatelessWidget {
  final ProxoCard page;
  const _ModerationBadge({required this.page});
  @override
  Widget build(BuildContext context) {
    final color = switch (page.moderationStatus) {
      'approved' => AdUi.green, 'rejected' => const Color(0xFFB74956),
      _ => const Color(0xFF966518),
    };
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: .07), borderRadius: BorderRadius.circular(8)),
      child: ProxoText(page.moderationLabel, style: AdUi.text(context, color: color)));
  }
}
class ProxoLinkPageSkeleton extends StatelessWidget {
  const ProxoLinkPageSkeleton({super.key});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(child: Container(
    padding: AdUi.cardPadding, decoration: const BoxDecoration(color: Colors.white,
      borderRadius: AdUi.radius, boxShadow: AdUi.cardShadow),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final width in [180.0, 140.0, 220.0, 140.0]) ...[
        FractionallySizedBox(widthFactor: width / 260, child: Container(height: 18,
          decoration: const BoxDecoration(color: AdUi.controlLine, borderRadius: AdUi.controlRadius))),
        const SizedBox(height: 12),
      ],
      Container(height: 52, decoration: const BoxDecoration(color: AdUi.controlLine,
        borderRadius: AdUi.controlRadius)),
    ])));
}
