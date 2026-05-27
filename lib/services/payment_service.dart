import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../state/app_state.dart';
import '../core/utils/app_logger.dart';

/// 결제 서비스 Provider
final paymentServiceProvider = Provider<PaymentService>((ref) {
  return PaymentService(ref);
});

/// 결제 서비스
class PaymentService {
  final Ref _ref;
  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  // 상품 ID 목록 (App Store Connect / Play Console에 등록된 ID)
  static const Set<String> _kProductIds = {
    'premium_monthly',
    'premium_yearly',
  };

  PaymentService(this._ref);

  /// 초기화 및 구매 스트림 리스닝 시작
  void initialize() {
    final purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen(
      (purchaseDetailsList) {
        _listenToPurchaseUpdated(purchaseDetailsList);
      },
      onDone: () {
        _subscription.cancel();
      },
      onError: (error) {
        AppLogger.error('[PaymentService] Purchase Stream Error', error);
      },
    );
  }

  /// 상품 목록 가져오기
  Future<List<ProductDetails>> fetchProducts() async {
    final bool available = await _iap.isAvailable();
    if (!available) {
      AppLogger.warning('[PaymentService] Store not available');
      return [];
    }

    final ProductDetailsResponse response =
        await _iap.queryProductDetails(_kProductIds);

    if (response.notFoundIDs.isNotEmpty) {
      AppLogger.warning(
          '[PaymentService] Products not found: ${response.notFoundIDs}');
    }

    if (response.error != null) {
      AppLogger.error(
          '[PaymentService] Query Product Error', response.error!.message);
      return [];
    }

    return response.productDetails;
  }

  /// 상품 구매 요청
  Future<void> buyProduct(ProductDetails product) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    
    // 소모품이 아닌 구독형 상품이므로 non-consumable 처리 (Android의 경우)
    // iOS는 기본적으로 non-consumable/subscription 처리됨
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  /// 구매 복원
  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  /// 구매 업데이트 처리
  Future<void> _listenToPurchaseUpdated(
      List<PurchaseDetails> purchaseDetailsList) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // 결제 대기 중 (UI 로딩 표시 등)
        AppLogger.info('[PaymentService] Purchase Pending: ${purchaseDetails.productID}');
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          AppLogger.error(
              '[PaymentService] Purchase Error', purchaseDetails.error!);
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          
          // 결제 성공 또는 복원 성공
          final bool valid = await _verifyPurchase(purchaseDetails);
          if (valid) {
            await _deliverProduct(purchaseDetails);
          } else {
            AppLogger.error('[PaymentService] Invalid Purchase');
          }
        }

        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  /// 구매 검증 (서버 사이드 검증 권장, 여기서는 클라이언트 처리)
  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    // TODO: 실제 프로덕션에서는 백엔드(Firebase Functions)를 통해 영수증 검증을 수행해야 함
    // 현재는 항상 true 반환
    return true;
  }

  /// 상품 지급 (프리미엄 상태 업데이트)
  Future<void> _deliverProduct(PurchaseDetails purchaseDetails) async {
    try {
      final userProfile = await _ref.read(userProfileProvider.future);
      if (userProfile != null) {
        // 구독 기간 계산 (단순 예시: 월간 30일, 연간 365일)
        // 실제로는 영수증의 만료일을 파싱해야 함
        final isMonthly = purchaseDetails.productID == 'premium_monthly';
        final expiryDate = DateTime.now().add(
          Duration(days: isMonthly ? 30 : 365),
        );

        final updatedProfile = userProfile.copyWith(
          isPremium: true,
          subscriptionExpiryDate: expiryDate,
        );

        // Firestore 업데이트
        await _ref
            .read(firestoreServiceProvider)
            .updateUserProfile(updatedProfile);
        
        // Provider 갱신
        _ref.invalidate(userProfileProvider);
        
        AppLogger.info('[PaymentService] Premium activated for ${userProfile.email}');
      }
    } catch (e) {
      AppLogger.error('[PaymentService] Failed to deliver product', e);
    }
  }

  void dispose() {
    _subscription.cancel();
  }
}
