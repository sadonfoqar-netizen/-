import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/surah.dart';
import '../models/ayah.dart';

/// خدمة التخزين المحلي باستخدام shared_preferences
class StorageService {
  static late SharedPreferences _prefs;
  static bool _initialized = false;

  // مفاتيح التخزين
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyQuranFontSize = 'quran_font_size';
  static const String _keyReciter = 'preferred_reciter';
  static const String _keySurahsCache = 'surahs_cache';
  static const String _keySurahsCacheTime = 'surahs_cache_time';
  static const String _keyAyahsPrefix = 'ayahs_cache_';
  static const String _keyLastRead = 'last_read';
  static const String _keyScrollPrefix = 'scroll_pos_';
  static const String _keyBookmarks = 'bookmarks';

  // ✅ القرآن الكامل
  static const String _keyFullQuran = 'full_quran_cache';
  static const String _keyFullQuranTime = 'full_quran_cache_time';

  // مدة صلاحية Cache السور (7 أيام)
  static const int _cacheDurationMs = 7 * 24 * 60 * 60 * 1000;

  // ============================================================
  // التهيئة
  // ============================================================
  static Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  // ============================================================
  // الإعدادات: الوضع
  // ============================================================
  static ThemeMode getThemeMode() {
    final value = _prefs.getString(_keyThemeMode) ?? 'light';
    return value == 'dark' ? ThemeMode.dark : ThemeMode.light;
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString(
        _keyThemeMode, mode == ThemeMode.dark ? 'dark' : 'light');
  }

  // ============================================================
  // الإعدادات: حجم خط المصحف
  // ============================================================
  static double getQuranFontSize() {
    return _prefs.getDouble(_keyQuranFontSize) ?? 26.0;
  }

  static Future<void> setQuranFontSize(double size) async {
    await _prefs.setDouble(_keyQuranFontSize, size);
  }

  // ============================================================
  // الإعدادات: القارئ المفضل
  // ============================================================
  static String getPreferredReciter() {
    return _prefs.getString(_keyReciter) ?? 'ar.alafasy';
  }

  static Future<void> setPreferredReciter(String identifier) async {
    await _prefs.setString(_keyReciter, identifier);
  }

