import 'package:just_audio/just_audio.dart';
import '../models/reciter.dart';

/// خدمة التلاوة الصوتية
/// - تشغيل داخل التطبيق باستخدام just_audio
/// - إمكانية تبديل القارئ أثناء التشغيل
class AudioService {
  static final AudioPlayer _player = AudioPlayer();

  // القارئ والسورة الحاليين
  static Reciter? _currentReciter;
  static int _currentSurahNumber = 0;
  static String _currentSurahName = '';

  // ============================================================
  // الوصول للحالة الحالية
  // ============================================================
  static Reciter? get currentReciter => _currentReciter;
  static int get currentSurahNumber => _currentSurahNumber;
  static String get currentSurahName => _currentSurahName;

  // ============================================================
  // تشغيل سورة
  // ============================================================
  static Future<bool> playSurah(
    Reciter reciter,
    int surahNumber, {
    String surahName = '',
  }) async {
    try {
      final url = reciter.getAudioUrl(surahNumber);

      if (_currentReciter?.identifier == reciter.identifier &&
          _currentSurahNumber == surahNumber &&
          _player.audioSource != null) {
        _player.play();
        return true;
      }

      await _player.stop();
      await _player.setUrl(url);

      _currentReciter = reciter;
      _currentSurahNumber = surahNumber;
      _currentSurahName = surahName;

      _player.play();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// تغيير القارئ فقط (مع نفس السورة)
  static Future<bool> changeReciter(Reciter reciter) async {
    if (_currentSurahNumber == 0) return false;
    return playSurah(
      reciter,
      _currentSurahNumber,
      surahName: _currentSurahName,
    );
  }

  // ============================================================
  // التحكم الأساسي
  // ============================================================
  static Future<void> pause() async {
    await _player.pause();
  }

  static Future<void> resume() async {
    _player.play();
  }

  static Future<void> stop() async {
    await _player.stop();
    _currentReciter = null;
    _currentSurahNumber = 0;
    _currentSurahName = '';
  }

  static Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  static Future<void> replay() async {
    await _player.seek(Duration.zero);
    _player.play();
  }

  // ============================================================
  // الحالة
  // ============================================================
  static bool get isPlaying => _player.playing;
  static Duration? get duration => _player.duration;
  static Duration get position => _player.position;
  static bool get hasAudio => _player.audioSource != null;

  // ============================================================
  // Streams للمراقبة
  // ============================================================
  static Stream<bool> get playingStream => _player.playingStream;
  static Stream<Duration> get positionStream => _player.positionStream;
  static Stream<Duration?> get durationStream => _player.durationStream;
  static Stream<ProcessingState> get processingStateStream =>
      _player.processingStateStream;

  static AudioPlayer get player => _player;

  // ============================================================
  // أدوات مساعدة — محدّث ✅ (يدعم الساعات)
  // ============================================================
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes =
        duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
        duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  static Future<void> dispose() async {
    await _player.dispose();
  }
}