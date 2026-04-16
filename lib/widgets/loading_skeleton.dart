import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:mensaena/config/theme.dart';

enum SkeletonType { postList, card, profile, chat }

class LoadingSkeleton extends StatelessWidget {
  final SkeletonType type;
  final int count;

  const LoadingSkeleton({
    super.key,
    this.type = SkeletonType.card,
    this.count = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.border,
      highlightColor: AppColors.borderLight,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        itemBuilder: (context, index) {
          switch (type) {
            case SkeletonType.postList:
              return _buildPostSkeleton();
            case SkeletonType.profile:
              return _buildProfileSkeleton();
            case SkeletonType.chat:
              return _buildChatSkeleton();
            case SkeletonType.card:
              return _buildCardSkeleton();
          }
        },
      ),
    );
  }

  Widget _buildPostSkeleton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 160, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const CircleAvatar(radius: 18, backgroundColor: Colors.white),
                    const SizedBox(width: 10),
                    Container(width: 120, height: 14, color: Colors.white),
                  ]),
                  const SizedBox(height: 12),
                  Container(width: double.infinity, height: 16, color: Colors.white),
                  const SizedBox(height: 8),
                  Container(width: 200, height: 14, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardSkeleton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildProfileSkeleton() {
    return Column(
      children: [
        const CircleAvatar(radius: 48, backgroundColor: Colors.white),
        const SizedBox(height: 16),
        Container(width: 160, height: 20, color: Colors.white),
        const SizedBox(height: 8),
        Container(width: 100, height: 14, color: Colors.white),
      ],
    );
  }

  Widget _buildChatSkeleton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const CircleAvatar(radius: 20, backgroundColor: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 120, height: 14, color: Colors.white),
                const SizedBox(height: 4),
                Container(width: 200, height: 12, color: Colors.white),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
