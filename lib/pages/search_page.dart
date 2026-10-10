import 'package:flutter/material.dart';
import '../models/surah.dart';
import '../models/ayah.dart';
import '../services/quran_api.dart';
import '../services/storage_service.dart';
import 'reader_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  List<_AyahSearchResult> _results = [];
  bool _searching = false;
  bool _hasSearched = false;
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ============================================================
  // البحث في كل القرآن
  // ============================================================
  Future<void> _performSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
        _query = '';
      });
      return;
    }

    setState(() {
      _searching = true;
      _hasSearched = true;
      _query = q;
      _results = [];
    });

    // ✅ البحث في كل القرآن المحمّل
    final Map<int, List<Ayah>>? fullQuran =
        StorageService.getFullQuran();

    if (fullQuran == null || fullQuran.isEmpty) {
      if (!mounted) return;
      setState(() => _searching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('المصحف لم يُحمَّل بعد')),
      );
      return;
    }

    // أسماء السور
    final surahs = StorageService.getSurahsCache() ?? [];
    final surahNames = <int, String>{};
    for (final s in surahs) {
      surahNames[s.number] = s.name.replaceAll('سُورَةُ ', '');
    }

    final results = <_AyahSearchResult>[];

    fullQuran.forEach((surahNumber, ayahs) {
      if (results.length >= 300) return;

      for (final ayah in ayahs) {
        if (QuranApi.matchesSearch(ayah.text, q)) {
          results.add(_AyahSearchResult(
            surahNumber: surahNumber,
            surahName: surahNames[surahNumber] ?? 'سورة $surahNumber',
            ayahNumber: ayah.numberInSurah,
            ayahText: ayah.text,
          ));
          if (results.length >= 300) return;
        }
      }
    });

    // ترتيب: حسب رقم السورة ثم رقم الآية
    results.sort((a, b) {
      final c = a.surahNumber.compareTo(b.surahNumber);
      if (c != 0) return c;
      return a.ayahNumber.compareTo(b.ayahNumber);
    });

    if (!mounted) return;
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  void _openResult(_AyahSearchResult result) {
    // حفظ آخر قراءة عند الآية
    StorageService.saveLastRead(
      surahNumber: result.surahNumber,
      surahName: result.surahName,
      ayahNumber: result.ayahNumber,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReaderPage(
          surahNumber: result.surahNumber,
          surahName: result.surahName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'البحث في القرآن',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          // ============ شريط البحث ============
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: _performSearch,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'ابحث عن كلمة أو جزء من آية...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _controller.clear();
                          _performSearch('');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // ============ زر البحث ============
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _performSearch(_controller.text),
                icon: const Icon(Icons.search_rounded),
                label: const Text('بحث'),
              ),
            ),
          ),

          // ============ نصيحة ============
          if (!_hasSearched)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceVariant.withOpacity(.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: scheme.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'اكتب البحث بدون تشكيل. مثال: "الرحمن" يجد "الرَّحْمَٰنِ".\n'
                        'البحث يشمل القرآن كاملاً.',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ============ النتائج ============
          if (_searching)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_hasSearched && _results.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_rounded,
                          size: 64, color: scheme.onSurfaceVariant),
                      const SizedBox(height: 16),
                      Text(
                        'لا توجد نتائج',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'لم نجد "$_query" في القرآن',
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_results.isNotEmpty)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                itemCount: _results.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        '${_results.length} نتيجة',
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }
                  return _buildResultCard(_results[index - 1], scheme);
                },
              ),
            )
          else
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_rounded,
                        size: 72, color: scheme.primary.withOpacity(.5)),
                    const SizedBox(height: 16),
                    Text(
                      'اكتب للبحث في القرآن',
                      style: TextStyle(
                        fontSize: 15,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultCard(_AyahSearchResult r, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openResult(r),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${r.surahName} • ${r.ayahNumber}',
                        style: TextStyle(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_back_rounded,
                        size: 16, color: scheme.primary),
                  ],
                ),
                const SizedBox(height: 10),
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    r.ayahText,
                    style: const TextStyle(
                      fontSize: 17,
                      height: 1.8,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AyahSearchResult {
  final int surahNumber;
  final String surahName;
  final int ayahNumber;
  final String ayahText;

  _AyahSearchResult({
    required this.surahNumber,
    required this.surahName,
    required this.ayahNumber,
    required this.ayahText,
  });
}