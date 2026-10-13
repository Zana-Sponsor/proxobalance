// auth_design.dart
import 'package:flutter/material.dart';
// ⚠ بوو `import '../../main.dart' show kAppFont;` — بەڵام `main.dart`
// نە `kAppFont` پێناسە دەکات و نە دەریدەخات (`export`ی نییە)؛ تەنها
// خۆی لە `app_theme.dart`ـەوە هاوردەی دەکات، و هاوردەکردن
// دەرخستن نییە. بۆیە `show kAppFont` هیچی نەدەهێنا و ناوەکە
// چارەسەر نەدەکرا. سەرچاوەکەی ڕاستەوخۆ لێرەوە دێت — هەروەک
// هەموو فایلەکانی تری ئەپەکە.
import '../../theme/app_theme.dart' show kAppFont;
import '../../theme/app_locale.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AuthTokens
// ─────────────────────────────────────────────────────────────────────────────

abstract final class AuthTokens {
  // ── پەلێتی ڕەنگ — تاقە سەرچاوە بۆ هەموو شاشەکانی چوونەژوورەوە ────────────
  // ⚠ پێش ئەمە هیچ ڕەنگێک لێرە نەبوو: هەر سێ فایلەکەی auth ژمارە hex-ەکانی
  // خۆیان لەناو `build`ـەکاندا دەنووسییەوە (#0365FF ١٢ جار، #E2E8F0 ٤ جار،
  // #94A3B8 ٤ جار، #0B0B32، #68687F، #FCA5A5 …). ئێستا هەموویان لێرەوە
  // دەخوێنرێنەوە، بۆیە گۆڕینی یەک دێڕ هەموو ڕووکاری چوونەژوورەوە دەگۆڕێت.
  static const Color pageBackground = Color(0xFFFFFFFF);
  static const Color fieldFill      = Colors.white;
  static const Color fieldFillOff   = Color(0xFFF8FAFC);

  /// مەرەکەبی سەرەکی — هەمان `AppColors.ink`ی ئەپەکە (#0F172A).
  static const Color ink         = Color(0xFF0F172A);

  /// دەقی لاوەکی — هەمان `#64748B`ی tools_screen و دۆخە بەتاڵەکان.
  static const Color inkMuted    = Color(0xFF64748B);

  /// دەقی جێگرەوە (placeholder) و ئایکۆنی پێشەوەی خانەکان.
  static const Color placeholder = Color(0xFF94A3B8);

  /// سنووری نەچالاکی خانەکان — هەمان سنووری چیپەکانی فلتەری ڕیکلام.
  static const Color line        = Color(0xFFE2E8F0);
  static const Color lineOff     = Color(0xFFF1F5F9);

  /// شینی سیستەم بۆ فۆکەس، لینک، CTA و ئایکۆنی چالاک.
  static const Color accent      = Color(0xFF046CFA);

  /// ڕووی دوگمەی سەرەکی — شینی دیاریکراوی Auth.
  static const Color primary     = Color(0xFF046CFA);
  static const Color onPrimary   = Color(0xFFFFFFFF);

  /// هەڵە و ئاگادارکردنەوە — بانەرێکی سووری نەرم.
  static const Color danger      = Color(0xFFDC2626);
  static const Color dangerBg    = Color(0xFFFEF2F2);
  static const Color dangerField = Color(0xFFEF4444);

  static const Color success     = Color(0xFF13A56A);
  static const Color successBg   = Color(0xFFECFDF5);

  /// ⚠ بوو 20. ئێستا 16 — هەمان گەتەری ئاسۆیی هەموو شاشەکانی تری ئەپەکە
  /// (باری فلتەری ڕیکلام، کارتە خێراکان، دۆخە بەتاڵەکان).
  static const EdgeInsetsDirectional pagePadding =
      EdgeInsetsDirectional.symmetric(horizontal: 16);

