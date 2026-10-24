import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Version 2 evaluates actual responses, never navigation or a default score.
class LearningSession {
  static const scoringVersion = 2;
  final List<Map<String, dynamic>> steps;
  final Map<String, int> weights;
  final int threshold;
  int currentStep = 0;
  String typedText = '';
  bool finished = false;
  final Set<int> viewed = {};
  final Map<int, Map<String, dynamic>> answers = {};

  LearningSession(this.steps, this.weights, this.threshold);

  static String? category(Map<String, dynamic> step) =>
      switch (step['step_type']) {
        'discrimination' => 'recognition',
        'tracing' => 'tracing',
        'keyboard_encoding' => 'encoding',
        _ => null,
      };

  String get revision {
    dynamic stable(dynamic value) {
      if (value is Map) {
        final keys = value.keys.map((k) => k.toString()).toList()..sort();
        return {
          for (final key in keys)
            if (!key.endsWith('_url')) key: stable(value[key]),
        };
      }
      if (value is List) return value.map(stable).toList();
      return value;
    }

    return sha256
        .convert(
          utf8.encode(
            jsonEncode(
              stable({
                'version': scoringVersion,
                'steps': steps,
                'weights': weights,
                'threshold': threshold,
              }),
            ),
          ),
        )
        .toString();
  }

  bool resolved(int index) => answers[index]?['resolved'] == true;
  bool get canAdvance =>
      category(steps[currentStep]) == null || resolved(currentStep);
  int get answeredCount => answers.length;
  int get correctCount =>
      answers.values.where((a) => a['first_correct'] == true).length;
  bool get allAssessed => steps
      .asMap()
      .entries
      .where((e) => category(e.value) != null)
      .every((e) => resolved(e.key));
  bool get canFinish =>
      steps.any((s) => category(s) != null) &&
      allAssessed &&
      steps
          .asMap()
          .entries
          .where((e) => e.value['step_type'] != 'celebration')
          .every((e) => viewed.contains(e.key));
  bool get passed => canFinish && score >= threshold.clamp(0, 100);

  int get score {
    double sum = 0;
    int totalWeight = 0;
    for (final name in ['recognition', 'tracing', 'encoding']) {
      final indexes = steps.asMap().entries.where(
        (e) => category(e.value) == name,
      );
      if (indexes.isEmpty) continue;
      final weight = (weights[name] ?? 0).clamp(0, 100);
      final correct = indexes
          .where((e) => answers[e.key]?['first_correct'] == true)
          .length;
      sum += weight * correct / indexes.length;
      totalWeight += weight;
    }
    return totalWeight == 0
        ? 0
        : (100 * sum / totalWeight).round().clamp(0, 100);
  }

  void answer(bool correct) {
    if (finished ||
        category(steps[currentStep]) == null ||
        resolved(currentStep)) {
      return;
    }
    final old = answers[currentStep];
    final successes = (old?['successes'] as int? ?? 0) + (correct ? 1 : 0);
    final requiredSuccesses = steps[currentStep]['step_type'] == 'tracing'
        ? 2
        : 1;
    answers[currentStep] = {
      'attempts': (old?['attempts'] as int? ?? 0) + 1,
      'first_correct': old?['first_correct'] ?? correct,
      'successes': successes,
      'resolved': successes >= requiredSuccesses,
    };
    viewed.add(currentStep);
  }

  int countViewed(String type) =>
      viewed.where((i) => steps[i]['step_type'] == type).length;

  Map<String, dynamic> toJson() => {
    'version': scoringVersion,
    'revision': revision,
    'current_step': currentStep,
    'typed_text': typedText,
    'finished': finished,
    'viewed': viewed.toList(),
    'answers': answers.map((k, v) => MapEntry('$k', v)),
  };

  void restore(Map<String, dynamic> data) {
    if (data['version'] != scoringVersion || data['revision'] != revision) {
      return;
    }
    currentStep = ((data['current_step'] as num?)?.toInt() ?? 0).clamp(
      0,
      steps.length - 1,
    );
    typedText = data['typed_text'] as String? ?? '';
    finished = data['finished'] == true;
    for (final i in (data['viewed'] as List? ?? [])) {
      if (i is int && i >= 0 && i < steps.length) viewed.add(i);
    }
    final saved = data['answers'];
    if (saved is Map) {
      for (final entry in saved.entries) {
        final index = int.tryParse(entry.key.toString());
        if (index == null ||
            index < 0 ||
            index >= steps.length ||
            entry.value is! Map) {
          continue;
        }
        answers[index] = Map<String, dynamic>.from(entry.value as Map);
      }
    }
  }
}
