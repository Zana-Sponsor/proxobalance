import 'dart:convert';
import 'dart:io';
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() async {
  final directory = Directory('build/polish-runtime')
    ..createSync(recursive: true);
  await integrationDriver(
    writeResponseOnFailure: true,
    responseDataCallback: (data) async {
      await File('${directory.path}/runtime.json')
          .writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    },
  );
}
