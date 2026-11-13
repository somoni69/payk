import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(Future<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final store = <String, String>{};
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async {
      final args = call.arguments;
      final key = args is Map ? args['key'] as String? : null;
      switch (call.method) {
        case 'read':
          return key == null ? null : store[key];
        case 'write':
          final value = args is Map ? args['value'] : null;
          if (key != null && value is String) store[key] = value;
          return null;
        case 'delete':
          if (key != null) store.remove(key);
          return null;
        case 'deleteAll':
        case 'clear':
          store.clear();
          return null;
        case 'containsKey':
          return key != null && store.containsKey(key);
        case 'readAll':
          return store;
        default:
          return null;
      }
    },
  );
  await testMain();
}
