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
    this.fillPreviousDots = false,
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

  /// عند التفعيل، النقاط السابقة للصفحة الحالية تأخذ لون [activeDotColor] مع حجم [dotSize]
  final bool fillPreviousDots;

  @override
  Widget build(BuildContext context) {
    final isHorizontal = axis == Axis.horizontal;
    final totalSize = (count - 1) * dotSize + (count - 1) * spacing + expandedSize;

    return SizedBox(
      width: isHorizontal ? totalSize : null,
      height: isHorizontal ? null : totalSize,
      child: Flex(
        direction: axis,
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < count; i++) ...[
            _Dot(
              index: i,
              controller: controller,
              isHorizontal: isHorizontal,
              dotSize: dotSize,
              expandedSize: expandedSize,
              dotColor: dotColor,
              activeDotColor: activeDotColor,
              animationDuration: animationDuration,
              fillPreviousDots: fillPreviousDots,
              onTap: onDotClicked,
            ),
            if (i < count - 1)
              SizedBox(
                width: isHorizontal ? spacing : 0,
                height: isHorizontal ? 0 : spacing,
              ),
          ],
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  const _Dot({
    required this.index,
    required this.controller,
    required this.isHorizontal,
    required this.dotSize,
    required this.expandedSize,
    required this.dotColor,
    required this.activeDotColor,
    required this.animationDuration,
    required this.fillPreviousDots,
    this.onTap,
  });

  final int index;
  final PageController controller;
  final bool isHorizontal;
  final double dotSize;
  final double expandedSize;
  final Color dotColor;
  final Color activeDotColor;
  final Duration animationDuration;
  final bool fillPreviousDots;
  final VoidCallback? onTap;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> {
  double _animationValue = 0;
  double _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.controller.initialPage.toDouble();
    _animationValue = _calculateAnimationValue(_currentPage);
    widget.controller.addListener(_onPageScroll);
  }

  double _calculateAnimationValue(double currentPage) {
    final distance = (currentPage - widget.index).abs();
    return (1 - distance).clamp(0.0, 1.0);
  }

  void _onPageScroll() {
    if (!widget.controller.hasClients) return;

    final currentPage = widget.controller.page ?? _currentPage;
    final newValue = _calculateAnimationValue(currentPage);

    if (_animationValue != newValue || _currentPage != currentPage) {
      setState(() {
        _animationValue = newValue;
        _currentPage = currentPage;
      });
    }
  }

  @override
  void didUpdateWidget(_Dot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onPageScroll);
      widget.controller.addListener(_onPageScroll);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onPageScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentSize =
        widget.dotSize + (widget.expandedSize - widget.dotSize) * _animationValue;

    // تحديد اللون بناءً على الموقع
    final Color currentColor;
    if (widget.fillPreviousDots && widget.index < _currentPage.floor()) {
      // النقاط السابقة تأخذ activeDotColor
      currentColor = widget.activeDotColor;
    } else {
      // النقطة الحالية والقادمة تتدرج بشكل طبيعي
      currentColor =
          Color.lerp(widget.dotColor, widget.activeDotColor, _animationValue)!;
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: widget.animationDuration,
        curve: Curves.easeOutCubic,
        height: widget.isHorizontal ? widget.dotSize : currentSize,
        width: widget.isHorizontal ? currentSize : widget.dotSize,
        decoration: BoxDecoration(
          color: currentColor,
          borderRadius: BorderRadius.circular(currentSize / 2),
        ),
      ),
    );
  }
}
