import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart' show kIqdRate;
import '../theme/app_theme.dart';
import '../widgets/auth/auth_design.dart'
    show kSupportWhatsAppNumber;
import '../widgets/proxo_refresh.dart';
import 'ad_screen.dart';
import 'deposit_screen.dart';
import 'faq_screen.dart' show FaqItem, kFaqItems;
import 'tools_screen.dart';

const String _emailChangeWebhookUrl =
    'https://email.proxopages.com/webhook/send_otp';

// ─────────────────────────────────────────────────────────────────────────────
// Profile screen
//
// Dynamic data is deliberately held in small ValueNotifiers. A profile or
// wallet realtime event therefore rebuilds only the header or balance text,
// and toggling the eye never invalidates the full scroll view.
// ─────────────────────────────────────────────────────────────────────────────

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.onBottomNavTap,
    this.refreshController,
  });

  /// Present when this screen is a MainShell tab. Standalone profile routes
  /// leave it null and quick actions push ordinary routes instead.
  final ValueChanged<int>? onBottomNavTap;
  final ProxoRefreshController? refreshController;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  SupabaseClient get _client => Supabase.instance.client;

  late final ValueNotifier<_ProfileData> _profile;
  final ValueNotifier<double?> _balanceIqd = ValueNotifier<double?>(null);
  final ValueNotifier<bool> _showBalance = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _signingOut = ValueNotifier<bool>(false);
  final ScrollController _scrollController = ScrollController();

  RealtimeChannel? _profileChannel;
  RealtimeChannel? _walletChannel;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    final User? user = _client.auth.currentUser;
    _profile = ValueNotifier<_ProfileData>(_ProfileData.fromUser(user));
    unawaited(_loadData());
    _subscribeToChanges(user);
    _authSubscription = _client.auth.onAuthStateChange.listen((AuthState state) {
      final User? updatedUser = state.session?.user;
      if (!mounted || updatedUser == null) return;
      if (state.event == AuthChangeEvent.userUpdated ||
          state.event == AuthChangeEvent.tokenRefreshed) {
        unawaited(_loadProfile(updatedUser));
      }
    });
  }

  @override
  void dispose() {
    final RealtimeChannel? profileChannel = _profileChannel;
    final RealtimeChannel? walletChannel = _walletChannel;
    profileChannel?.unsubscribe();
    walletChannel?.unsubscribe();
    _authSubscription?.cancel();
    _scrollController.dispose();
    _profile.dispose();
    _balanceIqd.dispose();
    _showBalance.dispose();
    _signingOut.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final User? user = _client.auth.currentUser;
    if (user == null) return;
    await Future.wait<void>(<Future<void>>[
      _loadProfile(user),
      _loadBalance(user.id),
    ]);
  }

  Future<void> _loadProfile(User user) async {
    try {
      Map<String, dynamic>? row = await _client
          .from('profiles')
          .select('full_name, email, phone, avatar_url')
          .eq('id', user.id)
          .maybeSingle();

      // Supabase Auth is authoritative for the sign-in address. With secure
      // email change enabled, Auth keeps the old address until the user has
      // completed the confirmation flow. The next profile load then mirrors
      // the confirmed address into public.profiles, keeping the app's custom
      // login and password-recovery lookups consistent without ever exposing
      // an unconfirmed address as active.
      final String authEmail = _normaliseEmail(user.email ?? '');
      final bool authEmailIsSynthetic =
          authEmail.endsWith('@phone.proxopages.com');
      final String profileEmail =
          _normaliseEmail(row?['email']?.toString() ?? '');
      if (row != null &&
          authEmail.isNotEmpty &&
          !authEmailIsSynthetic &&
          authEmail != profileEmail) {
        row = <String, dynamic>{...row, 'email': authEmail};
        try {
          final Map<String, dynamic>? syncedProfile = await _client
              .from('profiles')
              .update(<String, dynamic>{'email': authEmail})
              .eq('id', user.id)
              .select('id')
              .maybeSingle();
          if (syncedProfile == null) {
            throw StateError('Confirmed email sync returned no row.');
          }
        } catch (error, stackTrace) {
          debugPrint(
            '[ProfileScreen] confirmed email sync failed: '
            '$error\n$stackTrace',
          );
        }
      }
      if (!mounted) return;
      _profile.value = _ProfileData.fromRow(row, fallbackUser: user);
    } catch (error, stackTrace) {
      debugPrint('[ProfileScreen] profile load failed: $error\n$stackTrace');
    }
  }

  Future<void> _loadBalance(String userId) async {
    try {
      final Map<String, dynamic>? row = await _client
          .from('pa_wallets')
          .select('balance')
          .eq('user_id', userId)
          .maybeSingle();
      if (!mounted) return;
      _balanceIqd.value = _walletValueToIqd(row?['balance']);
    } catch (error, stackTrace) {
      debugPrint('[ProfileScreen] wallet load failed: $error\n$stackTrace');
    }
  }

  void _subscribeToChanges(User? user) {
    if (user == null) return;
    final String suffix = '${user.id}_${identityHashCode(this)}';

    _profileChannel = _client
        .channel('profile_screen_profile_$suffix')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: user.id,
          ),
          callback: (payload) {
            if (!mounted || payload.newRecord.isEmpty) return;
            _profile.value = _profile.value.merge(payload.newRecord);
          },
        )
        .subscribe();

    _walletChannel = _client
        .channel('profile_screen_wallet_$suffix')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'pa_wallets',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) {
            if (!mounted || !payload.newRecord.containsKey('balance')) return;
            _balanceIqd.value =
                _walletValueToIqd(payload.newRecord['balance']);
          },
        )
        .subscribe();
  }

  static double _walletValueToIqd(Object? value) {
    final double walletValue = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
    return walletValue * kIqdRate;
  }

  void _push(Widget page) {
    Navigator.of(context).push(
      ProxoPageRoute<void>(builder: (_) => page),
    );
  }

  void _openTabOrPage(int tab, Widget page) {
    final ValueChanged<int>? onBottomNavTap = widget.onBottomNavTap;
    if (onBottomNavTap != null) {
      onBottomNavTap(tab);
      return;
    }
    _push(page);
  }

  Future<void> _openEditProfile() async {
    final _ProfileData current = _profile.value;
    final bool? changed = await Navigator.of(context).push<bool>(
      ProxoPageRoute<bool>(
        builder: (_) => EditProfileScreen(
          initialFullName: current.fullName,
          initialEmail: current.email,
          initialPhone: current.phone,
          initialAvatarUrl: current.avatarUrl,
        ),
      ),
    );
    if (changed == true && mounted) {
      await _loadData();
    }
  }

  Future<void> _openSupport() async {
    final _SupportAction? action = await showModalBottomSheet<_SupportAction>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: _ProfileColors.scrim,
      builder: (_) => const _SupportSheet(),
    );
    if (action == null || !mounted) return;

    final String supportNumber =
        kSupportWhatsAppNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final Uri uri = action == _SupportAction.chat
        ? Uri.https(
            'wa.me',
            '/$supportNumber',
            const <String, String>{
              'text':
                  'سڵاو، پێویستم بە یارمەتیی تیمی پشتگیریی پڕۆکسۆ هەیە.',
            },
          )
        : Uri(
            scheme: 'tel',
            path: '+$supportNumber',
          );
    try {
      final bool opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        _showMessage(
          action == _SupportAction.chat
              ? 'نەتوانرا واتساپ بکرێتەوە. تکایە دواتر هەوڵ بدەرەوە.'
              : 'نەتوانرا پەیوەندی بکرێت. تکایە دواتر هەوڵ بدەرەوە.',
        );
      }
    } catch (_) {
      if (mounted) {
        _showMessage(
          action == _SupportAction.chat
              ? 'نەتوانرا واتساپ بکرێتەوە. تکایە دواتر هەوڵ بدەرەوە.'
              : 'نەتوانرا پەیوەندی بکرێت. تکایە دواتر هەوڵ بدەرەوە.',
        );
      }
    }
  }

  void _openAbout() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: _ProfileColors.scrim,
      builder: (_) => const _AboutAppSheet(),
    );
  }

  Future<void> _confirmSignOut() async {
    if (_signingOut.value) return;
    final bool confirmed = await _showConfirmationDialog(
          context,
          title: 'دەرچوون لە هەژمار',
          message: 'دڵنیایت دەتەوێت لە هەژمارەکەت دەربچیت؟',
          confirmText: 'دەرچوون',
        ) ??
        false;
    if (!confirmed || !mounted) return;

    _signingOut.value = true;
    try {
      await _client.auth.signOut();
    } on AuthException catch (error) {
      if (mounted) _showMessage(_friendlyAuthError(error.message));
    } catch (_) {
      if (mounted) {
        _showMessage('دەرچوون سەرکەوتوو نەبوو. تکایە دووبارە هەوڵ بدەرەوە.');
      }
    } finally {
      if (mounted) _signingOut.value = false;
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, textDirection: TextDirection.rtl),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
        child: Scaffold(
          backgroundColor: _ProfileColors.page,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: <Widget>[
                _ProfileTopBar(
                  showBack: widget.onBottomNavTap == null,
                  onBack: () => Navigator.of(context).maybePop(),
                  onEdit: _openEditProfile,
                ),
                Expanded(
                  child: ProxoRefresh(
                    controller: widget.refreshController,
                    scrollController: _scrollController,
                    onRefresh: _loadData,
                    child: ScrollConfiguration(
                      behavior: const _ProfileScrollBehavior(),
                      child: ListView(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        padding: EdgeInsets.fromLTRB(
                          16,
                          14,
                          16,
                          media.padding.bottom + 24,
                        ),
                        children: <Widget>[
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 430),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  ValueListenableBuilder<_ProfileData>(
                                    valueListenable: _profile,
                                    builder: (_, data, __) =>
                                        _ProfileIdentity(data: data),
                                  ),
                                  const SizedBox(height: 22),
                                  _BalanceCard(
                                    balanceIqd: _balanceIqd,
                                    showBalance: _showBalance,
                                    onTap: () => _push(const DepositScreen()),
                                  ),
                                  const SizedBox(height: 24),
                                  _QuickActions(
                                    onAds: () => _openTabOrPage(
                                      1,
                                      const AdScreen(),
                                    ),
                                    onAssets: () => _openTabOrPage(
                                      3,
                                      const ToolsScreen(),
                                    ),
                                    onCoupons: () => Navigator.of(context)
                                        .pushNamed('/coupons'),
                                  ),
                                  const SizedBox(height: 26),
                                  const _SectionTitle('هەژمار'),
                                  const SizedBox(height: 10),
                                  _SettingsGroup(
                                    entries: <_MenuEntry>[
                                      _MenuEntry(
                                        icon: SolarIconsOutline.bell,
                                        title: 'ئاگادارییەکان',
                                        onTap: () => Navigator.of(context)
                                            .pushNamed('/notifications'),
                                      ),
                                      _MenuEntry(
                                        icon: SolarIconsOutline.history,
                                        title: 'مێژووی مامەڵەکان',
                                        onTap: () => Navigator.of(context)
                                            .pushNamed('/transactions'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  const _SectionTitle('پشتگیری و ڕێساکان'),
                                  const SizedBox(height: 10),
                                  _SettingsGroup(
                                    entries: <_MenuEntry>[
                                      _MenuEntry(
                                        icon: SolarIconsOutline.chatRoundCall,
                                        title: 'پشتگیری',
                                        subtitle: 'پەیوەندی ڕاستەوخۆ بە واتساپ',
                                        onTap: _openSupport,
                                      ),
                                      _MenuEntry(
                                        icon: SolarIconsOutline.documentText,
                                        title: 'دەربارەی ئەپڵیکەیشن',
                                        onTap: _openAbout,
                                      ),
                                      _MenuEntry(
                                        icon: SolarIconsOutline.questionCircle,
                                        title: 'پرسیارە دووبارەکان',
                                        onTap: () =>
                                            _push(const _ProfileFaqScreen()),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  ValueListenableBuilder<bool>(
                                    valueListenable: _signingOut,
                                    builder: (_, signingOut, __) =>
                                        _SignOutTile(
                                      busy: signingOut,
                                      onTap: _confirmSignOut,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  const Text(
                                    'وەشانی ١.٠.٠',
                                    textAlign: TextAlign.center,
                                    style: _ProfileText.version,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit profile. Account deletion intentionally lives here, never on the main
// profile surface, so a destructive action cannot be triggered accidentally.
// ─────────────────────────────────────────────────────────────────────────────

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.initialFullName,
    required this.initialEmail,
    required this.initialPhone,
    this.initialAvatarUrl,
  });

  final String initialFullName;
  final String initialEmail;
  final String initialPhone;
  final String? initialAvatarUrl;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  SupabaseClient get _client => Supabase.instance.client;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();
  late final TextEditingController _emailController;
  late String? _currentAvatarUrl;
  Uint8List? _pendingAvatarBytes;
  String? _pendingAvatarContentType;
  bool _saving = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
    _currentAvatarUrl = widget.initialAvatarUrl;
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    if (_saving || _deleting) return;
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 88,
      );
      if (image == null) return;

      final Uint8List bytes = await image.readAsBytes();
      if (bytes.isEmpty) {
        _showMessage('وێنەکە بە دروستی نەخوێندرایەوە.');
        return;
      }
      if (bytes.lengthInBytes > 5 * 1024 * 1024) {
        _showMessage('قەبارەی وێنەکە نابێت لە ٥ مێگابایت زیاتر بێت.');
        return;
      }

      final String? contentType = _supportedImageContentType(bytes);
      if (contentType == null) {
        _showMessage('تەنها وێنەی JPG، PNG یان WebP ڕێگەپێدراوە.');
        return;
      }
      if (!mounted) return;
      setState(() {
        _pendingAvatarBytes = bytes;
        _pendingAvatarContentType = contentType;
      });
    } on PlatformException catch (error, stackTrace) {
      debugPrint(
        '[EditProfileScreen] avatar picker failed: $error\n$stackTrace',
      );
      if (mounted) {
        _showMessage('دەستگەیشتن بە گەلەری نەکرا؛ ڕێگەپێدانەکان بپشکنەوە.');
      }
    } catch (error, stackTrace) {
      debugPrint(
        '[EditProfileScreen] avatar read failed: $error\n$stackTrace',
      );
      if (mounted) _showMessage('وێنەکە هەڵنەبژێردرا؛ دووبارە هەوڵ بدەرەوە.');
    }
  }

  String? _supportedImageContentType(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0d &&
        bytes[5] == 0x0a &&
        bytes[6] == 0x1a &&
        bytes[7] == 0x0a) {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }
    return null;
  }

  Future<String> _uploadAvatar(User user) async {
    final Uint8List? bytes = _pendingAvatarBytes;
    final String? contentType = _pendingAvatarContentType;
    if (bytes == null || contentType == null) {
      throw StateError('No avatar selected.');
    }

    final String objectPath = '${user.id}/avatar';
    await _client.storage.from('avatars').uploadBinary(
          objectPath,
          bytes,
          fileOptions: FileOptions(
            cacheControl: '3600',
            contentType: contentType,
            upsert: true,
          ),
        );

    final String publicUrl =
        _client.storage.from('avatars').getPublicUrl(objectPath);
    final String versionedUrl = Uri.parse(publicUrl)
        .replace(
          queryParameters: <String, String>{
            'v': DateTime.now().millisecondsSinceEpoch.toString(),
          },
        )
        .toString();

    final Map<String, dynamic>? savedProfile = await _client
        .from('profiles')
        .update(<String, dynamic>{'avatar_url': versionedUrl})
        .eq('id', user.id)
        .select('id, avatar_url')
        .maybeSingle();
    if (savedProfile == null ||
        savedProfile['avatar_url']?.toString() != versionedUrl) {
      throw StateError('Avatar URL was not saved to profile.');
    }
    return versionedUrl;
  }

  Future<void> _save() async {
    if (_saving || _deleting || !_formKey.currentState!.validate()) return;
    final User? user = _client.auth.currentUser;
    if (user == null) {
      _showMessage('دانیشتنەکەت بەسەرچووە؛ تکایە دووبارە بچۆ ژوورەوە.');
      return;
    }

    final String email = _normaliseEmail(_emailController.text);
    final String currentEmail = _normaliseEmail(widget.initialEmail);
    final bool emailChanged = email != currentEmail;
    final bool avatarChanged = _pendingAvatarBytes != null;
    if (!emailChanged && !avatarChanged) {
      _showMessage('هیچ گۆڕانکارییەک نییە.');
      return;
    }
    setState(() => _saving = true);
    bool avatarSaved = false;
    try {
      if (avatarChanged) {
        final String savedAvatarUrl = await _uploadAvatar(user);
        avatarSaved = true;
        if (!mounted) return;
        setState(() {
          _currentAvatarUrl = savedAvatarUrl;
          _pendingAvatarBytes = null;
          _pendingAvatarContentType = null;
        });
      }

      if (!emailChanged) {
        if (mounted) Navigator.of(context).pop(true);
        return;
      }

      // The custom n8n workflow sends the OTP to the new address. Supabase
      // Auth is not asked to change anything until that code is verified.
      String requestId = await _requestEmailChangeCode(email);

      if (!mounted) return;
      setState(() => _saving = false);
      final bool? verified = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) =>
            _EmailChangeVerificationDialog(
          email: email,
          onVerify: (String code) => _verifyEmailChangeCode(
            userId: user.id,
            email: email,
            requestId: requestId,
            code: code,
          ),
          onResend: () async {
            try {
              requestId = await _requestEmailChangeCode(email);
              return null;
            } on _EmailWebhookException catch (error) {
              return _friendlyEmailWebhookError(error.code);
            } catch (error, stackTrace) {
              debugPrint(
                '[EditProfileScreen] email code resend failed: '
                '$error\n$stackTrace',
              );
              return 'کۆدەکە دووبارە نەنێردرا؛ تکایە دواتر هەوڵ بدەرەوە.';
            }
          },
        ),
      );
      if (!mounted) return;
      if (verified == true) {
        Navigator.of(context).pop(true);
      } else if (avatarSaved) {
        _showMessage('وێنەکە پاشەکەوت کرا؛ گۆڕینی ئیمەیڵ تەواو نەکرا.');
      }
    } on _EmailWebhookException catch (error) {
      if (mounted) {
        final String emailError = _friendlyEmailWebhookError(error.code);
        _showMessage(
          avatarSaved ? 'وێنەکە پاشەکەوت کرا؛ $emailError' : emailError,
        );
      }
    } on StorageException catch (error, stackTrace) {
      debugPrint(
        '[EditProfileScreen] avatar upload failed: $error\n$stackTrace',
      );
      if (mounted) {
        _showMessage('وێنەکە بارنەکرا؛ ئینتەرنێتەکەت بپشکنەوە و دووبارە هەوڵ بدەرەوە.');
      }
    } catch (error, stackTrace) {
      if (mounted) {
        _showMessage('گۆڕانکارییەکان پاشەکەوت نەکران. دووبارە هەوڵ بدەرەوە.');
      }
      debugPrint('[EditProfileScreen] save failed: $error\n$stackTrace');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String> _requestEmailChangeCode(String email) async {
    final Map<String, dynamic> result = await _callEmailWebhook(
      <String, dynamic>{
        'action': 'request_email_change',
        'new_email': email,
      },
    );
    final String requestId = result['request_id']?.toString().trim() ?? '';
    if (requestId.isEmpty) throw const _EmailWebhookException('server_error');
    return requestId;
  }

  Future<Map<String, dynamic>> _callEmailWebhook(
    Map<String, dynamic> payload,
  ) async {
    final Session? session = _client.auth.currentSession;
    if (session == null || session.accessToken.isEmpty) {
      throw const _EmailWebhookException('unauthorized');
    }

    late final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(_emailChangeWebhookUrl),
            headers: <String, String>{
              'Authorization': 'Bearer ${session.accessToken}',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 25));
    } on TimeoutException {
      throw const _EmailWebhookException('timeout');
    } catch (error) {
      throw _EmailWebhookException('network_error', cause: error);
    }

    Map<String, dynamic>? data;
    try {
      final Object? decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map) data = Map<String, dynamic>.from(decoded);
    } catch (_) {
      // Invalid webhook output is handled as a server error below.
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        data == null ||
        data['success'] != true) {
      final String code = data?['error']?.toString().trim() ?? 'server_error';
      throw _EmailWebhookException(code);
    }
    return data;
  }

  Future<void> _syncConfirmedEmail({
    required String userId,
    required String email,
  }) async {
    // Only a confirmed Auth address may be mirrored into public.profiles.
    // Returning the row also catches an UPDATE rejected by RLS.
    final Map<String, dynamic>? savedProfile = await _client
        .from('profiles')
        .update(<String, dynamic>{'email': email})
        .eq('id', userId)
        .select('id, email')
        .maybeSingle();
    if (savedProfile == null ||
        _normaliseEmail(savedProfile['email']?.toString() ?? '') != email) {
      throw StateError('Confirmed email was not saved to profiles.');
    }
  }

  Future<String?> _verifyEmailChangeCode({
    required String userId,
    required String email,
    required String requestId,
    required String code,
  }) async {
    try {
      final Map<String, dynamic> result = await _callEmailWebhook(
        <String, dynamic>{
          'action': 'verify_email_change',
          'request_id': requestId,
          'code': _normaliseOtp(code),
        },
      );
      final String confirmedEmail =
          _normaliseEmail(result['email']?.toString() ?? '');
      if (result['verified'] != true || confirmedEmail != email) {
        return 'پشتڕاستکردنەوە سەرکەوتوو نەبوو؛ دووبارە هەوڵ بدەرەوە.';
      }

      // The workflow has now changed and confirmed the Auth email through the
      // Admin API. Refresh local Auth state so future requests carry it.
      try {
        await _client.auth.refreshSession();
      } on AuthException {
        // The database trigger has already mirrored the confirmed address.
        // A later automatic refresh will update the local User object.
      }
      await _syncConfirmedEmail(userId: userId, email: email);
      return null;
    } on PostgrestException catch (error) {
      return _friendlyDatabaseError(error);
    } on _EmailWebhookException catch (error) {
      return _friendlyEmailWebhookError(error.code);
    } catch (error, stackTrace) {
      debugPrint(
        '[EditProfileScreen] email verification failed: $error\n$stackTrace',
      );
      return 'پشتڕاستکردنەوە سەرکەوتوو نەبوو؛ دووبارە هەوڵ بدەرەوە.';
    }
  }

  Future<void> _deleteAccount() async {
    if (_saving || _deleting) return;
    final bool confirmed = await _showConfirmationDialog(
          context,
          title: 'سڕینەوەی هەژمار',
          message: 'ئەم کردارە هەمیشەییە و هەموو داتا، مامەڵە و '
              'ڕیکلامەکانت دەسڕێتەوە. دڵنیایت؟',
          confirmText: 'هەژمارەکەم بسڕەوە',
          destructive: true,
        ) ??
        false;
    if (!confirmed || !mounted) return;

    setState(() => _deleting = true);
    try {
      final FunctionResponse response =
          await _client.functions.invoke('delete-user');
      final Object? data = response.data;
      final bool succeeded = data is Map && data['success'] == true;
      if (!succeeded) {
        final String detail = data is Map
            ? (data['detail'] ?? data['error'] ?? '').toString()
            : '';
        throw StateError(detail.isEmpty ? 'delete-user failed' : detail);
      }

      // Clear this device's cached session after the server has completed the
      // hard delete. AuthGate owns the resulting stack replacement.
      try {
        await _client.auth.signOut();
      } catch (_) {
        // The just-deleted access token can already be invalid. Navigation is
        // still handled by the Auth state listener when local state is cleared.
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _deleting = false);
      _showMessage(
        'هەژمارەکە نەسڕایەوە. تکایە پەیوەندی بە پشتگیری بکە یان دواتر هەوڵ بدەرەوە.',
      );
      debugPrint('[EditProfileScreen] account deletion failed: $error');
    }
  }

  String? _validateEmail(String? value) {
    final String email = _normaliseEmail(value ?? '');
    if (email.isEmpty) return 'تکایە ئیمەیڵەکەت بنووسە.';
    if (email.length > 254 ||
        !RegExp(r"^[a-z0-9.!#$%&'*+/=?^_`{|}~-]+@"
                r'[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?'
                r'(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+$')
            .hasMatch(email)) {
      return 'ناونیشانی ئیمەیڵەکە دروست نییە.';
    }
    // Authentication elsewhere in this app intentionally accepts Gmail only.
    // Enforcing the same rule here prevents a valid-looking address from
    // becoming impossible to use on the login screen.
    if (!email.endsWith('@gmail.com')) {
      return 'تکایە ئیمەیڵێکی Gmail بەکاربهێنە.';
    }
    return null;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, textDirection: TextDirection.rtl),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final double textScale =
        media.textScaler.scale(1).clamp(0.9, 1.05).toDouble();
    final _ProfileData preview = _ProfileData(
      fullName: widget.initialFullName,
      email: _emailController.text.trim(),
      phone: widget.initialPhone,
      avatarUrl: _currentAvatarUrl,
    );

    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.linear(textScale)),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: _ProfileColors.page,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: <Widget>[
                _SimpleTopBar(
                  title: 'دەستکاریکردنی پرۆفایل',
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      16,
                      24,
                      16,
                      media.padding.bottom + 28,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 430),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Center(
                                child: _EditableProfileAvatar(
                                  data: preview,
                                  memoryBytes: _pendingAvatarBytes,
                                  enabled: !_saving && !_deleting,
                                  onTap: _pickAvatar,
                                ),
                              ),
                              const SizedBox(height: 9),
                              Text(
                                'بۆ گۆڕینی وێنە کلیک بکە',
                                textAlign: TextAlign.center,
                                style: _ProfileText.userContact.copyWith(
                                  color: _ProfileColors.muted,
                                ),
                              ),
                              const SizedBox(height: 28),
                              const _FieldLabel('ناوی تەواو'),
                              const SizedBox(height: 7),
                              TextFormField(
                                initialValue: widget.initialFullName.isEmpty
                                    ? '—'
                                    : widget.initialFullName,
                                readOnly: true,
                                enableInteractiveSelection: true,
                                canRequestFocus: false,
                                style: _ProfileText.field.copyWith(
                                  color: _ProfileColors.muted,
                                ),
                                decoration: _profileInputDecoration(
                                  hint: '—',
                                  icon: SolarIconsOutline.userRounded,
                                  readOnly: true,
                                  suffixIcon: SolarIconsOutline.lock,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const _FieldLabel('ئیمەیڵ'),
                              const SizedBox(height: 7),
                              Directionality(
                                textDirection: TextDirection.ltr,
                                child: TextFormField(
                                  controller: _emailController,
                                  enabled: !_saving && !_deleting,
                                  validator: _validateEmail,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _save(),
                                  autocorrect: false,
                                  textCapitalization: TextCapitalization.none,
                                  autofillHints: const <String>[
                                    AutofillHints.email,
                                  ],
                                  inputFormatters: <TextInputFormatter>[
                                    LengthLimitingTextInputFormatter(254),
                                  ],
                                  style: _ProfileText.field,
                                  decoration: _profileInputDecoration(
                                    hint: 'name@gmail.com',
                                    icon: SolarIconsOutline.letter,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const _FieldLabel('ژمارەی مۆبایل'),
                              const SizedBox(height: 7),
                              Directionality(
                                textDirection: TextDirection.ltr,
                                child: TextFormField(
                                  initialValue: widget.initialPhone.isEmpty
                                      ? '—'
                                      : widget.initialPhone,
                                  readOnly: true,
                                  enableInteractiveSelection: true,
                                  canRequestFocus: false,
                                  style: _ProfileText.field.copyWith(
                                    color: _ProfileColors.muted,
                                  ),
                                  decoration: _profileInputDecoration(
                                    hint: '—',
                                    icon: SolarIconsOutline.smartphone,
                                    readOnly: true,
                                    suffixIcon: SolarIconsOutline.lock,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                height: 48,
                                child: FilledButton(
                                  onPressed:
                                      _saving || _deleting ? null : _save,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _ProfileColors.primary,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor:
                                        _ProfileColors.primary.withOpacity(.45),
                                    shape: const RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.all(Radius.circular(14)),
                                    ),
                                    textStyle: _ProfileText.button,
                                  ),
                                  child: _saving
                                      ? const SizedBox.square(
                                          dimension: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text('پاشەکەوتکردن'),
                                ),
                              ),
                              const SizedBox(height: 34),
                              const _SectionTitle('ناوچەی مەترسیدار'),
                              const SizedBox(height: 8),
                              Material(
                                color: _ProfileColors.dangerSoft,
                                shape: const RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(20)),
                                  side: BorderSide(
                                    color: _ProfileColors.dangerBorder,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: _saving || _deleting
                                      ? null
                                      : _deleteAccount,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 13,
                                    ),
                                    child: Row(
                                      children: <Widget>[
                                        const Icon(
                                          SolarIconsOutline.userCrossRounded,
                                          size: 21,
                                          color: _ProfileColors.danger,
                                        ),
                                        const SizedBox(width: 12),
                                        const Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: <Widget>[
                                              Text(
                                                'سڕینەوەی هەژمار',
                                                style: _ProfileText.dangerTitle,
                                              ),
                                              SizedBox(height: 3),
                                              Text(
                                                'هەموو داتاکانت بە هەمیشەیی دەسڕێتەوە',
                                                style: _ProfileText.dangerSub,
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (_deleting)
                                          const SizedBox.square(
                                            dimension: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: _ProfileColors.danger,
                                            ),
                                          )
                                        else
                                          const Icon(
                                            SolarIconsOutline.altArrowLeft,
                                            size: 21,
                                            color: _ProfileColors.danger,
                                          ),
                                      ],
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileData {
  const _ProfileData({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.avatarUrl,
  });

  factory _ProfileData.fromUser(User? user) {
    final Map<String, dynamic> metadata =
        user?.userMetadata ?? const <String, dynamic>{};
    return _ProfileData(
      fullName: (metadata['full_name'] ?? metadata['name'] ?? '')
          .toString()
          .trim(),
      email: ((user?.email ?? '').trim().endsWith('@phone.proxopages.com'))
          ? ''
          : (user?.email ?? '').trim(),
      phone: (metadata['phone'] ?? user?.phone ?? '').toString().trim(),
      avatarUrl: _cleanAvatar(
        metadata['avatar_url'] ?? metadata['picture'],
      ),
    );
  }

  factory _ProfileData.fromRow(
    Map<String, dynamic>? row, {
    required User fallbackUser,
  }) {
    final _ProfileData fallback = _ProfileData.fromUser(fallbackUser);
    if (row == null) return fallback;
    return _ProfileData(
      fullName: _nonEmpty(row['full_name']) ?? fallback.fullName,
      email: _nonEmpty(row['email']) ?? fallback.email,
      phone: _nonEmpty(row['phone']) ?? fallback.phone,
      avatarUrl: _cleanAvatar(row['avatar_url']) ?? fallback.avatarUrl,
    );
  }

  final String fullName;
  final String email;
  final String phone;
  final String? avatarUrl;

  String get displayName {
    if (fullName.isNotEmpty) return fullName;
    if (email.isNotEmpty) return email.split('@').first;
    if (phone.isNotEmpty) return phone;
    return 'بەکارهێنەر';
  }

  String get contact {
    final bool generatedPhoneEmail = email.endsWith('@phone.proxopages.com');
    if (phone.isNotEmpty && (email.isEmpty || generatedPhoneEmail)) return phone;
    if (email.isNotEmpty) return email;
    return phone.isNotEmpty ? phone : '—';
  }

  _ProfileData merge(Map<String, dynamic> row) {
    return _ProfileData(
      fullName: row.containsKey('full_name')
          ? (_nonEmpty(row['full_name']) ?? fullName)
          : fullName,
      email: row.containsKey('email')
          ? (_nonEmpty(row['email']) ?? email)
          : email,
      phone: row.containsKey('phone')
          ? (_nonEmpty(row['phone']) ?? '')
          : phone,
      avatarUrl: row.containsKey('avatar_url')
          ? _cleanAvatar(row['avatar_url'])
          : avatarUrl,
    );
  }

  static String? _nonEmpty(Object? value) {
    final String text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static String? _cleanAvatar(Object? value) {
    final String? url = _nonEmpty(value);
    if (url == null) return null;
    final Uri? uri = Uri.tryParse(url);
    return uri != null && (uri.scheme == 'https' || uri.scheme == 'http')
        ? url
        : null;
  }
}

class _ProfileTopBar extends StatelessWidget {
  const _ProfileTopBar({
    required this.showBack,
    required this.onBack,
    required this.onEdit,
  });

  final bool showBack;
  final VoidCallback onBack;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _ProfileColors.page,
      child: SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: <Widget>[
              showBack
                  ? _CircleActionButton(
                      semanticLabel: 'گەڕانەوە',
                      icon: SolarIconsOutline.altArrowRight,
                      onTap: onBack,
                    )
                  : _CircleActionButton(
                      semanticLabel: 'دەستکاریکردنی پرۆفایل',
                      icon: SolarIconsOutline.penNewSquare,
                      onTap: onEdit,
                    ),
              Expanded(
                child: showBack
                    ? const Text(
                        'پرۆفایل',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _ProfileText.screenTitle,
                      )
                    : const SizedBox.shrink(),
              ),
              showBack
                  ? _CircleActionButton(
                      semanticLabel: 'دەستکاریکردنی پرۆفایل',
                      icon: SolarIconsOutline.penNewSquare,
                      onTap: onEdit,
                    )
                  : const SizedBox(width: 44, height: 44),
            ],
          ),
        ),
      ),
    );
  }
}

class _SimpleTopBar extends StatelessWidget {
  const _SimpleTopBar({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: _ProfileColors.page,
        border: Border(
          bottom: BorderSide(color: _ProfileColors.topBarHairline),
        ),
      ),
      child: SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: <Widget>[
              _CircleActionButton(
                semanticLabel: 'گەڕانەوە',
                icon: SolarIconsOutline.altArrowRight,
                onTap: onBack,
              ),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _ProfileText.screenTitle,
                ),
              ),
              const SizedBox(width: 44, height: 44),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({
    required this.semanticLabel,
    required this.icon,
    required this.onTap,
  });

  final String semanticLabel;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: 44,
        child: Center(
          child: Material(
            color: _ProfileColors.iconSurface,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox.square(
                dimension: 40,
                child: Icon(icon, size: 20, color: _ProfileColors.iconInk),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileIdentity extends StatelessWidget {
  const _ProfileIdentity({required this.data});

  final _ProfileData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _ProfileAvatar(data: data),
        const SizedBox(height: 11),
        Text(
          data.displayName,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _ProfileText.userName,
        ),
        const SizedBox(height: 3),
        Directionality(
          textDirection: _containsArabic(data.contact)
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: Text(
            data.contact,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _ProfileText.userContact,
          ),
        ),
      ],
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.data,
    this.diameter = 86,
    this.iconSize = 35,
    this.memoryBytes,
  });

  final _ProfileData data;
  final double diameter;
  final double iconSize;
  final Uint8List? memoryBytes;

  @override
  Widget build(BuildContext context) {
    final String? avatarUrl = data.avatarUrl;
    final int cacheSize =
        (diameter * MediaQuery.devicePixelRatioOf(context)).ceil();
    return Semantics(
      image: true,
      label: 'وێنەی پرۆفایل',
      child: Container(
        width: diameter,
        height: diameter,
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.fromBorderSide(
            BorderSide(color: _ProfileColors.cardBorder),
          ),
        ),
        child: ClipOval(
          child: memoryBytes != null
              ? Image.memory(
                  memoryBytes!,
                  width: diameter,
                  height: diameter,
                  fit: BoxFit.cover,
                  cacheWidth: cacheSize,
                  cacheHeight: cacheSize,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.low,
                  errorBuilder: (_, __, ___) =>
                      _AvatarFallback(iconSize: iconSize),
                )
              : avatarUrl == null
                  ? _AvatarFallback(iconSize: iconSize)
                  : Image.network(
                      avatarUrl,
                      width: diameter,
                      height: diameter,
                      fit: BoxFit.cover,
                      cacheWidth: cacheSize,
                      cacheHeight: cacheSize,
                      filterQuality: FilterQuality.low,
                      errorBuilder: (_, __, ___) =>
                          _AvatarFallback(iconSize: iconSize),
                    ),
        ),
      ),
    );
  }
}

class _EditableProfileAvatar extends StatelessWidget {
  const _EditableProfileAvatar({
    required this.data,
    required this.memoryBytes,
    required this.enabled,
    required this.onTap,
  });

  final _ProfileData data;
  final Uint8List? memoryBytes;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'گۆڕینی وێنەی پرۆفایل',
      child: SizedBox(
        width: 88,
        height: 84,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: <Widget>[
            GestureDetector(
              onTap: enabled ? onTap : null,
              child: _ProfileAvatar(
                data: data,
                diameter: 76,
                iconSize: 32,
                memoryBytes: memoryBytes,
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Material(
                color: enabled
                    ? _ProfileColors.primary
                    : _ProfileColors.muted,
                shape: const CircleBorder(),
                elevation: 2,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: enabled ? onTap : null,
                  child: const SizedBox.square(
                    dimension: 30,
                    child: Icon(
                      Icons.photo_camera_outlined,
                      size: 17,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.iconSize});

  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _ProfileColors.iconSurface,
      child: Center(
        child: Icon(
          SolarIconsOutline.userRounded,
          size: iconSize,
          color: _ProfileColors.muted,
        ),
      ),
    );
  }
}

class _BalanceCard extends StatefulWidget {
  const _BalanceCard({
    required this.balanceIqd,
    required this.showBalance,
    required this.onTap,
  });

  final ValueListenable<double?> balanceIqd;
  final ValueNotifier<bool> showBalance;
  final VoidCallback onTap;

  @override
  State<_BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<_BalanceCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shineController;

  @override
  void initState() {
    super.initState();
    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      _shineController
        ..stop()
        ..value = 0;
    } else if (!_shineController.isAnimating) {
      _shineController.repeat();
    }
  }

  @override
  void dispose() {
    _shineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'باڵانسی ڕیکلام؛ دەستلێبدە بۆ زیادکردنی باڵانس',
      child: DecoratedBox(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(22)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Color(0x3D0057FF),
              blurRadius: 22,
              spreadRadius: -7,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: const BorderRadius.all(Radius.circular(22)),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            height: 120,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(22)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0xFF003FCC),
                  Color(0xFF0057FF),
                  Color(0xFF3D7BFF),
                ],
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Positioned.fill(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: _shineController,
                        child: Transform.rotate(
                          angle: -0.28,
                          child: const SizedBox(
                            width: 56,
                            height: 180,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: <Color>[
                                    Color(0x00FFFFFF),
                                    Color(0x1FFFFFFF),
                                    Color(0x00FFFFFF),
                                  ],
                                  stops: <double>[0, 0.5, 1],
                                ),
                              ),
                            ),
                          ),
                        ),
                        builder: (_, child) {
                          final double progress = const Interval(
                            0,
                            0.52,
                            curve: Curves.easeInOutCubic,
                          ).transform(_shineController.value);
                          return Align(
                            alignment: Alignment(-1.55 + (3.1 * progress), 0),
                            child: child,
                          );
                        },
                      ),
                    ),
                  ),
                ),
                InkWell(
                  onTap: widget.onTap,
                  child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Row(
                      children: <Widget>[
                        SizedBox.square(
                          dimension: 36,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Color(0x2EFFFFFF),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              SolarIconsOutline.wallet2,
                              size: 18,
                              color: Color(0xE6FFFFFF),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'باڵانسی ڕیکلام',
                          style: _ProfileText.balanceLabel,
                        ),
                      ],
                    ),
                    const Spacer(),
                    ValueListenableBuilder<bool>(
                      valueListenable: widget.showBalance,
                      builder: (_, visible, __) => Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          Expanded(
                            child: Directionality(
                              textDirection: TextDirection.ltr,
                              child: ValueListenableBuilder<double?>(
                                valueListenable: widget.balanceIqd,
                                builder: (_, value, __) => Text(
                                  visible
                                      ? _formatIqd(value)
                                      : '•••••• د.ع',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _ProfileText.balanceAmount,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Semantics(
                            button: true,
                            label: visible
                                ? 'شاردنەوەی باڵانس'
                                : 'پیشاندانی باڵانس',
                            excludeSemantics: true,
                            child: Material(
                              color: const Color(0x24FFFFFF),
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () =>
                                    widget.showBalance.value = !visible,
                                child: SizedBox.square(
                                  dimension: 38,
                                  child: Icon(
                                    visible
                                        ? SolarIconsOutline.eye
                                        : SolarIconsOutline.eyeClosed,
                                    size: 19,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatIqd(double? value) {
    if (value == null) return '— د.ع';
    final String latin = value.round().toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (_) => ',',
        );
    return '$latin د.ع';
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onAds,
    required this.onAssets,
    required this.onCoupons,
  });

  final VoidCallback onAds;
  final VoidCallback onAssets;
  final VoidCallback onCoupons;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _QuickActionCard(
            icon: SolarIconsOutline.clapperboardPlay,
            label: 'ڕیکلامەکانم',
            onTap: onAds,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickActionCard(
            icon: SolarIconsOutline.widget_2,
            label: 'کەرەستەکان',
            onTap: onAssets,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickActionCard(
            icon: SolarIconsOutline.tagPrice,
            label: 'کۆپۆن',
            onTap: onCoupons,
          ),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _ProfileColors.quickSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        side: BorderSide(color: _ProfileColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 76,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon, size: 23, color: _ProfileColors.iconInk),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _ProfileText.quickAction,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: _ProfileText.sectionTitle);
  }
}

class _MenuEntry {
  const _MenuEntry({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.entries});

  final List<_MenuEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _ProfileColors.groupSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
        side: BorderSide(color: _ProfileColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List<Widget>.generate(entries.length * 2 - 1, (int index) {
          if (index.isOdd) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(
                height: 1,
                thickness: 1,
                color: _ProfileColors.hairline,
              ),
            );
          }
          return _SettingsTile(entry: entries[index ~/ 2]);
        }, growable: false),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.entry});

  final _MenuEntry entry;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: entry.onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  entry.icon,
                  size: 20,
                  color: _ProfileColors.iconInk,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _ProfileText.menuTitle,
                    ),
                    if (entry.subtitle != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        entry.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _ProfileText.menuSubtitle,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                SolarIconsOutline.altArrowLeft,
                size: 20,
                color: _ProfileColors.chevron,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignOutTile extends StatelessWidget {
  const _SignOutTile({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _ProfileColors.groupSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
        side: BorderSide(color: _ProfileColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : onTap,
        child: SizedBox(
          height: 58,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: <Widget>[
                const SizedBox.square(
                  dimension: 38,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      SolarIconsOutline.logout,
                      size: 20,
                      color: _ProfileColors.iconInk,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('دەرچوون', style: _ProfileText.signOut),
                ),
                if (busy)
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _ProfileColors.danger,
                    ),
                  )
                else
                  const Icon(
                    SolarIconsOutline.altArrowLeft,
                    size: 20,
                    color: _ProfileColors.chevron,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _SupportAction { chat, phone }

/// شیتی پشتگیری بە هەمان زمانە بصرییەکەی ڤیدیۆ: ڕووی سپی، handleـی
/// باریک، ئایکۆنی outline و دوو دوگمەی pill. هیچ state یان listenerـێکی
/// داتا لێرە نییە، بۆیە کردنەوە و داخستنەوەکە تەنها transitionـی خودی
/// bottom sheet وێنا دەکات و داری پڕۆفایل دووبارە بنیات نانرێتەوە.
class _SupportSheet extends StatelessWidget {
  const _SupportSheet();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            10,
            16,
            MediaQuery.paddingOf(context).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(
                width: 42,
                height: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _ProfileColors.dragHandle,
                    borderRadius: BorderRadius.all(Radius.circular(99)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const SizedBox.square(
                dimension: 76,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _ProfileColors.supportIllustrationSurface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    SolarIconsOutline.chatRoundCall,
                    size: 38,
                    color: _ProfileColors.supportDark,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'چۆن دەتوانین پەیوەندیتان پێوە بکەین؟',
                textAlign: TextAlign.center,
                style: _ProfileText.supportQuestion,
              ),
              const SizedBox(height: 22),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _SupportChannelButton(
                      label: 'چات',
                      icon: SolarIconsOutline.chatRoundDots,
                      filled: false,
                      onTap: () => Navigator.of(context).pop(
                        _SupportAction.chat,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SupportChannelButton(
                      label: 'تەلەفۆن',
                      icon: SolarIconsOutline.phoneRounded,
                      filled: true,
                      onTap: () => Navigator.of(context).pop(
                        _SupportAction.phone,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportChannelButton extends StatelessWidget {
  const _SupportChannelButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color foreground =
        filled ? Colors.white : _ProfileColors.supportDark;
    return Material(
      color: filled ? _ProfileColors.supportDark : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(28)),
        side: const BorderSide(color: _ProfileColors.supportDark, width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 54,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: filled
                      ? _ProfileColors.supportIconWell
                      : _ProfileColors.iconSurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: foreground),
              ),
              const SizedBox(width: 9),
              Text(
                label,
                maxLines: 1,
                style: _ProfileText.supportButton.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutAppSheet extends StatelessWidget {
  const _AboutAppSheet();

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final double textScale =
        media.textScaler.scale(1).clamp(0.9, 1.05).toDouble();
    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.linear(textScale)),
      child: FractionallySizedBox(
        heightFactor: .88,
        child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: <Widget>[
              const SizedBox(height: 10),
              const SizedBox(
                width: 42,
                height: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _ProfileColors.dragHandle,
                    borderRadius: BorderRadius.all(Radius.circular(99)),
                  ),
                ),
              ),
              SizedBox(
                height: 54,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: <Widget>[
                      const SizedBox(width: 44),
                      const Expanded(
                        child: Text(
                          'دەربارەی ئەپڵیکەیشن',
                          textAlign: TextAlign.center,
                          style: _ProfileText.screenTitle,
                        ),
                      ),
                      _CircleActionButton(
                        semanticLabel: 'داخستن',
                        icon: SolarIconsOutline.closeCircle,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(
                height: 1,
                thickness: 1,
                color: _ProfileColors.hairline,
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16, 18, 16, 30),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 520),
                      child: Column(
                        children: <Widget>[
                          _PolicySection(
                            icon: SolarIconsOutline.sledgehammer,
                            title: 'مەرج و ڕێساکان',
                            body: 'بە بەکارهێنانی پڕۆکسۆ، بەکارهێنەر '
                                'بەرپرسیارە لە ڕاستی و یاساییبوونی ناوەڕۆکی '
                                'ڕیکلامەکە و مافی بەکارهێنانی وێنە، دەنگ و '
                                'براند. ڕیکلامی فێڵ، یاریی قومار، کاڵای '
                                'قەدەغەکراو یان ناوەڕۆکی دژ بە ڕێنماییەکانی '
                                'TikTok پەسەند ناکرێت. هەر داواکارییەک '
                                'پێداچوونەوەی بۆ دەکرێت و TikTok دەتوانێت '
                                'پەسەندی نەکات یان ڕابگرێت. دوای دەستپێکردنی '
                                'کەمپەین، تێچووی بەکارهاتوو ناگەڕێندرێتەوە؛ '
                                'تەنها باڵانسی بەکارنەهاتوو بەپێی دۆخی '
                                'داواکارییەکە هەژمار دەکرێت.',
                          ),
                          SizedBox(height: 12),
                          _PolicySection(
                            icon: SolarIconsOutline.shieldCheck,
                            title: 'سیاسەتی پاراستنی نهێنی',
                            body: 'تەنها ئەو زانیارییانە کۆدەکرێنەوە کە بۆ '
                                'بەڕێوەبردنی هەژمار، پارەدان، ڕیکلام و '
                                'پشتگیری پێویستن. داتای کەسی بە مەبەستی '
                                'بازرگانی نافرۆشرێت. دەستگەیشتن بە داتا بە '
                                'چوونەژوورەوە و مۆڵەتی هەژمار سنووردارە و '
                                'زانیاریی هەستیار بە شێوەی پارێزراو '
                                'مامەڵەی لەگەڵ دەکرێت. بەکارهێنەر دەتوانێت '
                                'لە بەشی دەستکاریکردنی پرۆفایل داوای '
                                'سڕینەوەی هەژمار و داتاکانی بکات.',
                          ),
                          SizedBox(height: 12),
                          _PolicySection(
                            icon: SolarIconsOutline.usersGroupRounded,
                            title: 'دەربارەی ئێمە',
                            body: 'پڕۆکسۆ پلاتفۆرمێکە بۆ ئاسانکردنی '
                                'دروستکردن و بەڕێوەبردنی ڕیکلامی TikTok بۆ '
                                'بازرگان و خاوەنکارەکان لە کوردستان و عێراق. '
                                'ئامانجمان ئەوەیە بە شێوەیەکی ڕوون و سادە '
                                'باڵانس زیاد بکەیت، کەمپەین بنێریت، ئامارەکان '
                                'ببینیت و مێژووی مامەڵەکانت بەدواداچوون بکەیت.',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  const _PolicySection({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: const BoxDecoration(
        color: _ProfileColors.groupSurface,
        borderRadius: BorderRadius.all(Radius.circular(20)),
        border: Border.fromBorderSide(
          BorderSide(color: _ProfileColors.cardBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 20, color: _ProfileColors.ink),
              const SizedBox(width: 9),
              Expanded(child: Text(title, style: _ProfileText.policyTitle)),
            ],
          ),
          const SizedBox(height: 10),
          Text(body, style: _ProfileText.policyBody),
        ],
      ),
    );
  }
}

class _ProfileFaqScreen extends StatelessWidget {
  const _ProfileFaqScreen();

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final double textScale =
        media.textScaler.scale(1).clamp(0.9, 1.05).toDouble();
    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.linear(textScale)),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
        backgroundColor: _ProfileColors.page,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              _SimpleTopBar(
                title: 'پرسیارە دووبارەکان',
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    18,
                    16,
                    MediaQuery.paddingOf(context).bottom + 24,
                  ),
                  itemCount: kFaqItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, int index) =>
                      _FaqExpansionCard(item: kFaqItems[index]),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _FaqExpansionCard extends StatelessWidget {
  const _FaqExpansionCard({required this.item});

  final FaqItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _ProfileColors.groupSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
        side: BorderSide(color: _ProfileColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: _ProfileColors.iconSurface,
          highlightColor: _ProfileColors.iconSurface.withOpacity(.45),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 15),
          iconColor: _ProfileColors.muted,
          collapsedIconColor: _ProfileColors.muted,
          title: Text(item.question, style: _ProfileText.faqQuestion),
          children: <Widget>[
            const Divider(
              height: 16,
              thickness: 1,
              color: _ProfileColors.hairline,
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(item.answer, style: _ProfileText.faqAnswer),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: _ProfileText.fieldLabel);
  }
}

InputDecoration _profileInputDecoration({
  required String hint,
  required IconData icon,
  bool readOnly = false,
  IconData? suffixIcon,
}) {
  const BorderRadius radius = BorderRadius.all(Radius.circular(18));
  final Color fill =
      readOnly ? _ProfileColors.readOnlySurface : _ProfileColors.groupSurface;
  const OutlineInputBorder normal = OutlineInputBorder(
    borderRadius: radius,
    borderSide: BorderSide(color: _ProfileColors.border),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: _ProfileText.hint,
    prefixIcon: Icon(icon, size: 20, color: _ProfileColors.muted),
    suffixIcon: suffixIcon == null
        ? null
        : Icon(suffixIcon, size: 17, color: _ProfileColors.quiet),
    filled: true,
    fillColor: fill,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    enabledBorder: normal,
    disabledBorder: normal,
    border: normal,
    focusedBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: _ProfileColors.primary, width: 1.4),
    ),
    errorBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: _ProfileColors.danger),
    ),
    focusedErrorBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: _ProfileColors.danger, width: 1.4),
    ),
    errorStyle: _ProfileText.error,
  );
}

Future<bool?> _showConfirmationDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmText,
  bool destructive = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        title: Text(title, style: _ProfileText.dialogTitle),
        content: Text(message, style: _ProfileText.dialogBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('پاشگەزبوونەوە'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: destructive
                  ? _ProfileColors.danger
                  : _ProfileColors.primary,
              textStyle: _ProfileText.dialogAction,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showInformationDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        title: Text(title, style: _ProfileText.dialogTitle),
        content: Text(message, style: _ProfileText.dialogBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: TextButton.styleFrom(
              foregroundColor: _ProfileColors.primary,
              textStyle: _ProfileText.dialogAction,
            ),
            child: const Text('باشە'),
          ),
        ],
      ),
    ),
  );
}

typedef _VerifyEmailCode = Future<String?> Function(String code);
typedef _ResendEmailCode = Future<String?> Function();

class _EmailChangeVerificationDialog extends StatefulWidget {
  const _EmailChangeVerificationDialog({
    required this.email,
    required this.onVerify,
    required this.onResend,
  });

  final String email;
  final _VerifyEmailCode onVerify;
  final _ResendEmailCode onResend;

  @override
  State<_EmailChangeVerificationDialog> createState() =>
      _EmailChangeVerificationDialogState();
}

class _EmailChangeVerificationDialogState
    extends State<_EmailChangeVerificationDialog> {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocus = FocusNode();
  bool _verifying = false;
  bool _resending = false;
  String? _error;
  String? _notice;

  bool get _busy => _verifying || _resending;

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_busy) return;
    final String code = _normaliseOtp(_codeController.text);
    if (code.length != 6) {
      setState(() => _error = 'تکایە کۆدی ٦ ژمارەیی بنووسە.');
      _codeFocus.requestFocus();
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
      _notice = null;
    });
    final String? error = await widget.onVerify(code);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _verifying = false;
      _error = error;
    });
    _codeController
      ..clear()
      ..selection = const TextSelection.collapsed(offset: 0);
    _codeFocus.requestFocus();
  }

  Future<void> _resend() async {
    if (_busy) return;
    setState(() {
      _resending = true;
      _error = null;
      _notice = null;
    });
    final String? error = await widget.onResend();
    if (!mounted) return;
    setState(() {
      _resending = false;
      _error = error;
      _notice = error == null
          ? 'کۆدێکی نوێ نێردرا؛ ئیمەیڵەکەت بپشکنە.'
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: !_busy,
        child: AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          title: const Text(
            'پشتڕاستکردنەوەی ئیمەیڵ',
            style: _ProfileText.dialogTitle,
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'کۆدی ٦ ژمارەیی نێردرا بۆ:',
                  style: _ProfileText.dialogBody,
                ),
                const SizedBox(height: 5),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    widget.email,
                    textAlign: TextAlign.center,
                    style: _ProfileText.field.copyWith(
                      color: _ProfileColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: TextField(
                    controller: _codeController,
                    focusNode: _codeFocus,
                    autofocus: true,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    textAlign: TextAlign.center,
                    autofillHints: const <String>[AutofillHints.oneTimeCode],
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9٠-٩۰-۹]'),
                      ),
                      LengthLimitingTextInputFormatter(6),
                    ],
                    onChanged: (_) {
                      if (_error != null || _notice != null) {
                        setState(() {
                          _error = null;
                          _notice = null;
                        });
                      }
                    },
                    onSubmitted: (_) => _verify(),
                    style: _ProfileText.field.copyWith(
                      fontSize: 22,
                      letterSpacing: 7,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: _profileInputDecoration(
                      hint: '000000',
                      icon: SolarIconsOutline.shieldCheck,
                    ).copyWith(errorText: _error),
                  ),
                ),
                if (_notice != null) ...<Widget>[
                  const SizedBox(height: 7),
                  Text(
                    _notice!,
                    textAlign: TextAlign.center,
                    style: _ProfileText.error.copyWith(
                      color: const Color(0xFF16803C),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: _busy ? null : _resend,
                    child: _resending
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('کۆدت پێ نەگەیشت؟ دووبارە بنێرەوە'),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(false),
              child: const Text('پاشگەزبوونەوە'),
            ),
            FilledButton(
              onPressed: _busy ? null : _verify,
              style: FilledButton.styleFrom(
                backgroundColor: _ProfileColors.primary,
                foregroundColor: Colors.white,
                textStyle: _ProfileText.dialogAction,
              ),
              child: _verifying
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('پشتڕاستکردنەوە'),
            ),
          ],
        ),
      ),
    );
  }
}

String _normaliseEmail(String input) => input.trim().toLowerCase();

class _EmailWebhookException implements Exception {
  const _EmailWebhookException(this.code, {this.cause});

  final String code;
  final Object? cause;
}

String _normaliseOtp(String input) {
  const String arabic = '٠١٢٣٤٥٦٧٨٩';
  const String persian = '۰۱۲۳۴۵۶۷۸۹';
  final StringBuffer result = StringBuffer();
  for (final int rune in input.runes) {
    final String character = String.fromCharCode(rune);
    final int arabicIndex = arabic.indexOf(character);
    final int persianIndex = persian.indexOf(character);
    if (arabicIndex >= 0) {
      result.write(arabicIndex);
    } else if (persianIndex >= 0) {
      result.write(persianIndex);
    } else if (RegExp(r'[0-9]').hasMatch(character)) {
      result.write(character);
    }
  }
  return result.toString();
}

String _friendlyDatabaseError(PostgrestException error) {
  if (error.code == '23505') {
    return 'ئەم ئیمەیڵە پێشتر لە هەژمارێکی تر بەکارهاتووە.';
  }
  return 'گۆڕانکارییەکان پاشەکەوت نەکران. دووبارە هەوڵ بدەرەوە.';
}

String _friendlyAuthError(String message) {
  final String error = message.toLowerCase();
  if (error.contains('already') ||
      error.contains('exists') ||
      error.contains('registered')) {
    return 'ئەم ئیمەیڵە پێشتر لە هەژمارێکی تر بەکارهاتووە.';
  }
  if (error.contains('invalid') && error.contains('email')) {
    return 'ناونیشانی ئیمەیڵەکە دروست نییە.';
  }
  if (error.contains('rate') || error.contains('too many')) {
    return 'داواکاری زۆر بوو؛ تکایە کەمێک چاوەڕێ بکە و دووبارە هەوڵ بدەرەوە.';
  }
  return 'دانیشتنەکەت نوێ بکەرەوە و دووبارە هەوڵ بدەرەوە.';
}

String _friendlyEmailWebhookError(String rawCode) {
  final String code = rawCode.trim().toLowerCase();
  if (code == 'invalid_email') {
    return 'ناونیشانی ئیمەیڵەکە دروست نییە.';
  }
  if (code == 'same_email') {
    return 'ئیمەیڵەکە هەر هەمانە؛ هیچ گۆڕانکارییەک نییە.';
  }
  if (code == 'email_taken') {
    return 'ئەم ئیمەیڵە پێشتر لە هەژمارێکی تر بەکارهاتووە.';
  }
  if (code == 'otp_rate_limited') {
    return 'کۆدێک تازە نێردراوە؛ ٦٠ چرکە چاوەڕێ بکە و دووبارە هەوڵ بدەرەوە.';
  }
  if (code == 'email_change_locked') {
    return 'دوای گۆڕینی ئیمەیڵ، تا ٣٠ ڕۆژ ناتوانیت دووبارە بیگۆڕیت.';
  }
  if (code == 'expired') {
    return 'کۆدەکە بەسەرچووە؛ کۆدێکی نوێ داوا بکە.';
  }
  if (code == 'invalid_code') {
    return 'کۆدەکە هەڵەیە یان بەسەرچووە؛ دووبارە بپشکنەوە.';
  }
  if (code == 'attempts_exceeded') {
    return 'هەوڵی زۆر دراوە؛ کۆدێکی نوێ داوا بکە.';
  }
  if (code == 'invalid_request' || code == 'missing_params') {
    return 'داواکارییەکە دروست نییە یان بەسەرچووە؛ کۆدێکی نوێ داوا بکە.';
  }
  if (code == 'unauthorized') {
    return 'دانیشتنەکەت بەسەرچووە؛ تکایە دووبارە بچۆ ژوورەوە.';
  }
  if (code == 'timeout' || code == 'network_error') {
    return 'پەیوەندی بە سێرڤەرەوە نەکرا؛ ئینتەرنێتەکەت بپشکنەوە.';
  }
  return 'سێرڤەری ئیمەیڵ وەڵامی دروستی نەدایەوە؛ دواتر هەوڵ بدەرەوە.';
}

bool _containsArabic(String value) =>
    RegExp(r'[\u0600-\u06FF]').hasMatch(value);

String _toKurdishDigits(String value) {
  const List<String> digits = <String>['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  return value.replaceAllMapped(
    RegExp(r'\d'),
    (Match match) => digits[int.parse(match.group(0)!)],
  );
}

class _ProfileScrollBehavior extends ScrollBehavior {
  const _ProfileScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}

abstract final class _ProfileColors {
  // ڕەنگەکان لە فریمە پڕقەبارەکانی ڤیدیۆکەوە هێمن کراون: پەڕە سپییە،
  // کارت و گرووپەکان تەنها یەک هەنگاو لێی جیاوازن و ڕەشەکە navy نییە.
  static const Color page = Color(0xFFFFFFFF);
  static const Color groupSurface = Color(0xFFFBFBFB);
  static const Color quickSurface = Color(0xFFF7FCFB);
  static const Color readOnlySurface = Color(0xFFF6F7F8);
  static const Color ink = Color(0xFF222428);
  static const Color iconInk = Color(0xFF2D3035);
  static const Color section = Color(0xFF3A3C42);
  static const Color muted = Color(0xFF636365);
  static const Color quiet = Color(0xFF8A8D92);
  static const Color border = Color(0xFFE6EAEC);
  static const Color cardBorder = Color(0xFFE6ECEE);
  static const Color hairline = Color(0xFFE4E6E8);
  static const Color topBarHairline = Color(0xFFF3F4F5);
  static const Color iconSurface = Color(0xFFF4F8FA);
  static const Color chevron = Color(0xFF74777B);
  static const Color primary = Color(0xFF2A8FE2);
  static const Color danger = Color(0xFFB74956);
  static const Color dangerSoft = Color(0xFFFFF7F7);
  static const Color dangerBorder = Color(0xFFF2DADD);
  static const Color dragHandle = Color(0xFFBEBEBE);
  static const Color scrim = Color(0x8A000000);
  static const Color supportDark = Color(0xFF032D4C);
  static const Color supportIconWell = Color(0xFF1F4A61);
  static const Color supportIllustrationSurface = Color(0xFFF2F8FA);
}

abstract final class _ProfileText {
  static const TextStyle screenTitle = TextStyle(
    fontFamily: kAppFont,
    fontSize: 17,
    fontWeight: FontWeight.w500,
    color: _ProfileColors.ink,
    height: 1.2,
  );
  static const TextStyle userName = TextStyle(
    fontFamily: kAppFont,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: _ProfileColors.ink,
    height: 1.25,
  );
  static const TextStyle userContact = TextStyle(
    fontFamily: kAppFont,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: _ProfileColors.muted,
    height: 1.3,
  );
  static const TextStyle balanceLabel = TextStyle(
    fontFamily: kAppFont,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: Color(0xE6FFFFFF),
    height: 1.25,
  );
  static const TextStyle balanceAmount = TextStyle(
    fontFamily: kAppFont,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    height: 1.05,
    letterSpacing: 0.1,
  );
  static const TextStyle quickAction = TextStyle(
    fontFamily: kAppFont,
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    color: _ProfileColors.ink,
    height: 1.2,
  );
  static const TextStyle sectionTitle = TextStyle(
    fontFamily: kAppFont,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: _ProfileColors.section,
    height: 1.25,
  );
  static const TextStyle menuTitle = TextStyle(
    fontFamily: kAppFont,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: _ProfileColors.ink,
    height: 1.25,
  );
  static const TextStyle menuSubtitle = TextStyle(
    fontFamily: kAppFont,
    fontSize: 11.5,
    fontWeight: FontWeight.w400,
    color: _ProfileColors.muted,
    height: 1.3,
  );
  static const TextStyle signOut = TextStyle(
    fontFamily: kAppFont,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: _ProfileColors.ink,
    height: 1.2,
  );
  static const TextStyle version = TextStyle(
    fontFamily: kAppFont,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: _ProfileColors.quiet,
    height: 1.2,
  );
  static const TextStyle fieldLabel = TextStyle(
    fontFamily: kAppFont,
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    color: _ProfileColors.section,
    height: 1.2,
  );
  static const TextStyle field = TextStyle(
    fontFamily: kAppFont,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: _ProfileColors.ink,
    height: 1.25,
  );
  static const TextStyle hint = TextStyle(
    fontFamily: kAppFont,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: _ProfileColors.quiet,
    height: 1.25,
  );
  static const TextStyle error = TextStyle(
    fontFamily: kAppFont,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: _ProfileColors.danger,
    height: 1.25,
  );
  static const TextStyle button = TextStyle(
    fontFamily: kAppFont,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );
  static const TextStyle dangerTitle = TextStyle(
    fontFamily: kAppFont,
    fontSize: 13.5,
    fontWeight: FontWeight.w500,
    color: _ProfileColors.danger,
    height: 1.25,
  );
  static const TextStyle dangerSub = TextStyle(
    fontFamily: kAppFont,
    fontSize: 11.5,
    fontWeight: FontWeight.w400,
    color: _ProfileColors.muted,
    height: 1.3,
  );
  static const TextStyle policyTitle = TextStyle(
    fontFamily: kAppFont,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: _ProfileColors.ink,
    height: 1.25,
  );
  static const TextStyle policyBody = TextStyle(
    fontFamily: kAppFont,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: _ProfileColors.muted,
    height: 1.6,
  );
  static const TextStyle faqQuestion = TextStyle(
    fontFamily: kAppFont,
    fontSize: 13.5,
    fontWeight: FontWeight.w400,
    color: _ProfileColors.ink,
    height: 1.35,
  );
  static const TextStyle faqAnswer = TextStyle(
    fontFamily: kAppFont,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: _ProfileColors.muted,
    height: 1.55,
  );
  static const TextStyle dialogTitle = TextStyle(
    fontFamily: kAppFont,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: _ProfileColors.ink,
  );
  static const TextStyle dialogBody = TextStyle(
    fontFamily: kAppFont,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: _ProfileColors.muted,
    height: 1.5,
  );
  static const TextStyle dialogAction = TextStyle(
    fontFamily: kAppFont,
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle supportQuestion = TextStyle(
    fontFamily: kAppFont,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: _ProfileColors.ink,
    height: 1.35,
  );

  static const TextStyle supportButton = TextStyle(
    fontFamily: kAppFont,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );
}