  // ── بۆشاییە یەکگرتووەکان ──────────────────────────────────────────────────
  static const double gapTopToTitle      = 16;
  static const double gapTitleToSubtitle = 6;
  static const double gapSubtitleToForm  = 20;
  static const double gapLabelToField    = 6;
  static const double gapBetweenFields   = 10.0;
  static const double gapFormToForgot    = 8;
  static const double gapForgotToSubmit  = 18;
  static const double gapSubmitToPrompt  = 16;
  static const double gapHeaderToPin     = 20;
  static const double gapSectionBottom   = 16;

  // ── فۆنت و دەقەکان ────────────────────────────────────────────────────────
  // هەمان سیستەمی پسوولەکان (`ReceiptTokens`): تەنها دوو قەبارە، هەمووی w500.
  //   • textSize  = 14 — هەموو دەقێک: خانە، label، دوگمە، لینک، یارمەتی، هەڵە.
  //     (= Material 3 Body Medium / Label Large)
  //   • titleSize = 16 — تەنها ناونیشانی پەڕە و ژمارەکانی OTP.
  //     (= Material 3 Title Medium)
  // ⚠ هیچ Bold / SemiBold ـێک نییە.
  static const double textSize = 14;
  static const double titleSize = 16;
  static const FontWeight weight = FontWeight.w500;

  static const TextStyle title = TextStyle(
    fontFamily: kAppFont,
    fontSize: titleSize,
    fontWeight: weight,
    color: ink,
    height: 1.30,
  );

  static const TextStyle subtitle = TextStyle(
    fontFamily: kAppFont,
    fontSize: textSize,
    fontWeight: weight,
    color: inkMuted,
    height: 1.40,
  );

  static const TextStyle fieldText = TextStyle(
    fontFamily: kAppFont,
    fontSize: textSize,
    fontWeight: weight,
    height: 1.30,
    color: ink,
  );

  static const TextStyle fieldLabel = TextStyle(
    fontFamily: kAppFont,
    fontSize: textSize,
    fontWeight: weight,
    color: ink,
    height: 1.30,
  );

  static const TextStyle buttonText = TextStyle(
    fontFamily: kAppFont,
    fontSize: textSize,
    height: 1.25,
    fontWeight: weight,
    color: onPrimary,
  );

  /// ژمێرەری دووبارەناردنەوە و دەقی یارمەتی ژێر OTP.
  static const TextStyle helper = TextStyle(
    fontFamily: kAppFont,
    fontSize: textSize,
    fontWeight: weight,
    color: inkMuted,
    height: 1.35,
  );

  static const TextStyle link = TextStyle(
    fontFamily: kAppFont,
    fontSize: textSize,
    height: 1.35,
    fontWeight: weight,
  );

  static const TextStyle inlineError = TextStyle(
    fontFamily: kAppFont,
    fontSize: textSize,
    height: 1.30,
    fontWeight: weight,
  );

  static const TextStyle ruleText = TextStyle(
    fontFamily: kAppFont,
    fontSize: textSize,
    fontWeight: weight,
    height: 1.35,
  );

  static const TextStyle otpDigit = TextStyle(
    fontFamily: kAppFont,
    fontSize: titleSize,
    fontWeight: weight,
    height: 1.20,
    color: ink,
  );

  // ── پێوانەی کۆنتڕۆڵەکان ────────────────────────────────────────────────────
  /// ⚠ بوو 50. 48 ئەو بەرزاییەیە کە هەموو دوگمە سەرەکییەکانی ئەپەکە
  /// بەکاری دەهێنن (`_kCtaHeight`ی ad_details، پیلەکانی tools).
  static const double buttonHeight = 48;
  static const double buttonRadius = 12;
  static const double fieldRadius  = 12;
  /// ⚠ ستوونی بوو 13. ئێستا 15 — لەناو مەودای 14–16، بۆیە خانەکە
  /// بەرزاییەکی ئاسوودەی هەیە بەبێ ئەوەی لە دوگمەکە قەڵەوتر بێت.
  static const EdgeInsets fieldContentPadding =
      EdgeInsets.symmetric(horizontal: 14, vertical: 15);

  static const double errorSlotHeight = 20; // یەک دێڕی 14 × 1.30
  static const double trailingSlot    = 42;
  static const double clearIconSize   = 17;

