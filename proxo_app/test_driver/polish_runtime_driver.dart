import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() async {
  final directory = Directory('build/polish-runtime')
    ..createSync(recursive: true);
  try {
    await integrationDriver(
      // Match the device fixture. A real host Future deadline below is also
      // needed: VMServiceFlutterDriver treats this argument as a slow warning.
      timeout: const Duration(minutes: 10),
      writeResponseOnFailure: true,
      responseDataCallback: (data) async {
        await File('${directory.path}/runtime.json')
            .writeAsString(const JsonEncoder.withIndent('  ').convert(data));
        final observations = data?['observations'];
        if (observations is! Map || observations['completed'] != true) {
          throw StateError(
              'Profile fixture did not complete; inspect runtime.json');
        }
      },
    ).timeout(const Duration(minutes: 10));
  } catch (error, stack) {
    final timedOut = error is TimeoutException;
    await File('${directory.path}/driver-failure.json')
        .writeAsString(const JsonEncoder.withIndent('  ').convert({
      'completed': false,
      'timed_out': timedOut,
      'error': error.toString(),
      'stack': stack.toString(),
    }));
    stderr.writeln('Profile fixture host failed: $error');
    // A lost VM may leave an open service connection after Future.timeout.
    exit(timedOut ? 124 : 1);
  }
}
