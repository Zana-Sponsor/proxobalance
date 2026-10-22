import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/widgets/proxo_drawer_navigation.dart';

void main() {
  testWidgets('open root drawer advertises Android Back handling',
      (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final handled = <bool>[];
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemNavigator.setFrameworkHandlesBack') {
        handled.add(call.arguments as bool);
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    final shell = GlobalKey<ScaffoldState>();
    await tester.pumpWidget(MaterialApp(
      home: Builder(
          builder: (context) => Scaffold(
                key: shell,
                onEndDrawerChanged: (_) =>
                    syncProxoDrawerBackNavigation(context),
                endDrawer: const Drawer(child: Text('Menu')),
                body: const Text('Home'),
              )),
    ));
    await tester.pumpAndSettle();
    shell.currentState!.openEndDrawer();
    await tester.pumpAndSettle();
    expect(shell.currentState!.isEndDrawerOpen, true);
    expect(handled, isNotEmpty);
    expect(handled.last, true);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(shell.currentState!.isEndDrawerOpen, false);
    expect(find.text('Home'), findsOneWidget);
    expect(handled.last, false);

    // A rapid reversal must publish the final live state, not a stale open.
    shell.currentState!.openEndDrawer();
    shell.currentState!.closeEndDrawer();
    await tester.pumpAndSettle();
    expect(handled.last, false);
  });

  testWidgets('closing a drawer preserves an existing route pop veto',
      (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final handled = <bool>[];
    var systemPops = 0;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemNavigator.setFrameworkHandlesBack') {
        handled.add(call.arguments as bool);
      }
      if (call.method == 'SystemNavigator.pop') systemPops++;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    final shell = GlobalKey<ScaffoldState>();
    await tester.pumpWidget(MaterialApp(
      home: PopScope(
        canPop: false,
        child: Builder(
            builder: (context) => Scaffold(
                  key: shell,
                  onEndDrawerChanged: (_) =>
                      syncProxoDrawerBackNavigation(context),
                  endDrawer: const Drawer(child: Text('Menu')),
                  body: const Text('Protected form'),
                )),
      ),
    ));
    await tester.pumpAndSettle();
    shell.currentState!.openEndDrawer();
    await tester.pumpAndSettle();
    expect(handled.last, true);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    // PopScope can veto local-history pops too. The navigation notification
    // must preserve that policy; an explicit drawer close is still allowed.
    expect(shell.currentState!.isEndDrawerOpen, true);
    shell.currentState!.closeEndDrawer();
    await tester.pumpAndSettle();
    expect(shell.currentState!.isEndDrawerOpen, false);
    expect(handled.last, true);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Protected form'), findsOneWidget);
    expect(systemPops, 0);
  });
}
