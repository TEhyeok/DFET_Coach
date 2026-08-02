import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../state/community_state.dart';
import '../../widgets/community/post_card.dart';
import '../../theme/tokens.dart';
import '../../utils/ios_navigation.dart';
import '../../utils/responsive_layout.dart';
import 'create_post_screen.dart';

class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(communityPostsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: postsAsync.when(
        data: (posts) => posts.isEmpty
            ? Center(
                child: Text(
                  '첫 게시글을 작성해보세요!',
                  style:
                      GoogleFonts.outfit(color: context.wellness.textSecondary),
                ),
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ListView.builder(
                    padding: ResponsiveLayout.pagePadding(context),
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      return PostCard(post: posts[index]);
                    },
                  ),
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('에러 발생: $error',
              style: TextStyle(color: context.wellness.textPrimary)),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            adaptivePageRoute(builder: (context) => const CreatePostScreen()),
          );
        },
        backgroundColor: PremiumColors.primary,
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    );
  }
}
