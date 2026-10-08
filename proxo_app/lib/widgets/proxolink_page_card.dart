import 'package:flutter/material.dart';

import '../models/proxo_card.dart';
import '../models/proxolink_design.dart';
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

class ProxoLinkPageCard extends StatelessWidget {
  final ProxoCard page;
  final ProxoLinkRepository repository;
  final bool busy;
  final VoidCallback onOpen, onMore, onPublic, onUse, onRetry;
  const ProxoLinkPageCard({
    super.key,
    required this.page,
    required this.repository,
    required this.busy,
    required this.onOpen,
    required this.onMore,
    required this.onPublic,
    required this.onUse,
    required this.onRetry,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: AdUi.radius,
    child: InkWell(
      onTap: busy ? null : onOpen,
      borderRadius: AdUi.radius,
      child: Container(
        padding: AdUi.cardPadding,
        decoration: const BoxDecoration(
          borderRadius: AdUi.radius,
          boxShadow: AdUi.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProxoLinkPageImage(page: page, repository: repository),
                const SizedBox(width: 12),
                Expanded(
                  child: ProxoText(
                    page.name,
                    style: AdUi.text(context),
                    maxLines: 3,
                  ),
                ),
                IconButton(
                  onPressed: busy ? null : onMore,
                  tooltip: 'زیاتر',
                  icon: const Icon(Icons.more_horiz),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: ProxoText(page.pageType.label)),
                Chip(label: ProxoText(ProxoLinkDesign.label(page.templateKey))),
                Chip(label: ProxoText(page.stateLabel)),
              ],
            ),
            ProxoText(
              'دروستکراو: ${pageDate(page.createdAt)}',
              style: AdUi.text(context, color: AdUi.secondary),
            ),
            ProxoText(
              'نوێکراوە: ${pageDate(page.updatedAt)}',
              style: AdUi.text(context, color: AdUi.secondary),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: busy ? null : onOpen,
                  child: const ProxoText('بەڕێوەبردن'),
                ),
                if (page.available)
                  OutlinedButton(
                    onPressed: busy ? null : onPublic,
                    child: const ProxoText('کردنەوەی پەڕە'),
                  ),
                if (page.available)
                  FilledButton(
                    onPressed: busy ? null : onUse,
                    child: const ProxoText('ڕیکلام'),
                  ),
                if (page.canRetry)
                  FilledButton(
                    onPressed: busy ? null : onRetry,
                    child: const ProxoText('دووبارە هەوڵبدەرەوە'),
                  ),
                if (busy || page.publishStatus == 'creating')
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class ProxoLinkPageSkeleton extends StatelessWidget {
  const ProxoLinkPageSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'بارکردنی پەڕەکان',
    child: Container(
      margin: const EdgeInsets.only(bottom: 22),
      padding: AdUi.cardPadding,
      decoration: const BoxDecoration(
        color: AdUi.controlSurface,
        borderRadius: AdUi.radius,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: CircleAvatar(radius: 24, backgroundColor: AdUi.controlLine),
          ),
          SizedBox(height: 16),
          ColoredBox(color: AdUi.controlLine, child: SizedBox(height: 18)),
          SizedBox(height: 12),
          ColoredBox(color: AdUi.controlLine, child: SizedBox(height: 18)),
        ],
      ),
    ),
  );
}
