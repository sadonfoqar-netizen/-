import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/surah.dart';
import '../models/ayah.dart';
import '../models/reciter.dart';

/// خدمة التعامل مع alquran.cloud API
/// مجاني تماماً، بدون API key.
class QuranApi {
  static const String _baseUrl = 'https://api.alquran.cloud/v1';

  // ============================================================
  // تطبيع النص العربي
  // ============================================================

  /// يزيل التشكيل والتطويل ويوحّد الألف والهاء والياء
  static String normalizeArabic(String input) {
    if (input == null || input.isEmpty) return '';

    String text = input;

    // 1) إزالة التشكيل
    text = text.replaceAll(
      RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED]'),
      '',
    );

    // 2) إزالة التطويل
    text = text.replaceAll('\u0640', '');

    // 3) توحيد الألف
    text = text
        .replaceAll('\u0622', '\u0627')
        .replaceAll('\u0623', '\u0627')
        .replaceAll('\u0625', '\u0627');

    // 4) توحيد الألف المقصورة والياء
    text = text
        .replaceAll('\u0649', '\u064A')
        .replaceAll('\u0626', '\u064A');

    // 5) توحيد التاء المربوطة
    text = text.replaceAll('\u0629', '\u0647');

    // 6) توحيد كلمة سورة
    text = text.replaceAll('سُورَةُ', 'سوره');
    text = text.replaceAll('سورة', 'سوره');

