import 'package:flutter/widgets.dart';

import '../theme/app_locale.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TxStrings — مێژووی مامەڵەکان + وردەکاری مامەڵە، بە کوردی و عەرەبی.
//
// هەمان ڕێگای `AdDetailStrings`: زمان ڕاستەوخۆ لە `ProxoLocale.current`
// دەخوێندرێتەوە، چونکە `MaterialApp` زمانی ckb دەکاتە ar.
// ─────────────────────────────────────────────────────────────────────────────

class TxStrings {
  final bool ar;
  const TxStrings._(this.ar);

  static const TxStrings _ckb = TxStrings._(false);
  static const TxStrings _ar = TxStrings._(true);

  static TxStrings of(Locale locale) =>
      locale.languageCode == 'ar' ? _ar : _ckb;

  static TxStrings get current => of(ProxoLocale.current.value);

  String _t(String ku, String arabic) => ar ? arabic : ku;

  // ── مێژوو ───────────────────────────────────────────────────────────────
  String get historyTitle => _t('مێژووی مامەڵەکان', 'سجل المعاملات');
  String get refresh => _t('نوێکردنەوە', 'تحديث');
  String get emptyTitle => _t('هیچ مامەڵەیەک نییە', 'لا توجد معاملات');
  String get emptyBody =>
      _t('هێشتا هیچ مامەڵەیەکت نەکردووە.', 'لم تقم بأي معاملة حتى الآن.');
  String get loadErrorTitle =>
      _t('مامەڵەکان بار نەبوون', 'تعذّر تحميل المعاملات');
  String get loadErrorBody => _t(
        'پەیوەندییەکەت بپشکنە و دووبارە هەوڵ بدەرەوە.',
        'تحقق من اتصالك وحاول مرة أخرى.',
      );
  String get retry => _t('دووبارە هەوڵ بدەرەوە', 'إعادة المحاولة');

  // ── وردەکاری ────────────────────────────────────────────────────────────
  String get detailTitle => _t('وردەکاری مامەڵە', 'تفاصيل المعاملة');
  String get receiptTitle => _t('پسوولەی مامەڵە', 'إيصال المعاملة');
  String get txId => _t('ئایدی مامەڵە', 'معرّف المعاملة');
  String get date => _t('ڕێکەوت', 'التاريخ');
  String get status => _t('دۆخ', 'الحالة');
  String get statusPending => _t('چاوەڕوانی', 'قيد الانتظار');
  String get statusRejected => _t('ڕەتکراوە', 'مرفوضة');

  String get summary => _t('پوختە', 'الملخص');
  String get topUpSummary => _t('پوختەی زیادکردنی پارە', 'ملخص إضافة الرصيد');
  String get refundSummary =>
      _t('پوختەی گەڕانەوەی پارە', 'ملخص استرداد المبلغ');

  String get total => _t('کۆی گشتی', 'المجموع');
  String get totalIqd => _t('کۆی گشتی (د.ع)', 'المجموع (د.ع)');
  String get accountBalance => _t('باڵانسی هەژمار', 'رصيد الحساب');
  String get balanceBefore => _t('باڵانسی پێش مامەڵە', 'الرصيد قبل المعاملة');
  String get balanceAfter => _t('باڵانسی دوای مامەڵە', 'الرصيد بعد المعاملة');
  String get totalPaid => _t('کۆی گشتی دراو', 'إجمالي المدفوع');
  String get totalAdded => _t('کۆی گشتی زیادکراو', 'إجمالي المُضاف');
  String get totalRefunded => _t('کۆی گشتی گەڕاوە', 'إجمالي المُسترد');
  String get totalDeducted => _t('کۆی گشتی بڕدراو', 'إجمالي المخصوم');

  String get paymentInfo => _t('زانیاری پارەدان', 'معلومات الدفع');
  String get noPaymentRequired =>
      _t('پارەدان پێویست نەبوو', 'لم يكن الدفع مطلوباً');
  String get paymentMethod => _t('ڕێگای پارەدان', 'طريقة الدفع');
  String get receiptUid => _t('ژ.م پسوولە', 'رقم الإيصال');

  String get adName => _t('ناوی ڕیکلام', 'اسم الإعلان');
  String get topUpSource => _t('سەرچاوەی زیادکردنی پارە', 'مصدر إضافة الرصيد');

  String get pdfButton => _t('داوڵۆند بکە بە PDF', 'تنزيل بصيغة PDF');
  String get pdfFailed => _t(
        'نەتوانرا PDF دروست بکرێت — دووبارە هەوڵ بدەرەوە',
        'تعذّر إنشاء ملف PDF — حاول مرة أخرى',
      );
  String get copied => _t('بەسەرکەوتوویی کۆپی کرا', 'تم النسخ بنجاح');
  String get copyFailed =>
      _t('کۆپی نەکرا؛ دووبارە هەوڵ بدەرەوە.', 'تعذّر النسخ؛ حاول مرة أخرى.');

  // ── ڕێگای پارەدان ───────────────────────────────────────────────────────
  String get methodBalance => _t('باڵانسی هەژمار', 'رصيد الحساب');
  String get methodAdmin => _t('لەلایەن ئادمینەوە', 'من قبل المشرف');
  String get methodVoucher => _t('ڤووچەر', 'قسيمة');
  String get methodReward => _t('خەڵات', 'مكافأة');
  String get methodCoins => _t('کۆین', 'عملات');

  // ── سەرچاوەی زیادکردن ───────────────────────────────────────────────────
  String get sourceOnline => _t('پارەدانی ئۆنلاین', 'دفع إلكتروني');
  String get sourceManual => _t('گواستنەوەی دەستی', 'تحويل يدوي');
  String get sourceAdmin =>
      _t('زیادکردن لەلایەن ئادمینەوە', 'إضافة من قبل المشرف');
  String get sourceReward =>
      _t('خەڵاتی تیروپشکی هەفتانە', 'جائزة السحب الأسبوعي');
  String get sourceCoins => _t('گۆڕینەوەی کۆین', 'تحويل العملات');
  String sourceVoucher(String code) =>
      code.isEmpty ? methodVoucher : '$methodVoucher · $code';
}
