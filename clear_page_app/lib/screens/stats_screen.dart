import 'dart:io';
import 'package:flutter/material.dart';
import '../services/preferences_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({Key? key}) : super(key: key);
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final PreferencesService _prefs = PreferencesService();

  int _streak = 0;
  int _weeklyPages = 0;
  int _totalPagesAllTime = 0;
  int _booksCompleted = 0;
  Map<String, int> _dailyStats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final streak = await _prefs.getReadingStreak();
    final weekly = await _prefs.getWeeklyPagesRead();
    final allTime = await _prefs.getTotalPagesReadAllTime();
    final daily = await _prefs.getLast7DaysStats();
    final recents = await _prefs.getRecentBooks();
    final archived = await _prefs.getArchivedBooks();
    
    int completed = 0;
    for (final path in [...recents, ...archived]) {
      if (!File(path).existsSync()) continue;
      final last = await _prefs.getLastPage(path);
      final total = await _prefs.getTotalPages(path);
      if (total > 0 && last >= total) completed++;
    }

    if (mounted) {
      setState(() {
        _streak = streak;
        _weeklyPages = weekly;
        _totalPagesAllTime = allTime;
        _dailyStats = daily;
        _booksCompleted = completed;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxBar = _dailyStats.values.isEmpty ? 1 : (_dailyStats.values.reduce((a, b) => a > b ? a : b)).clamp(1, 999);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Reading Stats', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero Stats Row
                    Row(
                      children: [
                        _buildStatCard(
                          icon: Icons.local_fire_department,
                          iconColor: Colors.orange,
                          value: '$_streak',
                          label: 'Day Streak',
                          isDark: isDark,
                          flex: 1,
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          icon: Icons.menu_book,
                          iconColor: Colors.blueAccent,
                          value: '$_weeklyPages',
                          label: 'Pages This Week',
                          isDark: isDark,
                          flex: 1,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildStatCard(
                          icon: Icons.check_circle_outline,
                          iconColor: Colors.green,
                          value: '$_booksCompleted',
                          label: 'Books Completed',
                          isDark: isDark,
                          flex: 1,
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          icon: Icons.auto_stories,
                          iconColor: Colors.purpleAccent,
                          value: '$_totalPagesAllTime',
                          label: 'Total Pages Read',
                          isDark: isDark,
                          flex: 1,
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Weekly Activity Chart
                    Text('Last 7 Days',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2A2A3C) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
                          blurRadius: 12, spreadRadius: 1,
                        )],
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 140,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: _dailyStats.entries.map((entry) {
                                final barHeight = maxBar > 0
                                    ? (entry.value / maxBar * 90).clamp(4.0, 90.0)
                                    : 4.0;
                                final isToday = entry.key == ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'][DateTime.now().weekday % 7];
                                return SizedBox(
                                  width: 32,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      if (entry.value > 0)
                                        Text('${entry.value}',
                                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white54 : Colors.grey.shade600)),
                                      const SizedBox(height: 2),
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 600),
                                        curve: Curves.easeOut,
                                        width: 24,
                                        height: barHeight,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(6),
                                          gradient: LinearGradient(
                                            begin: Alignment.bottomCenter,
                                            end: Alignment.topCenter,
                                            colors: isToday
                                              ? [Colors.blueAccent, Colors.blue.shade300]
                                              : [Colors.blueAccent.withOpacity(0.4), Colors.blueAccent.withOpacity(0.2)],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(entry.key,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                          color: isToday ? Colors.blueAccent : (isDark ? Colors.white54 : Colors.grey.shade600),
                                        )),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Streak motivational banner
                    if (_streak > 0)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _streak >= 7
                              ? [Colors.orange.shade700, Colors.deepOrange]
                              : [Colors.blueGrey.shade700, Colors.blueGrey.shade500],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Text(_streak >= 7 ? '🔥' : '📚', style: const TextStyle(fontSize: 36)),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _streak >= 30 ? 'Legendary Reader!' :
                                    _streak >= 14 ? 'On Fire! Keep it up!' :
                                    _streak >= 7  ? 'Great streak! 1 week!' :
                                    _streak >= 3  ? 'Building momentum!' :
                                    'Keep reading daily!',
                                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text('$_streak day${_streak > 1 ? 's' : ''} in a row',
                                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required bool isDark,
    required int flex,
  }) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A3C) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
            blurRadius: 12, spreadRadius: 1,
          )],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 14),
            Text(value,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 2),
            Text(label,
              style: TextStyle(fontSize: 12,
                color: isDark ? Colors.white54 : Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}
