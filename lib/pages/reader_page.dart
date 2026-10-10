import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/ayah.dart';
import '../models/reciter.dart';
import '../services/quran_api.dart';
import '../services/storage_service.dart';
import '../services/audio_service.dart';
import 'player_page.dart';

class ReaderPage extends StatefulWidget {
  const ReaderPage({
    Key? key,
    required this.surahNumber,
    required this.surahName,
  }) : super(key: key);

  final int surahNumber;
  final String surahName;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  List<Ayah> _ayahs = [];
  bool _loading = true;
  String? _error;
  double _fontSize = 26.0;
  Reciter? _selectedReciter;

  final ScrollController _scrollController = ScrollController();
  int _lastSavedAyah = 1;
  Timer? _saveDebouncer;

  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _playingSub;
  StreamSubscription? _stateSub;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isLoadingAudio = false;

  @override
  void initState() {
    super.initState();
    _fontSize = StorageService.getQuranFontSize();

    final reciters = QuranApi.getReciters();
    final prefId = StorageService.getPreferredReciter();
    _selectedReciter = reciters.firstWhere(
      (r) => r.identifier == prefId,
      orElse: () => reciters.first,
    );

    _scrollController.addListener(_onScroll);
    _setupAudioListeners();
    _loadAyahs();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    _stateSub?.cancel();
    _saveDebouncer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAyahs() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final cached = StorageService.getAyahsCache(widget.surahNumber);
    if (cached != null && cached.isNotEmpty) {
      setState(() {
        _ayahs = cached;
        _loading = false;
      });
      _restoreScroll();
      return;
    }

    try {
      final ayahs = await QuranApi.fetchAyahs(widget.surahNumber);
      await StorageService.saveAyahsCache(widget.surahNumber, ayahs);
      if (!mounted) return;
      setState(() {
        _ayahs = ayahs;
        _loading = false;
      });
      _restoreScroll();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل السورة. تأكد من الاتصال بالإنترنت.\n$e';
        _loading = false;
      });
    }
  }

  void _restoreScroll() {
    final savedOffset = StorageService.getScrollPosition(widget.surahNumber);
    if (savedOffset > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(
            savedOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
          );
        }
      });
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    _saveDebouncer?.cancel();
    _saveDebouncer = Timer(const Duration(milliseconds: 500), () {
      _saveScrollAndAyah();
    });
  }

  void _saveScrollAndAyah() {
    if (!_scrollController.hasClients) return;

    StorageService.saveScrollPosition(
      widget.surahNumber,
      _scrollController.offset,
    );

    if (_ayahs.isNotEmpty) {
      final totalScroll = _scrollController.position.maxScrollExtent;
      if (totalScroll <= 0) return;
      final progress = _scrollController.offset / totalScroll;
      final estimatedAyah =
          (progress * (_ayahs.length - 1)).round().clamp(0, _ayahs.length - 1);
      final ayahNumber = _ayahs[estimatedAyah].numberInSurah;

      if (ayahNumber != _lastSavedAyah) {
        _lastSavedAyah = ayahNumber;
        StorageService.updateLastReadAyah(
          surahNumber: widget.surahNumber,
          surahName: widget.surahName,
          ayahNumber: ayahNumber,
        );
      }
    }
  }

  void _setupAudioListeners() {
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
          _isLoadingAudio = state == ProcessingState.loading ||
              state == ProcessingState.buffering;
        });
      }
    });
  }

  Future<void> _togglePlayPause() async {
    if (_selectedReciter == null) return;

    if (AudioService.currentSurahNumber != widget.surahNumber ||
        AudioService.currentReciter?.identifier !=
            _selectedReciter!.identifier) {
      setState(() => _isLoadingAudio = true);
      final success = await AudioService.playSurah(
        _selectedReciter!,
        widget.surahNumber,
        surahName: widget.surahName,
      );
      if (!success && mounted) {
        setState(() => _isLoadingAudio = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تحميل التلاوة')),
        );
      }
      return;
    }

    if (_isPlaying) {
      await AudioService.pause();
    } else {
      await AudioService.resume();
    }
  }

  Future<void> _skip(int seconds) async {
    final target = _position.inSeconds + seconds;
    final max = _duration.inSeconds;
    final newPos = target < 0 ? 0 : (target > max ? max : target);
    await AudioService.seek(Duration(seconds: newPos));
  }

  void _openFullPlayer() {
    if (!AudioService.hasAudio) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('شغّل التلاوة أولاً من الزر الأسفل'),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PlayerPage()),
    );
  }

  Future<void> _toggleBookmark(Ayah ayah) async {
    final isMarked =
        StorageService.isBookmarked(widget.surahNumber, ayah.numberInSurah);
    if (isMarked) {
      await StorageService.removeBookmark(widget.surahNumber, ayah.numberInSurah);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إزالة الآية من المحفوظات')),
      );
    } else {
      await StorageService.addBookmark(
        surahNumber: widget.surahNumber,
        surahName: widget.surahName,
        ayahNumber: ayah.numberInSurah,
        ayahText: ayah.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الآية في المحفوظات')),
      );
    }
    setState(() {});
  }

  void _changeFontSize(double newSize) {
    setState(() => _fontSize = newSize);
    StorageService.setQuranFontSize(newSize);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.surahName,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          PopupMenuButton<double>(
            icon: const Icon(Icons.text_fields_rounded),
            tooltip: 'حجم الخط',
            onSelected: _changeFontSize,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 20, child: Text('صغير')),
              PopupMenuItem(value: 26, child: Text('متوسط')),
              PopupMenuItem(value: 32, child: Text('كبير')),
              PopupMenuItem(value: 40, child: Text('كبير جداً')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody(scheme)),
          _buildMiniPlayer(scheme),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme scheme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 64, color: scheme.error),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loadAyahs,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    if (_ayahs.isEmpty) {
      return const Center(child: Text('لا توجد آيات'));
    }

    return Scrollbar(
      controller: _scrollController,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
        children: [
          _buildHeader(scheme),
          const SizedBox(height: 18),
          if (widget.surahNumber != 9) _buildBismillah(scheme),
          _buildAyahsCard(scheme),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withOpacity(.55),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Text(
            'سُورَةُ ${widget.surahName}',
            style: TextStyle(
              color: scheme.primary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_ayahs.length} آية',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildBismillah(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: _fontSize - 4,
          height: 2,
          color: scheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildAyahsCard(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _ayahs.map((ayah) {
          final isMarked = StorageService.isBookmarked(
            widget.surahNumber,
            ayah.numberInSurah,
          );
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: RichText(
                    textAlign: TextAlign.justify,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: _fontSize,
                        height: 2.2,
                        color: scheme.onSurface,
                      ),
                      children: [
                        TextSpan(text: ayah.text),
                        TextSpan(
                          text: ' (${_toArabicDigits(ayah.numberInSurah)}) ',
                          style: TextStyle(
                            fontSize: _fontSize - 4,
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      iconSize: 20,
                      icon: Icon(
                        isMarked
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        color: isMarked ? scheme.primary : scheme.onSurfaceVariant,
                      ),
                      onPressed: () => _toggleBookmark(ayah),
                    ),
                  ],
                ),
                const Divider(height: 1),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMiniPlayer(ColorScheme scheme) {
    final isThisSurah = AudioService.currentSurahNumber == widget.surahNumber;
    final reciterName = isThisSurah
        ? (AudioService.currentReciter?.name ?? '')
        : (_selectedReciter?.name ?? '');

    final progress = (isThisSurah && _duration.inSeconds > 0)
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Material(
      color: scheme.surfaceVariant,
      child: InkWell(
        onTap: _openFullPlayer,
        child: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isThisSurah && _duration.inSeconds > 0)
                LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 2,
                  backgroundColor: scheme.surfaceVariant,
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _isLoadingAudio ? null : _togglePlayPause,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: _isLoadingAudio
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        scheme.onPrimary,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    _isPlaying && isThisSurah
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    size: 24,
                                    color: scheme.onPrimary,
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'سورة ${widget.surahName}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: scheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.mic_rounded,
                                  size: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    reciterName,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isThisSurah && _duration.inSeconds > 0) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '${AudioService.formatDuration(_position)} / ${AudioService.formatDuration(_duration)}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: scheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (isThisSurah)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              iconSize: 20,
                              tooltip: '10 ثواني للخلف',
                              icon: const Icon(Icons.replay_10_rounded),
                              onPressed:
                                  _isLoadingAudio ? null : () => _skip(-10),
                            ),
                            IconButton(
                              iconSize: 20,
                              tooltip: '10 ثواني للأمام',
                              icon: const Icon(Icons.forward_10_rounded),
                              onPressed:
                                  _isLoadingAudio ? null : () => _skip(10),
                            ),
                          ],
                        ),
                      Icon(
                        Icons.keyboard_arrow_up_rounded,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _toArabicDigits(int number) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return number
        .toString()
        .split('')
        .map((d) => arabicDigits[int.parse(d)])
        .join();
  }
}