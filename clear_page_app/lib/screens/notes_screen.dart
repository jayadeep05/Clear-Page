import 'dart:io';
import 'package:flutter/material.dart';
import '../services/preferences_service.dart';
import 'reader_screen.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({Key? key}) : super(key: key);

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final PreferencesService _prefs = PreferencesService();
  Map<String, String> _allNotes = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final notes = await _prefs.getAllNotes();
    setState(() {
      _allNotes = notes;
      _isLoading = false;
    });
  }

  void _openPdf(String path) {
    if (File(path).existsSync()) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ReaderScreen(pdfFile: File(path))),
      ).then((_) => _loadNotes()); // Reload notes when returning
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Book file not found.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('My Notes'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allNotes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.edit_note, size: 80, color: Colors.blueGrey.withOpacity(0.3)),
                      const SizedBox(height: 20),
                      Text('No notes yet', style: TextStyle(fontSize: 18, color: Colors.blueGrey.withOpacity(0.6))),
                      const SizedBox(height: 10),
                      const Text('Open a book and tap the note icon to start writing!'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _allNotes.length,
                  itemBuilder: (context, index) {
                    String path = _allNotes.keys.elementAt(index);
                    String noteText = _allNotes[path]!;
                    String name = path.split(Platform.pathSeparator).last.replaceAll('.pdf', '');

                    return Card(
                      margin: const EdgeInsets.only(bottom: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      color: isDark ? const Color(0xFF2A2A3C) : Colors.white,
                      elevation: 2,
                      child: InkWell(
                        onTap: () => _openPdf(path),
                        borderRadius: BorderRadius.circular(15),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.menu_book, size: 18, color: Colors.blueGrey),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      name, 
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87),
                                      maxLines: 1, overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 30),
                              Text(
                                noteText,
                                style: TextStyle(fontSize: 15, color: isDark ? Colors.white70 : Colors.black87, height: 1.5),
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                              )
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
