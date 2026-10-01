import 'package:flutter/widgets.dart';

import '../services/ad_categories.dart';
import '../theme/app_locale.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AdDetailStrings — هەموو دەقەکانی شاشەی وردەکاری ڕیکلام، بە کوردی و عەرەبی.
//
// ⚠ بۆچی `AppLocalizations` نا؟ `MaterialApp` لە `main.dart`دا `ckb` دەگۆڕێت
// بۆ `ar` (چونکە Flutter خۆی ckb ناناسێت)، و delegateـی `AppLocalizations`
// تۆمار نەکراوە. بۆیە `AppLocalizations.of` بۆ بەکارهێنەری کورد عەرەبی
// دەگەڕاندەوە. سەرچاوەی ڕاستەقینەی زمانی ئەپەکە `ProxoLocale.current`ـە،
// بۆیە ئەم فایلە ڕاستەوخۆ لەوێوە دەخوێنێتەوە.
// ─────────────────────────────────────────────────────────────────────────────

class AdDetailStrings {
  final bool ar;
  const AdDetailStrings._(this.ar);

  static const AdDetailStrings _ckb = AdDetailStrings._(false);
  static const AdDetailStrings _ar = AdDetailStrings._(true);

  /// کوردی بۆ هەموو زمانێک جگە لە عەرەبی.
  static AdDetailStrings of(Locale locale) =>
      locale.languageCode == 'ar' ? _ar : _ckb;

  static AdDetailStrings get current => of(ProxoLocale.current.value);

  String _t(String ku, String arabic) => ar ? arabic : ku;

  // ── AppBar / سەردێر ─────────────────────────────────────────────────────
  String get appBarTitle => _t('وردەکاری ڕیکلام', 'تفاصيل الإعلان');
  String get receiptTitle => _t('پسوولەی ڕیکلام', 'إيصال الإعلان');
  String get back => _t('گەڕانەوە', 'رجوع');

  // ── سەرەوە ──────────────────────────────────────────────────────────────
  String get adId => _t('ئایدی ڕیکلام', 'معرّف الإعلان');
  String get date => _t('ڕێکەوت', 'التاريخ');

  // ── ئامانجی ڕیکلام ──────────────────────────────────────────────────────
  String get sectionTarget => _t('ئامانجی ڕیکلام', 'استهداف الإعلان');
  String get age => _t('تەمەن', 'العمر');
  String get gender => _t('ڕەگەز', 'الجنس');
  String get location => _t('شوێن', 'الموقع');
  String get device => _t('ئامێر', 'الجهاز');
  String get category => _t('پۆل', 'الفئة');

  // ── پوختە ───────────────────────────────────────────────────────────────
  String get sectionSummary => _t('پوختە', 'الملخص');
  String get originalAmount => _t('نرخی سەرەتایی', 'المبلغ الأصلي');
  String get discount => _t('داشکاندن', 'الخصم');
  String get totalIqd => _t('کۆی کۆتایی', 'المبلغ النهائي');
  String get iqdUnit => 'د.ع';

  // ── زانیاری پارەدان ─────────────────────────────────────────────────────
  String get sectionPayment => _t('زانیاری پارەدان', 'معلومات الدفع');
  String get noPaymentRequired =>
      _t('پارەدان پێویست نەبوو', 'لم يكن الدفع مطلوباً');
  String get transactionId => _t('ئایدی مامەڵە', 'معرّف المعاملة');
  String get paymentMethod => _t('ڕێگای پارەدان', 'طريقة الدفع');

  // ── کۆتایی ──────────────────────────────────────────────────────────────
  String get adName => _t('ناوی سپۆنسەر', 'اسم الإعلان');
  String get receiptNo => _t('ژ.م پسوولە', 'رقم الإيصال');

  // ── PDF ─────────────────────────────────────────────────────────────────
  String get pdfButton => _t('داوڵۆند بکە بە PDF', 'تنزيل بصيغة PDF');
  String get pdfFailed => _t(
        'نەتوانرا PDF دروست بکرێت — دووبارە هەوڵ بدەرەوە',
        'تعذّر إنشاء ملف PDF — حاول مرة أخرى',
      );

