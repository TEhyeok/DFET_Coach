import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../theme/tokens.dart';
import '../../state/auth_state.dart';
import '../../core/utils/app_logger.dart';

class CreateRequestScreen extends ConsumerStatefulWidget {
  const CreateRequestScreen({super.key});

  @override
  ConsumerState<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends ConsumerState<CreateRequestScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  File? _videoFile;
  VideoPlayerController? _videoController;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 2), // Limit video length
      );

      if (video != null) {
        setState(() {
          _videoFile = File(video.path);
          _videoController?.dispose();
          _videoController = VideoPlayerController.file(_videoFile!)
            ..initialize().then((_) {
              setState(() {});
              _videoController!.play();
            });
        });
      }
    } catch (e) {
      AppLogger.error('Error picking video', e);
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('오류'),
            content: const Text('동영상을 선택하지 못했습니다. 다시 시도해주세요.'),
            actions: [
              CupertinoDialogAction(
                child: const Text('확인'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _submitRequest() async {
    if (_titleController.text.isEmpty || _descriptionController.text.isEmpty) {
      _showError('모든 항목을 입력해주세요');
      return;
    }

    if (_videoFile == null) {
      _showError('분석할 동영상을 첨부해주세요');
      return;
    }

    setState(() => _isUploading = true);

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) throw Exception('로그인이 필요합니다');

      // 1. Upload Video
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('requests/${user.uid}/$timestamp.mp4');
      
      final uploadTask = storageRef.putFile(_videoFile!);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // 2. Create Firestore Document
      await FirebaseFirestore.instance.collection('requests').add({
        'userId': user.uid,
        'userName': user.displayName ?? 'Unknown',
        'userPhotoUrl': user.photoURL,
        'type': 'postureCheck',
        'status': 'newRequest',
        'title': _titleController.text,
        'description': _descriptionController.text,
        'attachmentUrls': [downloadUrl],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        AppLogger.debug('Request submitted, popping screen');
        Navigator.of(context).pop(); // Go back
        _showSuccess('요청이 성공적으로 제출되었습니다!');
      }
    } catch (e) {
      AppLogger.error('Error submitting request', e);
      if (mounted) _showError('요청 제출 실패: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('오류'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('확인'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showSuccess(String message) {
    // Using a snackbar-like overlay or just pop with result would be better, 
    // but for now just log or assume user sees the screen change.
    // Since we popped, we might show this on the previous screen if we returned a result,
    // but here we just rely on the pop.
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: PremiumColors.backgroundStart,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: PremiumColors.backgroundStart.withOpacity(0.8),
        middle: Text('새로운 자세 교정 요청',
            style: TextStyle(color: context.wellness.textPrimary)),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Icon(CupertinoIcons.back,
              color: context.wellness.textPrimary),
          onPressed: () {
            AppLogger.debug('Back button pressed');
            Navigator.of(context).pop();
          },
        ),
        trailing: _isUploading
            ? const CupertinoActivityIndicator()
            : CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _submitRequest,
                child: const Text('제출', style: TextStyle(color: PremiumColors.primary)),
              ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CupertinoTextField(
              controller: _titleController,
              placeholder: '제목 (예: 스쿼트 자세 확인)',
              placeholderStyle:
                  TextStyle(color: context.wellness.textTertiary),
              style: TextStyle(color: context.wellness.textPrimary),
              decoration: BoxDecoration(
                color: context.wellness.bgSubtle,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.wellness.border),
              ),
              padding: const EdgeInsets.all(12),
            ),
            const SizedBox(height: 16),
            CupertinoTextField(
              controller: _descriptionController,
              placeholder: '고민되는 부분을 설명해주세요...',
              placeholderStyle:
                  TextStyle(color: context.wellness.textTertiary),
              style: TextStyle(color: context.wellness.textPrimary),
              decoration: BoxDecoration(
                color: context.wellness.bgSubtle,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.wellness.border),
              ),
              padding: const EdgeInsets.all(12),
              maxLines: 5,
            ),
            const SizedBox(height: 24),
            Text('동영상 첨부',
                style: TextStyle(
                    color: context.wellness.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_videoFile != null && _videoController != null && _videoController!.value.isInitialized)
              AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(_videoController!),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _videoController!.value.isPlaying
                              ? _videoController!.pause()
                              : _videoController!.play();
                        });
                      },
                      child: Icon(
                        _videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white.withOpacity(0.7),
                        size: 50,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _videoFile = null;
                            _videoController?.dispose();
                            _videoController = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickVideo(ImageSource.camera),
                      child: Container(
                        height: 120,
                        decoration: BoxDecoration(
                          color: context.wellness.bgCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.wellness.border),
                          boxShadow: WellnessShadows.soft,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(CupertinoIcons.camera, color: PremiumColors.primary, size: 32),
                            const SizedBox(height: 8),
                            Text('동영상 촬영',
                                style: TextStyle(
                                    color: context.wellness.textPrimary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickVideo(ImageSource.gallery),
                      child: Container(
                        height: 120,
                        decoration: BoxDecoration(
                          color: context.wellness.bgCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.wellness.border),
                          boxShadow: WellnessShadows.soft,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(CupertinoIcons.photo, color: PremiumColors.secondary, size: 32),
                            const SizedBox(height: 8),
                            Text('갤러리에서 선택',
                                style: TextStyle(
                                    color: context.wellness.textPrimary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
