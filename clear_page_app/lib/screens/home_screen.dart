import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'reader_screen.dart';
import 'settings_screen.dart';
import 'notes_screen.dart';
import 'stats_screen.dart';
import '../services/preferences_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PreferencesService _prefs = PreferencesService();
  List<String> _recentBooks = [];
  List<String> _archivedBooks = [];
  final Map<String, double> _bookProgress = {}; // path -> 0.0..1.0

  @override
  void initState() {
    super.initState();
    _loadAllBooks();
  }

  Future<void> _loadAllBooks() async {
    final recents = await _prefs.getRecentBooks();
    final archived = await _prefs.getArchivedBooks();
    final allPaths = {...recents, ...archived};
    final Map<String, double> progress = {};
    for (final path in allPaths) {
      final lastPage = await _prefs.getLastPage(path);
      final totalPages = await _prefs.getTotalPages(path);
      if (totalPages > 0) {
        progress[path] = (lastPage / totalPages).clamp(0.0, 1.0);
      }
    }
    setState(() {
      _recentBooks = _cleanPaths(recents);
      _archivedBooks = _cleanPaths(archived);
      _bookProgress.addAll(progress);
    });
  }

  List<String> _cleanPaths(List<String> paths) {
    Set<String> seen = {};
    List<String> valid = [];
    for (String p in paths) {
      if (File(p).existsSync()) {
        String normalized = p.toLowerCase();
        if (!seen.contains(normalized)) {
          seen.add(normalized);
          valid.add(p);
        }
      }
    }
    return valid;
  }

  Future<void> _openPdf(String filePath) async {
    await _prefs.addRecentBook(filePath);
    await _prefs.removeArchivedBook(filePath);
    _loadAllBooks();
    
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReaderScreen(pdfFile: File(filePath)),
      ),
    );
  }

  Future<void> _removeRecentBook(String path) async {
    await _prefs.removeRecentBook(path);
    _loadAllBooks();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Book deleted')));
    }
  }

  Future<void> _removeArchivedBook(String path) async {
    await _prefs.removeArchivedBook(path);
    _loadAllBooks();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Archived book deleted')));
    }
  }

  Future<void> _archiveBook(String path) async {
    await _prefs.archiveBook(path);
    _loadAllBooks();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Book archived')));
    }
  }

  Future<void> _unarchiveBook(String path) async {
    await _prefs.unarchiveBook(path);
    _loadAllBooks();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Book restored to recent library')));
    }
  }

  Future<void> _pickFile(BuildContext context) async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      _openPdf(result.files.single.path!);
    }
  }

  Widget _buildUploadArea(bool isDark) {
    return GestureDetector(
      onTap: () => _pickFile(context),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A3C) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.file_upload_outlined, 
              size: 48, 
              color: isDark ? Colors.white70 : Colors.blueGrey.shade400
            ),
            const SizedBox(height: 16),
            Text(
              'Upload Book',
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap to select a PDF file',
              style: TextStyle(
                fontSize: 14, 
                color: isDark ? Colors.white54 : Colors.grey.shade600
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBookTile({
    required File file,
    required bool isDark,
    required VoidCallback onTap,
    required VoidCallback onArchive,
    required VoidCallback onDelete,
    required bool isArchived,
  }) {
    String name = file.path.split(Platform.pathSeparator).last;
    String shortTitle = name.replaceAll('.pdf', '');

    return Dismissible(
      key: Key(file.path + (isArchived ? '_ar' : '_re')),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        decoration: BoxDecoration(color: isArchived ? Colors.blueAccent : Colors.green.shade500, borderRadius: BorderRadius.circular(12)),
        child: Icon(isArchived ? Icons.unarchive : Icons.archive, color: Colors.white, size: 28),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          // Show confirmation dialog for delete
          final bool? confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: isDark ? const Color(0xFF2A2A3C) : Colors.white,
              title: Text('Delete Book?', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              content: Text(
                'Remove "$shortTitle" from your library? This cannot be undone.',
                style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[700]),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                  child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
          if (confirmed == true) onDelete();
        } else if (direction == DismissDirection.startToEnd) {
          // Archive immediately — no confirmation needed
          onArchive();
        }
        return false; // We manage state manually
      },
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A3C) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8)
                ),
                child: Icon(
                  Icons.picture_as_pdf_outlined, 
                  color: isDark ? Colors.white70 : Colors.black54,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shortTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                        color: isDark ? Colors.white : Colors.black87
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Builder(builder: (_) {
                      final progress = _bookProgress[file.path];
                      if (progress == null || progress == 0) {
                        return Text(
                          isArchived ? 'Archived Document' : 'Not started yet',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.grey.shade600
                          ),
                        );
                      }
                      final pct = (progress * 100).toStringAsFixed(0);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                progress >= 1.0 ? '✓ Completed' : '$pct% read',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: progress >= 1.0
                                    ? Colors.green
                                    : (isDark ? Colors.white54 : Colors.grey.shade600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 4,
                              backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                progress >= 1.0 ? Colors.green : Colors.blueAccent,
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
              Icon(Icons.swipe_outlined, color: isDark ? Colors.white24 : Colors.grey.shade300, size: 20)
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookList(List<String> books, String title, bool isDark, bool isArchived) {
    if (books.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16, 
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
              letterSpacing: 0.5
            ),
          ),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: books.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final file = File(books[index]);
            return _buildBookTile(
              file: file,
              isDark: isDark,
              isArchived: isArchived,
              onTap: () => _openPdf(file.path),
              onArchive: () => isArchived ? _unarchiveBook(file.path) : _archiveBook(file.path),
              onDelete: () => isArchived ? _removeArchivedBook(file.path) : _removeRecentBook(file.path),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDrawer(bool isDark) {
    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A3C) : Colors.blueGrey.shade50,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: isDark ? Colors.white12 : Colors.blueGrey.withOpacity(0.2),
                  child: const Icon(Icons.person, size: 30, color: Colors.blueGrey),
                ),
                const SizedBox(height: 15),
                Text('Clear Page Reader', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('Home'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart_outlined),
            title: const Text('Reading Stats'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const StatsScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_note),
            title: const Text('My Notes'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const NotesScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
            },
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Clear Page', 
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: isDark ? Colors.white : Colors.black87
          )
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            tooltip: isDark ? 'Light Mode' : 'Dark Mode',
            onPressed: () {
              PreferencesService().setDarkMode(!isDark);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: _buildDrawer(isDark),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              _buildUploadArea(isDark),
              const SizedBox(height: 48),
              _buildBookList(_recentBooks, 'Recent', isDark, false),
              if (_recentBooks.isNotEmpty && _archivedBooks.isNotEmpty) const SizedBox(height: 48),
              _buildBookList(_archivedBooks, 'Archived Library', isDark, true),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
