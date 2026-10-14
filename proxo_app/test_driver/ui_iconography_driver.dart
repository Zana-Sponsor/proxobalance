import 'dart:convert';
import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final directory = Directory('build/ui-native')..createSync(recursive: true);
  await integrationDriver(
    writeResponseOnFailure: true,
    onScreenshot: (name, image, [args]) async {
      await File('${directory.path}/$name.png').writeAsBytes(image);
      return image.isNotEmpty;
    },
    responseDataCallback: (data) async {
      final observations = data?['observations'] as Map?;
      final config = observations?['config'] ?? 'unknown';
      await File('${directory.path}/$config.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert(observations));
    },
  );
}
