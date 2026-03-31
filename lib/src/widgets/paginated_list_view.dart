import 'package:flutter/material.dart';

import 'load_more_widget.dart';
import 'skeletonizer_widget.dart';

class _PaginatedListContent<T> extends StatelessWidget {
  const _PaginatedListContent({
    required this.scrollController,
    required this.items,
    required this.isLoading,
    required this.isLoadMore,
    required this.itemBuilder,
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
  final EdgeInsets? padding;
  final Color? shimmerBaseColor;
  final Color? shimmerContainersColor;
  final Color? loadMoreIndicatorColor;
  final Color? loadMoreBackgroundColor;

  @override
  Widget build(BuildContext context) {
    return SkeletonizerWidget(
      isLoading: isLoading,
      shimmerBaseColor: shimmerBaseColor,
      containersColor: shimmerContainersColor,
      child: ListView.builder(
        controller: scrollController,
        padding: padding ??
            const EdgeInsets.symmetric(horizontal: 20.0, vertical: 32.0),
        itemCount: items.length + 1,
        itemBuilder: (context, index) {
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
  });

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

  // ─── ألوان اختيارية ──────────────────────────────────────────────────────

  /// لون shimmer الأساسي — يعتمد على `colorScheme.onSurface` إذا لم يُمرَّر
  final Color? shimmerBaseColor;

  /// لون خلفية الـ containers في skeleton — يعتمد على `colorScheme.surface`
  final Color? shimmerContainersColor;

  /// لون مؤشر تحميل المزيد — يعتمد على `colorScheme.primary`
  final Color? loadMoreIndicatorColor;

  /// لون خلفية مؤشر تحميل المزيد — يعتمد على `colorScheme.surfaceContainerHighest`
  final Color? loadMoreBackgroundColor;

  @override
  State<PaginatedListView<T>> createState() => _PaginatedListViewState<T>();
}

class _PaginatedListViewState<T> extends State<PaginatedListView<T>> {
  late final ScrollController _scrollController;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.scrollController != null) {
      _scrollController = widget.scrollController!;
    } else {
      _scrollController = ScrollController();
      _ownsController = true;
    }
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
    if (!widget.canLoadMore || widget.isLoadMore) return;

    final remaining = _scrollController.position.maxScrollExtent -
        _scrollController.position.pixels;

    if (remaining <= 200.0) widget.onLoadMore();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onRefresh != null) {
      return RefreshIndicator(
        onRefresh: widget.onRefresh!,
        child: _PaginatedListContent<T>(
          scrollController: _scrollController,
          items: widget.items,
          isLoading: widget.isLoading,
          isLoadMore: widget.isLoadMore,
          padding: widget.padding,
          itemBuilder: widget.itemBuilder,
          shimmerBaseColor: widget.shimmerBaseColor,
          shimmerContainersColor: widget.shimmerContainersColor,
          loadMoreIndicatorColor: widget.loadMoreIndicatorColor,
          loadMoreBackgroundColor: widget.loadMoreBackgroundColor,
        ),
      );
    }

    return _PaginatedListContent<T>(
      scrollController: _scrollController,
      items: widget.items,
      isLoading: widget.isLoading,
      isLoadMore: widget.isLoadMore,
      padding: widget.padding,
      itemBuilder: widget.itemBuilder,
      shimmerBaseColor: widget.shimmerBaseColor,
      shimmerContainersColor: widget.shimmerContainersColor,
      loadMoreIndicatorColor: widget.loadMoreIndicatorColor,
      loadMoreBackgroundColor: widget.loadMoreBackgroundColor,
    );
  }
}
