import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../entities/base_entity.dart';

/// Widget يُعرض في نهاية القائمة لإظهار حالة تحميل المزيد.
///
/// [indicatorColor] و [indicatorBackgroundColor] — اختيارية، تعتمد
/// على `Theme.of(context).colorScheme` كـ fallback.
class LoadMoreWidget extends StatelessWidget {
  const LoadMoreWidget({
    super.key,
    required this.isLoadMore,
    this.topPadding = 24.0,
    this.indicatorColor,
    this.indicatorBackgroundColor,
  });

  final bool isLoadMore;
  final double topPadding;
  final Color? indicatorColor;
  final Color? indicatorBackgroundColor;

  @override
  Widget build(BuildContext context) {
    if (isLoadMore) {
      return Padding(
        padding: EdgeInsets.only(bottom: 64.0, top: topPadding),
        child: LoadMoreIndicatorWidget(
          color: indicatorColor,
          backgroundColor: indicatorBackgroundColor,
        ),
      );
    }

    return const SizedBox(height: 40.0);
  }

  static void _checkAndTriggerLoadMore({
    required ScrollPosition position,
    required Function onLoadMore,
    double offsetFromBottom = 200.0,
  }) {
    final double remainingDistance =
        position.maxScrollExtent - position.pixels;
    if (remainingDistance <= offsetFromBottom) {
      onLoadMore();
    }
  }

  static void onScroll({
    required ScrollController controller,
    required BaseEntity base,
    required Map<String, dynamic> filters,
    required bool isLoadMore,
    required Function onLoadMore,
    double offsetFromBottom = 200.0,
  }) {
    if (!controller.hasClients) return;

    final bool canLoadMore = base.count != 0 &&
        base.count > base.results.length &&
        base.next.isNotEmpty;

    if (!canLoadMore || isLoadMore || base.results.isEmpty) return;

    _checkAndTriggerLoadMore(
      position: controller.position,
      onLoadMore: onLoadMore,
      offsetFromBottom: offsetFromBottom,
    );
  }
}

/// مؤشر دوار يُعرض أثناء تحميل المزيد من البيانات.
class LoadMoreIndicatorWidget extends StatelessWidget {
  const LoadMoreIndicatorWidget({
    super.key,
    this.color,
    this.backgroundColor,
  });

  final Color? color;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 44.0,
          height: 44.0,
          constraints: const BoxConstraints(
            maxWidth: 44.0,
            maxHeight: 44.0,
            minWidth: 44.0,
            minHeight: 44.0,
          ),
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: backgroundColor ?? colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(100),
          ),
          child: CupertinoActivityIndicator(
            color: color ?? colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
