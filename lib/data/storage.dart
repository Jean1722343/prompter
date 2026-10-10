import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/prompter_settings.dart';
import '../models/script.dart';

/// Acceso a disco compartido entre la app y la ventana flotante.
///
/// La ventana flotante corre en otro motor de Flutter (otro isolate), así que
/// usamos [SharedPreferencesAsync], que no cachea y siempre lee lo último.
class Storage {
  Storage._();

  static final _prefs = SharedPreferencesAsync();

  static const _scriptsKey = 'scripts';
  static const _seededKey = 'seeded';
  static const _overlayScriptKey = 'overlay_script';
  static const _readerSettingsKey = 'settings_reader';
  static const _overlaySettingsKey = 'settings_overlay';

  static Future<List<Script>> loadScripts() async {
    final raw = await _prefs.getString(_scriptsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Script.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> saveScripts(List<Script> scripts) =>
      _prefs.setString(_scriptsKey, jsonEncode(scripts.map((s) => s.toJson()).toList()));

  static Future<bool> isSeeded() async => await _prefs.getBool(_seededKey) ?? false;

  static Future<void> markSeeded() => _prefs.setBool(_seededKey, true);

  /// Guion que mostrará la ventana flotante.
  static Future<void> setOverlayScript(Script script) =>
      _prefs.setString(_overlayScriptKey, jsonEncode(script.toJson()));

  static Future<Script?> overlayScript() async {
    final raw = await _prefs.getString(_overlayScriptKey);
    if (raw == null) return null;
    return Script.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  static Future<PrompterSettings> readerSettings() => _settings(_readerSettingsKey, PrompterSettings.reader);

  static Future<PrompterSettings> overlaySettings() => _settings(_overlaySettingsKey, PrompterSettings.overlay);

  static Future<void> saveReaderSettings(PrompterSettings s) =>
      _prefs.setString(_readerSettingsKey, jsonEncode(s.toJson()));

  static Future<void> saveOverlaySettings(PrompterSettings s) =>
      _prefs.setString(_overlaySettingsKey, jsonEncode(s.toJson()));

  static Future<PrompterSettings> _settings(String key, PrompterSettings fallback) async {
    final raw = await _prefs.getString(key);
    if (raw == null) return fallback;
    return PrompterSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>, fallback);
  }
}
