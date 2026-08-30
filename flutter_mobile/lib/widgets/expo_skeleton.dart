import 'package:flutter/material.dart';

class ExpoSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ExpoSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 12.0,
  });

  factory ExpoSkeleton.box({
    double width = double.infinity,
    double height = 16,
    double borderRadius = 8,
  }) {
    return ExpoSkeleton(
      width: width,
      height: height,
      borderRadius: borderRadius,
    );
  }

  factory ExpoSkeleton.card({
    double width = 130,
    double height = 130,
    double borderRadius = 12,
  }) {
    return ExpoSkeleton(
      width: width,
      height: height,
      borderRadius: borderRadius,
    );
  }

  static Widget listTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          const ExpoSkeleton(width: 48, height: 48, borderRadius: 8),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExpoSkeleton.box(width: 160, height: 14, borderRadius: 4),
                const SizedBox(height: 8),
                ExpoSkeleton.box(width: 100, height: 11, borderRadius: 4),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const ExpoSkeleton(width: 24, height: 24, borderRadius: 12),
        ],
      ),
    );
  }

  static Widget sectionShimmer() {
    return Padding(
      padding: const EdgeInsets.only(top: 22, left: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExpoSkeleton.box(width: 180, height: 20, borderRadius: 6),
          const SizedBox(height: 14),
          SizedBox(
            height: 176,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              itemBuilder: (context, index) => Container(
                margin: const EdgeInsets.only(right: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExpoSkeleton.card(width: 130, height: 130),
                    const SizedBox(height: 8),
                    ExpoSkeleton.box(width: 110, height: 12, borderRadius: 4),
                    const SizedBox(height: 4),
                    ExpoSkeleton.box(width: 80, height: 10, borderRadius: 4),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  State<ExpoSkeleton> createState() => _ExpoSkeletonState();
}

class _ExpoSkeletonState extends State<ExpoSkeleton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(const Color(0xFF222222), const Color(0xFF333333), _animation.value)!,
                Color.lerp(const Color(0xFF2B2B2B), const Color(0xFF444444), _animation.value)!,
                Color.lerp(const Color(0xFF222222), const Color(0xFF333333), _animation.value)!,
              ],
            ),
          ),
        );
      },
    );
  }
}
