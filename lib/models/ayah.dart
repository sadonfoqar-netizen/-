class Ayah {
  final int number;          // رقم الآية في المصحف كاملاً (1-6236)
  final String text;         // نص الآية
  final int numberInSurah;   // رقم الآية داخل السورة
  final int juz;             // رقم الجزء
  final int manzil;
  final int page;            // رقم الصفحة
  final int ruku;
  final int hizbQuarter;
  final bool sajda;

  Ayah({
    required this.number,
    required this.text,
    required this.numberInSurah,
    this.juz = 0,
    this.manzil = 0,
    this.page = 0,
    this.ruku = 0,
    this.hizbQuarter = 0,
    this.sajda = false,
  });

  /// يحوّل الأرقام العربية في نهاية الآية (۝)
  String get displayText {
    return '$text ۝$numberInSurah';
  }

  factory Ayah.fromJson(Map<String, dynamic> json) {
    return Ayah(
      number: json['number'] as int? ?? 0,
      text: json['text'] as String? ?? '',
      numberInSurah: json['numberInSurah'] as int? ?? 0,
      juz: json['juz'] as int? ?? 0,
      manzil: json['manzil'] as int? ?? 0,
      page: json['page'] as int? ?? 0,
      ruku: json['ruku'] as int? ?? 0,
      hizbQuarter: json['hizbQuarter'] as int? ?? 0,
      sajda: json['sajda'] is bool ? json['sajda'] : false,
    );
  }

  Map<String, dynamic> toJson() => {
        'number': number,
        'text': text,
        'numberInSurah': numberInSurah,
        'juz': juz,
        'manzil': manzil,
        'page': page,
        'ruku': ruku,
        'hizbQuarter': hizbQuarter,
        'sajda': sajda,
      };

  /// مفتاح فريد للحفظ
  String get uniqueKey => 'ayah_$number';
}