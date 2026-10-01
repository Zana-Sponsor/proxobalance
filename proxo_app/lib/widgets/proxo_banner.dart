// proxo_banner.dart
// بیخەرە ناو:  lib/widgets/proxo_banner.dart
//
// ── pubspec.yaml ─────────────────────────────────────────────────────────────
//   dependencies:
//     firebase_core:           ^3.6.0
//     firebase_database:       ^11.1.4
//     supabase_flutter:        ^2.5.6
//     cached_network_image:    ^3.3.1
//     flutter_cache_manager:   ^3.3.1
//     shared_preferences:      ^2.3.2
//     connectivity_plus:       ^6.0.5   ← تازە زیادکرا (Offline Banner)
//
// ── بەکارهێنان لە HomeScreen ─────────────────────────────────────────────────
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Stack(
//         children: [
//           // ناوەڕۆکی ئاساییت لێرە
//           SafeArea(
//             child: SingleChildScrollView(
//               child: Column(
//                 children: [
//                   ProxoBanner(
//                     onStart:    () => goPage('create'),
//                     onNavigate: (page) => goPage(page),
//                   ),
//                   // ... باقی widget ەکانت
//                 ],
//               ),
//             ),
//           ),
//           // Offline Banner دوای هەموو شتێک (لەسەرەوە)
//           const OfflineBanner(),
//         ],
//       ),
//     );
//   }
//
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';   // ← compute()
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import '../theme/app_theme.dart';
import 'proxo_error_ui.dart';
import '../main.dart' show supabase, firebaseAvailable;

// ─────────────────────────────────────────────────────────────────────────────
// FIX 1 — Shared CacheManager singleton
//
// Using a single CacheManager instance across all banner widgets means:
//   • One shared LRU memory cache (no duplicate downloads)
//   • One SQLite connection (no redundant DB opens)
//   • 7-day disk TTL so banners survive app restarts
// ─────────────────────────────────────────────────────────────────────────────

// isolate function بۆ base64 decode — پێویستە top-level بێت
Uint8List _decodeB64Isolate(String raw) => base64Decode(raw);

// ─────────────────────────────────────────────────────────────────────────────
// مێموری بایتسی وێنەکان — گلۆبال، تا app بەخۆی بگردرێتەوە دەمێنێتەوە
//
// کاتێک _prewarmImages بایتسی وێنەیەک دەخوێنێتەوە، لێرە پاشەکەوت دەکات.
// _NetImg.build() یەکەم ئەمەی پشکنێ — ئەگەر بایتس هەبوو، Image.memory()
// یەکسەر نیشان دەدات بەبێ هیچ I/O یان async.
// ─────────────────────────────────────────────────────────────────────────────
final Map<String, Uint8List> _sImageBytes = {};

// ─────────────────────────────────────────────────────────────────────────────
// Top-level constants & helpers (دەرەوەی هەموو کلاسەکان)
// ─────────────────────────────────────────────────────────────────────────────

const _kCacheFb      = 'proxo_banner_fb_v3';
const _kCacheSupa    = 'proxo_banner_supa_v3';
const _kDeviceId     = 'proxo_device_id';
const _kCacheVersion = 'proxo_banner_cache_ver';
const _kCacheTs      = 'proxo_banner_cache_ts';
// ئەم ژمارەیە بگۆڕە کاتێک بانەری نوێ بنێری — کاچی کۆن پاک دەکاتەوە
const _kCurrentVer   = '1';
// کاچ دوای ٧ ڕۆژ کۆنە دەبێت — ئینتەرنێت هەبوو نوێ دەکاتەوە، نەبوو کاچ دەخوێنێتەوە
const _kCacheTtlMs   = 7 * 24 * 60 * 60 * 1000;

// ── Device ID — ئایدی ڕاستەقینەی مۆبایل دەخوێنێتەوە ──
String? _sDeviceId;

Future<String> _getOrCreateDeviceId() async {
  // ① مێموری — خێراترین، بەبێ هیچ I/O
  if (_sDeviceId != null) return _sDeviceId!;

  final prefs = await SharedPreferences.getInstance();

  // ② SharedPreferences — پاشەکەوتراوی جاری پێشتر (بەبێ ئینتەرنێت، بەبێ Hardware)
  final saved = prefs.getString(_kDeviceId);
  if (saved != null && saved.isNotEmpty) {
    _sDeviceId = saved;
    return _sDeviceId!;
  }

  // ③ تەنها جاری یەکەم: ئایدی ڕاستەقینەی Hardware بخوێنەوە
  try {
    final info = DeviceInfoPlugin();
    String? hardwareId;
    if (!kIsWeb && Platform.isAndroid) {
      final android = await info.androidInfo;
      hardwareId = android.id;
    } else if (!kIsWeb && Platform.isIOS) {
      final ios = await info.iosInfo;
      hardwareId = ios.identifierForVendor;
    }
    if (hardwareId != null && hardwareId.isNotEmpty && hardwareId != 'unknown') {
      _sDeviceId = 'hw_$hardwareId';
      await prefs.setString(_kDeviceId, _sDeviceId!);
      return _sDeviceId!;
    }
  } catch (_) {}

  // ④ Fallback: ئەگەر Hardware ID نەبووبێت، random ID درووست بکە
  final rng  = DateTime.now().microsecondsSinceEpoch;
  final id   = 'gen_${rng}_${rng.hashCode.abs()}';
  _sDeviceId = id;
  await prefs.setString(_kDeviceId, id);
  return id;
}

// ── Banner CacheManager — هەمیشە دیسک کاچ (365 ڕۆژ) ──
final _bannerCacheManager = CacheManager(
  Config(
    'proxo_banner_images_v3',
    stalePeriod:         const Duration(days: 365),
    maxNrOfCacheObjects: 50,
    repo:                JsonCacheInfoRepository(databaseName: 'proxo_banner_images_v3'),
    fileService:         HttpFileService(),
  ),
);

// ─────────────────────────────────────────────────────────────────────────────
// ProxoBanner
//
// Shows one of three modes (priority order):
//   A) Firebase image slider  — imageURL
//   B) Firebase image slider  — imageB64
//   C) Supabase text hero     — pa_banners table
//   D) Static fallback
// ─────────────────────────────────────────────────────────────────────────────

class ProxoBanner extends StatefulWidget {
  final VoidCallback? onStart;
  final void Function(String page)? onNavigate;

  const ProxoBanner({super.key, this.onStart, this.onNavigate});

  @override
  State<ProxoBanner> createState() => _ProxoBannerState();
}

// ── Static cache — زیندو دەمێنێتەوە تەنانەت دوای dispose ──
List<_FbBanner>  _sBanners       = [];
_SupaBanner?     _sSupaHero;
bool             _sLoaded        = false;
int              _sCurSliderPage = 0;

StreamSubscription? _sGlobalFbSub;
final _sBannerRevision = ValueNotifier<int>(0);

Future<void> _prewarmGlobal(List<_FbBanner> banners) async {
  final urls = banners.where((b) => b.imageURL.isNotEmpty).toList();
  if (urls.isEmpty) return;
  await Future.wait(urls.map((b) async {
    if (_sImageBytes.containsKey(b.imageURL)) return;
    try {
      final f = await _bannerCacheManager.getSingleFile(b.imageURL);
      _sImageBytes[b.imageURL] = await f.readAsBytes();
    } catch (_) {}
  }));
  _sBannerRevision.value++;
}

class _ProxoBannerState extends State<ProxoBanner> {
  List<_FbBanner> get _fbBanners => _sBanners;
  set _fbBanners(List<_FbBanner> v) => _sBanners = v;

  _SupaBanner? get _supaHero => _sSupaHero;
  set _supaHero(_SupaBanner? v) => _sSupaHero = v;

  // کاتی یەکەم بار: loading. دواتر: ئەگەر static داتا هەبێت یەکسەر نیشان بدە
  bool _loading = !_sLoaded;

  StreamSubscription? _fbSub;
  RealtimeChannel?    _supaSub;

  @override
  void initState() {
    super.initState();
    _sBannerRevision.addListener(_onRevision);
    _boot();
  }

  void _onRevision() { if (mounted) setState(() {}); }

  Future<void> _boot() async {
    if (_sLoaded) {
      if (mounted) setState(() => _loading = false);
      // وێنەکانی کاچ کراوەکان لە دیسک بخەرە مێموری — بەبێ کۆتایی
      if (_sBanners.isNotEmpty) _prewarmGlobal(_sBanners).ignore();
      _startGlobalListener();
      return;
    }
    await _loadFromCache();
    _startGlobalListener();
  }

  @override
  void dispose() {
    _sBannerRevision.removeListener(_onRevision);
    _supaSub?.unsubscribe();
    super.dispose();
  }

  // ── ① Cache (device-ID based, permanent) ─────────────────────────────────

  Future<bool> _loadFromCache() async {
    try {
      final prefs    = await SharedPreferences.getInstance();
      final deviceId = await _getOrCreateDeviceId();

      // ئەگەر version گۆڕاوە کاچی کۆن پاک بکەرەوە
      final savedVer = prefs.getString(_kCacheVersion);
      if (savedVer != _kCurrentVer) {
        await prefs.remove('${_kCacheFb}_$deviceId');
        await prefs.remove('${_kCacheSupa}_$deviceId');
        await prefs.remove(_kCacheTs);
        await prefs.setString(_kCacheVersion, _kCurrentVer);
      }

      // TTL پشکنین — ئەگەر کاچ کۆنەتر لە ٣٠ خولەک، کۆنە دەزانرێت
      final savedTs  = prefs.getInt(_kCacheTs) ?? 0;
      final nowMs    = DateTime.now().millisecondsSinceEpoch;
      final isFresh  = (nowMs - savedTs) < _kCacheTtlMs;

      // TTL کۆنیش بێت — داتا نیشان بدە، background refresh بکاتەوە

      // Firebase banner کاچ
      final fbRaw = prefs.getString('${_kCacheFb}_$deviceId');
      if (fbRaw != null) {
        final list = (jsonDecode(fbRaw) as List)
            .map((e) => _FbBanner(
                  imageURL:  e['imageURL']  ?? '',
                  imageB64:  e['imageB64']  ?? '',
                  targetURL: e['targetURL'] ?? '',
                ))
            .where((b) => b.imageURL.isNotEmpty || b.imageB64.length > 10)
            .toList();
        if (list.isNotEmpty && mounted) {
          _sLoaded = true;
          setState(() { _fbBanners = list; _loading = false; });
          // FIX: وێنەکان لە دیسک کاچ بخەرە مێموری — بەبێ کۆتایی
          // بەمەوە دوای کردنەوەی app، _NetImg یەکسەر Image.memory() نیشان دەدات
          _prewarmGlobal(list).ignore();
          return true;
        }
      }

      // Supabase banner کاچ
      final supaRaw = prefs.getString('${_kCacheSupa}_$deviceId');
      if (supaRaw != null) {
        final m = jsonDecode(supaRaw) as Map<String, dynamic>;
        if (mounted) {
          _sLoaded = true;
          setState(() { _supaHero = _SupaBanner.fromMap(m); _loading = false; });
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  // ── Cache Save ─────────────────────────────────────────────────────────────

  Future<void> _saveFbCache(List<_FbBanner> list) async {
    try {
      final prefs    = await SharedPreferences.getInstance();
      final deviceId = await _getOrCreateDeviceId();
      await prefs.setString(
        '${_kCacheFb}_$deviceId',
        jsonEncode(list.map((b) => {
          'imageURL':  b.imageURL,
          'imageB64':  b.imageB64,
          'targetURL': b.targetURL,
        }).toList()),
      );
      // timestamp-ی نوێکردنەوە پاشەکەوت بکە
      await prefs.setInt(_kCacheTs, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  Future<void> _saveSupaCache(Map<String, dynamic> data) async {
    try {
      final prefs    = await SharedPreferences.getInstance();
      final deviceId = await _getOrCreateDeviceId();
      await prefs.setString('${_kCacheSupa}_$deviceId', jsonEncode(data));
      // timestamp-ی نوێکردنەوە پاشەکەوت بکە
      await prefs.setInt(_kCacheTs, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  // ── ② Global Firebase listener — هەرگیز کنسڵ ناکرێت ────────────────────

  void _startGlobalListener() {
    if (!firebaseAvailable) { _loadSupa(); return; }
    if (_sGlobalFbSub != null) {
      if (mounted && _loading) setState(() => _loading = false);
      return;
    }
    try {
      final ref = FirebaseDatabase.instance.ref('appContent/banners');
      _sGlobalFbSub = ref.onValue.listen(
        (event) async {
          List<_FbBanner> list = _parseBanners(event.snapshot.value);
          if (list.isEmpty) {
            try {
              final snap = await FirebaseDatabase.instance
                  .ref('appContent/activeBanner').get();
              final b = _parseActiveBanner(snap.value);
              if (b != null) list = [b];
            } catch (_) {}
          }
          if (list.isNotEmpty) {
            await _saveFbCache(list);
            _sBanners = list;
            _sLoaded  = true;
            _prewarmGlobal(list).ignore();
            _sBannerRevision.value++;
          } else if (_sBanners.isEmpty) {
            _loadSupaGlobal();
          }
        },
        onError: (_) { if (_sBanners.isEmpty) _loadSupaGlobal(); },
      );
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _loading) _loadSupa();
      });
    } catch (_) { _loadSupa(); }
  }

  Future<void> _loadSupaGlobal() async {
    try {
      final res = await supabase
          .from('pa_banners')
          .select('title,subtitle,btn_text,bg_color,navigate_to')
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (res != null) {
        await _saveSupaCache(res);
        _sSupaHero = _SupaBanner.fromMap(res);
        _sLoaded   = true;
        _sBannerRevision.value++;
      }
    } catch (_) {}
  }

  // ── Supabase ──────────────────────────────────────────────────────────────

  Future<void> _loadSupa() async {
    try {
      final res = await supabase
          .from('pa_banners')
          .select('title,subtitle,btn_text,bg_color,navigate_to')
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      // device-ID cache-ە پاشەکەوت بکە
      if (res != null) await _saveSupaCache(res);

      if (mounted) {
        if (res != null) _sLoaded = true;
        setState(() {
          _supaHero = res != null ? _SupaBanner.fromMap(res) : null;
          _loading  = false;
        });
      }

      _supaSub = supabase
          .channel('banner_rt')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'pa_banners',
            callback: (_) => _loadSupa(),
          )
          .subscribe();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Firebase parse ────────────────────────────────────────────────────────

  List<_FbBanner> _parseBanners(Object? val) {
    if (val == null) return [];

    // Firebase snapshot.value دێتە دەرەوە وەک Map<Object?, Object?> یان List<Object?>
    // پێویستە بە دەقی دووجار cast بکرێت
    Iterable<Object?> entries;
    if (val is Map) {
      entries = val.values;
    } else if (val is List) {
      entries = val.whereType<Object?>();
    } else {
      return [];
    }

    final list = <_FbBanner>[];
    for (final raw in entries) {
      if (raw == null || raw is! Map) continue;
      // Firebase Map<Object?, Object?> — کلیل و نرخ هەردووکیان Object? ن
      String get(String key) =>
          (raw.entries
              .where((e) => e.key?.toString() == key)
              .firstOrNull
              ?.value)
              ?.toString() ?? '';

      final imageUrl  = get('imageURL');
      final imageB64  = get('imageB64');
      final targetUrl = get('targetURL');

      if (imageUrl.isNotEmpty) {
        list.add(_FbBanner(imageURL: imageUrl, imageB64: '', targetURL: targetUrl));
      } else if (imageB64.length > 10) {
        list.add(_FbBanner(imageURL: '', imageB64: imageB64, targetURL: targetUrl));
      }
    }
    return list;
  }

  /// activeBanner نود وەک یەک ئایتەم parse دەکات
  _FbBanner? _parseActiveBanner(Object? val) {
    if (val == null || val is! Map) return null;
    String get(String key) =>
        (val.entries
            .where((e) => e.key?.toString() == key)
            .firstOrNull
            ?.value)
            ?.toString() ?? '';
    final b64 = get('imageB64');
    final url = get('imageURL');
    final tgt = get('targetURL');
    if (b64.length > 10) return _FbBanner(imageURL: '', imageB64: b64, targetURL: tgt);
    if (url.isNotEmpty)  return _FbBanner(imageURL: url, imageB64: '', targetURL: tgt);
    return null;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // ئەگەر داتا هاتوو — نیشانی بدە
    if (_fbBanners.isNotEmpty) {
      return _FbSlider(banners: _fbBanners, onNavigate: widget.onNavigate);
    }
    if (_supaHero != null) {
      return _SupaHero(
        banner:     _supaHero!,
        onStart:    widget.onStart,
        onNavigate: widget.onNavigate,
      );
    }
    // هەمیشە _StaticHero نیشان بدە (چ لۆدینگدا چ دوای)  — هیچ flash ی سپی نییە
    return _StaticHero(onStart: widget.onStart);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OfflineBanner — ئینتەرنێت پچڕاوە
//
// بیخەرە ناو Stack لە بالای هەموو شتێک:
//
//   Stack(children: [
//     _yourMainContent,
//     const OfflineBanner(),   // ← لەسەر هەموو شتێک
//   ])
//
// ── کارکردن ──────────────────────────────────────────────────────────────────
//  • connectivity_plus گوێ دەگرێت بە گۆڕانکاری connectivity
//  • ئینتەرنێت قەت بکات → بانەری سوور لەسەرەوە slide down دەکات
//  • ئینتەرنێت گەڕایەوە → بانەر slide up دەکاتەوە
//  • iOS + Android هەردووکیانیان پشتگیری دەکات
// ─────────────────────────────────────────────────────────────────────────────

class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner>
    with SingleTickerProviderStateMixin {
  bool _offline = false;
  late AnimationController _anim;
  late Animation<Offset>   _slide;

  StreamSubscription<List<ConnectivityResult>>? _sub;

  @override
  void initState() {
    super.initState();

    _anim = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 320),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),   // بانەر بەرەوی سەرەوە شاراوەیە
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));

    // چەک کردنی دەمی دەستپێک
    _checkConnectivity();

    // گوێگرتن بە گۆڕانکاری
    _sub = Connectivity().onConnectivityChanged.listen(_onChanged);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _anim.dispose();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    _onChanged(results);
  }

  void _onChanged(List<ConnectivityResult> results) {
    final isOffline = results.every((r) => r == ConnectivityResult.none);
    if (!mounted) return;
    if (isOffline == _offline) return;
    setState(() => _offline = isOffline);
    if (isOffline) {
      _anim.forward();
    } else {
      _anim.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    // کاتی online بوون و ئانیمەیشن تەواو بوو — هیچ شتێک render مەکە
    if (!_offline && !_anim.isAnimating) return const SizedBox.shrink();

    return Positioned(
      top:   0,
      left:  0,
      right: 0,
      child: SlideTransition(
        position: _slide,
        child: Material(
          color: Colors.transparent,
          // Losing connection is a status, not a failure, so it uses the
          // shared `offline` tone rather than the old full-bleed red bar —
          // red is reserved for things that actually went wrong. The strip
          // still spans the full width and still clears the status bar via
          // the device's own top padding.
          child: Builder(builder: (context) {
            final p = proxoErrorPalette(ProxoErrorTone.offline);
            return Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: p.surface,
                border: Border(bottom: BorderSide(color: p.border)),
              ),
              padding: EdgeInsets.only(
                top:    MediaQuery.of(context).padding.top + 8,
                bottom: 10,
                left:   ProxoErrorStyle.s16,
                right:  ProxoErrorStyle.s16,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.wifi_off_rounded,
                    color: p.accent,
                    size:  16,
                  ),
                  const SizedBox(width: ProxoErrorStyle.s8),
                  Flexible(
                    child: Text(
                      'ئینتەرنێت پچڕاوە — تکایە پەیوەندی بکەرەوە',
                      style: ProxoErrorType.body(p.ink, kAppFont),
                      textDirection: TextDirection.rtl,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Firebase Image Slider
// ─────────────────────────────────────────────────────────────────────────────

class _FbSlider extends StatefulWidget {
  final List<_FbBanner>             banners;
  final void Function(String page)? onNavigate;

  const _FbSlider({required this.banners, this.onNavigate});

  @override
  State<_FbSlider> createState() => _FbSliderState();
}

class _FbSliderState extends State<_FbSlider> {
  int              _cur  = _sCurSliderPage;
  late PageController _ctrl;
  Timer?           _timer;

  static const _slideDur   = Duration(milliseconds: 550);
  static const _slideCurve = Curves.fastOutSlowIn;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController(
      initialPage: _sCurSliderPage.clamp(0, widget.banners.length - 1),
      keepPage: true,
    );
    _startAuto(pause: true);   // timer یەکسەر دەستپێدەکات — چاو بە warming ناکات
    _prewarmImages(widget.banners);
  }

  @override
  void didUpdateWidget(_FbSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ئەگەر بانەری نوێ هات (لە Firebase update)، وێنەی نوێ پیشخەرم بکە
    final oldUrls = oldWidget.banners.map((b) => b.imageURL).toSet();
    final newUrls = widget.banners.map((b) => b.imageURL)
        .where((u) => u.isNotEmpty && !oldUrls.contains(u))
        .toList();
    if (newUrls.isNotEmpty) _prewarmImages(widget.banners);
  }

  /// هەموو وێنەکان وەک bytes لە مێموری پاشەکەوت دەکات — تواوەتواو (parallel).
  /// دوای ئەمە _NetImg.build() بایتسەکان synchronous دەیبینێت — هیچ async نییە.
  Future<void> _prewarmImages(List<_FbBanner> banners) async {
    final urlBanners = banners.where((b) => b.imageURL.isNotEmpty).toList();
    if (urlBanners.isEmpty) return;

    await Future.wait(
      urlBanners.map((b) async {
        if (_sImageBytes.containsKey(b.imageURL)) return; // پێشتر لە مێموریدایە
        try {
          // ① دیسک کاچ بخوێنەوە (یان دابەزێنە)
          final file  = await _bannerCacheManager.getSingleFile(b.imageURL);
          final bytes = await file.readAsBytes();
          _sImageBytes[b.imageURL] = bytes;
          _NetImgState._warmed.add(b.imageURL);

          // ② وێنەکە ناو Flutter image codec cache-ەوە pre-decode بکە
          // بەمەوە Image.memory() یەکسەر render دەبێت بەبێ هیچ decode delay
          if (mounted) {
            // ignore: use_build_context_synchronously
            await precacheImage(MemoryImage(bytes), context);
            setState(() {}); // _NetImg-ەکان دووبارە build بکە
          }
        } catch (_) {
          try {
            if (!mounted) return;
            // ignore: use_build_context_synchronously
            await precacheImage(
              CachedNetworkImageProvider(b.imageURL, cacheManager: _bannerCacheManager),
              context,
            );
            _NetImgState._warmed.add(b.imageURL);
          } catch (_) {}
        }
      }),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _startAuto({bool pause = false}) {
    if (widget.banners.length < 2) return;
    _timer?.cancel();
    _timer = Timer(Duration(seconds: pause ? 3 : 4), () {
      if (!mounted) return;
      _goNext();
      _scheduleCycle();
    });
  }

  void _scheduleCycle() {
    if (!mounted) return;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      _goNext();
    });
  }

  void _goNext() {
    if (!_ctrl.hasClients) return;
    _ctrl.animateToPage(
      (_cur + 1) % widget.banners.length,
      duration: _slideDur,
      curve:    _slideCurve,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxWidth * 9 / 16;
        return Container(
          height: h,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(22)),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              // PageView (نە builder) — هەموو پەیجەکان یەکسەر build دەبن
              // بەمەوە کاتی گۆڕین بۆ هەر پەیجێک: Flutter پێشتر render کردووی
              // و _NetImg Image.memory() یەکسەر نیشان دەدات — هیچ decode delay نییە
              PageView(
                controller:    _ctrl,
                onPageChanged: (i) {
                  setState(() => _cur = i);
                  _sCurSliderPage = i;
                },
                children: [
                  for (final b in widget.banners)
                    _KeepAlivePage(
                      child: GestureDetector(
                        onTap: () {
                          if (b.targetURL.isNotEmpty) {
                            widget.onNavigate?.call(b.targetURL);
                          }
                          _startAuto(pause: true);
                        },
                        child: b.imageURL.isNotEmpty
                            ? _NetImg(url: b.imageURL)
                            : _B64Img(b64: b.imageB64),
                      ),
                    ),
                ],
              ),

              if (widget.banners.length > 1)
                Positioned(
                  bottom: 10, left: 0, right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(widget.banners.length, (i) {
                      final active = _cur == i;
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          _ctrl.animateToPage(i, duration: _slideDur, curve: _slideCurve);
                          _startAuto(pause: true);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            width:  active ? 22 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: active
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.38),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _KeepAlivePage — پەیجەکانی PageView زیندو دەگرێتەوە
//
// بەبێ ئەمە: کاتێک لە پەیج ٣ دەگەڕێیتەوە پەیج ١، Flutter پەیج ١ دووبارە
// دروست دەکات و _NetImg.initState() دووبارە دەخرێتەوە — هۆی لاگ.
// بەئەمە: هەموو پەیجەکان لە مێموری دەمێننەوە — گۆڕین یەکسەر.
// ─────────────────────────────────────────────────────────────────────────────

class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NetImg  —  slide-in کاتێک یەکەم جار لۆد دەبێت، یەکسەر کاتێک cache هەیە
//
// FIXES applied:
//   • Uses shared _bannerCacheManager singleton (no redundant DB opens)
//   • Removes per-instance DefaultCacheManager() construction
//   • gaplessPlayback: true  prevents flicker on rebuild
// ─────────────────────────────────────────────────────────────────────────────

class _NetImg extends StatefulWidget {
  final String url;
  const _NetImg({required this.url});
  @override
  State<_NetImg> createState() => _NetImgState();
}

class _NetImgState extends State<_NetImg> with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double>   _fade;

  // URL-ە پیشخەرمکراوەکان (precacheImage یان getSingleFile)
  static final _warmed = <String>{};

  @override
  void initState() {
    super.initState();
    // ئەگەر bytes لە مێموری هەن یان پیشخەرم کراوە — هیچ ئانیمەیشن پێویست نییە
    final instant = _sImageBytes.containsKey(widget.url) ||
                    _warmed.contains(widget.url);
    _anim = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 350),
      value:    instant ? 1.0 : 0.0,
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);

    if (!instant) _checkCache();
  }

  // دیسک کاچ پشکنین (async — تەنها جاری یەکەم بار)
  Future<void> _checkCache() async {
    try {
      final info = await _bannerCacheManager.getFileFromCache(widget.url);
      if (info != null && mounted) {
        // فایل لە دیسکدا هەیە — bytes بخوێنەرەوە و لە مێموری پاشەکەوت بکە
        final bytes = await info.file.readAsBytes();
        _sImageBytes[widget.url] = bytes;
        _warmed.add(widget.url);
        if (mounted) setState(() => _anim.value = 1.0);
      }
    } catch (_) {}
  }

  void _onImageLoaded() {
    _warmed.add(widget.url);
    if (mounted && !_anim.isCompleted) _anim.forward();
  }

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    // ① بایتس لە مێموری هەن — یەکسەر Image.memory() بەبێ هیچ I/O
    final bytes = _sImageBytes[widget.url];
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit:             BoxFit.cover,
        width:           double.infinity,
        height:          double.infinity,
        gaplessPlayback: true,
      );
    }

    // ② هێشتا bytes لۆد نەبووە — CachedNetworkImage لە پشتەوە دابەزێنە
    return FadeTransition(
      opacity: _fade,
      child: CachedNetworkImage(
        imageUrl:        widget.url,
        cacheManager:    _bannerCacheManager,
        fit:             BoxFit.cover,
        width:           double.infinity,
        height:          double.infinity,
        fadeInDuration:  Duration.zero,
        fadeOutDuration: Duration.zero,
        imageBuilder: (_, img) {
          _onImageLoaded();
          return Image(
            image:           img,
            fit:             BoxFit.cover,
            width:           double.infinity,
            height:          double.infinity,
            gaplessPlayback: true,
          );
        },
        placeholder:  (_, __) => _BannerPlaceholder(),
        errorWidget:  (_, __, ___) => _BannerPlaceholder(error: true),
      ),
    );
  }
}

class _BannerPlaceholder extends StatefulWidget {
  final bool error;
  const _BannerPlaceholder({this.error = false});
  @override
  State<_BannerPlaceholder> createState() => _BannerPlaceholderState();
}

class _BannerPlaceholderState extends State<_BannerPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1100),
    );
    if (!widget.error) _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (widget.error) {
      return Container(
        color: AppColors.dark,
        child: const Center(
          child: Icon(Icons.broken_image_outlined, color: Colors.white24, size: 36),
        ),
      );
    }
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          color: Color.lerp(AppColors.dark, const Color(0xFF1C2333), _ctrl.value),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _B64Img  —  slide-in تەنها یەکەم جار، دواتر یەکسەر
//
// FIX — base64Decode moved off the UI thread via compute()
//
// OLD (broken): base64Decode ran synchronously inside build(), blocking
//               the UI thread for 10–80 ms per image → visible jank.
//
// NEW (fixed):  _decodeAsync() calls compute(_decodeB64Isolate, raw) which
//               spawns a Dart isolate. The UI thread stays free. A skeleton
//               placeholder is shown while decoding, then the image fades in.
// ─────────────────────────────────────────────────────────────────────────────

// b64 ی cache کراوەکان بە prefix key پاشەکەوت دەکرێن
final _b64Shown = <String>{};

class _B64Img extends StatefulWidget {
  final String b64;
  const _B64Img({required this.b64});
  @override
  State<_B64Img> createState() => _B64ImgState();
}

class _B64ImgState extends State<_B64Img> with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<Offset>   _slide;
  Uint8List? _bytes;   // null = still decoding in isolate

  @override
  void initState() {
    super.initState();
    final alreadySeen = _b64Shown.contains(widget.b64.substring(0, 20));
    _anim = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 420),
      value:    alreadySeen ? 1.0 : 0.0,
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));

    // FIX — decode off the UI thread
    _decodeAsync();
  }

  Future<void> _decodeAsync() async {
    try {
      final raw = widget.b64.contains(',')
          ? widget.b64.split(',').last
          : widget.b64;

      // compute() runs _decodeB64Isolate in a separate Dart isolate.
      // The UI thread is never blocked regardless of image size.
      final bytes = await compute(_decodeB64Isolate, raw);

      if (!mounted) return;
      setState(() => _bytes = bytes);

      final key = widget.b64.substring(0, 20);
      if (!_b64Shown.contains(key)) {
        _b64Shown.add(key);
        _anim.forward(); // یەکەم جار slide-in
      } else {
        _anim.value = 1.0; // پێشتر نیشاندراوە — یەکسەر نیشان بدە
      }
    } catch (_) {
      // شکستی decode — placeholder نیشان بدە
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    // هێشتا لە isolate دەکرێتەوە — skeleton نیشان بدە
    if (_bytes == null) return _BannerPlaceholder();

    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _anim,
        child: Image.memory(
          _bytes!,
          fit:             BoxFit.cover,
          width:           double.infinity,
          height:          double.infinity,
          gaplessPlayback: true,   // FIX — no flicker on rebuild
          errorBuilder:    (_, __, ___) => _placeholder(),
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: AppColors.dark,
        child: const Center(
          child: Icon(Icons.image_outlined, color: Colors.white24, size: 40),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// _SupaHero
// ─────────────────────────────────────────────────────────────────────────────

class _SupaHero extends StatelessWidget {
  final _SupaBanner                  banner;
  final VoidCallback?                onStart;
  final void Function(String page)?  onNavigate;

  const _SupaHero({required this.banner, this.onStart, this.onNavigate});

  Color _parseBg() {
    try {
      if (banner.bgColor.isNotEmpty) {
        final hex = banner.bgColor.replaceAll('#', '');
        if (hex.length == 6) return Color(int.parse('FF$hex', radix: 16));
      }
    } catch (_) {}
    return AppColors.dark;
  }

  void _handleTap() {
    if (banner.navigateTo.isNotEmpty) {
      onNavigate?.call(banner.navigateTo);
    } else {
      onStart?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: _parseBg(),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -30, right: -30,
              child: Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -20, left: -20,
              child: Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  banner.title,
                  // Bold kept: a promo hero headline's whole job is to grab
                  // attention, which is the "high-priority emphasis" case.
                  // Explicit height added (was unset/font-default) since
                  // banner.title is CMS content of unpredictable length.
                  style: const TextStyle(
                    fontFamily: kAppFont,
                    fontSize:   20,
                    fontWeight: FontWeight.w700,
                    color:      Colors.white,
                    height:     1.25,
                  ),
                ),
                if (banner.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    banner.subtitle,
                    style: TextStyle(
                      fontFamily: kAppFont,
                      fontSize:   13.5,
                      fontWeight: FontWeight.w400,
                      color:      Colors.white.withOpacity(0.6),
                      height:     1.35, // was 1.7, above the multiline ceiling
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.play_arrow_rounded, size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        banner.btnText.isNotEmpty ? banner.btnText : 'دەستپێکردن',
                        style: const TextStyle(
                          fontFamily: kAppFont,
                          fontSize:   13,
                          color:      Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StaticHero (fallback)
// ─────────────────────────────────────────────────────────────────────────────

class _StaticHero extends StatelessWidget {
  final VoidCallback? onStart;
  const _StaticHero({this.onStart});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onStart,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.dark,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -30, right: -30,
              child: Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -20, left: -20,
              child: Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ڕیکلامی تیک تۆک بەردەستە',
                  // Same reasoning as _SupaHero above: Bold kept (hero
                  // headline), explicit height added where none existed.
                  style: TextStyle(
                    fontFamily: kAppFont,
                    fontSize:   20,
                    fontWeight: FontWeight.w700,
                    color:      Colors.white,
                    height:     1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'ڕیکلامەکانت بڕوانە و بیکەرەوە بە ئاسانی لەگەڵ Proxo',
                  style: TextStyle(
                    fontFamily: kAppFont,
                    fontSize:   13.5,
                    fontWeight: FontWeight.w400,
                    color:      Colors.white.withOpacity(0.6),
                    height:     1.35, // was 1.7, above the multiline ceiling
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow_rounded, size: 14, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'دەستپێکردن',
                        style: TextStyle(
                          fontFamily: kAppFont,
                          fontSize:   13,
                          color:      Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SkeletonBanner
// ─────────────────────────────────────────────────────────────────────────────

class _SkeletonBanner extends StatefulWidget {
  const _SkeletonBanner();
  @override
  State<_SkeletonBanner> createState() => _SkeletonBannerState();
}

class _SkeletonBannerState extends State<_SkeletonBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        height: 145,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: Color.lerp(AppColors.border1, AppColors.bg, _ctrl.value),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data Models
// ─────────────────────────────────────────────────────────────────────────────

class _FbBanner {
  final String imageURL;
  final String imageB64;
  final String targetURL;

  const _FbBanner({
    required this.imageURL,
    required this.imageB64,
    required this.targetURL,
  });
}

class _SupaBanner {
  final String title;
  final String subtitle;
  final String btnText;
  final String bgColor;
  final String navigateTo;

  const _SupaBanner({
    required this.title,
    required this.subtitle,
    required this.btnText,
    required this.bgColor,
    required this.navigateTo,
  });

  factory _SupaBanner.fromMap(Map<String, dynamic> m) => _SupaBanner(
        title:      m['title']?.toString()       ?? 'Proxo',
        subtitle:   m['subtitle']?.toString()    ?? '',
        btnText:    m['btn_text']?.toString()    ?? 'دەستپێکردن',
        bgColor:    m['bg_color']?.toString()    ?? '',
        navigateTo: m['navigate_to']?.toString() ?? '',
      );
}
