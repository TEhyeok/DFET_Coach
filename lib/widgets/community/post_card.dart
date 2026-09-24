import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/community/post.dart';
import '../../state/community_state.dart';
import '../../theme/tokens.dart';
import '../../screens/community/post_detail_screen.dart';
import '../../utils/ios_navigation.dart';

class PostCard extends ConsumerWidget {
  final Post post;

  const PostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.wellness.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.wellness.borderSubtle),
        boxShadow: WellnessShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: context.wellness.bgSubtle,
                backgroundImage: post.authorProfileImage != null
                    ? (post.authorProfileImage!.startsWith('assets/')
                        ? AssetImage(post.authorProfileImage!) as ImageProvider
                        : NetworkImage(post.authorProfileImage!))
                    : null,
                child: post.authorProfileImage == null
                    ? Icon(Icons.person, color: context.wellness.textTertiary)
                    : null,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.authorName,
                    style: GoogleFonts.outfit(
                      color: context.wellness.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    DateFormat('yyyy.MM.dd HH:mm').format(post.createdAt),
                    style: GoogleFonts.outfit(
                      color: context.wellness.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Content
          Text(
            post.content,
            style: GoogleFonts.outfit(
              color: context.wellness.textPrimary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),

          // Images
          if (post.imageUrls.isNotEmpty)
            Container(
              height: 200,
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(
                  image: post.imageUrls.first.startsWith('assets/')
                      ? AssetImage(post.imageUrls.first) as ImageProvider
                      : NetworkImage(post.imageUrls.first),
                  fit: BoxFit.cover,
                ),
              ),
            ),

          // Actions
          Row(
            children: [
              _ActionButton(
                icon: post.isLikedByMe ? Icons.favorite : Icons.favorite_border,
                label: '${post.likeCount}',
                color: post.isLikedByMe
                    ? PremiumColors.primary
                    : context.wellness.textSecondary,
                onTap: () {
                  ref.read(communityServiceProvider).toggleLike(post.id);
                },
              ),
              const SizedBox(width: 24),
              _ActionButton(
                icon: Icons.chat_bubble_outline,
                label: '${post.commentCount}',
                color: context.wellness.textSecondary,
                onTap: () {
                  Navigator.of(context).push(
                    adaptivePageRoute(
                      builder: (_) => PostDetailScreen(postId: post.id),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.outfit(
              color: color,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
