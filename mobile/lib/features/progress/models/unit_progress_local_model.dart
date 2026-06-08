class UnitProgressLocalModel {
  final String unitSlug;
  final String status;
  final int currentStep;
  final int totalSteps;
  final int bestScorePercent;
  final bool completed;
  final String lastStage;
  final DateTime startedAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  const UnitProgressLocalModel({
    required this.unitSlug,
    required this.status,
    required this.currentStep,
    required this.totalSteps,
    required this.bestScorePercent,
    required this.completed,
    required this.lastStage,
    required this.startedAt,
    required this.updatedAt,
    required this.completedAt,
  });

  factory UnitProgressLocalModel.started({
    required String unitSlug,
    required int totalSteps,
  }) {
    final now = DateTime.now().toUtc();

    return UnitProgressLocalModel(
      unitSlug: unitSlug,
      status: 'started',
      currentStep: 0,
      totalSteps: totalSteps,
      bestScorePercent: 0,
      completed: false,
      lastStage: 'intro',
      startedAt: now,
      updatedAt: now,
      completedAt: null,
    );
  }

  factory UnitProgressLocalModel.fromJson(Map<String, dynamic> json) {
    return UnitProgressLocalModel(
      unitSlug: _asString(json['unit_slug']),
      status: _asString(json['status'], fallback: 'started'),
      currentStep: _asInt(json['current_step']),
      totalSteps: _asInt(json['total_steps']),
      bestScorePercent: _asInt(json['best_score_percent']),
      completed: _asBool(json['completed']),
      lastStage: _asString(json['last_stage'], fallback: 'intro'),
      startedAt: _asDate(json['started_at']) ?? DateTime.now().toUtc(),
      updatedAt: _asDate(json['updated_at']) ?? DateTime.now().toUtc(),
      completedAt: _asDate(json['completed_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'unit_slug': unitSlug,
      'status': status,
      'current_step': currentStep,
      'total_steps': totalSteps,
      'best_score_percent': bestScorePercent,
      'completed': completed,
      'last_stage': lastStage,
      'started_at': startedAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  UnitProgressLocalModel copyWith({
    String? status,
    int? currentStep,
    int? totalSteps,
    int? bestScorePercent,
    bool? completed,
    String? lastStage,
    DateTime? updatedAt,
    DateTime? completedAt,
  }) {
    return UnitProgressLocalModel(
      unitSlug: unitSlug,
      status: status ?? this.status,
      currentStep: currentStep ?? this.currentStep,
      totalSteps: totalSteps ?? this.totalSteps,
      bestScorePercent: bestScorePercent ?? this.bestScorePercent,
      completed: completed ?? this.completed,
      lastStage: lastStage ?? this.lastStage,
      startedAt: startedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _asString(dynamic value, {String fallback = ''}) {
    final text = value?.toString() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    return value?.toString() == 'true' || value?.toString() == '1';
  }

  static DateTime? _asDate(dynamic value) {
    final text = value?.toString() ?? '';
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }
}