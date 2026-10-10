import 'package:flutter/material.dart';
import '../models/surah.dart';
import '../services/quran_api.dart';
import '../services/storage_service.dart';
import 'reader_page.dart';

class QuranPage extends StatefulWidget {
  const QuranPage({Key? key, required this.quranFontSize}) : super(key: key);

  final double quranFontSize;

  @override
  State<QuranPage> createState() => _QuranPageState();
}

class _QuranPageState extends State<QuranPage> {
  List<Surah> _allSurahs = [];
  List<Surah> _filteredSurahs = [];
  bool _loading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSurahs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSurahs() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final cached = StorageService.getSurahsCache();
    if (cached != null && cached.isNotEmpty) {
      setState(() {
        _allSurahs = cached;
        _filteredSurahs = cached;
        _loading = false;
      });
      return;
    }

    try {
      final surahs = await QuranApi.fetchSurahs();
      await StorageService.saveSurahsCache(surahs);
      if (!mounted) return;
      setState(() {
        _allSurahs = surahs;
        _filteredSurahs = surahs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل السور. تأكد من الاتصال بالإنترنت.\n$e';
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _filteredSurahs = QuranApi.searchSurahs(_allSurahs, query);
    });
  }

  void _openSurah(Surah surah) {
    final displayName = surah.name.replaceAll('سُورَةُ ', '');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReaderPage(
          surahNumber: surah.number,
          surahName: displayName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'المصحف',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _loadSurahs,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
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
              Icon(Icons.error_outline_rounded,
                  size: 64, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loadSurahs,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 30),
      children: <Widget>[
        TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          decoration: const InputDecoration(
            hintText: 'ابحث عن سورة',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: <Widget>[
            const Text(
              'السور',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            Text(
              '${_filteredSurahs.length} من ${_allSurahs.length}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._filteredSurahs.map((surah) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _openSurah(surah),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          child: Text(
                            '${surah.number}',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                surah.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${surah.revelationArabic} • ${surah.numberOfAyahs} آية',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_left_rounded),
                      ],
                    ),
                  ),
                ),
              ),
            )),
      ],
    );
  }
}