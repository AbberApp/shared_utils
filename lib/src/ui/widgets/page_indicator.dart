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
    this.animationDuration = const Duration(milliseconds: 400),
    this.fillPreviousDots = false,
  });

  final PageController controller;
  final int count;
  final VoidCallback? onDotClicked;
  final Axis axis;

  /// مدّة انتقال النقطة بين حالتَي الصغر والامتداد. `Duration.zero` تعني
  /// انتقالاً فورياً بلا انيميشن.
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
    // قائمة فارغة قادمة من الـ API حالة طبيعية لا استثنائية، وبلا هذا الحارس
    // يصير totalSize سالباً مع قيم dotSize/spacing شائعة فترفضه BoxConstraints
    if (count <= 0) return const SizedBox.shrink();

    final isHorizontal = axis == Axis.horizontal;
    final totalSize = (count - 1) * (dotSize + spacing) + expandedSize;

    // `totalSize` يكبر خطّياً مع `count`، فمع عددٍ كبير من الصفحات يتجاوز
    // المساحة المتاحة فيرمي `Flex` خطأ RenderFlex overflow ويقطع شريط النقاط.
    // `BoxFit.scaleDown` يصغّر الشريط كلّه إلى ما يسع — ولا أثر له إطلاقاً حين
    // يتّسع المكان (المقياس 1)، فالأحجام المعتادة تبقى كما هي بالضبط.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
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
      duration: widget.animationDuration,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    // `initialPage` قيمة المُنشئ لا الصفحة المعروضة فعلاً. فلو رُكّب المؤشّر
    // بعد أن تحرّك الـPageView — إظهارٌ مشروط، تبديل تبويب يعيد بناء الشجرة،
    // أو استئناف شاشة محفوظة بـPageStorage — لبدأت النقطة الأولى نشطةً
    // وممتدّةً والمستخدم على صفحةٍ أخرى، ولا يُصحَّح ذلك أبداً لأنّ
    // `_onPageScroll` لا يُستدعى إلا عند تمريرٍ فعليّ. فنقرأ الموضع الحقيقي
    // متى كان المتحكّم مرتبطاً، ونسقط إلى `initialPage` قبل الارتباط.
    _currentPage = widget.controller.hasClients
        ? (widget.controller.page ?? widget.controller.initialPage.toDouble())
        : widget.controller.initialPage.toDouble();
    _targetValue = _calculateTargetValue(_currentPage);
    _controller.value = _targetValue;

    widget.controller.addListener(_onPageScroll);

    // حين يُبنى المؤشّر مع الـPageView في الإطار نفسه لا يكون المتحكّم مرتبطاً
    // بعدُ في initState، فنعيد القراءة مرّةً بعد أوّل إطار لضبط الحالة الأولى
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onPageScroll();
    });
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
      // اللون المعبّأ يقرأ floor(_currentPage) في build، وإعادة البناء الوحيدة
      // تأتي من AnimatedBuilder الذي لا يتحرّك حين يبقى هدف هذه النقطة كما هو
      // (قفزة بعيدة مثلاً)، فنطلب البناء صراحةً عند تغيّر الصفحة الصحيحة
      if (mounted &&
          widget.fillPreviousDots &&
          _currentPage.floor() != currentPage.floor()) {
        setState(() => _currentPage = currentPage);
      } else {
        _currentPage = currentPage;
      }
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
    // المدّة تُقرأ مرّةً عند الإنشاء، فتغييرها بعد التركيب (ثيمٌ متحرّك، أو
    // إطفاء الانيميشن عند تفضيل تقليل الحركة) يلزمه تحديث المتحكّم صراحةً.
    if (oldWidget.animationDuration != widget.animationDuration) {
      _controller.duration = widget.animationDuration;
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
