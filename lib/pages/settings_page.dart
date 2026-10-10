import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/quran_api.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    Key? key,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.quranFontSize,
    required this.onQuranFontSizeChanged,
  }) : super(key: key);

  final bool isDarkMode;
  final VoidCallback onThemeChanged;
  final double quranFontSize;
  final ValueChanged<double> onQuranFontSizeChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _reciterName = '';
  String _reciterId = '';

  @override
  void initState() {
    super.initState();
    _loadReciter();
  }

  void _loadReciter() {
    final reciters = QuranApi.getReciters();
    final id = StorageService.getPreferredReciter();
    final r = reciters.firstWhere((x) => x.identifier == id,
        orElse: () => reciters.first);
    setState(() {
      _reciterId = r.identifier;
      _reciterName = r.name;
    });
  }

  void _showReciterDialog() {
    final reciters = QuranApi.getReciters();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('اختر القارئ المفضل'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: reciters.length,
            itemBuilder: (_, i) {
              final r = reciters[i];
              final isSelected = r.identifier == _reciterId;
              return ListTile(
                leading: Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                ),
                title: Text(r.name),
                subtitle: Text(r.englishName),
                onTap: () async {
                  await StorageService.setPreferredReciter(r.identifier);
                  _loadReciter();
                  if (!mounted) return;
                  Navigator.pop(ctx);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _showFontSizeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حجم خط المصحف'),
        content: StatefulBuilder(
          builder: (context, setInnerState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${widget.quranFontSize.toInt()}'),
                Slider(
                  value: widget.quranFontSize,
                  min: 18,
                  max: 44,
                  divisions: 13,
                  label: '${widget.quranFontSize.toInt()}',
                  onChanged: (value) {
                    setInnerState(() {});
                    widget.onQuranFontSizeChanged(value);
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مسح البيانات المؤقتة'),
        content: const Text(
            'سيتم مسح السور المحمّلة مؤقتاً. ستحتاج للاتصال بالإنترنت عند فتح السور مجدداً.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('مسح'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await StorageService.clearAllCache();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم مسح البيانات المؤقتة')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'الإعدادات',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          const Text('التفضيلات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: <Widget>[
                SwitchListTile(
                  value: widget.isDarkMode,
                  onChanged: (_) => widget.onThemeChanged(),
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: const Text('الوضع الداكن'),
                  subtitle: const Text('راحة أكبر للعين أثناء الليل'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.text_fields_rounded),
                  title: const Text('حجم خط المصحف'),
                  subtitle: Text('${widget.quranFontSize.toInt()} نقطة'),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: _showFontSizeDialog,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.mic_rounded),
                  title: const Text('القارئ المفضل'),
                  subtitle: Text(_reciterName),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: _showReciterDialog,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('البيانات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.cleaning_services_rounded),
                  title: const Text('مسح البيانات المؤقتة'),
                  subtitle: const Text('السور المحمّلة ستُعاد تحميلها من الإنترنت'),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: _clearCache,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('حول',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: <Widget>[
                const ListTile(
                  leading: Icon(Icons.info_outline_rounded),
                  title: Text('رفيق القرآن'),
                  subtitle: Text('الإصدار 1.0.0'),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.source_rounded),
                  title: Text('مصدر البيانات'),
                  subtitle: Text('alquran.cloud'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}