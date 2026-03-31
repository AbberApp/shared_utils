import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Widget يعرض تأثير skeleton أثناء التحميل.
///
/// [shimmerBaseColor] — لون shimmer الأساسي. إذا لم يُمرَّر يستخدم
/// `colorScheme.onSurface` بشفافية منخفضة.
///
/// [containersColor] — لون خلفية الـ containers عند [ignoreContainers].
/// إذا لم يُمرَّر يستخدم `colorScheme.surface`.
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
      containersColor: ignoreContainers
          ? (containersColor ?? colorScheme.surface)
          : null,
      effect: ShimmerEffect(
        baseColor: shimmerBaseColor ?? colorScheme.surfaceTint,
        duration: const Duration(milliseconds: 900),
      ),
      child: child,
    );
  }
}
