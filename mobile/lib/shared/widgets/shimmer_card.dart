import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Shimmering placeholder card with three text-like lines, shown while a
/// list is loading. [ShimmerList] stacks several of them into a full-screen
/// loading state — the standard loading treatment for every list screen.
class ShimmerCard extends StatelessWidget {
  final double height;
  const ShimmerCard({super.key, this.height = 104});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _line(widthFactor: 0.6, height: 14),
          const SizedBox(height: 10),
          _line(widthFactor: 0.9, height: 10),
          const SizedBox(height: 8),
          _line(widthFactor: 0.4, height: 10),
        ],
      ),
    );
  }

  Widget _line({required double widthFactor, required double height}) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

/// Full-screen list of shimmering placeholder cards.
class ShimmerList extends StatelessWidget {
  final int itemCount;
  final double cardHeight;

  const ShimmerList({super.key, this.itemCount = 6, this.cardHeight = 104});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, _) => ShimmerCard(height: cardHeight),
      ),
    );
  }
}