  // ============================================================
  // Cache السور
  // ============================================================
  static Future<void> saveSurahsCache(List<Surah> surahs) async {
    try {
      final data = surahs.map((s) => s.toJson()).toList();
      await _prefs.setString(_keySurahsCache, jsonEncode(data));
      await _prefs.setInt(
          _keySurahsCacheTime, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  static List<Surah>? getSurahsCache() {
    try {
      final timeStr = _prefs.getInt(_keySurahsCacheTime) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - timeStr > _cacheDurationMs) return null;

      final raw = _prefs.getString(_keySurahsCache);
      if (raw == null || raw.isEmpty) return null;

      final List<dynamic> data = jsonDecode(raw) as List<dynamic>;
      return data
          .map((item) => Surah.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // Cache آيات سورة محددة
  // ============================================================
  static Future<void> saveAyahsCache(
      int surahNumber, List<Ayah> ayahs) async {
    try {
      final data = ayahs.map((a) => a.toJson()).toList();
      await _prefs.setString('$_keyAyahsPrefix$surahNumber', jsonEncode(data));
    } catch (_) {}
  }

  static List<Ayah>? getAyahsCache(int surahNumber) {
    try {
      final raw = _prefs.getString('$_keyAyahsPrefix$surahNumber');
      if (raw == null || raw.isEmpty) return null;

      final List<dynamic> data = jsonDecode(raw) as List<dynamic>;
      return data
          .map((item) => Ayah.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearAllCache() async {
    await _prefs.remove(_keySurahsCache);
    await _prefs.remove(_keySurahsCacheTime);

    final keys =
        _prefs.getKeys().where((k) => k.startsWith(_keyAyahsPrefix)).toList();
    for (final key in keys) {
      await _prefs.remove(key);
    }
  }

  // ============================================================
  // القرآن الكامل — جديد ✅
  // ============================================================

  /// حفظ كل القرآن
  /// البنية: { surahNumber: [ayah1, ayah2, ...] }
  static Future<void> saveFullQuran(Map<int, List<Ayah>> fullQuran) async {
    try {
      final map = <String, dynamic>{};
      fullQuran.forEach((key, value) {
        map[key.toString()] = value.map((a) => a.toJson()).toList();
      });
      final json = jsonEncode(map);
      await _prefs.setString(_keyFullQuran, json);
      await _prefs.setInt(
        _keyFullQuranTime,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {}
  }

  /// قراءة كل القرآن
  static Map<int, List<Ayah>>? getFullQuran() {
    try {
      final raw = _prefs.getString(_keyFullQuran);
      if (raw == null || raw.isEmpty) return null;

      final Map<String, dynamic> map =
          jsonDecode(raw) as Map<String, dynamic>;
      final result = <int, List<Ayah>>{};
      map.forEach((key, value) {
        final list = (value as List)
            .map((item) => Ayah.fromJson(item as Map<String, dynamic>))
            .toList();
        result[int.parse(key)] = list;
      });
      return result;
    } catch (_) {
      return null;
    }
  }

  /// هل القرآن محمّل كاملاً؟
  static bool isFullQuranReady() {
    final raw = _prefs.getString(_keyFullQuran);
    return raw != null && raw.isNotEmpty;
  }

  /// وقت تحميل القرآن
  static DateTime? getFullQuranTime() {
    final ms = _prefs.getInt(_keyFullQuranTime);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// مسح القرآن المحمّل
  static Future<void> clearFullQuran() async {
    await _prefs.remove(_keyFullQuran);
    await _prefs.remove(_keyFullQuranTime);
  }

  // ============================================================
  // آخر قراءة (Last Read)
  // ============================================================
  static Future<void> saveLastRead({
    required int surahNumber,
    required String surahName,
    required int ayahNumber,
  }) async {
    final data = {
      'surahNumber': surahNumber,
      'surahName': surahName,
      'ayahNumber': ayahNumber,
      'time': DateTime.now().millisecondsSinceEpoch,
    };
    await _prefs.setString(_keyLastRead, jsonEncode(data));
  }

  static Future<void> updateLastReadAyah({
    required int surahNumber,
    required String surahName,
    required int ayahNumber,
  }) async {
    final current = getLastRead();
    if (current != null &&
        current['surahNumber'] == surahNumber &&
        current['ayahNumber'] == ayahNumber) {
      return;
    }
    await saveLastRead(
      surahNumber: surahNumber,
      surahName: surahName,
      ayahNumber: ayahNumber,
    );
  }

  static Map<String, dynamic>? getLastRead() {
    try {
      final raw = _prefs.getString(_keyLastRead);
      if (raw == null || raw.isEmpty) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearLastRead() async {
    await _prefs.remove(_keyLastRead);
  }

  // ============================================================
  // موضع التمرير في السورة
  // ============================================================
  static Future<void> saveScrollPosition(
      int surahNumber, double offset) async {
    await _prefs.setDouble('$_keyScrollPrefix$surahNumber', offset);
  }

  static double getScrollPosition(int surahNumber) {
    return _prefs.getDouble('$_keyScrollPrefix$surahNumber') ?? 0.0;
  }

  static Future<void> clearScrollPosition(int surahNumber) async {
    await _prefs.remove('$_keyScrollPrefix$surahNumber');
  }

  // ============================================================
  // المفضلة (Bookmarks)
  // ============================================================
  static Future<void> addBookmark({
    required int surahNumber,
    required String surahName,
    required int ayahNumber,
    required String ayahText,
    String note = '',
  }) async {
    final bookmarks = getBookmarks();
    final key = '$surahNumber:$ayahNumber';

    bookmarks
        .removeWhere((b) => '${b['surahNumber']}:${b['ayahNumber']}' == key);

    bookmarks.insert(0, {
      'surahNumber': surahNumber,
      'surahName': surahName,
      'ayahNumber': ayahNumber,
      'ayahText': ayahText,
      'note': note,
      'time': DateTime.now().millisecondsSinceEpoch,
    });

    await _prefs.setString(_keyBookmarks, jsonEncode(bookmarks));
  }

  static Future<void> updateBookmarkNote(
      int surahNumber, int ayahNumber, String note) async {
    final bookmarks = getBookmarks();
    for (int i = 0; i < bookmarks.length; i++) {
      final b = bookmarks[i];
      if (b['surahNumber'] == surahNumber && b['ayahNumber'] == ayahNumber) {
        b['note'] = note;
        bookmarks[i] = b;
        break;
      }
    }
    await _prefs.setString(_keyBookmarks, jsonEncode(bookmarks));
  }

  static Future<void> removeBookmark(int surahNumber, int ayahNumber) async {
    final bookmarks = getBookmarks();
    bookmarks.removeWhere((b) =>
        b['surahNumber'] == surahNumber && b['ayahNumber'] == ayahNumber);
    await _prefs.setString(_keyBookmarks, jsonEncode(bookmarks));
  }

  static List<Map<String, dynamic>> getBookmarks() {
    try {
      final raw = _prefs.getString(_keyBookmarks);
      if (raw == null || raw.isEmpty) return [];
      final List<dynamic> data = jsonDecode(raw) as List<dynamic>;
      return data
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static bool isBookmarked(int surahNumber, int ayahNumber) {
    return getBookmarks().any((b) =>
        b['surahNumber'] == surahNumber && b['ayahNumber'] == ayahNumber);
  }

  static Future<void> clearBookmarks() async {
    await _prefs.remove(_keyBookmarks);
  }
}