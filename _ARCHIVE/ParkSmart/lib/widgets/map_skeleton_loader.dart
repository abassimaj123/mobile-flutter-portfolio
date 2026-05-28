import 'package:flutter/material.dart';
import 'package:calcwise_core/calcwise_core.dart';

/// Skeleton loader displayed while map geometry is loading.
/// Shows shimmer animation to indicate data is loading.
class MapSkeletonLoader extends StatefulWidget {
  const MapSkeletonLoader({super.key});

  @override
  State<MapSkeletonLoader> createState() => _MapSkeletonLoaderState();
}

class _MapSkeletonLoaderState extends State<MapSkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.of(context).disableAnimations;

    return Container(
      color: const Color(0xFFF1F5F9),
      child: Stack(
        children: [
          // Fake map tile grid (3x3)
          GridView.count(
            crossAxisCount: 3,
            children: List.generate(9, (i) {
              return Container(
                margin: const EdgeInsets.all(2),
                color: const Color(0xFFE2E8F0),
              );
            }),
          ),
          // Shimmer effect overlay (respects reduced-motion)
          if (!disableAnimations)
            AnimatedBuilder(
              animation: _shimmerController,
              builder: (context, child) {
                return Positioned(
                  left: -300 + (_shimmerController.value * 600),
                  top: 0,
                  bottom: 0,
                  width: 100,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.white.withAlpha(0),
                          Colors.white.withAlpha(100),
                          Colors.white.withAlpha(0),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          // Loading text
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Color(0xFF475569)),
                SizedBox(height: 16),
                Text(
                  'Chargement des données de rue...',
                  style: TextStyle(
                    color: Color(0xFF334155),
                    fontSize: AppTextSize.body,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
