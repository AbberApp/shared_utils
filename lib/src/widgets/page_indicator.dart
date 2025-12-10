import 'package:flutter/material.dart';

/// مؤشر نقطي للصفحات مع انيميشن سلس
class PageIndicator extends StatelessWidget {
  const PageIndicator({
    super.key,
    required this.controller,
    required this.count,
    required this.dotColor,
    required this.activeDotColor,
    this.onDotClicked,
    this.axis = Axis.horizontal,
    this.spacing = 8.0,
    this.dotSize = 8.0,
    this.expandedSize = 32.0,
    this.animationDuration = Duration.zero,
  });

  final PageController controller;
  final int count;
  final VoidCallback? onDotClicked;
  final Axis axis;
  final Duration animationDuration;
  final double spacing;
  final double dotSize;
  final double expandedSize;
  final Color dotColor;
  final Color activeDotColor;

  @override
  Widget build(BuildContext context) {
    final isHorizontal = axis == Axis.horizontal;
    final totalSize = _calculateTotalSize(isHorizontal);

    return SizedBox(
      width: isHorizontal ? totalSize : null,
      height: isHorizontal ? null : totalSize,
      child: isHorizontal
          ? Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: _buildDots(isHorizontal),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: _buildDots(isHorizontal),
            ),
    );
  }

  double _calculateTotalSize(bool isHorizontal) {
    final normalDotSize = dotSize;
    final totalNormalDots = (count - 1) * normalDotSize;
    final totalSpacing = (count - 1) * spacing;
    return totalNormalDots + expandedSize + totalSpacing;
  }

  List<Widget> _buildDots(bool isHorizontal) {
    final dots = <Widget>[];

    for (int i = 0; i < count; i++) {
      dots.add(
        AnimatedBuilder(
          animation: controller,
          builder: (context, _) => _buildDot(i, isHorizontal),
        ),
      );

      if (i < count - 1) {
        dots.add(SizedBox(
          width: isHorizontal ? spacing : 0,
          height: isHorizontal ? 0 : spacing,
        ));
      }
    }

    return dots;
  }

  Widget _buildDot(int index, bool isHorizontal) {
    double currentPage = 0;

    if (controller.hasClients) {
      currentPage = controller.page ?? 0;
    }

    final distance = (currentPage - index).abs();
    final animationValue = (1 - distance).clamp(0.0, 1.0);
    final currentDotSize = dotSize + (expandedSize - dotSize) * animationValue;
    final interpolatedColor = Color.lerp(dotColor, activeDotColor, animationValue)!;

    return GestureDetector(
      onTap: onDotClicked,
      child: AnimatedContainer(
        duration: animationDuration,
        curve: Curves.easeInOut,
        height: isHorizontal ? dotSize : currentDotSize,
        width: isHorizontal ? currentDotSize : dotSize,
        decoration: BoxDecoration(
          color: interpolatedColor,
          borderRadius: BorderRadius.circular(currentDotSize / 2),
        ),
      ),
    );
  }
}
