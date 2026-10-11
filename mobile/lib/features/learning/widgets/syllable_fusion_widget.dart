import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class SyllableFusionWidget extends StatefulWidget {
  final String consonantSymbol;
  final String vowelSymbol;
  final String resultingSyllable;
  final VoidCallback onFused;

  const SyllableFusionWidget({
    super.key,
    required this.consonantSymbol,
    required this.vowelSymbol,
    required this.resultingSyllable,
    required this.onFused,
  });

  @override
  State<SyllableFusionWidget> createState() => _SyllableFusionWidgetState();
}

class _SyllableFusionWidgetState extends State<SyllableFusionWidget> with SingleTickerProviderStateMixin {
  bool _isFused = false;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.15).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _fuse() {
    if (_isFused) return;
    setState(() {
      _isFused = true;
    });
    _animController.forward();
    widget.onFused();
  }

  @override
  Widget build(BuildContext context) {
    if (_isFused) {
      return ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFD4AF37), Color(0xFFF5D77F)],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.5),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.resultingSyllable,
                style: const TextStyle(
                  fontFamily: 'Kedebideri',
                  fontSize: 56,
                  color: Color(0xFF0F3227),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, color: Color(0xFF0F3227), size: 20),
                  SizedBox(width: 6),
                  Text(
                    'Syllabe Unie !',
                    style: TextStyle(
                      color: Color(0xFF0F3227),
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Glisse la consonne vers la voyelle pour les unir',
          style: TextStyle(color: Colors.white70, fontSize: 15),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Consonne déplaçable
            Draggable<String>(
              data: widget.consonantSymbol,
              feedback: Material(
                color: Colors.transparent,
                child: _buildTile(widget.consonantSymbol, isDragging: true),
              ),
              childWhenDragging: Opacity(
                opacity: 0.3,
                child: _buildTile(widget.consonantSymbol),
              ),
              child: _buildTile(widget.consonantSymbol),
            ),

            const SizedBox(width: 24),
            const Icon(Icons.arrow_forward_rounded, color: AppColors.gold, size: 32),
            const SizedBox(width: 24),

            // Voyelle réceptrice
            DragTarget<String>(
              onWillAcceptWithDetails: (details) => true,
              onAcceptWithDetails: (details) {
                _fuse();
              },
              builder: (context, candidateData, rejectedData) {
                final isHovered = candidateData.isNotEmpty;
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: isHovered
                        ? [
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.6),
                              blurRadius: 18,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: _buildTile(
                    widget.vowelSymbol,
                    isTargetHovered: isHovered,
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _fuse,
          icon: const Icon(Icons.touch_app_rounded),
          label: const Text('Toucher pour unir'),
        ),
      ],
    );
  }

  Widget _buildTile(String symbol, {bool isDragging = false, bool isTargetHovered = false}) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: isTargetHovered
            ? AppColors.gold.withValues(alpha: 0.25)
            : AppColors.night.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isTargetHovered ? AppColors.gold : Colors.white.withValues(alpha: 0.2),
          width: isTargetHovered ? 2.5 : 1.5,
        ),
        boxShadow: isDragging
            ? [
                const BoxShadow(
                  color: Colors.black54,
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        symbol,
        style: const TextStyle(
          fontFamily: 'Kedebideri',
          fontSize: 42,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
