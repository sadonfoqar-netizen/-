import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/storage_service.dart';
import 'reader_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key, this.onGoToQuran}) : super(key: key);

  final VoidCallback? onGoToQuran;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, dynamic>? _lastRead;

  // آية اليوم (ثابتة — يمكن تحويلها لديناميكية لاحقاً)
  static const String _dailyAyahText =
      '﴿ أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ ﴾';
  static const String _dailyAyahRef = 'الرعد • ٢٨';
  static const int _dailySurahNumber = 13;
  static const int _dailyAyahNumber = 28;

  @override
  void initState() {
    super.initState();
    _loadLastRead();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // إعادة تحميل آخر قراءة كلما رجع المستخدم للرئيسية
    _loadLastRead();
  }

  void _loadLastRead() {
    final data = StorageService.getLastRead();
    if (data != _lastRead) {
      setState(() => _lastRead = data);
    }
  }

  // ============================================================
  // مشاركة آية اليوم
  // ============================================================
  Future<void> _shareDailyAyah() async {
    final text = '$_dailyAyahText\n\n$_dailyAyahRef';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ الآية — الصقها في أي تطبيق')),
    );
  }

  // ============================================================
  // حفظ آية اليوم في المفضلة
  // ============================================================
  Future<void> _bookmarkDailyAyah() async {
    final isMarked = StorageService.isBookmarked(
      _dailySurahNumber,
      _dailyAyahNumber,
    );
    if (isMarked) {
      await StorageService.removeBookmark(
        _dailySurahNumber,
        _dailyAyahNumber,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إزالة الآية من المحفوظات')),
      );
    } else {
      await StorageService.addBookmark(
        surahNumber: _dailySurahNumber,
        surahName: 'الرعد',
        ayahNumber: _dailyAyahNumber,
        ayahText: _dailyAyahText,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الآية')),
      );
    }
    setState(() {});
  }

  // ============================================================
  // فتح سورة الرعد عند الآية 28
  // ============================================================
  void _openDailyAyah() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ReaderPage(
          surahNumber: _dailySurahNumber,
          surahName: 'الرعد',
        ),
      ),
    ).then((_) => _loadLastRead());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          children: <Widget>[
            // ============ الرأس ============
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const <Widget>[
                      Text('السلام عليكم', style: TextStyle(fontSize: 15)),
                      SizedBox(height: 4),
                      Text(
                        'رفيقك مع القرآن',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const CircleAvatar(
                  backgroundColor: Color(0xFFDCEFE6),
                  child:
                      Icon(Icons.person_outline_rounded, color: Color(0xFF16745B)),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ============ بطاقة "متابعة القراءة" ============
            _buildContinueCard(scheme),

            const SizedBox(height: 28),

            // ============ اختصارات سريعة ============
            const _SectionHeader(title: 'نـور'),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _QuickAction(
                    icon: Icons.menu_book_rounded,
                    title: 'نـور',
                    color: scheme.primaryContainer,
                    onTap: () {
                      if (widget.onGoToQuran != null) widget.onGoToQuran!();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.search_rounded,
                    title: 'نـور',
                    color: scheme.secondaryContainer,
                    onTap: () {
                      if (widget.onGoToQuran != null) widget.onGoToQuran!();
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ============ آية اليوم ============
            const _SectionHeader(title: 'نـور'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  GestureDetector(
                    onTap: _openDailyAyah,
                    child: Text(
                      _dailyAyahText,
                      style: TextStyle(
                        fontSize: 22,
                        height: 1.8,
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    _dailyAyahRef,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      // مشاركة
                      IconButton(
                        icon: const Icon(Icons.share_outlined, size: 22),
                        color: scheme.primary,
                        tooltip: 'مشاركة',
                        onPressed: _shareDailyAyah,
                      ),
                      // حفظ
                      IconButton(
                        icon: Icon(
                          StorageService.isBookmarked(
                                  _dailySurahNumber, _dailyAyahNumber)
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          size: 22,
                        ),
                        color: scheme.primary,
                        tooltip: 'حفظ',
                        onPressed: _bookmarkDailyAyah,
                      ),
                      const Spacer(),
                      // المزيد
                      TextButton.icon(
                        onPressed: _openDailyAyah,
                        icon: const Icon(Icons.arrow_back_rounded, size: 16),
                        label: const Text('فتح السورة'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // بطاقة "متابعة القراءة"
  // ============================================================
  Widget _buildContinueCard(ColorScheme scheme) {
    if (_lastRead == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.auto_awesome_rounded,
                    color: scheme.onPrimaryContainer),
                const SizedBox(width: 8),
                Text(
                  'ابدأ رحلتك',
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'لم تبدأ القراءة بعد',
              style: TextStyle(
                color: scheme.onPrimaryContainer,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'افتح المصحف وابدأ من سورة الفاتحة',
              style: TextStyle(
                color: scheme.onPrimaryContainer.withOpacity(.75),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ReaderPage(
                      surahNumber: 1,
                      surahName: 'الفاتحة',
                    ),
                  ),
                ).then((_) => _loadLastRead());
              },
              child: const Text('ابدأ القراءة'),
            ),
          ],
        ),
      );
    }

    final surahNumber = _lastRead!['surahNumber'] as int? ?? 1;
    final surahName = _lastRead!['surahName'] as String? ?? 'الفاتحة';
    final ayahNumber = _lastRead!['ayahNumber'] as int? ?? 1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.auto_awesome_rounded, color: scheme.onPrimary),
              const SizedBox(width: 8),
              Text(
                'مواصلة الورد',
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'سورة $surahName',
            style: TextStyle(
              color: scheme.onPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'الآية $ayahNumber',
            style: TextStyle(
              color: scheme.onPrimary.withOpacity(.75),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ReaderPage(
                    surahNumber: surahNumber,
                    surahName: surahName,
                  ),
                ),
              ).then((_) => _loadLastRead());
            },
            child: const Text('متابعة القراءة'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// عناصر مساعدة
// ============================================================
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.title,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}