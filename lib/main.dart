import 'package:flutter/material.dart';
import 'theme.dart';
import 'pages/home_page.dart';
import 'pages/quran_page.dart';
import 'pages/saved_page.dart';
import 'pages/settings_page.dart';
import 'services/storage_service.dart';
import 'services/quran_api.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  runApp(const QuranApp());
}

class QuranApp extends StatefulWidget {
  const QuranApp({Key? key}) : super(key: key);

  @override
  State<QuranApp> createState() => QuranAppState();
}

class QuranAppState extends State<QuranApp> {
  ThemeMode themeMode = ThemeMode.light;
  double quranFontSize = 26.0;

  @override
  void initState() {
    super.initState();
    themeMode = StorageService.getThemeMode();
    quranFontSize = StorageService.getQuranFontSize();
  }

  void toggleTheme() {
    setState(() {
      themeMode =
          themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
    StorageService.setThemeMode(themeMode);
  }

  void setQuranFontSize(double size) {
    setState(() => quranFontSize = size);
    StorageService.setQuranFontSize(size);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'نـور',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: const SplashDownloadPage(),
    );
  }
}

// ============================================================
// شاشة التحميل الأولى
// ============================================================
class SplashDownloadPage extends StatefulWidget {
  const SplashDownloadPage({Key? key}) : super(key: key);

  @override
  State<SplashDownloadPage> createState() => _SplashDownloadPageState();
}

class _SplashDownloadPageState extends State<SplashDownloadPage> {
  bool _checking = true;
  bool _downloading = false;
  bool _error = false;
  int _current = 0;
  int _total = 114;
  String _surahName = '';

  @override
  void initState() {
    super.initState();
    _checkAndDownload();
  }

  Future<void> _checkAndDownload() async {
    setState(() {
      _checking = true;
      _error = false;
    });

    if (StorageService.isFullQuranReady()) {
      if (!mounted) return;
      _goToApp();
      return;
    }

    if (!mounted) return;
    setState(() {
      _checking = false;
      _downloading = true;
    });

    await _downloadQuran();
  }

  Future<void> _downloadQuran() async {
    try {
      final fullQuran = await QuranApi.fetchFullQuran(
        onProgress: (current, total, surahName) {
          if (!mounted) return;
          setState(() {
            _current = current;
            _total = total;
            _surahName = surahName.replaceAll('سُورَةُ ', '');
          });
        },
      );

      // احفظ السور أيضاً
      try {
        final surahs = await QuranApi.fetchSurahs();
        await StorageService.saveSurahsCache(surahs);
      } catch (_) {}

      await StorageService.saveFullQuran(fullQuran);

      if (!mounted) return;
      _goToApp();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = true;
      });
    }
  }

  void _goToApp() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainShellPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // أيقونة التطبيق
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [scheme.primary, scheme.primary.withOpacity(.6)],
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
                  child: Icon(
                    Icons.menu_book_rounded,
                    size: 64,
                    color: scheme.onPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'رفيق القرآن',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'رفيقك اليومي مع كتاب الله',
                  style: TextStyle(
                    fontSize: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 48),

                if (_checking) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('جارٍ التحقق من البيانات...'),
                ] else if (_downloading) ...[
                  Text(
                    'جارٍ تحضير المصحف',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _surahName.isNotEmpty
                        ? 'سورة $_surahName'
                        : 'جارٍ التحميل...',
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: LinearProgressIndicator(
                      value: _total > 0 ? _current / _total : 0,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$_current من $_total سورة (${_total > 0 ? ((_current / _total) * 100).toStringAsFixed(0) : 0}%)',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: scheme.surfaceVariant.withOpacity(.5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 20, color: scheme.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'يتم التحميل مرة واحدة فقط. بعد ذلك يعمل التطبيق بلا إنترنت.',
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
                ] else if (_error) ...[
                  Icon(Icons.error_outline_rounded,
                      size: 64, color: scheme.error),
                  const SizedBox(height: 16),
                  Text(
                    'تعذر تحميل المصحف',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'تأكد من اتصالك بالإنترنت ثم أعد المحاولة.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _checkAndDownload,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('إعادة المحاولة'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// الواجهة الرئيسية
// ============================================================
class MainShellPage extends StatefulWidget {
  const MainShellPage({Key? key}) : super(key: key);

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  int _index = 0;
  ThemeMode _themeMode = ThemeMode.light;
  double _quranFontSize = 26.0;

  @override
  void initState() {
    super.initState();
    _themeMode = StorageService.getThemeMode();
    _quranFontSize = StorageService.getQuranFontSize();
  }

  void _toggleTheme() {
    final appState = context.findAncestorStateOfType<QuranAppState>();
    if (appState != null) {
      appState.toggleTheme();
      setState(() {
        _themeMode = appState.themeMode;
      });
    }
  }

  void _setQuranFontSize(double size) {
    final appState = context.findAncestorStateOfType<QuranAppState>();
    if (appState != null) {
      appState.setQuranFontSize(size);
    }
    setState(() => _quranFontSize = size);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            HomePage(onGoToQuran: () => setState(() => _index = 1)),
            QuranPage(quranFontSize: _quranFontSize),
            const SavedPage(),
            SettingsPage(
              isDarkMode: _themeMode == ThemeMode.dark,
              onThemeChanged: _toggleTheme,
              quranFontSize: _quranFontSize,
              onQuranFontSizeChanged: _setQuranFontSize,
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (value) => setState(() => _index = value),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'الرئيسية',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book_rounded),
              label: 'المصحف',
            ),
            NavigationDestination(
              icon: Icon(Icons.bookmark_outline_rounded),
              selectedIcon: Icon(Icons.bookmark_rounded),
              label: 'المحفوظات',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'الإعدادات',
            ),
          ],
        ),
      ),
    );
  }
}