import 'package:flutter/material.dart';

/// إعدادات الشبكة المتجاوبة.
///
/// تحدد أبعاد العنصر الدقيقة كما في التصميم.
class GridConfig {
  const GridConfig({
    required this.itemWidth,
    required this.itemHeight,
    this.crossAxisSpacing = 12.0,
    this.mainAxisSpacing = 12.0,
    this.minCrossAxisCount = 2,
    this.maxCrossAxisCount = 6,
    this.rowCount,
  }) : // الأبعاد صفراً أو سالبة تمرّ صامتةً هنا ثمّ تنفجر بعيداً داخل مندوب
       // الشبكة على `assert(childAspectRatio > 0)` — خطأٌ لا يدلّ على مصدره.
       // نرفضها عند الإنشاء حيث الخطأ ما يزال واضح النسبة إلى مُنشئه.
       assert(itemWidth > 0, 'itemWidth يجب أن يكون أكبر من صفر'),
       assert(itemHeight > 0, 'itemHeight يجب أن يكون أكبر من صفر'),
       // min > max يجعل clamp يرمي ArgumentError غامضاً أثناء البناء.
       assert(
         minCrossAxisCount <= maxCrossAxisCount,
         'minCrossAxisCount يجب ألّا يتجاوز maxCrossAxisCount',
       );

  /// عرض العنصر كما في التصميم.
  final double itemWidth;

  /// ارتفاع العنصر كما في التصميم.
  final double itemHeight;

  /// المسافة الأفقية بين العناصر.
  final double crossAxisSpacing;

  /// المسافة العمودية بين العناصر.
  final double mainAxisSpacing;

  /// أقل عدد أعمدة.
  final int minCrossAxisCount;

  /// أكثر عدد أعمدة.
  final int maxCrossAxisCount;

  /// عدد الصفوف (اختياري). إذا كان null يعرض جميع العناصر.
  final int? rowCount;

  /// نسبة العرض إلى الارتفاع.
  double get childAspectRatio => itemWidth / itemHeight;
}

/// شبكة متجاوبة تحسب عدد الأعمدة تلقائياً بناءً على المساحة المتاحة.
///
/// مثال:
/// ```dart
/// ResponsiveGridView(
///   config: const GridConfig(
///     itemWidth: 160,
///     itemHeight: 200,
///     crossAxisSpacing: 12,
///     mainAxisSpacing: 12,
///   ),
///   itemCount: items.length,
///   itemBuilder: (context, index) => ItemCard(item: items[index]),
/// )
/// ```
class ResponsiveGridView extends StatelessWidget {
  const ResponsiveGridView({
    super.key,
    required this.config,
    required this.itemCount,
    required this.itemBuilder,
    this.shrinkWrap = true,
    this.physics = const NeverScrollableScrollPhysics(),
    this.padding,
  });

  /// إعدادات الشبكة.
  final GridConfig config;

  /// عدد العناصر.
  final int itemCount;

  /// بناء العنصر.
  final Widget Function(BuildContext context, int index) itemBuilder;

  /// تقليص حجم الشبكة. الافتراضي true.
  final bool shrinkWrap;

  /// فيزياء التمرير. الافتراضي NeverScrollableScrollPhysics.
  final ScrollPhysics physics;

  /// الحشوة حول الشبكة.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gridWidth = constraints.maxWidth;

        // حساب عدد الأعمدة بناءً على عرض العنصر.
        // القسمة هنا قد تنتج Infinity أو NaN: العرض المتاح يكون لانهائياً تحت
        // أبٍ بعرض غير محدود (Row بلا Expanded، أو قائمة أفقية)، والمقام يكون
        // صفراً بإعدادٍ حدّي. و floor() على أيٍّ منهما يرمي UnsupportedError،
        // لذا نحسم الحالتين قبل التحويل إلى int.
        // مندوب الشبكة يفرض عموداً واحداً على الأقلّ، فـ `minCrossAxisCount: 0`
        // على شاشةٍ أضيق من عنصرٍ واحد يُنزل الناتج إلى صفر فينفجر assert
        // داخله. نرفع الحدّ الأدنى الفعليّ إلى 1، ونرفع الأعلى إليه إن خالفه
        // — فـ clamp يرمي حين min > max، والـ assert أعلاه مطفأ في الإصدار.
        final int minCount = config.minCrossAxisCount < 1
            ? 1
            : config.minCrossAxisCount;
        final int maxCount = config.maxCrossAxisCount < minCount
            ? minCount
            : config.maxCrossAxisCount;

        final double columnExtent = config.itemWidth + config.crossAxisSpacing;
        final double rawCrossAxisCount = columnExtent <= 0
            ? minCount.toDouble()
            : (gridWidth + config.crossAxisSpacing) / columnExtent;
        final int crossAxisCount =
            (rawCrossAxisCount.isFinite
                    ? rawCrossAxisCount.floor()
                    : maxCount)
                .clamp(minCount, maxCount);

        // حساب عدد العناصر المعروضة
        final int displayItemCount = config.rowCount != null
            ? (config.rowCount! * crossAxisCount).clamp(0, itemCount)
            : itemCount;

        return GridView.builder(
          shrinkWrap: shrinkWrap,
          physics: physics,
          padding: padding,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: config.crossAxisSpacing,
            mainAxisSpacing: config.mainAxisSpacing,
            childAspectRatio: config.childAspectRatio,
          ),
          itemCount: displayItemCount,
          itemBuilder: itemBuilder,
        );
      },
    );
  }
}
