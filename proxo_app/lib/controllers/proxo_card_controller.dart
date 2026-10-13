import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/proxo_card.dart';
import '../services/proxolink_service.dart';

class ProxoCardController extends ChangeNotifier {
  final ProxoLinkRepository repository;
  ProxoCardController({ProxoLinkRepository? repository})
    : repository = repository ?? ProxoLinkService(Supabase.instance.client);
  List<ProxoCard> _cards = [];
  bool loading = false;
  String? error;
  List<ProxoCard> get cards => List.unmodifiable(_cards);
  Future<void> fetchCards() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      _cards = await repository.cards();
    } catch (_) {
      error = 'نەتوانرا پەڕەکان پیشان بدرێن.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteCard(String id) async {
    try {
      await repository.action(id, 'delete');
      await fetchCards();
      return true;
    } on ProxoLinkFailure catch (e) {
      error = e.message;
      notifyListeners();
      return false;
    }
  }
}
