class Summary {
  final String simplifiedExplanation;
  final String bulletPoints;
  final String realLifeExample;
  final String oneLineSummary;

  Summary({
    required this.simplifiedExplanation,
    required this.bulletPoints,
    required this.realLifeExample,
    required this.oneLineSummary,
  });

  factory Summary.fromJson(Map<String, dynamic> json) {
    return Summary(
      simplifiedExplanation: json['simplifiedExplanation'] ?? 'N/A',
      bulletPoints: json['bulletPoints'] ?? 'N/A',
      realLifeExample: json['realLifeExample'] ?? 'N/A',
      oneLineSummary: json['oneLineSummary'] ?? 'N/A',
    );
  }
}
