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

  /// callback عند النقر على نقطة - يُمرر index النقطة المضغوطة
  final ValueChanged<int>? onDotClicked;
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
    final totalNormalDots = (count - 1) * dotSize;
    final totalSpacing = (count - 1) * spacing;
    final totalSize = totalNormalDots + expandedSize + totalSpacing;

    return RepaintBoundary(
      child: SizedBox(
        width: isHorizontal ? totalSize : dotSize,
        height: isHorizontal ? dotSize : totalSize,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final currentPage = controller.hasClients
                ? (controller.page ?? controller.initialPage.toDouble())
                : controller.initialPage.toDouble();

            return Flex(
              direction: axis,
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < count; i++)
                  _buildDot(
                    index: i,
                    currentPage: currentPage,
                    isHorizontal: isHorizontal,
                    isLast: i == count - 1,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDot({
    required int index,
    required double currentPage,
    required bool isHorizontal,
    required bool isLast,
  }) {
    final distance = (currentPage - index).abs();
    final animationValue = (1 - distance).clamp(0.0, 1.0);
    final currentDotSize = dotSize + (expandedSize - dotSize) * animationValue;
    final interpolatedColor = Color.lerp(dotColor, activeDotColor, animationValue)!;

    return Padding(
      padding: EdgeInsetsDirectional.only(
        end: isHorizontal && !isLast ? spacing : 0,
        bottom: !isHorizontal && !isLast ? spacing : 0,
      ),
      child: GestureDetector(
        onTap: onDotClicked != null ? () => onDotClicked!(index) : null,
        behavior: HitTestBehavior.opaque,
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
      ),
    );
  }
}