  // ── هەڵە / دۆخ ──────────────────────────────────────────────────────────
  String get notFoundTitle =>
      _t('ڕیکلامەکە نەدۆزرایەوە', 'لم يتم العثور على الإعلان');
  String get notFoundBody => _t(
        'لەوانەیە سڕابێتەوە، یان ئەم ئایدییە هی هەژمارێکی ترە.',
        'ربما تم حذفه، أو أن هذا المعرّف يخص حساباً آخر.',
      );
  String get loadErrorTitle =>
      _t('نەتوانرا وردەکارییەکان بهێنرێن', 'تعذّر تحميل التفاصيل');
  String get loadErrorBody => _t(
        'پەیوەندییەکەت بپشکنە و دووبارە هەوڵ بدەرەوە.',
        'تحقق من اتصالك وحاول مرة أخرى.',
      );
  String get retry => _t('دووبارە هەوڵ بدەرەوە', 'إعادة المحاولة');
  String get copied => _t('بەسەرکەوتوویی کۆپی کرا', 'تم النسخ بنجاح');
  String get copyFailed =>
      _t('کۆپی نەکرا؛ دووبارە هەوڵ بدەرەوە.', 'تعذّر النسخ؛ حاول مرة أخرى.');

  // ── بەهاکان ─────────────────────────────────────────────────────────────
  String get allAges => _t('هەموو تەمەنەکان', 'جميع الأعمار');

  String genderLabel(String code) => switch (code.trim().toLowerCase()) {
        'male' => _t('نێر', 'ذكور'),
        'female' => _t('مێ', 'إناث'),
        'all' || 'both' => _t('هەردووکیان', 'كلاهما'),
        '' => '—',
        _ => code,
      };

  String locationLabel(String code) => switch (code.trim().toLowerCase()) {
        'kurdistan' => _t('کوردستان', 'كردستان'),
        'iraq' => _t('عێراق', 'العراق'),
        'erbil' || 'هەولێر' || 'أربيل' => _t('هەولێر', 'أربيل'),
        'all' => _t('هەموو شوێنەکان', 'جميع المناطق'),
        '' => '—',
        _ => code,
      };

  /// ⚠ ناوی براندەکان لاتینی دەمێننەوە (iPhone / Android) — وەک نموونەی
  /// دیزاینەکە.
  String deviceLabel(String code) => switch (code.trim().toLowerCase()) {
        'iphone' || 'ios' => 'iPhone',
        'android' => 'Android',
        'all' || 'both' => _t('هەموو ئامێرەکان', 'جميع الأجهزة'),
        '' => '—',
        _ => code,
      };

  String paymentLabel(String code) => switch (code.trim().toLowerCase()) {
        'fastpay' => 'FastPay',
        'app_balance' => _t('باڵانسی هەژمار', 'رصيد الحساب'),
        '' => '—',
        _ => code,
      };

  String categoryLabel(String slug) {
    final String normalized = slug.trim().toLowerCase();
    if (normalized.isEmpty) return '—';
    if (!isSupportedAdCategory(normalized)) return slug;
    if (!ar) return adCategoryLabel(normalized);
    return switch (normalized) {
      'cosmetics_beauty' => 'التجميل والعناية',
      'fashion_apparel' => 'الأزياء والملابس',
      'electronics' => 'الإلكترونيات',
      'food_beverage' => 'الطعام والمشروبات',
      'home_living' => 'المنزل والأثاث',
      'automotive' => 'السيارات',
      'services' => 'الخدمات',
      'education' => 'التعليم',
      'games_apps' => 'الألعاب والتطبيقات',
      'health_wellness' => 'الصحة والعافية',
      'retail_ecommerce' => 'التجزئة والتسوق الإلكتروني',
      _ => 'أخرى',
    };
  }
}
