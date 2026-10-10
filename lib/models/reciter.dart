class Reciter {
  final String identifier;
  final String name;
  final String englishName;
  final String server;
  final String surahPath;

  const Reciter({
    required this.identifier,
    required this.name,
    required this.englishName,
    required this.server,
    required this.surahPath,
  });

  /// يولّد رابط التلاوة لسورة محددة
  /// مثال: https://server8.mp3quran.net/afs/001.mp3
  String getAudioUrl(int surahNumber) {
    final padded = surahNumber.toString().padLeft(3, '0');
    if (surahPath.isNotEmpty) {
      return '$server$surahPath$padded.mp3';
    }
    return '$server$padded.mp3';
  }

  factory Reciter.fromJson(Map<String, dynamic> json) {
    return Reciter(
      identifier: json['identifier'] as String? ?? '',
      name: json['name'] as String? ?? '',
      englishName: json['englishName'] as String? ?? '',
      server: json['server'] as String? ?? '',
      surahPath: json['surah_path'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'identifier': identifier,
        'name': name,
        'englishName': englishName,
        'server': server,
        'surah_path': surahPath,
      };
}