import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonLoader extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const SkeletonLoader({
    super.key,
    this.width = double.infinity,
    this.height = 20,
    this.borderRadius = 8,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      period: const Duration(milliseconds: 1500),
      child: Container(
        width: width,
        height: height,
        margin: margin,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }

  // ── Preset: Card Skeleton ────────────────────────────────────────────────
  static Widget card({double height = 120, int count = 5}) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: count,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SkeletonLoader(width: 80, height: 14),
                  const Spacer(),
                  SkeletonLoader(width: 60, height: 20, borderRadius: 20),
                ],
              ),
              const SizedBox(height: 16),
              const SkeletonLoader(width: 200, height: 16),
              const SizedBox(height: 8),
              const SkeletonLoader(width: 150, height: 12),
              const SizedBox(height: 16),
              SkeletonLoader(height: 40, borderRadius: 10),
            ],
          ),
        ),
      ),
    );
  }

  // ── Preset: Grid Skeleton ────────────────────────────────────────────────
  static Widget grid({int count = 6}) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: count,
      itemBuilder: (_, __) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonLoader(width: 50, height: 10),
            const SizedBox(height: 12),
            const SkeletonLoader(width: 100, height: 14),
            const SizedBox(height: 6),
            const SkeletonLoader(width: 80, height: 10),
            const Spacer(),
            const SkeletonLoader(height: 30, borderRadius: 8),
          ],
        ),
      ),
    );
  }
}
