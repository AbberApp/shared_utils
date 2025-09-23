import 'package:flutter/material.dart';

class PageIndicatorDotWidget extends StatelessWidget {
  const PageIndicatorDotWidget({
    super.key,
    required this.controller,
    required this.count,
    this.onDotClicked,
    this.axisDirection = Axis.horizontal,
    this.spacing = 8.0,
    this.dotHeight = 8.0,
    this.dotWidth = 8.0,
    this.expansionFactor = 32.0,
    this.duration = const Duration(milliseconds: 0),
    required this.dotColor,
    required this.activeDotColor,
  });

  final PageController controller;
  final int count;
  final VoidCallback? onDotClicked;
  final Axis axisDirection;
  final Duration duration;
  final double spacing;
  final double dotHeight;
  final double dotWidth;
  final double expansionFactor;
  final Color dotColor, activeDotColor;

  @override
  Widget build(BuildContext context) {
    // حساب صحيح للحجم الإجمالي
    if (axisDirection == Axis.vertical) {
      final double totalHeight = _calculateTotalSize(false);
      return SizedBox(
        height: totalHeight,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: _buildDots(false),
        ),
      );
    }

    final double totalWidth = _calculateTotalSize(true);
  
    return SizedBox(
      width: totalWidth,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: _buildDots(true),
      ),
    );
  }

  // حساب الحجم الإجمالي بدقة
  double _calculateTotalSize(bool isHorizontal) {
    final double normalDotSize = isHorizontal ? dotWidth : dotHeight;
    final double totalNormalDots = (count - 1) * normalDotSize;
    final double totalSpacing = (count - 1) * spacing;

    return totalNormalDots + expansionFactor + totalSpacing;
  }

  // بناء النقاط مع spacing صحيح
  List<Widget> _buildDots(bool isHorizontal) {
    final List<Widget> dots = [];

    for (int i = 0; i < count; i++) {
      dots.add(
        AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            return buildDot(i, isHorizontal);
          },
        ),
      );

      // إضافة spacing بين النقاط (ما عدا النقطة الأخيرة)
      if (i < count - 1) {
        dots.add(SizedBox(width: isHorizontal ? spacing : 0, height: isHorizontal ? 0 : spacing));
      }
    }

    return dots;
  }

  Widget buildDot(int index, bool isHorizontal) {
    double currentPage = 0;

    if (controller.hasClients) {
      currentPage = controller.page ?? 0;
    }

    // حساب مدى قرب النقطة من النقطة النشطة للانتقال السلس
    final double distance = (currentPage - index).abs();
    final double animationValue = (1 - distance).clamp(0.0, 1.0);

    // تحريك سلس بين الأحجام
    final double dotSize = dotHeight + (expansionFactor - dotHeight) * animationValue;

    // تحريك سلس بين الألوان
    final Color interpolatedColor = Color.lerp(dotColor, activeDotColor, animationValue)!;

    return GestureDetector(
      onTap: onDotClicked,
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeInOut,
        height: isHorizontal ? dotHeight : dotSize,
        width: isHorizontal ? dotSize : dotWidth,
        decoration: BoxDecoration(
          color: interpolatedColor,
          borderRadius: BorderRadius.circular(dotSize / 2),
        ),
      ),
    );
  }
}
