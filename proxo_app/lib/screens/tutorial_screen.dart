import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../main.dart' show supabase;
import '../widgets/proxo_toast.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TutorialScreen — فێرکاری
// ثومبنەیل یەک جار دابەزێت → وەک .jpg لە دایمی دەستگا مێنێتەوە
// دووەم جار ئینتەرنێت پێویست ناکات
// ─────────────────────────────────────────────────────────────────────────────
//
// ⚠️  pubspec.yaml — پاکێجەکانی پێویست:
//     http: ^1.2.0
//     path_provider: ^2.1.0
// ─────────────────────────────────────────────────────────────────────────────

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  List<Map<String, dynamic>> _tutorials = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTutorials();
  }

  Future<void> _loadTutorials() async {
    setState(() => _loading = true);
    try {
      final res = await supabase
          .from('pa_tutorials')
          .select('*')
          .order('created_at', ascending: true);
      if (mounted) {
        setState(() =>
            _tutorials = List<Map<String, dynamic>>.from(res ?? []));
      }
    } catch (_) {
      if (mounted) setState(() => _tutorials = _demoTutorials);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _demoTutorials => [
        {
          'id': '1',
          'title': 'چۆنیەتی دروستکردنی کەرەستەی پەیوەندی لەئەپی پرۆکسۆ',
          'section': 'دەستێک',
          'youtube_url': 'https://youtube.com/shorts/dQw4w9WgXcQ',
        },
        {
          'id': '2',
          'title': 'چۆنیەتی دروستکردنی ڕیکلامی نوێ لەئەپی پرۆکسۆ',
          'section': 'ڕیکلام',
          'youtube_url': 'https://youtube.com/shorts/dQw4w9WgXcQ',
        },
        {
          'id': '3',
          'title': 'چۆنیەتی خۆتۆماركردن لەئەپی پرۆکسۆ',
          'section': 'دەستێک',
          'youtube_url': 'https://youtube.com/shorts/dQw4w9WgXcQ',
        },
      ];

  // ── یوتیوب ئایدی دەردەهێنێت ──────────────────────────────
  static String? _ytVideoId(String url) {
    if (url.isEmpty) return null;
    final patterns = [
      RegExp(r'youtu\.be/([^?&\s]+)'),
      RegExp(r'youtube\.com/shorts/([^?&\s]+)'),
      RegExp(r'[?&]v=([^&\s]+)'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(url);
      if (m != null) return m.group(1);
    }
    return null;
  }

  Future<void> _openVideo(String youtubeUrl) async {
    if (youtubeUrl.isEmpty) return;
    final uri = Uri.parse(youtubeUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        showProxoToast(
          context,
          'نەتوانرا ڤیدیۆکە بکرێتەوە',
          type: ProxoToastType.error,
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: _loading ? _buildLoader() : _buildBody(),
        ),
      ),
    );
  }

  Widget _buildLoader() {
    return const Center(
      child: CircularProgressIndicator(
          color: AppColors.dark, strokeWidth: 2.5),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      color: AppColors.dark,
      onRefresh: _loadTutorials,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        children: [
          if (_tutorials.isEmpty)
            _buildEmpty()
          else
            ...List.generate(
              _tutorials.length,
              (i) => _buildTutCard(_tutorials[i], i),
            ),
        ],
      ),
    );
  }

  // ── Tutorial Card ─────────────────────────────────────────

  Widget _buildTutCard(Map<String, dynamic> tut, int index) {
    final title      = tut['title']?.toString() ?? 'فێرکاری';
    final youtubeUrl = tut['youtube_url']?.toString() ?? '';
    final videoId    = _ytVideoId(youtubeUrl);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 160 + index * 50),
      curve: Curves.easeOut,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
            offset: Offset(0, 12 * (1 - v)), child: child),
      ),
      child: GestureDetector(
        onTap: () => _openVideo(youtubeUrl),
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Thumbnail ──────────────────────────────────
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: videoId != null
                      ? _PersistentThumb(videoId: videoId)
                      : _thumbPlaceholder(),
                ),
              ),

              // ── Title ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Text(
                  title,
                  textAlign: TextAlign.right,
                  // cardTitle role: SemiBold not Bold; relaxed-band height
                  // since a video title can wrap to 2 lines, not the old 1.6
                  style: AppTypography.cardTitle(height: AppTypography.lineRelaxed),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      color: AppColors.bg,
      child: const Center(
        child: Icon(Icons.play_circle_fill_rounded,
            size: 48, color: AppColors.muted),
      ),
    );
  }

  // ── Empty ─────────────────────────────────────────────────

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: const Center(
                child: Icon(Icons.play_circle_outline_rounded,
                    size: 30, color: AppColors.muted),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'هیچ فێرکارییەک نەدۆزرایەوە',
              // sectionHeading role: SemiBold not Bold
              style: AppTypography.sectionHeading(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PersistentThumb
// یەک جار دابەزێت → وەک jpg لە getApplicationDocumentsDirectory مێنێتەوە
// دووەم جار ئینتەرنێت پێویست ناکات
// ─────────────────────────────────────────────────────────────────────────────

class _PersistentThumb extends StatefulWidget {
  const _PersistentThumb({required this.videoId});
  final String videoId;

  @override
  State<_PersistentThumb> createState() => _PersistentThumbState();
}

class _PersistentThumbState extends State<_PersistentThumb> {
  File?   _localFile;
  bool    _downloading = false;
  bool    _error       = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final dir  = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/yt_thumb_${widget.videoId}.jpg');

      // ئەگەر پێشتر مێنێتەوەبوو یەکسەر نیشان بدە
      if (await file.exists()) {
        if (mounted) setState(() => _localFile = file);
        return;
      }

      // نەبوو — دابەزێت و بیخەنە دیسک
      if (mounted) setState(() => _downloading = true);

      final thumbUrl =
          'https://img.youtube.com/vi/${widget.videoId}/hqdefault.jpg';
      final response = await http.get(Uri.parse(thumbUrl));

      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes, flush: true);
        if (mounted) setState(() { _localFile = file; _downloading = false; });
      } else {
        if (mounted) setState(() { _error = true; _downloading = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _error = true; _downloading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ فایلی دایمی بەردەستە
    if (_localFile != null) {
      return Image.file(
        _localFile!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }

    // ⏳ بارەکەشدایە
    if (_downloading) {
      return Container(
        color: AppColors.bg,
        child: const Center(
          child: CircularProgressIndicator(
              color: AppColors.dark, strokeWidth: 2),
        ),
      );
    }

    // ❌ هەڵە
    return Container(
      color: AppColors.bg,
      child: const Center(
        child: Icon(Icons.play_circle_fill_rounded,
            size: 48, color: AppColors.muted),
      ),
    );
  }
}
