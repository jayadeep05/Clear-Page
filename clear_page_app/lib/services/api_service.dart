import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/summary.dart';

class ApiService {
  // Use 10.0.2.2 for Android emulator to connect to localhost spring boot
  static const String baseUrl = 'http://10.0.2.2:8080/api/ai';

  Future<Summary?> summarizeText(String text) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/summarize'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      );

      if (response.statusCode == 200) {
        return Summary.fromJson(jsonDecode(response.body));
      } else {
        print('Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('API Error: $e');
      return null;
    }
  }
}
