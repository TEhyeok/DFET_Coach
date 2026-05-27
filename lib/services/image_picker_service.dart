import 'package:image_picker/image_picker.dart';

/// 이미지 선택 서비스 (웹 호환)
class ImagePickerService {
  final ImagePicker _picker = ImagePicker();

  /// 카메라로 사진 촬영
  Future<XFile?> pickFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );
      return image;
    } catch (e) {
      // 시뮬레이터 또는 권한 거부 시
      return null;
    }
  }

  /// 갤러리에서 사진 선택
  Future<XFile?> pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      return image;
    } catch (e) {
      // 권한 거부 시
      return null;
    }
  }
}
