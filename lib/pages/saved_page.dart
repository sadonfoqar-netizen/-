import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/storage_service.dart';
import 'reader_page.dart';

class SavedPage extends StatefulWidget {
  const SavedPage({Key? key}) : super(key: key);

  @override
  State<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage> {
  List<Map<String, dynamic>> _bookmarks = [];

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadBookmarks();
  }

  void _loadBookmarks() {
    final data = StorageService.getBookmarks();
    if (data.length != _bookmarks.length || !_sameContent(data, _bookmarks)) {
      setState(() => _bookmarks = data);
    }
  }

  bool _sameContent(
      List<Map<String, dynamic>> a, List<Map<String, dynamic>> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i]['surahNumber'] != b[i]['surahNumber']) return false;
      if (a[i]['ayahNumber'] != b[i]['ayahNumber']) return false;
      if (a[i]['note'] != b[i]['note']) return false;
    }
    return true;
  }

  Future<void> _removeBookmark(int surahNumber, int ayahNumber) async {
    await StorageService.removeBookmark(surahNumber, ayahNumber);
    _loadBookmarks();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إزالة الآية')),
    );
  }

  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف جميع المحفوظات'),
        content: const Text('هل أنت متأكد من حذف جميع الآيات المحفوظة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف الكل'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await StorageService.clearBookmarks();
      _loadBookmarks();
    }
  }

  Future<void> _copyAyah(Map<String, dynamic> bookmark) async {
    final text =
        '${bookmark['ayahText']}\n\n${bookmark['surahName']} • ${bookmark['ayahNumber']}';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ الآية')),
    );
  }

  Future<void> _openInReader(Map<String, dynamic> bookmark) async {
    final surahNumber = bookmark['surahNumber'] as int? ?? 1;
    final surahName = bookmark['surahName'] as String? ?? '';
    final ayahNumber = bookmark['ayahNumber'] as int? ?? 1;

    await StorageService.saveLastRead(
      surahNumber: surahNumber,
      surahName: surahName,
      ayahNumber: ayahNumber,
    );

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReaderPage(
          surahNumber: surahNumber,
          surahName: surahName,
        ),
      ),
    );
    _loadBookmarks();
  }

  Future<void> _editNote(Map<String, dynamic> bookmark) async {
    final controller =
        TextEditingController(text: bookmark['note'] as String? ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ملاحظة على الآية'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'اكتب ملاحظتك هنا...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (result != null) {
      await StorageService.updateBookmarkNote(
        bookmark['surahNumber'] as int,
        bookmark['ayahNumber'] as int,
        result,
      );
      _loadBookmarks();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'المحفوظات',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (_bookmarks.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: 'حذف الكل',
              onPressed: _confirmClearAll,
            ),
        ],
      ),
      body: _bookmarks.isEmpty ? _buildEmpty(scheme) : _buildList(scheme),
    );
  }

  Widget _buildEmpty(ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_outline_rounded,
                size: 72, color: scheme.primary),
            const SizedBox(height: 16),
            const Text(
              'ستظهر آياتك المحفوظة هنا',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'احفظ آية أثناء القراءة بالضغط على أيقونة الحفظ',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(ColorScheme scheme) {
    return RefreshIndicator(
      onRefresh: () async => _loadBookmarks(),
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _bookmarks.length,
        itemBuilder: (context, index) {
          final b = _bookmarks[index];
          final surahNumber = b['surahNumber'] as int? ?? 1;
          final surahName = b['surahName'] as String? ?? '';
          final ayahNumber = b['ayahNumber'] as int? ?? 1;
          final ayahText = b['ayahText'] as String? ?? '';
          final note = b['note'] as String? ?? '';

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(20),
              ),
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
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$surahName • $ayahNumber',
                          style: TextStyle(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Spacer(),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert_rounded,
                            size: 20, color: scheme.onSurfaceVariant),
                        onSelected: (value) {
                          switch (value) {
                            case 'note':
                              _editNote(b);
                              break;
                            case 'copy':
                              _copyAyah(b);
                              break;
                            case 'delete':
                              _removeBookmark(surahNumber, ayahNumber);
                              break;
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'note',
                            child: ListTile(
                              leading: Icon(Icons.edit_note_rounded),
                              title: Text('إضافة ملاحظة'),
                              dense: true,
                            ),
                          ),
                          PopupMenuItem(
                            value: 'copy',
                            child: ListTile(
                              leading: Icon(Icons.copy_rounded),
                              title: Text('نسخ'),
                              dense: true,
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                              leading: Icon(Icons.delete_outline_rounded),
                              title: Text('حذف'),
                              dense: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Text(
                    ayahText,
                    style: const TextStyle(
                      fontSize: 18,
                      height: 1.9,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),

                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: scheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.sticky_note_2_outlined,
                              size: 16, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              note,
                              style: TextStyle(
                                fontSize: 13,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _openInReader(b),
                      icon: const Icon(Icons.menu_book_rounded, size: 18),
                      label: const Text('فتح السورة'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}