    // 7) إزالة المسافات المتعددة
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    return text;
  }

  /// مقارنة بحث
  static bool matchesSearch(String text, String query) {
    if (text == null || query == null) return false;
    final normalizedText = normalizeArabic(text).toLowerCase();
    final normalizedQuery = normalizeArabic(query).toLowerCase();
    return normalizedText.contains(normalizedQuery);
  }

  // ============================================================
  // جلب البيانات من API
  // ============================================================

  /// جلب قائمة السور الـ 114
  static Future<List<Surah>> fetchSurahs() async {
    final url = Uri.parse('$_baseUrl/surah');
    final response = await http.get(url).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('فشل جلب السور: ${response.statusCode}');
    }

    final json =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (json['status'] != 'OK') {
      throw Exception('استجابة غير متوقعة من API');
    }

    final List<dynamic> data = json['data'] as List<dynamic>;
    return data
        .map((item) => Surah.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// جلب سورة كاملة
  static Future<Map<String, dynamic>> fetchSurahWithAyahs(
    int surahNumber, {
    String edition = 'quran-uthmani',
  }) async {
    final url = Uri.parse('$_baseUrl/surah/$surahNumber/$edition');
    final response = await http.get(url).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('فشل جلب السورة: ${response.statusCode}');
    }

    final json =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (json['status'] != 'OK') {
      throw Exception('استجابة غير متوقعة من API');
    }

    return json['data'] as Map<String, dynamic>;
  }

  /// جلب السورة كـ List<Ayah>
  static Future<List<Ayah>> fetchAyahs(int surahNumber) async {
    final data = await fetchSurahWithAyahs(surahNumber);
    final List<dynamic> ayahsJson = data['ayahs'] as List<dynamic>? ?? [];
    return ayahsJson
        .map((item) => Ayah.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// جلب سورة مع الصوت
  static Future<Map<String, dynamic>> fetchSurahWithAudio(
    int surahNumber,
    String reciterIdentifier,
  ) async {
    final url = Uri.parse('$_baseUrl/surah/$surahNumber/$reciterIdentifier');
    final response = await http.get(url).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('فشل جلب السورة بالصوت: ${response.statusCode}');
    }

    final json =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (json['status'] != 'OK') {
      throw Exception('استجابة غير متوقعة من API');
    }

    return json['data'] as Map<String, dynamic>;
  }

  // ============================================================
  // تحميل كل القرآن — جديد ✅
  // ============================================================

  /// يحمّل كل المصحف (114 سورة) مع تقدّم
  /// [onProgress]: يُستدعى بعد كل سورة (current, total, surahName)
  static Future<Map<int, List<Ayah>>> fetchFullQuran({
    void Function(int current, int total, String surahName)? onProgress,
  }) async {
    // 1) اجلب قائمة السور
    final surahs = await fetchSurahs();

    final result = <int, List<Ayah>>{};

    for (int i = 0; i < surahs.length; i++) {
      final surah = surahs[i];
      try {
        final ayahs = await fetchAyahs(surah.number);
        result[surah.number] = ayahs;
        if (onProgress != null) {
          onProgress(i + 1, surahs.length, surah.name);
        }
      } catch (e) {
        // نعيد رمي الخطأ ليعرف المستخدم
        rethrow;
      }
    }

    return result;
  }

  // ============================================================
  // القراء
  // ============================================================

  static List<Reciter> getReciters() {
    return const [
      Reciter(
        identifier: 'ar.alafasy',
        name: 'مشاري العفاسي',
        englishName: 'Mishary Alafasy',
        server: 'https://server8.mp3quran.net/afs/',
        surahPath: '',
      ),
      Reciter(
        identifier: 'ar.abdulbasitmurattal',
        name: 'عبد الباسط عبد الصمد',
        englishName: 'Abdul Basit',
        server: 'https://server7.mp3quran.net/basit/',
        surahPath: '',
      ),
      Reciter(
        identifier: 'ar.abdurrahmaansudais',
        name: 'عبد الرحمن السديس',
        englishName: 'Abdurrahman As-Sudais',
        server: 'https://server11.mp3quran.net/sds/',
        surahPath: '',
      ),
      Reciter(
        identifier: 'ar.husary',
        name: 'محمود خليل الحصري',
        englishName: 'Mahmoud Khalil Al-Husary',
        server: 'https://server13.mp3quran.net/husr/',
        surahPath: '',
      ),
      Reciter(
        identifier: 'ar.minshawi',
        name: 'محمد صديق المنشاوي',
        englishName: 'Muhammad Siddiq Al-Minshawi',
        server: 'https://server10.mp3quran.net/minsh/',
        surahPath: '',
      ),
      Reciter(
        identifier: 'ar.mahermuaiqly',
        name: 'ماهر المعيقلي',
        englishName: 'Maher Al Muaiqly',
        server: 'https://server12.mp3quran.net/maher/',
        surahPath: '',
      ),
      Reciter(
        identifier: 'ar.hudhaify',
        name: 'علي الحذيفي',
        englishName: 'Ali Al-Hudhaify',
        server: 'https://server9.mp3quran.net/hthf/',
        surahPath: '',
      ),
      Reciter(
        identifier: 'ar.shaatree',
        name: 'أبو بكر الشاطري',
        englishName: 'Abu Bakr Ash-Shaatree',
        server: 'https://server11.mp3quran.net/shatri/',
        surahPath: '',
      ),
      Reciter(
        identifier: 'ar.ahmedajamy',
        name: 'أحمد بن علي العجمي',
        englishName: 'Ahmed ibn Ali al-Ajamy',
        server: 'https://server10.mp3quran.net/ajm/',
        surahPath: '',
      ),
      Reciter(
        identifier: 'ar.hanirifai',
        name: 'هاني الرفاعي',
        englishName: 'Hani Ar-Rifai',
        server: 'https://server8.mp3quran.net/hani/',
        surahPath: '',
      ),
    ];
  }

  // ============================================================
  // البحث
  // ============================================================

  /// البحث في السور
  static List<Surah> searchSurahs(List<Surah> surahs, String query) {
    if (query.trim().isEmpty) return surahs;

    final q = query.trim();
    final qLower = q.toLowerCase();
    final qNumber = int.tryParse(q);

    return surahs.where((s) {
      if (qNumber != null && s.number == qNumber) return true;
      if (matchesSearch(s.name, q)) return true;
      if (s.englishName.toLowerCase().contains(qLower)) return true;
      if (s.englishNameTranslation.toLowerCase().contains(qLower)) {
        return true;
      }
      return false;
    }).toList();
  }
}