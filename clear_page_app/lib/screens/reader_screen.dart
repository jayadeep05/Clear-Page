import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../services/api_service.dart';
import '../models/summary.dart';

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

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    final bytes = await widget.pdfFile.readAsBytes();
    if (mounted) {
      setState(() {
        _document = PdfDocument(inputBytes: bytes);
      });
    }
  }

  Future<void> _summarizeCurrentPage() async {
    if (_document == null) return;
    int pageNumber = _pdfViewerController.pageNumber;
    if (pageNumber < 1) return;

    // extract text from current page
    String text = PdfTextExtractor(_document!).extractText(startPageIndex: pageNumber - 1, endPageIndex: pageNumber - 1);

    if (text.trim().isEmpty) {
      _showError("No text found on this page.");
      return;
    }

    setState(() => _isLoading = true);
    
    // Call AI
    Summary? summary = await _apiService.summarizeText(text);
    
    if (mounted) setState(() => _isLoading = false);

    if (summary != null) {
      _showSummaryModal(summary);
    } else {
      _showError("Failed to get summary. Is the backend running?");
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  void _showSummaryModal(Summary summary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 5,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 20),
            Text('Smart AI Summary', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSection('One Line Summary', summary.oneLineSummary, Icons.flash_on),
                    _buildSection('Simple Explanation', summary.simplifiedExplanation, Icons.psychology),
                    _buildSection('Key Points', summary.bulletPoints, Icons.format_list_bulleted),
                    _buildSection('Real-life Example', summary.realLifeExample, Icons.lightbulb_outline),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blueGrey, size: 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            ],
          ),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(fontSize: 16, height: 1.5)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reading Mode', style: TextStyle(color: Colors.black)),
        backgroundColor: const Color(0xFFF5F5EC),
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.psychology),
            tooltip: 'Summarize Page',
            onPressed: _isLoading ? null : _summarizeCurrentPage,
          )
        ],
      ),
      body: Stack(
        children: [
          SfPdfViewer.file(
            widget.pdfFile,
            controller: _pdfViewerController,
            canShowScrollHead: false,
            canShowScrollStatus: false,
            pageSpacing: 4,
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _summarizeCurrentPage,
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Explain Page'),
        backgroundColor: Colors.blueGrey,
      ),
    );
  }
}
