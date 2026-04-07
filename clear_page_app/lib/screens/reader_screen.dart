import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../services/api_service.dart';
import '../models/summary.dart';
import '../models/chat_message.dart';
import '../services/preferences_service.dart';
class ReaderScreen extends StatefulWidget {
  final File pdfFile;
  const ReaderScreen({Key? key, required this.pdfFile}) : super(key: key);

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  PdfDocument? _document;
  String? _selectedText;
  bool _isFocusMode = false;
  int _currentPage = 1;
  int _totalPages = 0;
  Summary? _activeSummary;
  double _summaryHeightFactor = 0.5;

  // Bookmarks
  bool _isCurrentPageBookmarked = false;

  // Chat AI
  bool _isChatOpen = false;
  bool _isChatLoading = false;
  final List<ChatMessage> _chatMessages = [];
  final TextEditingController _chatInputController = TextEditingController();
  double _chatHeightFactor = 0.5;

  @override
  void dispose() {
    _chatInputController.dispose();
    super.dispose();
  }

  Future<void> _loadBookmarkState() async {
    final bookmarked = await PreferencesService().isBookmarked(widget.pdfFile.path, _currentPage);
    if (mounted) setState(() => _isCurrentPageBookmarked = bookmarked);
  }

  Future<void> _toggleBookmark() async {
    await PreferencesService().toggleBookmark(widget.pdfFile.path, _currentPage);
    await _loadBookmarkState();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isCurrentPageBookmarked ? 'Page $_currentPage bookmarked!' : 'Bookmark removed'),
        duration: const Duration(seconds: 1),
      ));
    }
  }

  Future<void> _openBookmarksList() async {
    final bookmarks = await PreferencesService().getBookmarks(widget.pdfFile.path);
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A3C) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bookmarked Pages', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 16),
            if (bookmarks.isEmpty)
              Text('No bookmarks yet. Tap the bookmark icon on any page.', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
            ...bookmarks.map((page) => ListTile(
              leading: const Icon(Icons.bookmark, color: Colors.amber),
              title: Text('Page $page', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
              onTap: () {
                Navigator.pop(context);
                _pdfViewerController.jumpToPage(page);
              },
            )),
          ],
        ),
      ),
    );
  }

  String _getCurrentPageText() {
    if (_document == null) return '';
    try {
      return PdfTextExtractor(_document!).extractText(
        startPageIndex: _currentPage - 1,
        endPageIndex: _currentPage - 1,
      );
    } catch (_) { return ''; }
  }

  Future<void> _sendChatMessage(String question) async {
    if (question.trim().isEmpty) return;
    _chatInputController.clear();
    final pageText = _getCurrentPageText();
    final userMsg = ChatMessage(text: question, isUser: true, timestamp: DateTime.now());
    setState(() {
      _chatMessages.add(userMsg);
      _isChatLoading = true;
    });
    final answer = await _apiService.askQuestion(pageText, question);
    if (mounted) {
      setState(() {
        _isChatLoading = false;
        _chatMessages.add(ChatMessage(
          text: answer ?? 'Sorry, could not get an answer. Please try again.',
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
    }
  }

  Future<void> _summarizeContent({String? textToSummarize}) async {
    if (_document == null) return;
    
    String text = textToSummarize ?? "";

    if (text.isEmpty) {
      int pageNumber = _pdfViewerController.pageNumber;
      if (pageNumber < 1) return;
      text = PdfTextExtractor(_document!).extractText(startPageIndex: pageNumber - 1, endPageIndex: pageNumber - 1);
    }

    if (text.trim().isEmpty) {
      _showError("No text found.");
      return;
    }

    setState(() => _isLoading = true);
    
    Summary? summary = await _apiService.summarizeText(text);
    
    if (mounted) setState(() => _isLoading = false);

    if (summary != null) {
      _showSummaryModal(summary);
    } else {
      _showError("Failed to get summary. Have you updated your Backend IP in Settings?");
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  void _showSummaryModal(Summary summary) {
    setState(() {
      _activeSummary = summary;
    });
  }

  Widget _buildSection(String title, String content, IconData icon, Color iconColor) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: iconColor.withOpacity(0.25),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: iconColor.withOpacity(isDark ? 0.08 : 0.06),
              blurRadius: 12,
              spreadRadius: 1,
              offset: const Offset(0, 3),
            )
          ]
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: title == 'Core Explanation',
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10)
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            title: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              MarkdownBody(
                data: content,
                styleSheet: MarkdownStyleSheet(
                  h2: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                    height: 2.0,
                  ),
                  h3: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                    height: 1.8,
                  ),
                  p: TextStyle(
                    fontSize: 13.5,
                    height: 1.65,
                    color: isDark ? Colors.white70 : Colors.grey[800],
                  ),
                  listBullet: TextStyle(
                    fontSize: 13.5,
                    color: isDark ? Colors.white70 : Colors.grey[800],
                  ),
                  strong: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  em: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: iconColor,
                  ),
                  blockquote: TextStyle(
                    fontSize: 13.5,
                    color: isDark ? Colors.white54 : Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                  blockquoteDecoration: BoxDecoration(
                    color: iconColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border(
                      left: BorderSide(color: iconColor, width: 3),
                    ),
                  ),
                  code: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                    color: isDark ? Colors.amberAccent : Colors.deepOrange,
                    backgroundColor: isDark ? const Color(0xFF2A2A3C) : const Color(0xFFF5F5F5),
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2A2A3C) : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openNotes() async {
    String currentNote = await PreferencesService().getNoteForBook(widget.pdfFile.path);
    TextEditingController controller = TextEditingController(text: currentNote);
    
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        bool isDark = Theme.of(context).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.6,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('My Notes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                    TextButton(
                      onPressed: () {
                        PreferencesService().saveNoteForBook(widget.pdfFile.path, controller.text);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notes saved!')));
                      },
                      style: TextButton.styleFrom(foregroundColor: Colors.blueGrey),
                      child: const Text('Save & Close', style: TextStyle(fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: TextField(
                    controller: controller,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: InputDecoration(
                      hintText: 'Type your notes for this book here...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF2A2A3C) : Colors.grey.shade100,
                    ),
                  ),
                )
              ],
            ),
          ),
        );
      }
    );
  }

  Future<void> _addQuoteToNotes(String quote) async {
    String currentNote = await PreferencesService().getNoteForBook(widget.pdfFile.path);
    String newEntry = "\n\n> \"$quote\"\n\n";
    String combinedNote = currentNote + newEntry;
    
    await PreferencesService().saveNoteForBook(widget.pdfFile.path, combinedNote.trimLeft());
    
    _pdfViewerController.clearSelection();
    _openNotes();
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    Widget pdfViewer = SfPdfViewer.file(
      widget.pdfFile,
      controller: _pdfViewerController,
      canShowScrollHead: true,
      canShowScrollStatus: true,
      pageSpacing: 4,
      onDocumentLoaded: (PdfDocumentLoadedDetails details) async {
        _document = details.document;
        final totalPages = details.document.pages.count;
        int lastPage = await PreferencesService().getLastPage(widget.pdfFile.path);
        await PreferencesService().saveTotalPages(widget.pdfFile.path, totalPages);
        if (mounted) {
          setState(() {
            _totalPages = totalPages;
            _currentPage = lastPage > 1 ? lastPage : 1;
          });
        }
        if (lastPage > 1 && mounted) {
          _pdfViewerController.jumpToPage(lastPage);
        }
      },
      onPageChanged: (PdfPageChangedDetails details) {
        PreferencesService().saveLastPage(widget.pdfFile.path, details.newPageNumber);
        PreferencesService().recordPageRead();
        if (mounted) {
          setState(() => _currentPage = details.newPageNumber);
          _loadBookmarkState();
        }
      },
      onTextSelectionChanged: (PdfTextSelectionChangedDetails details) {
        if (details.selectedText == null && _selectedText != null) {
          setState(() => _selectedText = null);
        } else if (details.selectedText != null && _selectedText != details.selectedText) {
          setState(() => _selectedText = details.selectedText);
        }
      },
    );

    // Apply color filter to invert PDF colors in dark mode
    if (isDark) {
      pdfViewer = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          -1,  0,  0, 0, 255,
           0, -1,  0, 0, 255,
           0,  0, -1, 0, 255,
           0,  0,  0, 1,   0,
        ]),
        child: pdfViewer,
      );
    }

    return Scaffold(
      appBar: _isFocusMode ? null : AppBar(
        title: const Text('Reading Mode'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            tooltip: isDark ? 'Light Mode' : 'Dark Mode',
            onPressed: () => PreferencesService().setDarkMode(!isDark),
          ),
          IconButton(
            icon: Icon(
              _isCurrentPageBookmarked ? Icons.bookmark : Icons.bookmark_outline,
              color: _isCurrentPageBookmarked ? Colors.amber : null,
            ),
            tooltip: _isCurrentPageBookmarked ? 'Remove Bookmark' : 'Bookmark Page',
            onPressed: _toggleBookmark,
          ),
          IconButton(
            icon: const Icon(Icons.bookmarks_outlined),
            tooltip: 'View Bookmarks',
            onPressed: _openBookmarksList,
          ),
          IconButton(
            icon: const Icon(Icons.edit_note),
            tooltip: 'My Notes',
            onPressed: _openNotes,
          ),
          IconButton(
            icon: const Icon(Icons.fullscreen),
            tooltip: 'Focus Mode',
            onPressed: () {
              setState(() => _isFocusMode = true);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Focus Mode Enabled. Use the top right button to exit.')),
              );
            },
          )
        ],
      ),
      body: GestureDetector(
        onTap: () {
          if (_isFocusMode) {
            setState(() => _isFocusMode = false);
          }
        },
        child: Stack(
          children: [
            pdfViewer,
            if (_isFocusMode)
              Positioned(
                top: 40,
                right: 20,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
                    tooltip: 'Exit Focus Mode',
                    onPressed: () {
                      setState(() => _isFocusMode = false);
                    },
                  ),
                ),
              ),
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            if (_totalPages > 0 && !_isFocusMode)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2A2A3C).withOpacity(0.9) : Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
                        ],
                      ),
                      child: Text(
                        'Page $_currentPage of $_totalPages',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ),
            if (_activeSummary != null)
              Positioned(
                bottom: 0, left: 0, right: 0,
                height: MediaQuery.of(context).size.height * _summaryHeightFactor,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF13131F) : const Color(0xFFF8F8FC),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                    boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 20, offset: Offset(0, -6))]
                  ),
                  child: Column(
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragUpdate: (details) {
                          setState(() {
                            _summaryHeightFactor -= details.primaryDelta! / MediaQuery.of(context).size.height;
                            if (_summaryHeightFactor < 0.15) _summaryHeightFactor = 0.15;
                            if (_summaryHeightFactor > 0.95) _summaryHeightFactor = 0.95;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.only(top: 14, left: 20, right: 12, bottom: 6),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Container(
                                  width: 48, height: 5,
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white24 : Colors.grey[300],
                                    borderRadius: BorderRadius.circular(10)
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'AI Teacher Explanation',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                        Text(
                                          'Page $_currentPage — structured for learning',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: isDark ? Colors.white38 : Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.close, color: isDark ? Colors.white54 : Colors.grey),
                                    tooltip: 'Close Explanation',
                                    onPressed: () => setState(() => _activeSummary = null),
                                  )
                                ],
                              ),
                              const SizedBox(height: 6),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                          physics: const BouncingScrollPhysics(),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF7C3AED).withOpacity(0.2),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF7C3AED).withOpacity(0.07),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            padding: const EdgeInsets.all(20),
                            child: MarkdownBody(
                              data: _activeSummary!.coreExplanation,
                              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                                h1: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF7C3AED),
                                  letterSpacing: 0.8,
                                  height: 2.8,
                                ),
                                h2: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF7C3AED),
                                  letterSpacing: 0.5,
                                  height: 2.6,
                                ),
                                h3: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFFB4A8FF) : const Color(0xFF5B21B6),
                                  height: 2.2,
                                ),
                                p: TextStyle(
                                  fontSize: 13.5,
                                  height: 1.8,
                                  color: isDark ? Colors.white.withOpacity(0.85) : const Color(0xFF1F2937),
                                  letterSpacing: 0.2,
                                ),
                                listBullet: TextStyle(
                                  fontSize: 13.5,
                                  color: isDark ? Colors.white60 : const Color(0xFF4B5563),
                                  height: 1.8,
                                ),
                                listIndent: 20,
                                strong: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black,
                                  fontSize: 14.0, // Slightly bigger to make it pop
                                  decoration: TextDecoration.none,
                                ),
                                em: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: const Color(0xFF7C3AED),
                                  fontWeight: FontWeight.w500,
                                ),
                                blockquote: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white54 : Colors.grey[700],
                                  fontStyle: FontStyle.italic,
                                  height: 1.6,
                                ),
                                blockquoteDecoration: BoxDecoration(
                                  color: const Color(0xFF7C3AED).withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(8),
                                  border: const Border(
                                    left: BorderSide(color: Color(0xFF7C3AED), width: 3.5),
                                  ),
                                ),
                                blockquotePadding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                                code: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color: isDark ? Colors.amberAccent : const Color(0xFFDC2626),
                                  backgroundColor: isDark ? const Color(0xFF2A2A3C) : const Color(0xFFF3F4F6),
                                ),
                                codeblockDecoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF2A2A3C) : const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.1)),
                                ),
                                horizontalRuleDecoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(
                                      color: const Color(0xFF7C3AED).withOpacity(0.15),
                                      width: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_activeSummary != null || _isChatOpen) const SizedBox(),
            // --- CHAT AI PANEL ---
            if (_isChatOpen)
              Positioned(
                bottom: 0, left: 0, right: 0,
                height: MediaQuery.of(context).size.height * _chatHeightFactor,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 15, offset: Offset(0, -5))]
                  ),
                  child: Column(
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragUpdate: (d) {
                          setState(() {
                            _chatHeightFactor -= d.primaryDelta! / MediaQuery.of(context).size.height;
                            _chatHeightFactor = _chatHeightFactor.clamp(0.3, 0.92);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(24, 15, 8, 8),
                          child: Row(
                            children: [
                              Container(
                                width: 40, height: 5,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              const Icon(Icons.chat_bubble_outline, size: 18, color: Colors.blueAccent),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('Ask AI about Page $_currentPage',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => setState(() => _isChatOpen = false),
                              )
                            ],
                          ),
                        ),
                      ),
                      Divider(height: 1, color: isDark ? Colors.white12 : Colors.black12),
                      Expanded(
                        child: _chatMessages.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.psychology_outlined, size: 48, color: isDark ? Colors.white24 : Colors.grey.shade300),
                                  const SizedBox(height: 12),
                                  Text('Ask anything about this page',
                                    style: TextStyle(color: isDark ? Colors.white38 : Colors.grey)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: _chatMessages.length + (_isChatLoading ? 1 : 0),
                              itemBuilder: (_, i) {
                                if (_isChatLoading && i == _chatMessages.length) {
                                  return Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(vertical: 4),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF2A2A3C) : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(width: 16, height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2,
                                              color: Colors.blueAccent)),
                                          const SizedBox(width: 8),
                                          Text('Thinking...', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                                final msg = _chatMessages[i];
                                return Align(
                                  alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Container(
                                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: msg.isUser
                                        ? Colors.blueAccent
                                        : (isDark ? const Color(0xFF2A2A3C) : Colors.grey.shade100),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(msg.text,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        color: msg.isUser ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, -2))],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _chatInputController,
                                style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Ask about this page...',
                                  hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF2A2A3C) : Colors.grey.shade100,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                ),
                                onSubmitted: _sendChatMessage,
                                textInputAction: TextInputAction.send,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _sendChatMessage(_chatInputController.text),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: const BoxDecoration(
                                  color: Colors.blueAccent,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.send, color: Colors.white, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: _isFocusMode ? null : Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_selectedText != null) ...[
            SizedBox(
              height: 40,
              child: FloatingActionButton.extended(
                heroTag: 'quote_btn',
                onPressed: () => _addQuoteToNotes(_selectedText!),
                extendedPadding: const EdgeInsets.symmetric(horizontal: 12),
                icon: const Icon(Icons.format_quote, size: 18),
                label: const Text('Quote to Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
          ],
          // Chat option disabled temporarily as requested
          /* SizedBox(
            height: 40,
            child: FloatingActionButton.extended(
              heroTag: 'chat_btn',
              onPressed: () => setState(() {
                _isChatOpen = !_isChatOpen;
                _activeSummary = null; // close summary if open
              }),
              extendedPadding: const EdgeInsets.symmetric(horizontal: 12),
              icon: Icon(_isChatOpen ? Icons.close : Icons.chat_bubble_outline, size: 18),
              label: Text(_isChatOpen ? 'Close Chat' : 'Ask AI', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 10), */
          SizedBox(
            height: 40,
            child: FloatingActionButton.extended(
              heroTag: 'explain_btn',
              onPressed: _isLoading ? null : () => _summarizeContent(textToSummarize: _selectedText),
              extendedPadding: const EdgeInsets.symmetric(horizontal: 12),
              icon: Icon(_selectedText != null ? Icons.psychology : Icons.auto_awesome, size: 18),
              label: Text(
                _selectedText != null ? 'Explain Selection' : 'Explain Page', 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)
              ),
              backgroundColor: _selectedText != null ? Colors.deepOrangeAccent : Colors.blueGrey,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
