import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart' show supabase;
import '../theme/app_theme.dart';
import 'package:proxo_app/widgets/proxo_text.dart';

const Color _kFeedbackInk = Color(0xFF0F172A);
const Color _kFeedbackMuted = Color(0xFF64748B);
const Color _kFeedbackAccent = Color(0xFF6D28D9);
const Color _kFeedbackSurface = Color(0xFFFAF7FF);
const Color _kFeedbackBorder = Color(0xFFE9D5FF);
const Color _kStar = Color(0xFFF59E0B);
const Color _kStarSurface = Color(0xFFFFFBEB);
const Color _kStarBorder = Color(0xFFFDE68A);
const Color _kIdleStar = Color(0xFF94A3B8);
const Color _kIdleSurface = Color(0xFFF8FAFC);
const Color _kIdleBorder = Color(0xFFE2E8F0);

const List<String> _kRatingLabels = <String>[
  '',
  'خراپ',
  'مامناوەند',
  'باش',
  'زۆر باش',
  'نایاب',
];

/// Opens the single feedback surface used by both Home and AdScreen.
///
/// A non-null result means the RPC accepted and stored the rating. Closing the
/// dialog without rating returns null, so callers can leave the ad pending and
/// ask again in a later app session.
Future<int?> showAdFeedbackDialog(
  BuildContext context, {
  required String adId,
  required String adTitle,
  String? thumbnailUrl,
}) {
  return showDialog<int>(
    context: context,
    barrierDismissible: true,
    barrierColor: const Color(0x660F172A),
    builder: (_) => _AdFeedbackDialog(
      adId: adId,
      adTitle: adTitle,
      thumbnailUrl: thumbnailUrl,
    ),
  );
}

class _AdFeedbackDialog extends StatefulWidget {
  final String adId;
  final String adTitle;
  final String? thumbnailUrl;

  const _AdFeedbackDialog({
    required this.adId,
    required this.adTitle,
    this.thumbnailUrl,
  });

  @override
  State<_AdFeedbackDialog> createState() => _AdFeedbackDialogState();
}

class _AdFeedbackDialogState extends State<_AdFeedbackDialog> {
  int _rating = 0;
  bool _saving = false;
  String? _error;

