import 'dart:convert';
  import 'package:flutter/foundation.dart';
  import 'package:http/http.dart' as http;
  import 'package:supabase_flutter/supabase_flutter.dart';
  import '../models/proxo_card.dart';

  /// Handles all Supabase CRUD operations for ProxoLink cards
  /// and automatically notifies the Telegram bot when a new card is created.
  class ProxoCardController extends ChangeNotifier {
    // ── Telegram credentials ──────────────────────────
    static const String _tgBotToken =
        '7963583382:AAGoGWV8UOKE-K_r-0m08hYJNWI7OlBpcuE';
    static const String _tgChatId = '6259019006';

    // ── Supabase table ────────────────────────────────
    static const String _table = 'proxolink_cards';

    // ── State ─────────────────────────────────────────
    List<ProxoCard> _cards = [];
    bool _loading = false;
    String? _error;

    List<ProxoCard> get cards   => List.unmodifiable(_cards);
    bool            get loading => _loading;
    String?         get error   => _error;

    final SupabaseClient _db = Supabase.instance.client;

    // ── Fetch ─────────────────────────────────────────
    /// Loads all cards for the currently authenticated user.
    Future<void> fetchCards() async {
      _loading = true;
      _error = null;
      notifyListeners();

      try {
        final userId = _db.auth.currentUser?.id;
        if (userId == null) throw Exception('Not authenticated');

        final res = await _db
            .from(_table)
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false);

        _cards = (res as List)
            .map((e) => ProxoCard.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        _error = e.toString();
      } finally {
        _loading = false;
        notifyListeners();
      }
    }

    // ── Create & send to Telegram ─────────────────────
    /// Inserts a new card into Supabase, then sends [htmlContent] as a
    /// text message to the Telegram bot.
    Future<ProxoCard?> createCard({
      required String name,
      required String htmlContent,
      String? bio,
      String style = 'dark',
      String colorTheme = 'purple',
      String? avatarB64,
    }) async {
      _error = null;

      try {
        final userId = _db.auth.currentUser?.id;
        if (userId == null) throw Exception('Not authenticated');

        final cardNumber =
            (DateTime.now().millisecondsSinceEpoch % 900000) + 100000;

        final inserted = await _db.from(_table).insert({
          'user_id':      userId,
          'name':         name,
          'bio':          bio,
          'style':        style,
          'color_theme':  colorTheme,
          'avatar_b64':   avatarB64,
          'html_content': htmlContent,
          'card_number':  cardNumber,
        }).select().single();

        final card = ProxoCard.fromJson(inserted as Map<String, dynamic>);
        _cards.insert(0, card);
        notifyListeners();

        // Send HTML to Telegram in the background — do not block UI.
        _sendToTelegram(
          name:        name,
          style:       style,
          colorTheme:  colorTheme,
          htmlContent: htmlContent,
        );

        return card;
      } catch (e) {
        _error = e.toString();
        notifyListeners();
        return null;
      }
    }

    // ── Delete ────────────────────────────────────────
    /// Deletes a card by [id] from Supabase and removes it from the local list.
    Future<bool> deleteCard(String id) async {
      _error = null;
      try {
        await _db.from(_table).delete().eq('id', id);
        _cards.removeWhere((c) => c.id == id);
        notifyListeners();
        return true;
      } catch (e) {
        _error = e.toString();
        notifyListeners();
        return false;
      }
    }

    // ── Telegram ──────────────────────────────────────
    /// Sends [htmlContent] directly as a Telegram text message.
    /// Message is split into 4096-char chunks if needed.
    Future<void> _sendToTelegram({
      required String name,
      required String style,
      required String colorTheme,
      required String htmlContent,
    }) async {
      const maxLen = 4096;
      final caption =
          'ProxoLink — کەرەستەی نوێ\nناو: $name\nستایل: $style / $colorTheme\n\n';

      // Build full message (caption + html), split as needed
      final fullText = caption + htmlContent;
      final chunks = <String>[];
      var start = 0;
      while (start < fullText.length) {
        chunks.add(fullText.substring(start, (start + maxLen).clamp(0, fullText.length)));
        start += maxLen;
      }

      final url = Uri.parse(
        'https://api.telegram.org/bot$_tgBotToken/sendMessage',
      );

      for (final chunk in chunks) {
        try {
          await http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'chat_id': _tgChatId,
              'text':    chunk,
            }),
          );
        } catch (_) {
          // Telegram errors are non-fatal — silently ignore.
        }
      }
    }
  }
  