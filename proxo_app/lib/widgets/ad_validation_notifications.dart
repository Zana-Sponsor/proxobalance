import 'package:flutter/material.dart';
import 'proxo_notice.dart';

/// The first actionable error is shown briefly; individual fields keep their
/// validation state. There is no hidden queue that can replay obsolete errors.
class AdValidationController extends ChangeNotifier {
  String? _message;
  int _generation = 0;
  bool _disposed = false;
  Object? _owner;
  bool Function()? _canShow;
  void show(Map<String, String> errors) {
    if (_disposed || _canShow?.call() == false) return;
    final messages = errors.values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty);
    if (messages.isEmpty || messages.first == _message) return;
    _message = messages.first;
    ++_generation;
    notifyListeners();
  }

  void clear() {
    if (_disposed || _message == null) return;
    _message = null;
    ++_generation;
    notifyListeners();
  }

  void _expire(int generation) {
    if (_generation == generation) clear();
  }

  void _attach(Object owner, bool Function() canShow) {
    if (_disposed) return;
    _owner = owner;
    _canShow = canShow;
  }

  void _release(Object owner) {
    if (_owner != owner) return;
    _detach(_generation);
    _owner = null;
    _canShow = () => false;
  }

  void _detach(int generation) {
    if (_disposed || _generation != generation) return;
    // Widget removal must not replay this error if its controller is reused.
    // Do not notify listeners while the widget tree is being torn down.
    _message = null;
    ++_generation;
  }

  @override
  void dispose() {
    _disposed = true;
    _message = null;
    _owner = null;
    _canShow = null;
    super.dispose();
  }
}

class AdValidationNotifications extends StatefulWidget {
  const AdValidationNotifications({super.key, required this.controller});
  final AdValidationController controller;

  @override
  State<AdValidationNotifications> createState() =>
      _AdValidationNotificationsState();
}

class _AdValidationNotificationsState extends State<AdValidationNotifications> {
  ModalRoute<dynamic>? _route;

  bool _canShow() =>
      mounted &&
      (_route?.isCurrent ?? true) &&
      TickerMode.getValuesNotifier(context).value.enabled;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    final current =
        (_route?.isCurrent ?? true) && TickerMode.valuesOf(context).enabled;
    widget.controller._attach(this, _canShow);
    if (!current) {
      widget.controller._detach(widget.controller._generation);
    }
  }

  @override
  void didUpdateWidget(covariant AdValidationNotifications oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller._release(this);
      widget.controller._attach(this, _canShow);
    }
  }

  @override
  void dispose() {
    widget.controller._release(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final controller = widget.controller;
            if (!_canShow()) {
              controller._detach(controller._generation);
              return const SizedBox.shrink();
            }
            final message = controller._message;
            if (message == null) return const SizedBox.shrink();
            final generation = controller._generation;
            return ProxoTimedNotice(
                key: ValueKey((controller, generation)),
                onExpired: () => controller._expire(generation),
                onDisposed: () => controller._detach(generation),
                child: ProxoNoticeCard(message: message));
          },
        ),
      );
}
