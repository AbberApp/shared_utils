import 'package:flutter/material.dart';

import 'load_more_widget.dart';
import 'skeletonizer_widget.dart';

/// قائمة مُرقَّمة جاهزة تدير [ScrollController] داخلياً وتعرض:
/// - [SkeletonizerWidget] أثناء التحميل الأولي
/// - [RefreshIndicator] للسحب للتحديث إذا مُرِّر [onRefresh]
/// - [LoadMoreWidget] في نهاية القائمة
///
/// ### الألوان
/// جميع معاملات الألوان اختيارية — عند إهمالها تُستخدم ألوان
/// `Theme.of(context).colorScheme` تلقائياً.
class PaginatedListView<T> extends StatefulWidget {
  const PaginatedListView({
    super.key,
    required this.items,
    required this.isLoading,
    required this.isLoadMore,
    required this.canLoadMore,
    required this.onLoadMore,
    required this.itemBuilder,
    this.onRefresh,
    this.padding,
    this.scrollController,
    this.shimmerBaseColor,
    this.shimmerContainersColor,
    this.loadMoreIndicatorColor,
    this.loadMoreBackgroundColor,
    this.skeletonItemCount = 6,
    this.skeletonItemBuilder,
  }) : assert(skeletonItemCount >= 0, 'skeletonItemCount لا يكون سالباً');

  final List<T> items;

  /// تحميل أولي — يُظهر الـ Skeleton
  final bool isLoading;

  /// تحميل صفحة إضافية — يُظهر [LoadMoreWidget] في الأسفل
  final bool isLoadMore;

  /// هل يوجد المزيد من البيانات للتحميل
  final bool canLoadMore;

  /// يُستدعى عند الوصول لنهاية القائمة
  final VoidCallback onLoadMore;

  /// يُستدعى عند السحب للتحديث — إذا كان null لا يُعرض [RefreshIndicator]
  final Future<void> Function()? onRefresh;

  final Widget Function(BuildContext context, T item) itemBuilder;

  final EdgeInsets? padding;

  /// [ScrollController] خارجي اختياري — إذا لم يُمرَّر يُنشأ داخلياً
  final ScrollController? scrollController;

  // ─── الـ Skeleton ────────────────────────────────────────────────────────

  /// عدد العناصر الوهمية المرسومة أثناء التحميل الأولي حين تكون [items] فارغة
  final int skeletonItemCount;

  /// شكل العنصر الوهمي أثناء التحميل الأولي — إذا لم يُمرَّر يُستخدم شكل
  /// محايد جاهز. مرّره ليطابق الهيكل شكل البطاقة الحقيقية
  final Widget Function(BuildContext context)? skeletonItemBuilder;

  // ─── ألوان اختيارية ──────────────────────────────────────────────────────

  /// لون shimmer الأساسي — يعتمد على `colorScheme.surfaceTint` إذا لم يُمرَّر
  final Color? shimmerBaseColor;

  /// لون خلفية الـ containers في skeleton — يعتمد على `colorScheme.surface`
  final Color? shimmerContainersColor;

  /// لون مؤشر تحميل المزيد — يعتمد على `colorScheme.primary`
  final Color? loadMoreIndicatorColor;

  /// لون خلفية مؤشر تحميل المزيد — يعتمد على `colorScheme.secondary`
  final Color? loadMoreBackgroundColor;

  @override
  State<PaginatedListView<T>> createState() => _PaginatedListViewState<T>();
}

class _PaginatedListViewState<T> extends State<PaginatedListView<T>> {
  static const double _loadMoreOffset = 200.0;

  late ScrollController _scrollController;
  bool _ownsController = false;

  /// يمنع إطلاق [PaginatedListView.onLoadMore] مرّات متتالية من أحداث التمرير
  /// قبل أن ينعكس الطلب في الحالة. يُخفَض حالما يخرج المستخدم من منطقة العتبة
  /// أو تتغيّر البيانات، فلا يعلق أبداً في وضعٍ يمنع التحميل.
  bool _loadMoreRequested = false;

  @override
  void initState() {
    super.initState();
    _attachController(widget.scrollController);
  }

  @override
  void didUpdateWidget(covariant PaginatedListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // الأب قد يستبدل المتحكّم عند إعادة البناء (تبديل تبويب أو تغيّر مفتاح)؛
    // التمسّك بالقديم يترك القائمة مربوطة بمتحكّمٍ قد يتخلّص منه الأب.
    if (oldWidget.scrollController != widget.scrollController) {
      _scrollController.removeListener(_onScroll);
      if (_ownsController) _scrollController.dispose();
      _attachController(widget.scrollController);
    }

    if (oldWidget.items.length != widget.items.length ||
        oldWidget.isLoadMore != widget.isLoadMore ||
        oldWidget.canLoadMore != widget.canLoadMore) {
      _loadMoreRequested = false;
    }
  }