  // ── چیپسەکان ─────────────────────────────────────────────────────────────
  static const double chipHeight = 32; // دەقی 14
  static const double chipRadius = 16;
  static const double chipGap    = 6;
  static const double gapFieldToChips = 4;
  static const TextStyle chipText = TextStyle(
    fontFamily: kAppFont,
    fontSize: textSize,
    height: 1.20,
    fontWeight: weight,
  );

  // ── سندووقەکانی OTP ───────────────────────────────────────────────────────
  /// ⚠ بوو 46 × 52.
  static const double otpBoxWidth  = 48;
  static const double otpBoxHeight = 54;
  static const double otpBoxRadius = 12;
  static const double otpBoxGap    = 8;
  static const double otpHeaderIcon = 42;

  // ── پێوەری هێزی وشەی نهێنی ────────────────────────────────────────────────
  static const double meterSegmentHeight = 4;
  static const double meterSegmentRadius = 3;
  static const double meterSegmentGap    = 4;
  static const Color strengthWeakColor   = Color(0xFFEF4444);
  static const Color strengthMediumColor = Color(0xFFF59E0B);
  static const Color strengthStrongColor = Color(0xFF13A56A);

  // ── ئەنیمەیشن ──────────────────────────────────────────────────────────────
  static const Duration viewTransition  = Duration(milliseconds: 240);
  static const Duration microTransition = Duration(milliseconds: 180);
  static const Duration shake           = Duration(milliseconds: 250);
  static const Curve curve              = Curves.easeInOutCubic;
  static const Curve microCurve         = Curves.easeOutCubic;
}

// ─────────────────────────────────────────────────────────────────────────────
// AuthStrings
// ─────────────────────────────────────────────────────────────────────────────

abstract final class AuthStrings {
  static String _v(String ku, String ar) => ProxoLocale.isArabic ? ar : ku;

  static String get signInTitle => _v('چوونەژوورەوە', 'تسجيل الدخول');
  static String get signInSubtitle => _v(
      'بەخێربێیتەوە! تکایە زانیارییەکانت بنووسە',
      'مرحباً بعودتك! أدخل معلوماتك للمتابعة');
  static String get signUpTitle => _v('دروستکردنی هەژمار', 'إنشاء حساب');
  static String get signUpSubtitle => _v(
      'هەژمارێکی نوێ لە پڕۆکسۆ دروست بکە',
      'أنشئ حساباً جديداً في Proxo');
  static String get resetPasswordTitle =>
      _v('گۆڕینی وشەی نهێنی', 'إعادة تعيين كلمة المرور');
  static String get resetPasswordSubtitle => _v(
      'ئیمەیڵەکەت بنووسە بۆ وەرگرتنی کۆد',
      'أدخل بريدك الإلكتروني لاستلام الرمز');

  static String get fullNameLabel => _v('ناوی تەواو', 'الاسم الكامل');
  static String get fullNameHint => _v('ناوەکەت لێرە بنووسە', 'اكتب اسمك هنا');
  static String get emailLabel => _v('ئیمەیڵ', 'البريد الإلكتروني');

