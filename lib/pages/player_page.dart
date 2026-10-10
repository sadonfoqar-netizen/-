import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/reciter.dart';
import '../models/surah.dart';
import '../services/audio_service.dart';
import '../services/quran_api.dart';
import '../services/storage_service.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({Key? key}) : super(key: key);

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _playingSub;
  StreamSubscription? _stateSub;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _isSwitching = false;

  Reciter? _reciter;
  int _surahNumber = 0;
  String _surahName = '';
  List<Surah> _allSurahs = [];

  @override
  void initState() {
    super.initState();
    _reciter = AudioService.currentReciter;
    _surahNumber = AudioService.currentSurahNumber;
    _surahName = AudioService.currentSurahName;
    _loadSurahs();
    _setupListeners();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    _stateSub?.cancel();
    super.dispose();
  }

  void _loadSurahs() {
    final cached = StorageService.getSurahsCache();
    if (cached != null && cached.isNotEmpty) {
      _allSurahs = cached;
    }
  }

  void _setupListeners() {
    _positionSub = AudioService.positionStream.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _durationSub = AudioService.durationStream.listen((dur) {
      if (mounted) setState(() => _duration = dur ?? Duration.zero);
    });
    _playingSub = AudioService.playingStream.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    });
    _stateSub = AudioService.processingStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isLoading = state == ProcessingState.loading ||
              state == ProcessingState.buffering;
        });
      }
    });
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await AudioService.pause();
    } else {
      await AudioService.resume();
    }
  }

  Future<void> _seekTo(double seconds) async {
    await AudioService.seek(Duration(seconds: seconds.round()));
  }

  Future<void> _skip(int seconds) async {
    final target = _position.inSeconds + seconds;
    final max = _duration.inSeconds;
    await _seekTo((target < 0 ? 0 : (target > max ? max : target)).toDouble());
  }

  Future<void> _goToSurah(int surahNumber, String surahName) async {
    if (_reciter == null) return;
    if (surahNumber == _surahNumber) return;

    setState(() {
      _isSwitching = true;
      _position = Duration.zero;
      _duration = Duration.zero;
    });

    final ok = await AudioService.playSurah(
      _reciter!,
      surahNumber,
      surahName: surahName,
    );

    if (!mounted) return;
    if (ok) {
      setState(() {
        _surahNumber = surahNumber;
        _surahName = surahName;
        _isSwitching = false;
      });
      StorageService.saveLastRead(
        surahNumber: surahNumber,
        surahName: surahName,
        ayahNumber: 1,
      );
    } else {
      setState(() => _isSwitching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحميل السورة')),
      );
    }
  }

  Future<void> _nextSurah() async {
    if (_surahNumber >= 114) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هذه آخر سورة')),
      );
      return;
    }
    await _goToSurah(_surahNumber + 1, _getSurahName(_surahNumber + 1));
  }

  Future<void> _previousSurah() async {
    if (_surahNumber <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هذه أول سورة')),
      );
      return;
    }
    await _goToSurah(_surahNumber - 1, _getSurahName(_surahNumber - 1));
  }

  String _getSurahName(int number) {
    if (_allSurahs.isEmpty) return 'سورة $number';
    try {
      final s = _allSurahs.firstWhere((s) => s.number == number);
      return s.name.replaceAll('سُورَةُ ', '');
    } catch (_) {
      return 'سورة $number';
    }
  }

  void _showSurahsList() {
    if (_allSurahs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('قائمة السور غير متوفرة')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) => Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.onSurfaceVariant.withOpacity(.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.menu_book_rounded, color: scheme.primary),
                      const SizedBox(width: 10),
                      Text(
                        'اختر سورة',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_allSurahs.length} سورة',
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _allSurahs.length,
                    itemBuilder: (context, index) {
                      final surah = _allSurahs[index];
                      final displayName =
                          surah.name.replaceAll('سُورَةُ ', '');
                      final isCurrent = surah.number == _surahNumber;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isCurrent
                              ? scheme.primary
                              : scheme.primaryContainer,
                          child: Text(
                            '${surah.number}',
                            style: TextStyle(
                              color: isCurrent
                                  ? scheme.onPrimary
                                  : scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        title: Text(
                          displayName,
                          style: TextStyle(
                            fontWeight: isCurrent
                                ? FontWeight.w900
                                : FontWeight.w600,
                            color: isCurrent
                                ? scheme.primary
                                : scheme.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          '${surah.revelationArabic} • ${surah.numberOfAyahs} آية',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: isCurrent
                            ? Icon(
                                Icons.volume_up_rounded,
                                color: scheme.primary,
                              )
                            : null,
                        onTap: () {
                          Navigator.pop(ctx);
                          _goToSurah(surah.number, displayName);
                        },
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('إغلاق'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRecitersDialog() {
    final reciters = QuranApi.getReciters();
    final currentId = _reciter?.identifier;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(ctx)
                    .colorScheme
                    .onSurfaceVariant
                    .withOpacity(.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.mic_rounded,
                      color: Theme.of(ctx).colorScheme.primary),
                  const SizedBox(width: 10),
                  Text(
                    'اختر القارئ',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: reciters.length,
                itemBuilder: (_, i) {
                  final r = reciters[i];
                  final isSelected = r.identifier == currentId;
                  return ListTile(
                    leading: Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: isSelected
                          ? Theme.of(ctx).colorScheme.primary
                          : Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                    title: Text(
                      r.name,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(r.englishName),
                    onTap: () {
                      Navigator.pop(ctx);
                      _changeReciter(r);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeReciter(Reciter newReciter) async {
    setState(() {
      _reciter = newReciter;
      _isSwitching = true;
    });

    await StorageService.setPreferredReciter(newReciter.identifier);
    final ok = await AudioService.changeReciter(newReciter);

    if (!mounted) return;
    setState(() => _isSwitching = false);

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تغيير القارئ')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final displayName = _surahName.isNotEmpty ? _surahName : 'قيد التشغيل';
    final isBusy = _isLoading || _isSwitching;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'المشغل',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
          tooltip: 'إغلاق',
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.queue_music_rounded),
            tooltip: 'قائمة السور',
            onPressed: _showSurahsList,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            scheme.primary,
                            scheme.primary.withOpacity(.6),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.primary.withOpacity(.3),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.menu_book_rounded,
                          size: 100,
                          color: scheme.onPrimary,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    GestureDetector(
                      onTap: _showSurahsList,
                      child: Column(
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'سورة $displayName',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: scheme.onSurface,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.expand_more_rounded,
                                color: scheme.onSurfaceVariant,
                                size: 22,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'اضغط لاختيار سورة أخرى',
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    GestureDetector(
                      onTap: _showRecitersDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.mic_rounded,
                              size: 18,
                              color: scheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _reciter?.name ?? 'غير معروف',
                              style: TextStyle(
                                color: scheme.onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.expand_more_rounded,
                              size: 18,
                              color: scheme.onPrimaryContainer,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 6,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 8),
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 18),
                          ),
                          child: Slider(
                            value: _duration.inSeconds > 0
                                ? _position.inSeconds
                                    .clamp(0, _duration.inSeconds)
                                    .toDouble()
                                : 0,
                            max: _duration.inSeconds > 0
                                ? _duration.inSeconds.toDouble()
                                : 1,
                            onChanged: (isBusy || _duration.inSeconds <= 0)
                                ? null
                                : (v) => _seekTo(v),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                AudioService.formatDuration(_position),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                AudioService.formatDuration(_duration),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          iconSize: 32,
                          tooltip: 'السورة السابقة',
                          icon: const Icon(Icons.skip_previous_rounded),
                          onPressed: (isBusy || _surahNumber <= 1)
                              ? null
                              : _previousSurah,
                        ),
                        IconButton(
                          iconSize: 36,
                          tooltip: '10 ثواني للخلف',
                          icon: const Icon(Icons.replay_10_rounded),
                          onPressed: isBusy ? null : () => _skip(-10),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: scheme.primary.withOpacity(.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Material(
                            color: scheme.primary,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: isBusy ? null : _togglePlayPause,
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: isBusy
                                    ? SizedBox(
                                        width: 40,
                                        height: 40,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 3,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            scheme.onPrimary,
                                          ),
                                        ),
                                      )
                                    : Icon(
                                        _isPlaying
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        size: 40,
                                        color: scheme.onPrimary,
                                      ),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          iconSize: 36,
                          tooltip: '10 ثواني للأمام',
                          icon: const Icon(Icons.forward_10_rounded),
                          onPressed: isBusy ? null : () => _skip(10),
                        ),
                        IconButton(
                          iconSize: 32,
                          tooltip: 'السورة التالية',
                          icon: const Icon(Icons.skip_next_rounded),
                          onPressed: (isBusy || _surahNumber >= 114)
                              ? null
                              : _nextSurah,
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: scheme.surfaceVariant.withOpacity(.5),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SafeArea(
                top: false,
                child: OutlinedButton.icon(
                  onPressed: _showRecitersDialog,
                  icon: const Icon(Icons.person_rounded, size: 20),
                  label: const Text('تغيير القارئ'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}