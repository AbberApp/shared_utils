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

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _currentPage = 0;
  double _targetValue = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _currentPage = widget.controller.initialPage.toDouble();
    _targetValue = _calculateTargetValue(_currentPage);
    _controller.value = _targetValue;

    widget.controller.addListener(_onPageScroll);
  }

  double _calculateTargetValue(double currentPage) {
    final distance = (currentPage - widget.index).abs();
    return (1 - distance).clamp(0.0, 1.0);
  }

  void _onPageScroll() {
    if (!widget.controller.hasClients) return;

    final currentPage = widget.controller.page ?? _currentPage;
    final newTarget = _calculateTargetValue(currentPage);

    if (_currentPage != currentPage) {
      _currentPage = currentPage;
    }

    if ((_targetValue - newTarget).abs() > 0.01) {
      _targetValue = newTarget;
      _controller.animateTo(_targetValue);
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
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final animationValue = _animation.value;
        final currentSize = widget.dotSize +
            (widget.expandedSize - widget.dotSize) * animationValue;

        // تحديد اللون بناءً على الموقع
        final Color currentColor;
        if (widget.fillPreviousDots && widget.index < _currentPage.floor()) {
          // النقاط السابقة تأخذ activeDotColor
          currentColor = widget.activeDotColor;
        } else {
          // النقطة الحالية والقادمة تتدرج بشكل طبيعي
          currentColor = Color.lerp(
              widget.dotColor, widget.activeDotColor, animationValue)!;
        }

        return GestureDetector(
          onTap: widget.onTap,
          child: Container(
            height: widget.isHorizontal ? widget.dotSize : currentSize,
            width: widget.isHorizontal ? currentSize : widget.dotSize,
            decoration: BoxDecoration(
              color: currentColor,
              borderRadius: BorderRadius.circular(currentSize / 2),
            ),
          ),
        );
      },
    );
  }
}
