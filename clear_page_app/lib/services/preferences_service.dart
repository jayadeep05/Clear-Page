import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String keyApiUrl = 'backend_api_url';
  static const String keyRecentBooks = 'recent_books_paths';
  static const String keyArchivedBooks = 'archived_books_paths';
  static const String keyDarkMode = 'dark_mode';
  static const String prefixNote = 'note_';
  static const String prefixPage = 'page_';
  static const String prefixTotalPages = 'total_pages_';
  static const String prefixBookmarks = 'bookmarks_';
  static const String prefixStats = 'stats_pages_';
  static const String keyReadingDays = 'reading_days';

  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

  Future<void> initTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(keyDarkMode);
    if (isDark != null) {
      themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
    }
  }

  Future<void> setDarkMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyDarkMode, isDark);
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<bool?> getDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyDarkMode);
  }

  Future<String> getApiUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyApiUrl) ?? 'https://deepcodev.com/api/ai';
  }

  Future<void> setApiUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyApiUrl, url.trim().replaceAll(RegExp(r'/$'), ''));
  }

  Future<List<String>> getRecentBooks() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(keyRecentBooks) ?? [];
  }

  Future<void> addRecentBook(String path) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> books = prefs.getStringList(keyRecentBooks) ?? [];
    if (books.contains(path)) {
      books.remove(path);
    }
    books.insert(0, path);
    if (books.length > 5) {
      books = books.sublist(0, 5);
    }
    await prefs.setStringList(keyRecentBooks, books);
  }

  Future<void> removeRecentBook(String path) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> books = prefs.getStringList(keyRecentBooks) ?? [];
    books.remove(path);
    await prefs.setStringList(keyRecentBooks, books);
  }

  Future<List<String>> getArchivedBooks() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(keyArchivedBooks) ?? [];
  }

  Future<void> archiveBook(String path) async {
    final prefs = await SharedPreferences.getInstance();

    List<String> recents = prefs.getStringList(keyRecentBooks) ?? [];
    recents.remove(path);
    await prefs.setStringList(keyRecentBooks, recents);

    List<String> archived = prefs.getStringList(keyArchivedBooks) ?? [];
    if (!archived.contains(path)) {
      archived.insert(0, path);
      await prefs.setStringList(keyArchivedBooks, archived);
    }
  }

  Future<void> removeArchivedBook(String path) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> archived = prefs.getStringList(keyArchivedBooks) ?? [];
    archived.remove(path);
    await prefs.setStringList(keyArchivedBooks, archived);
  }

  Future<void> unarchiveBook(String path) async {
    await removeArchivedBook(path);
    await addRecentBook(path);
  }

  Future<void> saveNoteForBook(String path, String note) async {
    final prefs = await SharedPreferences.getInstance();
    if (note.trim().isEmpty) {
      await prefs.remove('$prefixNote$path');
    } else {
      await prefs.setString('$prefixNote$path', note.trim());
    }
  }

  Future<String> getNoteForBook(String path) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$prefixNote$path') ?? '';
  }

  Future<Map<String, String>> getAllNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    Map<String, String> notes = {};
    for (String key in keys) {
      if (key.startsWith(prefixNote)) {
        String path = key.replaceFirst(prefixNote, '');
        String? note = prefs.getString(key);
        if (note != null && note.isNotEmpty) {
          notes[path] = note;
        }
      }
    }
    return notes;
  }

  Future<void> saveLastPage(String path, int page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$prefixPage$path', page);
  }

  Future<int> getLastPage(String path) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$prefixPage$path') ?? 1;
  }

  Future<void> saveTotalPages(String path, int total) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$prefixTotalPages$path', total);
  }

  Future<int> getTotalPages(String path) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$prefixTotalPages$path') ?? 0;
  }

  // ─── BOOKMARKS ───────────────────────────────────────────────
  Future<List<int>> getBookmarks(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('$prefixBookmarks$path') ?? [];
    return raw.map((e) => int.tryParse(e) ?? 0).toList();
  }

  Future<void> toggleBookmark(String path, int page) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$prefixBookmarks$path';
    List<String> raw = prefs.getStringList(key) ?? [];
    final pageStr = page.toString();
    if (raw.contains(pageStr)) {
      raw.remove(pageStr);
    } else {
      raw.add(pageStr);
    }
    await prefs.setStringList(key, raw);
  }

  Future<bool> isBookmarked(String path, int page) async {
    final bookmarks = await getBookmarks(path);
    return bookmarks.contains(page);
  }

  // ─── READING STATS ───────────────────────────────────────────
  String _todayKey() {
    final now = DateTime.now();
    return '${prefixStats}${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
  }

  String _dateKey(DateTime d) {
    return '${prefixStats}${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  }

  Future<void> recordPageRead() async {
    final prefs = await SharedPreferences.getInstance();
    // Increment today's page count
    final todayKey = _todayKey();
    final current = prefs.getInt(todayKey) ?? 0;
    await prefs.setInt(todayKey, current + 1);
    // Record reading day for streak tracking
    final today = _dateKey(DateTime.now());
    List<String> days = prefs.getStringList(keyReadingDays) ?? [];
    if (!days.contains(today)) {
      days.add(today);
      await prefs.setStringList(keyReadingDays, days);
    }
  }

  Future<int> getWeeklyPagesRead() async {
    final prefs = await SharedPreferences.getInstance();
    int total = 0;
    for (int i = 0; i < 7; i++) {
      final day = DateTime.now().subtract(Duration(days: i));
      total += prefs.getInt(_dateKey(day)) ?? 0;
    }
    return total;
  }

  Future<int> getReadingStreak() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> days = prefs.getStringList(keyReadingDays) ?? [];
    if (days.isEmpty) return 0;
    // Sort descending
    days.sort((a, b) => b.compareTo(a));
    int streak = 0;
    DateTime check = DateTime.now();
    for (int i = 0; i <= 365; i++) {
      final key = _dateKey(check);
      if (days.contains(key)) {
        streak++;
        check = check.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  Future<int> getTotalPagesReadAllTime() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(prefixStats));
    int total = 0;
    for (final k in keys) total += prefs.getInt(k) ?? 0;
    return total;
  }

  Future<Map<String, int>> getLast7DaysStats() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, int> result = {};
    for (int i = 6; i >= 0; i--) {
      final day = DateTime.now().subtract(Duration(days: i));
      final key = _dateKey(day);
      final label = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'][day.weekday % 7];
      result[label] = prefs.getInt(key) ?? 0;
    }
    return result;
  }
}
