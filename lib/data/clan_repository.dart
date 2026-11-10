import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Lưu toàn bộ gia phả trên thiết bị (localStorage trên web,
/// SharedPreferences trên Android/iOS).
class ClanRepository {
  ClanRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'giaphavietnam.clans.v1';
  static const _corruptKey = 'giaphavietnam.clans.corrupt';
  static const backupFormat = 'giaphavietnam';
  static const backupVersion = 1;

  List<Clan> load() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      final list = decoded is Map ? decoded['clans'] : decoded;
      if (list is! List) return [];
      return list
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => Clan.fromJson(e.cast<String, Object?>()))
          .toList();
    } catch (e, st) {
      // Giữ lại bản lỗi để không bị ghi đè mất dữ liệu.
      debugPrint('Không đọc được dữ liệu gia phả: $e\n$st');
      _prefs.setString(_corruptKey, raw).ignore();
      return [];
    }
  }

  Future<void> save(List<Clan> clans) async {
    final payload = jsonEncode({
      'format': backupFormat,
      'version': backupVersion,
      'clans': clans.map((c) => c.toJson()).toList(),
    });
    final ok = await _prefs.setString(_key, payload);
    if (!ok) throw StateError('Không lưu được dữ liệu gia phả');
  }

  /// Tệp sao lưu một gia phả (JSON).
  static String exportClan(Clan clan) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert({
      'format': backupFormat,
      'version': backupVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'clan': clan.toJson(),
    });
  }

  /// Đọc tệp sao lưu; ném [FormatException] khi nội dung không hợp lệ.
  static Clan importClan(String text) {
    final decoded = jsonDecode(text.trim());
    if (decoded is! Map) throw const FormatException('Không phải tệp gia phả');
    final version = (decoded['version'] as num?)?.toInt() ?? 0;
    if (version > backupVersion) {
      throw const FormatException('Tệp được tạo từ phiên bản ứng dụng mới hơn');
    }
    final clanJson = decoded['clan'];
    if (clanJson is! Map || clanJson['id'] is! String) {
      throw const FormatException('Thiếu dữ liệu gia phả');
    }
    return Clan.fromJson(clanJson.cast<String, Object?>());
  }
}