  // ── کۆنترۆڵی بەشەکراوی چوونەژوورەوە ─────────────────────────────────────
  // ⚠ تەنها لە شاشەی **چوونەژوورەوە**دا بەکاردێن. شاشەی تۆمارکردن
  // وەک خۆی ماوەتەوە و هیچ سویچێکی نییە.
  static String get channelPhone => _v('ژمارەی مۆبایل', 'رقم الهاتف');
  static String get channelEmail => _v('ئیمەیڵ', 'البريد الإلكتروني');
  static String get phoneLabel => _v('ژمارەی مۆبایل', 'رقم الهاتف');
  static const phoneHint = '7XX XXX XXXX';
  static const phonePrefix          = '+964';
  static String get sendOtpButton => _v('ناردنی کۆدی دڵنیابوونەوە', 'إرسال رمز التحقق');
  static String get phoneInvalid => _v('ژمارەی مۆبایل دروست نییە', 'رقم الهاتف غير صحيح');
  static String get otpSendFailed => _v(
      'ناردنی کۆد سەرکەوتوو نەبوو — دووبارە هەوڵ بدەوە',
      'تعذر إرسال الرمز، حاول مرة أخرى');
  static String get phoneBanned => _v(
      'ئەم هەژمارە ڕاگیراوە. پەیوەندی بە پشتگیرییەوە بکە.',
      'هذا الحساب موقوف. تواصل مع الدعم.');
  /// چەند هەژمارێک هەمان ژمارەیان تۆمار کردووە. ⚠ ئەپەکە بە ئەنقەست
  /// یەکێکیان هەڵنابژێرێت — بڕوانە `ambiguous_phone` لە فەنکشنی ئێج.
  static String get phoneAmbiguous => _v(
      'ئەم ژمارەیە لەسەر زیاتر لە هەژمارێک تۆمارکراوە!',
      'رقم الهاتف مرتبط بأكثر من حساب');
  static String get phoneNotRegistered => _v(
      'نەتوانرا بەم ژمارەیە بەردەوام بیت. زانیارییەکان بپشکنەوە.',
      'تعذر المتابعة بهذا الرقم. تحقق من المعلومات.');
  static String get phoneAlreadyRegistered => _v(
      'ئەم ژمارەیە پێشتر تۆمارکراوە؛ تکایە بچۆ ژوورەوە',
      'هذا الرقم مسجل مسبقاً؛ سجّل الدخول');
  static String get phoneNoEmail => _v(
      'ناتوانرێت بە ژمارە بچیتە ژوورەوە بۆ ئەم هەژمارە. تکایە بە ئیمەیڵ بچۆرە ژوورەوە.',
      'تعذر تسجيل الدخول بالرقم لهذا الحساب. استخدم البريد الإلكتروني.');
  static const emailHint            = 'example@gmail.com';
  static String get passwordLabel => _v('وشەی نهێنی', 'كلمة المرور');
  static const passwordHint         = '••••••••';
  static String get confirmPasswordLabel =>
      _v('دووبارەکردنەوەی وشەی نهێنی', 'تأكيد كلمة المرور');

  static String get forgotPasswordLink =>
      _v('وشەی نهێنیت لەبیرچووە؟', 'نسيت كلمة المرور؟');

  static String get continueAsPrefix => _v('بەردەوامبوون وەک ', 'المتابعة باسم ');
  static String get notYou => _v('ئەمە من نیم', 'ليس أنا');
  static String get enterPasswordToContinue => _v(
      'وشەی نهێنیت بنووسە بۆ بەردەوامبوون',
      'أدخل كلمة المرور للمتابعة');
  static String get signInButton => _v('چوونەژوورەوە', 'تسجيل الدخول');
  static String get signUpButton => _v('بەردەوامبوون', 'متابعة');
  static String get savePasswordButton =>
      _v('پاشەکەوتکردن و چوونەژوورەوە', 'حفظ وتسجيل الدخول');
  static String get verifyButton => _v('پشتڕاستکردنەوە', 'تحقق');

  static String get noAccountLead => _v('هەژمارت نییە؟', 'ليس لديك حساب؟');
  static String get noAccountAction => _v('تۆمارکردن', 'إنشاء حساب');
  static String get haveAccountLead => _v('هەژمارت هەیە؟', 'لديك حساب؟');
  static String get haveAccountAction => _v('چوونەژوورەوە', 'تسجيل الدخول');

  static String get strengthHeader => _v('هێزی وشەی نهێنی:', 'قوة كلمة المرور:');
  static String get strengthWeak => _v('لاواز', 'ضعيفة');
  static String get strengthMedium => _v('مامناوەند', 'متوسطة');
  static String get strengthStrong => _v('بەهێز', 'قوية');

  static String get ruleMinChars => _v('لانیکەم ٨ پیت بێت', '8 أحرف على الأقل');
  static String get ruleUppercase => _v('پیتی گەورەی تێدا بێت (A-Z)', 'حرف كبير (A-Z)');
  static String get ruleSpecial => _v('هێمای تایبەتی تێدا بێت (@, #, \$, ...)', 'رمز خاص (@, #, \$, ...)');
  static String get ruleDigit => _v('ژمارەی تێدا بێت (0-9)', 'رقم (0-9)');

