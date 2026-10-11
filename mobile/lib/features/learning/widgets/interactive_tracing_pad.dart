import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../engine/tracing_engine.dart';

class InteractiveTracingPad extends StatefulWidget {
  final String symbol;
  final List<TracingStroke> targetStrokes;
  final ValueChanged<TracingValidationResult> onTraceCompleted;
  final VoidCallback? onReset;
  final int currentAttempt;
  final int totalAttemptsRequired;

  const InteractiveTracingPad({
    super.key,
    required this.symbol,
    required this.targetStrokes,
    required this.onTraceCompleted,
    this.onReset,
    this.currentAttempt = 1,
    this.totalAttemptsRequired = 3,
  });

  @override
  State<InteractiveTracingPad> createState() => _InteractiveTracingPadState();
}

class _InteractiveTracingPadState extends State<InteractiveTracingPad> {
  final List<List<Offset>> _userStrokes = [];
  List<Offset> _currentStroke = [];
  final TracingEngine _engine = const TracingEngine();
  TracingValidationResult? _lastResult;

  @override
  void didUpdateWidget(covariant InteractiveTracingPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentAttempt != widget.currentAttempt || oldWidget.symbol != widget.symbol) {
      _userStrokes.clear();
      _currentStroke.clear();
      _lastResult = null;
    }
  }

  void _onPanStart(DragStartDetails details, RenderBox box) {
    final localPosition = box.globalToLocal(details.globalPosition);
    setState(() {
      _currentStroke = [localPosition];
      _userStrokes.add(_currentStroke);
      _lastResult = null;
    });
  }

  void _onPanUpdate(DragUpdateDetails details, RenderBox box) {
    final localPosition = box.globalToLocal(details.globalPosition);
    setState(() {
      _currentStroke.add(localPosition);
    });
  }

  void _onPanEnd(DragEndDetails details, Size canvasSize) {
    if (_userStrokes.isEmpty) return;

    final result = _engine.evaluate(
      userDrawnStrokes: _userStrokes,
      targetStrokes: _effectiveStrokes(),
      canvasSize: canvasSize,
    );

    setState(() {
      _lastResult = result;
    });

    widget.onTraceCompleted(result);
  }

  void _clear() {
    setState(() {
      _userStrokes.clear();
      _currentStroke.clear();
      _lastResult = null;
    });
    widget.onReset?.call();
  }

  List<TracingStroke> _effectiveStrokes() {
    return widget.targetStrokes.isNotEmpty
        ? widget.targetStrokes
        : TracingEngine.getStrokesForSymbol(widget.symbol);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // En-tête : Jauge des passages réussis
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.gesture_rounded, color: AppColors.gold, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Passage ${widget.currentAttempt}/${widget.totalAttemptsRequired}',
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            IconButton(
              onPressed: _clear,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
              tooltip: 'Effacer et recommencer',
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Zone de dessin Canvas
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            height: 320,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _lastResult?.isSuccess == true
                    ? AppColors.gold
                    : Colors.white.withValues(alpha: 0.15),
                width: 2,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);

                return Stack(
                  children: [
                    // Symbole modèle en arrière-plan transparent
                    Center(
                      child: Text(
                        widget.symbol,
                        style: TextStyle(
                          fontFamily: 'Kedebideri',
                          fontSize: 180,
                          color: Colors.white.withValues(
                            alpha: widget.currentAttempt == 1 ? 0.20 : 0.08,
                          ),
                        ),
                      ),
                    ),

                    // Guide vectoriel discret (Points de repère)
                    if (widget.currentAttempt <= 2)
                      CustomPaint(
                        size: canvasSize,
                        painter: _GuidePointsPainter(
                          strokes: _effectiveStrokes(),
                        ),
                      ),

                    // Gesture detector et rendu des traits utilisateur
                    Positioned.fill(
                      child: Builder(
                        builder: (ctx) {
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanStart: (d) => _onPanStart(d, ctx.findRenderObject() as RenderBox),
                            onPanUpdate: (d) => _onPanUpdate(d, ctx.findRenderObject() as RenderBox),
                            onPanEnd: (d) => _onPanEnd(d, canvasSize),
                            child: CustomPaint(
                              painter: _UserStrokesPainter(
                                strokes: _userStrokes,
                                isSuccess: _lastResult?.isSuccess,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Message de feedback immédiat
        if (_lastResult != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _lastResult!.isSuccess
                  ? AppColors.green.withValues(alpha: 0.8)
                  : Colors.red.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _lastResult!.isSuccess ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  _lastResult!.feedbackMessage,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _GuidePointsPainter extends CustomPainter {
  final List<TracingStroke> strokes;

  _GuidePointsPainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    final pointPaint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;

    final startRingPaint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (final stroke in strokes) {
      if (stroke.keypoints.isEmpty) continue;
      // Cercle de départ
      final startOffset = stroke.keypoints.first.toOffset(size);
      canvas.drawCircle(startOffset, 8.0, startRingPaint);
      canvas.drawCircle(startOffset, 4.0, pointPaint);

      // Points de repère suivants
      for (int i = 1; i < stroke.keypoints.length; i++) {
        final offset = stroke.keypoints[i].toOffset(size);
        canvas.drawCircle(offset, 4.0, pointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GuidePointsPainter oldDelegate) => false;
}

class _UserStrokesPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final bool? isSuccess;

  _UserStrokesPainter({required this.strokes, this.isSuccess});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = isSuccess == true
          ? AppColors.gold
          : (isSuccess == false ? Colors.orangeAccent : Colors.white)
      ..strokeWidth = 9.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path();
      path.moveTo(stroke.first.dx, stroke.first.dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _UserStrokesPainter oldDelegate) => true;
}
