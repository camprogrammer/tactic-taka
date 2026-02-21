import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

class LocalStorage {
  const LocalStorage();

  static const _boxName = 'football_social_app_box';
  static const _stateKey = 'app_state';
  static bool _initialized = false;

  Future<void> _ensureInit() async {
    if (!_initialized) {
      await Hive.initFlutter();
      _initialized = true;
    }
  }

  Future<Box<String>> _box() async {
    await _ensureInit();
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<String>(_boxName);
    }
    return Hive.openBox<String>(_boxName);
  }

  Future<Map<String, dynamic>?> readState() async {
    final box = await _box();
    final content = box.get(_stateKey);
    if (content == null || content.trim().isEmpty) {
      return null;
    }

    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    return decoded;
  }

  Future<void> writeState(Map<String, dynamic> data) async {
    final box = await _box();
    final encoded = jsonEncode(data);
    await box.put(_stateKey, encoded);
  }
}