  static String get otpTitle => _v('کۆدی دڵنیاکردنەوە', 'رمز التحقق');
  static String get otpSubtitle => _v('کۆد نێردرا بۆ:', 'تم إرسال الرمز إلى:');
  static String get resendIn => _v('داواکردنەوەی کۆد دوای', 'إعادة الإرسال خلال');
  static String get resendAction => _v('دووبارە ناردنەوەی کۆد', 'إعادة إرسال الرمز');

  static String get errorPrefix => _v('هەڵە: ', 'خطأ: ');

  static String asError(String message) {
    final String m = message.trim();
    if (m.isEmpty) return errServer;
    if (m.startsWith(errorPrefix)) return m;
    return errorPrefix + m;
  }

  static String get errEmptyField => _v('تکایە ئەم خانەیە پڕبکەرەوە', 'يرجى ملء هذا الحقل');
  static String get errInvalidEmail => _v('ئیمەیڵێکی دروست بنووسە', 'أدخل بريداً إلكترونياً صحيحاً');
  static String get errShortPassword => _v('وشەی نهێنی دەبێت کەمترین ٨ پیت بێت', 'يجب ألا تقل كلمة المرور عن 8 أحرف');
  static String get errWeakPassword => _v('وشەی نهێنی دەبێت پیتی گەورە، ژمارە و هێمای تایبەتی تێدا بێت', 'يجب أن تتضمن كلمة المرور حرفاً كبيراً ورقماً ورمزاً خاصاً');
  static String get errPasswordMismatch => _v('وشەی نهێنییەکان یەکسان نین', 'كلمتا المرور غير متطابقتين');
  static String get errInvalidName => _v('ناوێکی دروست بنووسە', 'أدخل اسماً صحيحاً');
  static String get errInvalidOtp => _v('کۆدی دڵنیاکردنەوە هەڵەیە', 'رمز التحقق غير صحيح');
  static String get errExpiredOtp => _v('کاتی کۆدەکە بەسەرچووە', 'انتهت صلاحية الرمز');
  static String get errUserNotFound => _v('زانیارییەکان دروست نین', 'تعذر التحقق من المعلومات');
  static String get errWrongPassword => _v('ئیمەیڵ یان وشەی نهێنی هەڵەیە', 'البريد الإلكتروني أو كلمة المرور غير صحيحة');
  static String get errEmailExists => _v('ناتوانرێت بەم ئیمەیڵە بەردەوام بیت', 'تعذر المتابعة بهذا البريد الإلكتروني');
  static String get errNetwork => _v('پەیوەندی ئینتەرنێت نییە', 'لا يوجد اتصال بالإنترنت');
  static String get errServer => _v('هەڵەیەک لە سێرڤەر ڕوویدا', 'حدث خطأ في الخادم');

  static String get lockoutBody => _v('ئەم هەژمارە کاتی قفڵکراوە بەهۆی هەوڵی زۆر.', 'تم قفل الحساب مؤقتاً بسبب كثرة المحاولات.');
  static String get lockoutAction => _v('پەیوەندی بە پشتگیری بکە.', 'تواصل مع الدعم.');
  static String get supportUnavailable => _v('ناتوانرێت واتساپ بکرێتەوە. پەیوەندی بکە بە ٠٧٧٥٨٨٨٧٤٨٨', 'تعذر فتح واتساب. اتصل على 07758887488');
}

const String kSupportWhatsAppNumber  = '9647758887488';
const String kSupportWhatsAppMessage = 'سڵاو، کێشەم هەیە لە چوونەژوورەوە بۆ هەژمارەکەم.';

const List<String> kEmailDomainSuggestions = <String>[
  '@gmail.com',
];

// ─────────────────────────────────────────────────────────────────────────────
// Password Policy
// ─────────────────────────────────────────────────────────────────────────────

enum PasswordStrength { none, weak, medium, strong }

extension PasswordStrengthX on PasswordStrength {
  int get filledSegments => switch (this) {
        PasswordStrength.none   => 0,
        PasswordStrength.weak   => 1,
        PasswordStrength.medium => 2,
        PasswordStrength.strong => 3,
      };