  void _select(int rating) {
    if (_saving || rating == _rating) return;
    HapticFeedback.selectionClick();
    setState(() {
      _rating = rating;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_saving || _rating == 0) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final dynamic response = await supabase.rpc(
        'submit_ad_feedback',
        params: <String, dynamic>{
          'p_ad_id': widget.adId,
          'p_rating': _rating,
          'p_comment': null,
        },
      );

      final Map<dynamic, dynamic>? data = response is Map ? response : null;
      if (data?['ok'] != true) {
        throw _FeedbackFailure((data?['reason'] ?? 'unknown').toString());
      }

      if (!mounted) return;
      HapticFeedback.lightImpact();
      Navigator.of(context).pop(_rating);
    } on _FeedbackFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = switch (error.reason) {
          'already_rated' => 'فیدباکی ئەم ڕیکلامە پێشتر نێردراوە.',
          'ad_not_completed' => 'تەنها ڕیکلامی تەواوبوو هەڵدەسەنگێنرێت.',
          'ad_not_found' => 'ڕیکلامەکە نەدۆزرایەوە.',
          'not_authenticated' => 'تکایە دووبارە بچۆرە ژوورەوە.',
          _ => 'ناردنی فیدباک سەرکەوتوو نەبوو. دووبارە هەوڵ بدەوە.',
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'ناردنی فیدباک سەرکەوتوو نەبوو. پەیوەندییەکەت بپشکنە.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final double textScale =
        media.textScaler.scale(1).clamp(0.9, 1.05).toDouble();

    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.linear(textScale)),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: PopScope(
          canPop: !_saving,
          child: Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: Color(0xFFE7ECF3)),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Expanded(
                          child: ProxoText(
                            'هەڵسەنگاندنی ڕیکلام',
                            style: TextStyle(
                              fontFamily: kAppFont,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _kFeedbackMuted,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: IconButton(
                            onPressed: _saving
                                ? null
                                : () => Navigator.of(context).pop(),
                            padding: EdgeInsets.zero,
                            splashRadius: 20,
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: _kFeedbackMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _FeedbackAdIdentity(
                      title: widget.adTitle,
                      thumbnailUrl: widget.thumbnailUrl,
                    ),
                    const SizedBox(height: 20),
                    const ProxoText(
                      'ئەم ڕیکلامە چۆن بوو؟',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: kAppFont,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: _kFeedbackInk,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const ProxoText(
                      'ئەستێرەیەک هەڵبژێرە؛ فیدباکەکەت یارمەتیمان دەدات باشتر بین.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: kAppFont,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: _kFeedbackMuted,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List<Widget>.generate(5, (int index) {
                        final int value = index + 1;
                        return Padding(
                          padding: EdgeInsetsDirectional.only(
                            start: index == 0 ? 0 : 4,
                          ),
                          child: _RatingStar(
                            value: value,
                            selected: value <= _rating,
                            enabled: !_saving,
                            onTap: () => _select(value),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 24,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 140),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeOut,
                        child: ProxoText(
                          _rating == 0
                              ? 'هەڵسەنگاندنێک هەڵبژێرە'
                              : _kRatingLabels[_rating],
                          key: ValueKey<int>(_rating),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: kAppFont,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: _rating == 0
                                ? _kFeedbackMuted
                                : _kFeedbackAccent,
                          ),
                        ),
                      ),
                    ),
                    if (_error != null) ...<Widget>[
                      const SizedBox(height: 8),
                      ProxoText(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: kAppFont,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFFB91C1C),
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton(
                        onPressed: _rating == 0 || _saving ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          disabledBackgroundColor: const Color(0xFFE2E8F0),
                          foregroundColor: Colors.white,
                          disabledForegroundColor: const Color(0xFF94A3B8),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const ProxoText(
                                'ناردنی فیدباک',
                                style: TextStyle(
                                  fontFamily: kAppFont,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RatingStar extends StatelessWidget {
  final int value;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _RatingStar({
    required this.value,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$value ئەستێرە — ${_kRatingLabels[value]}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: selected ? _kStarSurface : _kIdleSurface,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected ? _kStarBorder : _kIdleBorder,
            ),
          ),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutBack,
            scale: selected ? 1 : 0.9,
            child: Icon(
              selected ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 25,
              color: selected ? _kStar : _kIdleStar,
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedbackAdIdentity extends StatelessWidget {
  final String title;
  final String? thumbnailUrl;

  const _FeedbackAdIdentity({required this.title, this.thumbnailUrl});

  @override
  Widget build(BuildContext context) {
    final String url = thumbnailUrl?.trim() ?? '';
    final Uri? uri = Uri.tryParse(url);
    final bool hasImage = uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
    const Widget fallback = ColoredBox(color: Colors.white);
    final int decodePx = (50 * MediaQuery.devicePixelRatioOf(context)).round();

    final Widget image = hasImage
        ? CachedNetworkImage(
            imageUrl: url,
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            memCacheWidth: decodePx,
            memCacheHeight: decodePx,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            placeholderFadeInDuration: Duration.zero,
            placeholder: (_, __) => fallback,
            errorWidget: (_, __, ___) => fallback,
          )
        : fallback;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _kIdleSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kIdleBorder),
      ),
      child: Row(
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kIdleBorder),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              clipBehavior: Clip.hardEdge,
              child: SizedBox(width: 50, height: 50, child: image),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ProxoText(
              title.trim().isEmpty ? 'ڕیکلام' : title.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: kAppFont,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: _kFeedbackInk,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact completed-ad feedback surface placed directly in an ad card.
class CompletedAdFeedbackTile extends StatelessWidget {
  final double scale;
  final int? rating;
  final VoidCallback? onTap;

  const CompletedAdFeedbackTile({
    super.key,
    required this.scale,
    required this.rating,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    final int safeRating = (rating ?? 0).clamp(0, 5).toInt();
    final bool rated = safeRating > 0;
    final BorderRadius radius = BorderRadius.circular(14 * s);

    return Material(
      color: _kFeedbackSurface,
      borderRadius: radius,
      child: InkWell(
        onTap: rated ? null : onTap,
        borderRadius: radius,
        splashColor: _kFeedbackAccent.withOpacity(0.05),
        highlightColor: _kFeedbackAccent.withOpacity(0.04),
        child: Container(
          constraints: BoxConstraints(minHeight: 54 * s),
          padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 9 * s),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: _kFeedbackBorder),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 34 * s,
                height: 34 * s,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(11 * s),
                  border: Border.all(color: _kFeedbackBorder),
                ),
                child: Icon(
                  rated ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 19 * s,
                  color: rated ? _kStar : _kFeedbackAccent,
                ),
              ),
              SizedBox(width: 10 * s),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    ProxoText(
                      rated
                          ? 'سوپاس بۆ فیدباکەکەت'
                          : 'ئەم ڕیکلامە چۆن بوو؟',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: kAppFont,
                        fontSize: 12.5 * s,
                        fontWeight: FontWeight.w400,
                        color: _kFeedbackAccent,
                        height: 1.25,
                      ),
                    ),
                    SizedBox(height: 3 * s),
                    rated
                        ? _CompactStars(rating: safeRating, scale: s)
                        : ProxoText(
                            'بە ئەستێرە هەڵیسەنگێنە',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: kAppFont,
                              fontSize: 11 * s,
                              fontWeight: FontWeight.w400,
                              color: _kFeedbackMuted,
                              height: 1.25,
                            ),
                          ),
                  ],
                ),
              ),
              if (!rated) ...<Widget>[
                SizedBox(width: 8 * s),
                Icon(
                  Icons.chevron_left_rounded,
                  size: 19 * s,
                  color: _kFeedbackAccent,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactStars extends StatelessWidget {
  final int rating;
  final double scale;

  const _CompactStars({required this.rating, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(
        5,
        (int index) => Icon(
          index < rating ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 13 * scale,
          color: index < rating ? _kStar : _kIdleStar,
        ),
      ),
    );
  }
}

class _FeedbackFailure implements Exception {
  final String reason;
  const _FeedbackFailure(this.reason);
}
