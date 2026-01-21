import 'package:flutter/material.dart';

/// مؤشر نقطي للصفحات مع انيميشن سلس
class PageIndicator extends StatefulWidget {
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
  State<PageIndicator> createState() => _PageIndicatorState();
}

class _PageIndicatorState extends State<PageIndicator> {
  late double _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.controller.initialPage.toDouble();
    widget.controller.addListener(_onPageChanged);
  }

  @override
  void didUpdateWidget(PageIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onPageChanged);
      widget.controller.addListener(_onPageChanged);
      _currentPage = widget.controller.initialPage.toDouble();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onPageChanged);
    super.dispose();
  }

  void _onPageChanged() {
    if (widget.controller.hasClients) {
      setState(() {
        _currentPage = widget.controller.page ?? _currentPage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHorizontal = widget.axis == Axis.horizontal;
    final totalNormalDots = (widget.count - 1) * widget.dotSize;
    final totalSpacing = (widget.count - 1) * widget.spacing;
    final totalSize = totalNormalDots + widget.expandedSize + totalSpacing;

    return RepaintBoundary(
      child: SizedBox(
        width: isHorizontal ? totalSize : widget.dotSize,
        height: isHorizontal ? widget.dotSize : totalSize,
        child: Flex(
          direction: widget.axis,
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < widget.count; i++)
              _DotWidget(
                key: ValueKey(i),
                index: i,
                currentPage: _currentPage,
                isHorizontal: isHorizontal,
                dotSize: widget.dotSize,
                expandedSize: widget.expandedSize,
                dotColor: widget.dotColor,
                activeDotColor: widget.activeDotColor,
                animationDuration: widget.animationDuration,
                spacing: i == widget.count - 1 ? 0 : widget.spacing,
                onTap: widget.onDotClicked != null
                    ? () => widget.onDotClicked!(i)
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _DotWidget extends StatelessWidget {
  const _DotWidget({
    super.key,
    required this.index,
    required this.currentPage,
    required this.isHorizontal,
    required this.dotSize,
    required this.expandedSize,
    required this.dotColor,
    required this.activeDotColor,
    required this.animationDuration,
    required this.spacing,
    this.onTap,
  });

  final int index;
  final double currentPage;
  final bool isHorizontal;
  final double dotSize;
  final double expandedSize;
  final Color dotColor;
  final Color activeDotColor;
  final Duration animationDuration;
  final double spacing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final distance = (currentPage - index).abs();
    final animationValue = (1 - distance).clamp(0.0, 1.0);
    final currentDotSize = dotSize + (expandedSize - dotSize) * animationValue;
    final interpolatedColor = Color.lerp(dotColor, activeDotColor, animationValue)!;

    return Padding(
      padding: EdgeInsetsDirectional.only(
        end: isHorizontal ? spacing : 0,
        bottom: isHorizontal ? 0 : spacing,
      ),
      child: GestureDetector(
        onTap: onTap,
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
