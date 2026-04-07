import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/summary.dart';
import 'preferences_service.dart';

class ApiService {
  final PreferencesService _prefs = PreferencesService();

  Future<Summary?> summarizeText(String text) async {
    try {
      final baseUrl = await _prefs.getApiUrl();
      final response = await http.post(
        Uri.parse('$baseUrl/summarize'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return Summary.fromJson(jsonDecode(response.body));
      } else {
        print('Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('API Error: $e');
      return null;
    }
  }

  Future<String?> askQuestion(String pageText, String question) async {
    try {
      final baseUrl = await _prefs.getApiUrl();
      final response = await http.post(
        Uri.parse('$baseUrl/ask'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'pageText': pageText, 'question': question}),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded['answer'] as String?;
      } else {
        print('Ask Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Ask API Error: $e');
      return null;
    }
  }
}
