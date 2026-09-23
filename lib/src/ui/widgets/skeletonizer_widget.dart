import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Widget يعرض تأثير skeleton أثناء التحميل.
///
/// [shimmerBaseColor] — لون shimmer الأساسي. إذا لم يُمرَّر يستخدم
/// `colorScheme.surfaceTint` كما هو، بلا شفافية.
///
/// تنبيه: `surfaceTint` مشتقٌّ من اللون الأساسي ومنخفض التباين في Material 3،
/// فقد يبدو الـ shimmer شبه غير مرئيّ على خلفية فاتحة. مرِّر لوناً صريحاً
/// (مثل `AppColors.of(context).muted`) حين تريده أوضح.
///
/// [containersColor] — لون خلفية الـ containers. يُطبَّق فقط حين يكون
/// [ignoreContainers] بقيمة `false`، إذ لا تُرسم الحاويات أصلاً عند تجاهلها.
/// إذا لم يُمرَّر تبقى الحاويات بألوانها الفعلية.
class SkeletonizerWidget extends StatelessWidget {
  const SkeletonizerWidget({
    super.key,
    required this.isLoading,
    required this.child,
    this.ignoreContainers = false,
    this.shimmerBaseColor,
    this.containersColor,
  });

  final bool isLoading;
  final Widget child;
  final bool ignoreContainers;
  final Color? shimmerBaseColor;
  final Color? containersColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Skeletonizer(
      enabled: isLoading,
      justifyMultiLineText: true,
      ignoreContainers: ignoreContainers,
      ignorePointers: true,
      // الحزمة لا تقرأ containersColor إلا في فرع `!ignoreContainers`، لذا
      // يُمرَّر كما هو: يُطبَّق حين تُرسم الحاويات، ويُتجاهَل تلقائياً حين لا تُرسم.
      containersColor: containersColor,
      effect: ShimmerEffect(
        baseColor: shimmerBaseColor ?? colorScheme.surfaceTint,
        duration: const Duration(milliseconds: 900),
      ),
      child: child,
    );
  }
}
