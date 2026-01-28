import 'package:flutter/material.dart';

/// A responsive grid view widget that automatically calculates
/// the number of columns based on available width.
///
/// This widget uses [LayoutBuilder] to determine the available width
/// and calculates the optimal number of columns based on [maxItemWidth].
///
/// Example usage:
/// ```dart
/// ResponsiveGridView(
///   maxItemWidth: 200,
///   itemCount: items.length,
///   itemBuilder: (context, index) => ItemCard(item: items[index]),
/// )
/// ```
class ResponsiveGridView extends StatelessWidget {
  const ResponsiveGridView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.maxItemWidth = 200.0,
    this.crossAxisSpacing = 12.0,
    this.mainAxisSpacing = 12.0,
    this.childAspectRatio = 1.0,
    this.minCrossAxisCount = 2,
    this.maxCrossAxisCount = 6,
    this.rowCount,
    this.shrinkWrap = true,
    this.physics = const NeverScrollableScrollPhysics(),
    this.padding,
  });

  /// Total number of items in the grid.
  final int itemCount;

  /// Builder function for each item.
  final Widget Function(BuildContext context, int index) itemBuilder;

  /// Maximum width for each item. Used to calculate column count.
  /// Default is 200.0.
  final double maxItemWidth;

  /// Horizontal spacing between items. Default is 12.0.
  final double crossAxisSpacing;

  /// Vertical spacing between items. Default is 12.0.
  final double mainAxisSpacing;

  /// Width to height ratio of each item. Default is 1.0 (square).
  final double childAspectRatio;

  /// Minimum number of columns. Default is 2.
  final int minCrossAxisCount;

  /// Maximum number of columns. Default is 6.
  final int maxCrossAxisCount;

  /// Optional: Limit the grid to a specific number of rows.
  /// If null, all items will be displayed.
  final int? rowCount;

  /// Whether the grid should shrink wrap its contents. Default is true.
  final bool shrinkWrap;

  /// Scroll physics. Default is [NeverScrollableScrollPhysics].
  final ScrollPhysics physics;

  /// Padding around the grid.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gridWidth = constraints.maxWidth;

        // Calculate optimal column count based on available width
        final int crossAxisCount = ((gridWidth + crossAxisSpacing) /
                (maxItemWidth + crossAxisSpacing))
            .floor()
            .clamp(minCrossAxisCount, maxCrossAxisCount);

        // Calculate actual item count (limited by rowCount if specified)
        final int displayItemCount = rowCount != null
            ? (rowCount! * crossAxisCount).clamp(0, itemCount)
            : itemCount;

        return GridView.builder(
          shrinkWrap: shrinkWrap,
          physics: physics,
          padding: padding,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: crossAxisSpacing,
            mainAxisSpacing: mainAxisSpacing,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: displayItemCount,
          itemBuilder: itemBuilder,
        );
      },
    );
  }
}

/// A variant of [ResponsiveGridView] that uses [maxCrossAxisExtent]
/// instead of calculating columns from [maxItemWidth].
///
/// This is useful when you want more precise control over item sizing.
class ResponsiveGridViewExtent extends StatelessWidget {
  const ResponsiveGridViewExtent({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.maxCrossAxisExtent = 100.0,
    this.crossAxisSpacing = 12.0,
    this.mainAxisSpacing = 12.0,
    this.childAspectRatio = 1.0,
    this.rowCount,
    this.shrinkWrap = true,
    this.physics = const NeverScrollableScrollPhysics(),
    this.padding,
  });

  /// Total number of items in the grid.
  final int itemCount;

  /// Builder function for each item.
  final Widget Function(BuildContext context, int index) itemBuilder;

  /// Maximum extent (width) for each item in the cross axis.
  /// Default is 100.0.
  final double maxCrossAxisExtent;

  /// Horizontal spacing between items. Default is 12.0.
  final double crossAxisSpacing;

  /// Vertical spacing between items. Default is 12.0.
  final double mainAxisSpacing;

  /// Width to height ratio of each item. Default is 1.0 (square).
  final double childAspectRatio;

  /// Optional: Limit the grid to a specific number of rows.
  /// If null, all items will be displayed.
  final int? rowCount;

  /// Whether the grid should shrink wrap its contents. Default is true.
  final bool shrinkWrap;

  /// Scroll physics. Default is [NeverScrollableScrollPhysics].
  final ScrollPhysics physics;

  /// Padding around the grid.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gridWidth = constraints.maxWidth;

        // Calculate column count for rowCount limitation
        final int crossAxisCount =
            ((gridWidth + crossAxisSpacing) / (maxCrossAxisExtent + crossAxisSpacing))
                .floor()
                .clamp(2, 10);

        // Calculate actual item count (limited by rowCount if specified)
        final int displayItemCount = rowCount != null
            ? (rowCount! * crossAxisCount).clamp(0, itemCount)
            : itemCount;

        return GridView.builder(
          shrinkWrap: shrinkWrap,
          physics: physics,
          padding: padding,
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: maxCrossAxisExtent,
            crossAxisSpacing: crossAxisSpacing,
            mainAxisSpacing: mainAxisSpacing,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: displayItemCount,
          itemBuilder: itemBuilder,
        );
      },
    );
  }
}
