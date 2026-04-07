class Summary {
  final String coreExplanation;
  final String terminologyBreakdown;
  final String practicalUnderstanding;
  final String clarifications;
  final String mentalModel;

  Summary({
    required this.coreExplanation,
    required this.terminologyBreakdown,
    required this.practicalUnderstanding,
    required this.clarifications,
    required this.mentalModel,
  });

  factory Summary.fromJson(Map<String, dynamic> json) {
    return Summary(
      coreExplanation: json['coreExplanation'] ?? 'N/A',
      terminologyBreakdown: json['terminologyBreakdown'] ?? 'N/A',
      practicalUnderstanding: json['practicalUnderstanding'] ?? 'N/A',
      clarifications: json['clarifications'] ?? 'N/A',
      mentalModel: json['mentalModel'] ?? 'N/A',
    );
  }
}
