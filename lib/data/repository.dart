import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:mtg_table/data/app_log.dart';
import 'package:mtg_table/data/retry.dart';
import 'package:mtg_table/domain/game_controller.dart';
import 'package:mtg_table/domain/models.dart';
import 'package:mtg_table/domain/night_session.dart';
import 'package:mtg_table/domain/player_profile.dart';
import 'package:mtg_table/domain/stats.dart';

class AppRepository {
  static const settingsKey = 'table_mtg_settings_v1';
  static const sessionKey = 'table_mtg_session_v1';
  static const groupKey = 'table_mtg_group_v1';
  static const ledgerKey = 'table_mtg_ledger_v1';
  static const cardCacheKey = 'table_mtg_scryfall_cache_v1';
  static const profilesKey = 'table_mtg_profiles_v1';
  static const nightKey = 'table_mtg_night_v1';

  Future<SharedPreferences> _prefs() {
    return withFourTries(
      SharedPreferences.getInstance,
      baseDelay: const Duration(milliseconds: 50),
    );
  }

  Future<AppSettings> loadSettings() async {
    try {
      final prefs = await _prefs();
      final decoded = _decode(prefs.getString(settingsKey));
      if (decoded == null) return AppSettings.defaults;
      return AppSettings.fromJson(decoded);
    } on Object catch (error, stack) {
      AppLog.error('loadSettings', error, stack);
      return AppSettings.defaults;
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    try {
      final prefs = await _prefs();
      await prefs.setString(settingsKey, jsonEncode(settings.toJson()));
    } on Object catch (error, stack) {
      AppLog.error('saveSettings', error, stack);
    }
  }

  Future<Map<String, dynamic>?> loadSession() async {
    try {
      final prefs = await _prefs();
      return _decode(prefs.getString(sessionKey));
    } on Object catch (error, stack) {
      AppLog.error('loadSession', error, stack);
      return null;
    }
  }

  Future<void> saveSession(GameController controller) async {
    try {
      final prefs = await _prefs();
      await prefs.setString(sessionKey, jsonEncode(controller.exportSession()));
    } on Object catch (error, stack) {
      AppLog.error('saveSession', error, stack);
    }
  }

  Future<void> clearSession() async {
    try {
      final prefs = await _prefs();
      await prefs.remove(sessionKey);
    } on Object catch (error, stack) {
      AppLog.error('clearSession', error, stack);
    }
  }

  Future<Playgroup?> loadGroup() async {
    try {
      final prefs = await _prefs();
      final decoded = _decode(prefs.getString(groupKey));
      if (decoded == null) return null;
      return Playgroup.fromJson(decoded);
    } on Object catch (error, stack) {
      AppLog.error('loadGroup', error, stack);
      return null;
    }
  }

  Future<void> saveGroup(Playgroup group) async {
    try {
      final prefs = await _prefs();
      await prefs.setString(groupKey, jsonEncode(group.toJson()));
    } on Object catch (error, stack) {
      AppLog.error('saveGroup', error, stack);
    }
  }

  Future<LocalLedger> loadLedger() async {
    try {
      final prefs = await _prefs();
      final decoded = _decode(prefs.getString(ledgerKey));
      if (decoded == null) return LocalLedger();
      return LocalLedger.fromJson(decoded);
    } on Object catch (error, stack) {
      AppLog.error('loadLedger', error, stack);
      return LocalLedger();
    }
  }

  Future<void> saveLedger(LocalLedger ledger) async {
    try {
      final prefs = await _prefs();
      await prefs.setString(ledgerKey, jsonEncode(ledger.toJson()));
    } on Object catch (error, stack) {
      AppLog.error('saveLedger', error, stack);
    }
  }

  Future<List<PlayerProfile>> loadProfiles() async {
    try {
      final prefs = await _prefs();
      final decoded = _decode(prefs.getString(profilesKey));
      if (decoded == null) return const [];
      final raw = decoded['items'];
      if (raw is! List) return const [];
      return [
        for (final item in raw)
          if (item is Map<String, dynamic>)
            PlayerProfile.fromJson(item)
          else if (item is Map)
            PlayerProfile.fromJson(Map<String, dynamic>.from(item)),
      ];
    } on Object catch (error, stack) {
      AppLog.error('loadProfiles', error, stack);
      return const [];
    }
  }

  Future<void> saveProfiles(List<PlayerProfile> profiles) async {
    try {
      final prefs = await _prefs();
      await prefs.setString(
        profilesKey,
        jsonEncode({
          'items': [for (final p in profiles) p.toJson()],
        }),
      );
    } on Object catch (error, stack) {
      AppLog.error('saveProfiles', error, stack);
    }
  }

  Future<NightSession?> loadNight() async {
    try {
      final prefs = await _prefs();
      final decoded = _decode(prefs.getString(nightKey));
      if (decoded == null) return null;
      return NightSession.fromJson(decoded);
    } on Object catch (error, stack) {
      AppLog.error('loadNight', error, stack);
      return null;
    }
  }

  Future<void> saveNight(NightSession? night) async {
    try {
      final prefs = await _prefs();
      if (night == null) {
        await prefs.remove(nightKey);
        return;
      }
      await prefs.setString(nightKey, jsonEncode(night.toJson()));
    } on Object catch (error, stack) {
      AppLog.error('saveNight', error, stack);
    }
  }

  /// Cache local Scryfall (ToS : attribution + pas de redistrib massique).
  Future<Map<String, dynamic>?> loadCachedCard(String key) async {
    try {
      final prefs = await _prefs();
      final all = _decode(prefs.getString(cardCacheKey));
      if (all == null) return null;
      final entry = all[key.toLowerCase()];
      if (entry is Map<String, dynamic>) return entry;
      if (entry is Map) return Map<String, dynamic>.from(entry);
      return null;
    } on Object catch (error, stack) {
      AppLog.error('loadCachedCard', error, stack);
      return null;
    }
  }

  Future<void> cacheCard(String key, Map<String, dynamic> card) async {
    try {
      final prefs = await _prefs();
      final existing = _decode(prefs.getString(cardCacheKey)) ?? {};
      existing[key.toLowerCase()] = {
        ...card,
        '_cachedAtMs': DateTime.now().millisecondsSinceEpoch,
      };
      if (existing.length > 80) {
        final entries = existing.entries.toList()
          ..sort((a, b) {
            final am = asInt((a.value as Map)['_cachedAtMs']);
            final bm = asInt((b.value as Map)['_cachedAtMs']);
            return am.compareTo(bm);
          });
        for (final old in entries.take(existing.length - 80)) {
          existing.remove(old.key);
        }
      }
      await prefs.setString(cardCacheKey, jsonEncode(existing));
    } on Object catch (error, stack) {
      AppLog.error('cacheCard', error, stack);
    }
  }

  Future<void> clearCardCache() async {
    try {
      final prefs = await _prefs();
      await prefs.remove(cardCacheKey);
      AppLog.info('clearCardCache');
    } on Object catch (error, stack) {
      AppLog.error('clearCardCache', error, stack);
    }
  }

  /// Efface toutes les données locales (droit à l’effacement / RGPD).
  Future<void> clearAllLocalData() async {
    try {
      final prefs = await _prefs();
      await prefs.remove(settingsKey);
      await prefs.remove(sessionKey);
      await prefs.remove(groupKey);
      await prefs.remove(ledgerKey);
      await prefs.remove(cardCacheKey);
      await prefs.remove(profilesKey);
      await prefs.remove(nightKey);
      AppLog.info('clearAllLocalData: prefs vidées');
    } on Object catch (error, stack) {
      AppLog.error('clearAllLocalData', error, stack);
      rethrow;
    }
  }

  Map<String, dynamic>? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final value = jsonDecode(raw);
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
    } on Object catch (error, stack) {
      AppLog.error('prefs decode', error, stack);
      return null;
    }
    return null;
  }
}
