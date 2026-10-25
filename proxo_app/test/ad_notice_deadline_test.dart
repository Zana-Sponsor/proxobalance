import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/widgets/ad_validation_notifications.dart';
import 'package:proxo_app/widgets/proxo_error_stack.dart';
import 'package:proxo_app/widgets/proxo_notice.dart';
import 'package:proxo_app/widgets/proxo_toast.dart';

void main() {
  tearDown(ProxoErrorStack.clear);
  testWidgets(
      'manual close is immediate and action-required feedback stays readable',
      (t) async {
    late BuildContext screen;
    var actionCalls = 0;
    await t.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      screen = context;
      return const Scaffold();
    })));
    ProxoErrorStack.show(screen, 'Recoverable failure');
    await t.pump();
    await t.tap(find.byKey(const ValueKey('notice-dismiss')));
    await t.pump();
    expect(find.byType(ProxoNoticeCard), findsNothing);
    ProxoErrorStack.show(screen, 'Action required',
        actionLabel: 'Retry', onAction: () => actionCalls++);
    await t.pump();
    await t.pump(const Duration(seconds: 10));
    expect(find.text('Action required'), findsOneWidget);
    await t.tap(find.text('Retry'));
    await t.pump();
    expect(actionCalls, 1);
    expect(find.byType(ProxoNoticeCard), findsNothing);
    ProxoErrorStack.show(screen, 'Long readable message ' * 5);
    await t.pump();
    await t.pump(const Duration(seconds: 2));
    expect(find.byType(ProxoNoticeCard), findsOneWidget);
    await t.pump(const Duration(seconds: 1));
    expect(find.byType(ProxoNoticeCard), findsNothing);
  });
  testWidgets(
      'validation expires 2000ms after appearing, including delayed mount',
      (t) async {
    final controller = AdValidationController();
    addTearDown(controller.dispose);
    await t.pumpWidget(MaterialApp(
        home:
            Scaffold(body: AdValidationNotifications(controller: controller))));
    controller.show({'first': 'First error', 'second': 'Second error'});
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('First error'), findsOneWidget);
    expect(find.text('Second error'), findsNothing);
    await t.pump(const Duration(milliseconds: 1999));
    expect(find.text('First error'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 1));
    expect(find.byType(ProxoNoticeCard), findsNothing);
    await t.pumpWidget(const SizedBox.shrink());
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'duplicate keeps deadline; replacement cancels old timer; clear cancels',
      (t) async {
    final controller = AdValidationController();
    addTearDown(controller.dispose);
    await t.pumpWidget(MaterialApp(
        home:
            Scaffold(body: AdValidationNotifications(controller: controller))));
    controller.show({'a': 'First error'});
    await t.pump();
    await t.pump(const Duration(milliseconds: 1000));
    controller.show({'a': 'First error'});
    await t.pump(const Duration(milliseconds: 999));
    expect(find.text('First error'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 1));
    expect(find.text('First error'), findsNothing);
    controller.show({'a': 'Old error'});
    await t.pump();
    await t.pump(const Duration(milliseconds: 1000));
    controller.show({'a': 'New error'});
    await t.pump();
    await t.pump(const Duration(milliseconds: 1000));
    expect(find.text('New error'), findsOneWidget);
    controller.clear();
    await t.pump();
    expect(find.byType(ProxoNoticeCard), findsNothing);
    await t.pump(const Duration(seconds: 3));
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'global notices use 2000ms even with legacy duration/accessibility',
      (t) async {
    late BuildContext screen;
    await t.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(accessibleNavigation: true),
            child: child!),
        home: Builder(builder: (context) {
          screen = context;
          return const Scaffold();
        })));
    showProxoToast(screen, 'Network error',
        duration: const Duration(seconds: 9));
    await t.pump();
    await t.pump(const Duration(milliseconds: 1999));
    expect(find.text('Network error'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 1));
    expect(find.text('Network error'), findsNothing);
  });

  testWidgets(
      'notice does not block editing or scrolling and clears on route close',
      (t) async {
    final navigator = GlobalKey<NavigatorState>();
    final text = TextEditingController();
    addTearDown(text.dispose);
    late BuildContext screen;
    var builds = 0;
    await t.pumpWidget(MaterialApp(
        navigatorKey: navigator, home: const Scaffold(body: Text('Overview'))));
    navigator.currentState!.push(MaterialPageRoute<void>(builder: (context) {
      screen = context;
      builds++;
      return Scaffold(
          body: ListView(children: [
        const SizedBox(height: 64),
        TextField(controller: text),
        const SizedBox(height: 1400),
        const Text('Bottom'),
      ]));
    }));
    await t.pumpAndSettle();
    ProxoErrorStack.show(screen, 'Request failed');
    await t.pump();
    final count = builds;
    await t.tap(find.byType(TextField));
    await t.enterText(find.byType(TextField), 'Corrected input');
    expect(text.text, 'Corrected input');
    await t.drag(find.byType(ListView), const Offset(0, -200));
    await t.pump();
    final scrollable = t.state<ScrollableState>(find.descendant(
        of: find.byType(ListView), matching: find.byType(Scrollable)));
    expect(scrollable.position.pixels, greaterThan(0));
    expect(builds, count);
    navigator.currentState!.pop();
    await t.pumpAndSettle();
    expect(find.byType(ProxoNoticeCard), findsNothing);
    expect(find.text('Overview'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('disposed validation screen cancels its timer', (t) async {
    final controller = AdValidationController();
    await t.pumpWidget(MaterialApp(
        home:
            Scaffold(body: AdValidationNotifications(controller: controller))));
    controller.show({'a': 'Error'});
    await t.pump();
    await t.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    await t.pump(const Duration(seconds: 3));
    expect(t.takeException(), isNull);
  });

  testWidgets('a reused validation controller does not replay a closed notice',
      (t) async {
    final controller = AdValidationController();
    addTearDown(controller.dispose);
    Widget screen() => MaterialApp(
        home:
            Scaffold(body: AdValidationNotifications(controller: controller)));
    await t.pumpWidget(screen());
    controller.show({'a': 'Old screen error'});
    await t.pump();
    expect(find.text('Old screen error'), findsOneWidget);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpWidget(screen());
    expect(find.byType(ProxoNoticeCard), findsNothing);
    controller.show({'a': 'New screen error'});
    await t.pump();
    expect(find.text('New screen error'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 2000));
    expect(find.byType(ProxoNoticeCard), findsNothing);
    // The screen can close before the scheduled notice has its first frame.
    controller.show({'a': 'Unpainted old error'});
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpWidget(screen());
    expect(find.byType(ProxoNoticeCard), findsNothing);
  });

  testWidgets('navigation clears the old notice without clearing a new one',
      (t) async {
    final navigator = GlobalKey<NavigatorState>();
    late BuildContext first;
    late BuildContext second;
    await t.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      navigatorObservers: [ProxoNoticeObserver()],
      home: Builder(builder: (context) {
        first = context;
        return const Scaffold();
      }),
    ));
    ProxoErrorStack.show(first, 'Old route error');
    await t.pump();
    final firstRoute = ModalRoute.of(first)!;
    navigator.currentState!.push(MaterialPageRoute<void>(builder: (context) {
      second = context;
      return const Scaffold();
    }));
    await t.pumpAndSettle();
    expect(find.text('Old route error'), findsNothing);
    ProxoErrorStack.show(first, 'Late error from covered route');
    await t.pump();
    expect(find.text('Late error from covered route'), findsNothing);
    ProxoErrorStack.show(second, 'New route error');
    await t.pump();
    navigator.currentState!.removeRoute(firstRoute);
    await t.pump();
    await t.pump(const Duration(milliseconds: 1999));
    expect(find.text('New route error'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 1));
    expect(find.byType(ProxoNoticeCard), findsNothing);
  });

  testWidgets(
      'replacing a controller gives its message a new two second lifetime',
      (t) async {
    final first = AdValidationController();
    final second = AdValidationController();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    Widget app(AdValidationController controller) => MaterialApp(
        home:
            Scaffold(body: AdValidationNotifications(controller: controller)));
    await t.pumpWidget(app(first));
    first.show({'a': 'Old controller'});
    await t.pump();
    await t.pump(const Duration(milliseconds: 1000));
    second.show({'a': 'New controller'});
    await t.pumpWidget(app(second));
    await t.pump(const Duration(milliseconds: 1999));
    expect(find.text('New controller'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 1));
    expect(find.byType(ProxoNoticeCard), findsNothing);
    await t.pumpWidget(app(first));
    expect(find.text('Old controller'), findsNothing);
  });

  testWidgets('removing the whole Navigator releases its notification entry',
      (t) async {
    late BuildContext screen;
    Widget app() => MaterialApp(home: Builder(builder: (context) {
          screen = context;
          return const Scaffold();
        }));
    await t.pumpWidget(app());
    ProxoErrorStack.show(screen, 'Retry request');
    await t.pump();
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpWidget(app());
    ProxoErrorStack.show(screen, 'Retry request');
    await t.pump();
    expect(find.text('Retry request'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 2000));
    expect(find.byType(ProxoNoticeCard), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('covered validation screens discard old and background notices',
      (t) async {
    final navigator = GlobalKey<NavigatorState>();
    final controller = AdValidationController();
    addTearDown(controller.dispose);
    await t.pumpWidget(MaterialApp(
        navigatorKey: navigator,
        home:
            Scaffold(body: AdValidationNotifications(controller: controller))));
    controller.show({'a': 'Before navigation'});
    await t.pump();
    navigator.currentState!
        .push(MaterialPageRoute<void>(builder: (context) => const Scaffold()));
    await t.pumpAndSettle();
    controller.show({'a': 'Late background failure'});
    await t.pump();
    navigator.currentState!.pop();
    await t.pumpAndSettle();
    expect(find.byType(ProxoNoticeCard), findsNothing);
    controller.show({'a': 'Visible screen failure'});
    await t.pump();
    expect(find.text('Visible screen failure'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 2000));
    expect(find.byType(ProxoNoticeCard), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('an error immediately after closing confirmation remains visible',
      (t) async {
    final navigator = GlobalKey<NavigatorState>();
    final controller = AdValidationController();
    addTearDown(controller.dispose);
    late BuildContext screen;
    await t.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      home: Builder(builder: (context) {
        screen = context;
        return Scaffold(
            body: AdValidationNotifications(controller: controller));
      }),
    ));
    final confirmation = showDialog<bool>(
        context: screen,
        builder: (_) => const AlertDialog(title: Text('Delete?')));
    await t.pumpAndSettle();
    controller.show({'a': 'Old covered failure'});
    navigator.currentState!.pop(true);
    expect(await confirmation, isTrue);
    // A synchronous repository rejection can arrive before the next frame
    // updates ModalRoute dependencies after the confirmation closes.
    controller.show({'a': 'This page still has advertisements'});
    await t.pump();
    expect(find.text('Old covered failure'), findsNothing);
    expect(find.text('This page still has advertisements'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 1999));
    expect(find.byType(ProxoNoticeCard), findsOneWidget);
    await t.pump(const Duration(milliseconds: 1));
    expect(find.byType(ProxoNoticeCard), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'kept alive inactive tabs discard notices and cannot show overlays',
      (t) async {
    final active = ValueNotifier(true);
    final controller = AdValidationController();
    addTearDown(active.dispose);
    addTearDown(controller.dispose);
    late BuildContext tab;
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
      body: ValueListenableBuilder<bool>(
        valueListenable: active,
        builder: (context, enabled, child) => TickerMode(
          enabled: enabled,
          child: Builder(builder: (context) {
            tab = context;
            return AdValidationNotifications(controller: controller);
          }),
        ),
      ),
    )));
    controller.show({'a': 'Active tab error'});
    await t.pump();
    active.value = false;
    await t.pump();
    expect(find.byType(ProxoNoticeCard), findsNothing);
    controller.show({'a': 'Hidden tab error'});
    ProxoErrorStack.show(tab, 'Hidden tab overlay');
    await t.pump();
    expect(find.byType(ProxoNoticeCard), findsNothing);
    active.value = true;
    await t.pump();
    expect(find.byType(ProxoNoticeCard), findsNothing);
    ProxoErrorStack.show(tab, 'Current tab overlay');
    await t.pump();
    expect(find.text('Current tab overlay'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 2000));
    expect(find.byType(ProxoNoticeCard), findsNothing);
  });

  testWidgets('long Kurdish notice grows naturally at200percent text',
      (t) async {
    t.view.physicalSize = const Size(320, 740);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final controller = AdValidationController();
    addTearDown(controller.dispose);
    await t.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(2)),
            child: child!),
        home: Scaffold(
            body: Padding(
                padding: const EdgeInsets.all(20),
                child: AdValidationNotifications(controller: controller)))));
    controller.show({
      'network':
          'وەڵامی کۆتایی نەگەیشت؛ پەیوەندی ئینتەرنێت بپشکنە و هەمان داواکاری دووبارە بپشکنەوە'
    });
    await t.pump();
    final paragraph = t.renderObject<RenderParagraph>(find
        .descendant(
            of: find.byType(ProxoNoticeCard), matching: find.byType(RichText))
        .first);
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(t.getSize(find.byType(ProxoNoticeCard)).height,
        greaterThanOrEqualTo(paragraph.size.height + 24));
    expect(t.getRect(find.byType(ProxoNoticeCard)).bottom, lessThan(740));
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
  });
}