  void _attachController(ScrollController? external) {
    _ownsController = external == null;
    _scrollController = external ?? ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    if (_ownsController) _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    // isLoading أيضاً: أثناء التحديث (سحب للأسفل) تبقى القائمة معروضة وقابلة
    // للتمرير، فينطلق طلب صفحةٍ تالية بالتوازي مع طلب الصفحة الأولى.
    if (widget.isLoading || widget.isLoadMore || !widget.canLoadMore) return;

    final remaining =
        _scrollController.position.maxScrollExtent -
        _scrollController.position.pixels;

    if (remaining > _loadMoreOffset) {
      _loadMoreRequested = false;
      return;
    }

    if (_loadMoreRequested) return;
    _loadMoreRequested = true;
    widget.onLoadMore();
  }

  @override
  Widget build(BuildContext context) {
    final content = _PaginatedListContent<T>(
      scrollController: _scrollController,
      items: widget.items,
      isLoading: widget.isLoading,
      isLoadMore: widget.isLoadMore,
      padding: widget.padding,
      itemBuilder: widget.itemBuilder,
      skeletonItemCount: widget.skeletonItemCount,
      skeletonItemBuilder: widget.skeletonItemBuilder,
      shimmerBaseColor: widget.shimmerBaseColor,
      shimmerContainersColor: widget.shimmerContainersColor,
      loadMoreIndicatorColor: widget.loadMoreIndicatorColor,
      loadMoreBackgroundColor: widget.loadMoreBackgroundColor,
    );

    if (widget.onRefresh != null) {
      return RefreshIndicator(onRefresh: widget.onRefresh!, child: content);
    }

    return content;
  }
}

class _PaginatedListContent<T> extends StatelessWidget {
  const _PaginatedListContent({
    required this.scrollController,
    required this.items,
    required this.isLoading,
    required this.isLoadMore,
    required this.itemBuilder,
    required this.skeletonItemCount,
    this.skeletonItemBuilder,
    this.padding,
    this.shimmerBaseColor,
    this.shimmerContainersColor,
    this.loadMoreIndicatorColor,
    this.loadMoreBackgroundColor,
  });

  final ScrollController scrollController;
  final List<T> items;
  final bool isLoading;
  final bool isLoadMore;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final int skeletonItemCount;
  final Widget Function(BuildContext context)? skeletonItemBuilder;
  final EdgeInsets? padding;
  final Color? shimmerBaseColor;
  final Color? shimmerContainersColor;
  final Color? loadMoreIndicatorColor;
  final Color? loadMoreBackgroundColor;

  @override
  Widget build(BuildContext context) {
    // الـ Skeletonizer يرسم هياكل العناصر المعروضة؛ وفي التحميل الأولي تكون
    // القائمة فارغة فلا يجد ما يرسمه وتظهر شاشة خالية. نرسم عناصر وهمية.
    final bool showSkeleton = isLoading && items.isEmpty;

    return SkeletonizerWidget(
      isLoading: isLoading,
      shimmerBaseColor: shimmerBaseColor,
      containersColor: shimmerContainersColor,
      child: ListView.builder(
        controller: scrollController,
        padding:
            padding ??
            const EdgeInsets.symmetric(horizontal: 20.0, vertical: 32.0),
        itemCount: showSkeleton ? skeletonItemCount : items.length + 1,
        itemBuilder: (context, index) {
          if (showSkeleton) {
            return skeletonItemBuilder?.call(context) ??
                const _DefaultSkeletonItem();
          }

          if (index == items.length) {
            return LoadMoreWidget(
              isLoadMore: isLoadMore,
              indicatorColor: loadMoreIndicatorColor,
              indicatorBackgroundColor: loadMoreBackgroundColor,
            );
          }
          return itemBuilder(context, items[index]);
        },
      ),
    );
  }
}

/// عنصر وهمي محايد (صورة مصغّرة وسطران) يحوّله [SkeletonizerWidget] إلى هيكل
/// shimmer أثناء التحميل الأولي حين لا يمرّر المستهلك شكلاً خاصاً به.
class _DefaultSkeletonItem extends StatelessWidget {
  const _DefaultSkeletonItem();

  @override
  Widget build(BuildContext context) {
    final Color color = Theme.of(context).colorScheme.surfaceContainerHighest;
    final BorderRadius radius = BorderRadius.circular(8.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56.0,
            height: 56.0,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12.0),
            ),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14.0,
                  decoration: BoxDecoration(color: color, borderRadius: radius),
                ),
                const SizedBox(height: 10.0),
                Container(
                  height: 14.0,
                  width: 160.0,
                  decoration: BoxDecoration(color: color, borderRadius: radius),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