  String get label => switch (this) {
        PasswordStrength.none   => '',
        PasswordStrength.weak   => AuthStrings.strengthWeak,
        PasswordStrength.medium => AuthStrings.strengthMedium,
        PasswordStrength.strong => AuthStrings.strengthStrong,
      };

  Color get color => switch (this) {
        PasswordStrength.none   => const Color(0x00000000),
        PasswordStrength.weak   => AuthTokens.strengthWeakColor,
        PasswordStrength.medium => AuthTokens.strengthMediumColor,
        PasswordStrength.strong => AuthTokens.strengthStrongColor,
      };

  bool get isAcceptable => this == PasswordStrength.strong;
}

final class PasswordRule {
  const PasswordRule({required this.label, required this.test});
  final String label;
  final bool Function(String password) test;
}

abstract final class PasswordPolicy {
  static const int minLength = 8;

  static final RegExp _uppercase = RegExp(r'[A-Z]');
  static final RegExp _digit     = RegExp(r'[0-9]');
  static final RegExp _special   = RegExp(r'[@#$%&!?*^~]');

  static List<PasswordRule> get rules => <PasswordRule>[
    PasswordRule(label: AuthStrings.ruleMinChars, test: (p) => p.length >= minLength),
    PasswordRule(label: AuthStrings.ruleUppercase, test: (p) => _uppercase.hasMatch(p)),
    PasswordRule(label: AuthStrings.ruleSpecial,   test: (p) => _special.hasMatch(p)),
    PasswordRule(label: AuthStrings.ruleDigit,     test: (p) => _digit.hasMatch(p)),
  ];

  static List<bool> satisfaction(String password) =>
      rules.map((r) => r.test(password)).toList(growable: false);

  static PasswordStrength evaluate(String password) {
    if (password.isEmpty) return PasswordStrength.none;
    final int score = satisfaction(password).where((b) => b).length;
    return switch (score) {
      0       => PasswordStrength.none,
      1 || 2  => PasswordStrength.weak,
      3       => PasswordStrength.medium,
      _       => PasswordStrength.strong,
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AuthValidators
// ─────────────────────────────────────────────────────────────────────────────

abstract final class AuthValidators {
  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

  static String normalizeEmail(String? v) => (v ?? '').trim().toLowerCase();

  static String? email(String? v) {
    final String s = normalizeEmail(v);
    if (s.isEmpty) return AuthStrings.errEmptyField;
    if (!_email.hasMatch(s)) return AuthStrings.errInvalidEmail;
    return null;
  }

  static String? loginPassword(String? v) =>
      (v ?? '').isEmpty ? AuthStrings.errEmptyField : null;

  static const int minLoginPasswordLength = 6;

  static bool signInReady({required String email, required String password}) =>
      email.trim().isNotEmpty && password.isNotEmpty;

  static bool signUpReady({
    required String name,
    required String phone,
    required String password,
    required String confirmation,
  }) =>
      name.trim().isNotEmpty &&
      RegExp(r'^\+9647\d{9}$').hasMatch(phone) &&
      AuthValidators.newPassword(password) == null &&
      confirmation.isNotEmpty &&
      confirmation == password;

  static String? newPassword(String? v) {
    final String s = v ?? '';
    if (s.isEmpty) return AuthStrings.errEmptyField;
    if (s.length < PasswordPolicy.minLength) return AuthStrings.errShortPassword;
    if (!PasswordPolicy.evaluate(s).isAcceptable) {
      return AuthStrings.errWeakPassword;
    }
    return null;
  }

  static String? confirmPassword(String? v, String original) {
    final String s = v ?? '';
    if (s.isEmpty) return AuthStrings.errEmptyField;
    if (s != original) return AuthStrings.errPasswordMismatch;
    return null;
  }

  static String? fullName(String? v) {
    final String s = (v ?? '').trim();
    if (s.isEmpty) return AuthStrings.errEmptyField;
    if (s.runes.length < 3) return AuthStrings.errInvalidName;
    return null;
  }
}
