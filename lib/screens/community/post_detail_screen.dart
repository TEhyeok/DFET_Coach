import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/community/community_comment.dart';
import '../../models/community/post.dart';
import '../../state/community_state.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_card.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key, required this.postId});

  final String postId;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _controller = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(communityServiceProvider);
    return Scaffold(
      backgroundColor: context.wellness.bgRoot,
      appBar: AppBar(
        title: const Text('게시글'),
        backgroundColor: context.wellness.bgRoot,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<Post?>(
                stream: service.getPostStream(widget.postId),
                builder: (context, postSnapshot) {
                  if (postSnapshot.hasError) {
                    return _MessageState(
                      icon: CupertinoIcons.exclamationmark_triangle,
                      message: '게시글을 불러오지 못했습니다.',
                    );
                  }
                  if (!postSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final post = postSnapshot.data;
                  if (post == null) {
                    return const _MessageState(
                      icon: CupertinoIcons.doc_text_search,
                      message: '삭제되었거나 존재하지 않는 게시글입니다.',
                    );
                  }
                  return StreamBuilder<List<CommunityComment>>(
                    stream: service.getCommentsStream(widget.postId),
                    builder: (context, commentSnapshot) {
                      final comments = commentSnapshot.data ?? const [];
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        children: [
                          _PostBody(
                            post: post,
                            onLike: () => service.toggleLike(post.id),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '댓글 ${post.commentCount}',
                            style: AppTextStyles.h3.copyWith(
                              color: context.wellness.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (commentSnapshot.hasError)
                            Text(
                              '댓글을 불러오지 못했습니다.',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: context.wellness.danger,
                              ),
                            )
                          else if (!commentSnapshot.hasData)
                            const Center(child: CircularProgressIndicator())
                          else if (comments.isEmpty)
                            AppCard(
                              child: Text(
                                '첫 댓글로 응원을 남겨보세요.',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: context.wellness.textSecondary,
                                ),
                              ),
                            )
                          else
                            for (final comment in comments) ...[
                              _CommentTile(comment: comment),
                              const SizedBox(height: 8),
                            ],
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                12,
                10,
                12,
                10 + MediaQuery.paddingOf(context).bottom,
              ),
              decoration: BoxDecoration(
                color: context.wellness.bgCard,
                border: Border(
                  top: BorderSide(color: context.wellness.borderSubtle),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 3,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        hintText: '댓글을 입력하세요',
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isSending ? null : _send,
                    child: Text(_isSending ? '등록 중' : '등록'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    setState(() => _isSending = true);
    try {
      await ref.read(communityServiceProvider).addComment(widget.postId, value);
      _controller.clear();
      if (mounted) FocusScope.of(context).unfocus();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('댓글 등록 실패: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}

class _PostBody extends StatelessWidget {
  const _PostBody({required this.post, required this.onLike});

  final Post post;
  final Future<void> Function() onLike;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: context.wellness.bgSubtle,
                backgroundImage: post.authorProfileImage == null
                    ? null
                    : NetworkImage(post.authorProfileImage!),
                child: post.authorProfileImage == null
                    ? Icon(CupertinoIcons.person_fill,
                        color: context.wellness.textTertiary)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.authorName,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      DateFormat('yyyy.MM.dd HH:mm').format(post.createdAt),
                      style: AppTextStyles.caption.copyWith(
                        color: context.wellness.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            post.content,
            style: AppTextStyles.body.copyWith(
              color: context.wellness.textPrimary,
              height: 1.5,
            ),
          ),
          if (post.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                post.imageUrls.first,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 180,
                  color: context.wellness.bgSubtle,
                  alignment: Alignment.center,
                  child: const Text('이미지를 표시할 수 없습니다.'),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onLike,
            icon: Icon(
              post.isLikedByMe
                  ? CupertinoIcons.heart_fill
                  : CupertinoIcons.heart,
              color: post.isLikedByMe
                  ? context.wellness.danger
                  : context.wellness.textSecondary,
            ),
            label: Text('좋아요 ${post.likeCount}'),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final CommunityComment comment;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(CupertinoIcons.person_crop_circle,
              color: context.wellness.textTertiary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.authorName,
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      DateFormat('MM.dd HH:mm').format(comment.createdAt),
                      style: AppTextStyles.caption.copyWith(
                        color: context.wellness.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.content,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: context.wellness.textPrimary,
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

class _MessageState extends StatelessWidget {
  const _MessageState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 46, color: context.wellness.textTertiary),
          const SizedBox(height: 12),
          Text(message, style: AppTextStyles.body),
        ],
      ),
    );
  }
}
