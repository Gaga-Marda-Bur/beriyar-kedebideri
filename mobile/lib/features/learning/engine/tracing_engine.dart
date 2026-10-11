import 'dart:math';
import 'package:flutter/material.dart';

class TracingPoint {
  final double x;
  final double y;

  const TracingPoint(this.x, this.y);

  factory TracingPoint.fromJson(Map<String, dynamic> json) {
    return TracingPoint(
      (json['x'] as num?)?.toDouble() ?? 0.0,
      (json['y'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  Offset toOffset(Size canvasSize) => Offset(x * canvasSize.width, y * canvasSize.height);

  double distanceTo(TracingPoint other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return sqrt(dx * dx + dy * dy);
  }
}

class TracingStroke {
  final int order;
  final List<TracingPoint> keypoints;
  final String recommendedDirection;

  const TracingStroke({
    required this.order,
    required this.keypoints,
    this.recommendedDirection = 'top_to_bottom',
  });

  factory TracingStroke.fromJson(Map<String, dynamic> json) {
    final list = json['keypoints'] as List<dynamic>? ?? [];
    return TracingStroke(
      order: json['order'] as int? ?? 1,
      recommendedDirection: json['recommended_direction'] as String? ?? 'top_to_bottom',
      keypoints: list.map((e) => TracingPoint.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'order': order,
    'recommended_direction': recommendedDirection,
    'keypoints': keypoints.map((e) => e.toJson()).toList(),
  };
}

enum TracingQuality {
  perfect, // Forme et ordre recommandés corrects (3 étoiles)
  acceptable, // Forme correcte, ordre ou direction alternative (2 étoiles)
  failed, // Forme incomplète ou trop déviante (0 étoile)
}

class TracingValidationResult {
  final TracingQuality quality;
  final double coverageRatio;
  final double deviationRatio;
  final bool isSuccess;
  final String feedbackMessage;

  const TracingValidationResult({
    required this.quality,
    required this.coverageRatio,
    required this.deviationRatio,
    required this.isSuccess,
    required this.feedbackMessage,
  });
}

class TracingEngine {
  final double snapRadiusRatio;
  final double strokeCoverageThreshold;
  final double maxAllowedDeviation;
  final bool enforceStrokeOrder;

  const TracingEngine({
    this.snapRadiusRatio = 0.26,
    this.strokeCoverageThreshold = 0.40,
    this.maxAllowedDeviation = 0.35,
    this.enforceStrokeOrder = false,
  });

  /// Retourne les traits vectoriels cibles étalonnés pour chaque caractère Beriya
  static List<TracingStroke> getStrokesForSymbol(String symbol) {
    switch (symbol) {
      case '𖺣': // e : boucle haute arrondie + tige descendante + base
        return const [
          TracingStroke(
            order: 1,
            recommendedDirection: 'clockwise_loop',
            keypoints: [
              TracingPoint(0.60, 0.48),
              TracingPoint(0.52, 0.44),
              TracingPoint(0.40, 0.48),
              TracingPoint(0.38, 0.54),
              TracingPoint(0.42, 0.62),
              TracingPoint(0.52, 0.62),
            ],
          ),
          TracingStroke(
            order: 2,
            recommendedDirection: 'top_to_bottom',
            keypoints: [
              TracingPoint(0.52, 0.62),
              TracingPoint(0.52, 0.68),
            ],
          ),
          TracingStroke(
            order: 3,
            recommendedDirection: 'left_to_right',
            keypoints: [
              TracingPoint(0.44, 0.68),
              TracingPoint(0.60, 0.68),
            ],
          ),
        ];

      case '𖺡': // b : triangle inversé + 3 pointes en haut
        return const [
          TracingStroke(
            order: 1,
            recommendedDirection: 'loop',
            keypoints: [
              TracingPoint(0.35, 0.48),
              TracingPoint(0.50, 0.68),
              TracingPoint(0.65, 0.48),
              TracingPoint(0.35, 0.48),
            ],
          ),
          TracingStroke(
            order: 2,
            recommendedDirection: 'bottom_to_top',
            keypoints: [
              TracingPoint(0.38, 0.48),
              TracingPoint(0.38, 0.40),
            ],
          ),
          TracingStroke(
            order: 3,
            recommendedDirection: 'bottom_to_top',
            keypoints: [
              TracingPoint(0.50, 0.48),
              TracingPoint(0.50, 0.38),
            ],
          ),
          TracingStroke(
            order: 4,
            recommendedDirection: 'bottom_to_top',
            keypoints: [
              TracingPoint(0.62, 0.48),
              TracingPoint(0.62, 0.40),
            ],
          ),
        ];

      case '𖺵': // t : barre verticale + traverse
        return const [
          TracingStroke(
            order: 1,
            recommendedDirection: 'top_to_bottom',
            keypoints: [
              TracingPoint(0.50, 0.38),
              TracingPoint(0.50, 0.54),
              TracingPoint(0.50, 0.70),
            ],
          ),
          TracingStroke(
            order: 2,
            recommendedDirection: 'left_to_right',
            keypoints: [
              TracingPoint(0.36, 0.48),
              TracingPoint(0.50, 0.48),
              TracingPoint(0.64, 0.48),
            ],
          ),
        ];

      default:
        // Guide centré par défaut
        return const [
          TracingStroke(
            order: 1,
            keypoints: [
              TracingPoint(0.40, 0.42),
              TracingPoint(0.40, 0.65),
              TracingPoint(0.60, 0.65),
            ],
          ),
        ];
    }
  }

  /// Évalue une série de points dessinés par l'utilisateur par rapport aux traits attendus
  TracingValidationResult evaluate({
    required List<List<Offset>> userDrawnStrokes,
    required List<TracingStroke> targetStrokes,
    required Size canvasSize,
  }) {
    if (userDrawnStrokes.isEmpty || canvasSize.width <= 0 || canvasSize.height <= 0) {
      return const TracingValidationResult(
        quality: TracingQuality.failed,
        coverageRatio: 0.0,
        deviationRatio: 1.0,
        isSuccess: false,
        feedbackMessage: 'Trace le caractère pour continuer.',
      );
    }

    // Normalisation de tous les points tracés
    final allUserPoints = <TracingPoint>[];
    double totalUserLength = 0.0;

    for (final stroke in userDrawnStrokes) {
      if (stroke.isEmpty) continue;
      for (int i = 0; i < stroke.length; i++) {
        final p = TracingPoint(
          (stroke[i].dx / canvasSize.width).clamp(0.0, 1.0),
          (stroke[i].dy / canvasSize.height).clamp(0.0, 1.0),
        );
        allUserPoints.add(p);
        if (i > 0) {
          final prev = stroke[i - 1];
          final dx = (stroke[i].dx - prev.dx) / canvasSize.width;
          final dy = (stroke[i].dy - prev.dy) / canvasSize.height;
          totalUserLength += sqrt(dx * dx + dy * dy);
        }
      }
    }

    // Si le tracé est trop court (simple tap ou tremblement)
    if (allUserPoints.length < 5 || totalUserLength < 0.12) {
      return const TracingValidationResult(
        quality: TracingQuality.failed,
        coverageRatio: 0.05,
        deviationRatio: 0.95,
        isSuccess: false,
        feedbackMessage: 'Trace le caractère le long du guide.',
      );
    }

    // Calcul des cibles effectives
    final targets = targetStrokes.isNotEmpty
        ? targetStrokes
        : const [
            TracingStroke(
              order: 1,
              keypoints: [
                TracingPoint(0.40, 0.45),
                TracingPoint(0.50, 0.55),
                TracingPoint(0.60, 0.65),
              ],
            ),
          ];

    int totalKeypoints = 0;
    int matchedKeypoints = 0;

    for (final target in targets) {
      for (final kp in target.keypoints) {
        totalKeypoints++;
        // Trouver la distance minimale entre ce point clé et le tracé utilisateur
        double minDistance = double.infinity;
        for (final up in allUserPoints) {
          final dist = kp.distanceTo(up);
          if (dist < minDistance) {
            minDistance = dist;
            if (minDistance <= snapRadiusRatio) break;
          }
        }
        if (minDistance <= snapRadiusRatio) {
          matchedKeypoints++;
        }
      }
    }

    final double coverage = totalKeypoints > 0
        ? (matchedKeypoints / totalKeypoints).clamp(0.0, 1.0)
        : 0.5;

    // Un tracé substantiel centré sur la zone du caractère est validé
    final bool isSubstantialTrace = totalUserLength >= 0.28 && allUserPoints.length >= 12;
    final bool passed = coverage >= strokeCoverageThreshold || (isSubstantialTrace && coverage >= 0.25);

    if (!passed) {
      return TracingValidationResult(
        quality: TracingQuality.failed,
        coverageRatio: coverage,
        deviationRatio: 1.0 - coverage,
        isSuccess: false,
        feedbackMessage: 'Essaie encore en suivant bien le guide.',
      );
    }

    final bool isPerfect = coverage >= 0.65;

    return TracingValidationResult(
      quality: isPerfect ? TracingQuality.perfect : TracingQuality.acceptable,
      coverageRatio: coverage,
      deviationRatio: 1.0 - coverage,
      isSuccess: true,
      feedbackMessage: isPerfect ? 'Excellent tracé ! ✨' : 'Très bien tracé ! 👍',
    );
  }
}
