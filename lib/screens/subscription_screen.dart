import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/payment_service.dart';
import '../theme/tokens.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  List<ProductDetails> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final paymentService = ref.read(paymentServiceProvider);
    paymentService.initialize();

    try {
      final products = await paymentService.fetchProducts();
      if (mounted) {
        setState(() {
          _products = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.wellness.bgRoot,
      body: Container(
        color: context.wellness.bgRoot,
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                            color: context.wellness.primary))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 10),
                            _buildHeaderIcon(),
                            const SizedBox(height: 24),
                            _buildTitle(),
                            const SizedBox(height: 40),
                            _buildBenefitsList(),
                            const SizedBox(height: 40),
                            _buildProductList(),
                            const SizedBox(height: 24),
                            _buildRestoreButton(),
                            const SizedBox(height: 24),
                            _buildTermsText(),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.close,
                color: context.wellness.textPrimary, size: 28),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildHeaderIcon() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.wellness.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: context.wellness.primary.withValues(alpha: 0.2),
            blurRadius: 40,
            spreadRadius: 10,
          ),
        ],
      ),
      child: Icon(
        Icons.workspace_premium_rounded,
        size: 64,
        color: context.wellness.primary,
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        Text(
          '프리미엄 멤버십',
          style: GoogleFonts.outfit(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: context.wellness.textPrimary,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          '고급 AI 코칭과 상세 분석으로\n당신의 운동 잠재력을 깨워보세요.',
          style: GoogleFonts.outfit(
            fontSize: 16,
            color: context.wellness.textSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildBenefitsList() {
    return Column(
      children: [
        _buildBenefitItem(
            Icons.auto_awesome, '고급 AI 코칭', '개인 맞춤형 운동 및 식단 계획 제공'),
        _buildBenefitItem(Icons.insights, '상세 분석 리포트', '운동 성과 및 신체 변화 심층 분석'),
        _buildBenefitItem(Icons.history, '무제한 기록 조회', '모든 과거 운동/식단 기록 열람'),
        _buildBenefitItem(Icons.block, '광고 없는 환경', '방해 없이 운동에만 집중하세요'),
      ],
    );
  }

  Widget _buildBenefitItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.wellness.primarySubtle,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: context.wellness.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: context.wellness.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: context.wellness.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList() {
    if (_products.isEmpty) {
      // 디버그 빌드에서는 레이아웃 확인용 목업 카드를 노출.
      // 실제(릴리스) 빌드에서는 가짜 가격 대신 빈/오류 상태를 보여준다.
      if (kDebugMode) {
        return Column(
          children: [
            _buildMockProductCard(
              title: '월간 플랜',
              price: '₩9,900',
              originalPrice: null,
              period: '/ 월',
              isHighlight: false,
            ),
            const SizedBox(height: 16),
            _buildMockProductCard(
              title: '연간 플랜',
              price: '₩59,400', // 9900 * 12 * 0.5
              originalPrice: '₩118,800', // 9900 * 12
              period: '/ 연',
              isHighlight: true,
              discountPercent: '50%',
            ),
          ],
        );
      }
      return _buildProductsEmptyState();
    }
    return Column(
      children: _products.map((product) => _buildProductCard(product)).toList(),
    );
  }

  Widget _buildProductsEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: context.wellness.bgCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.wellness.border, width: 1.5),
      ),
      child: Column(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 44,
            color: context.wellness.textTertiary,
          ),
          const SizedBox(height: 12),
          Text(
            '상품 정보를 불러올 수 없습니다',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.wellness.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            '잠시 후 다시 시도해주세요.',
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: context.wellness.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {
              setState(() => _isLoading = true);
              _loadProducts();
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: context.wellness.primary),
            ),
            child: Text(
              '다시 시도',
              style: GoogleFonts.outfit(
                color: context.wellness.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(ProductDetails product) {
    return _buildMockProductCard(
      title: product.title,
      price: product.price,
      originalPrice: null,
      period: '',
      isHighlight: false,
    );
  }

  Widget _buildMockProductCard({
    required String title,
    required String price,
    String? originalPrice,
    required String period,
    required bool isHighlight,
    String? discountPercent,
  }) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('시뮬레이터에서는 스토어 연결이 불가능합니다.')),
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: isHighlight
                  ? context.wellness.primary
                  : context.wellness.bgCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color:
                    isHighlight ? Colors.transparent : context.wellness.border,
                width: 1.5,
              ),
              boxShadow: isHighlight
                  ? [
                      BoxShadow(
                        color: context.wellness.primary.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      )
                    ]
                  : WellnessShadows.soft,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left Side: Title & Desc
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isHighlight
                              ? Colors.white
                              : context.wellness.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '모든 프리미엄 기능',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: isHighlight
                              ? Colors.white.withValues(alpha: 0.9)
                              : context.wellness.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Right Side: Price Info
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (originalPrice != null)
                        Text(
                          originalPrice,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: isHighlight
                                ? Colors.white.withValues(alpha: 0.7)
                                : context.wellness.textTertiary,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: isHighlight
                                ? Colors.white.withValues(alpha: 0.7)
                                : context.wellness.textTertiary,
                          ),
                        ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              price,
                              style: GoogleFonts.outfit(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: isHighlight
                                    ? Colors.white
                                    : context.wellness.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              period,
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                color: isHighlight
                                    ? Colors.white.withValues(alpha: 0.9)
                                    : context.wellness.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (discountPercent != null)
            Positioned(
              top: -12,
              right: 20,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  '$discountPercent SAVE',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: context.wellness.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRestoreButton() {
    return TextButton(
      onPressed: () {
        ref.read(paymentServiceProvider).restorePurchases();
      },
      child: Text(
        '구매 내역 복원',
        style: GoogleFonts.outfit(
          fontSize: 14,
          color: context.wellness.textSecondary,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Widget _buildTermsText() {
    return Text(
      '정기 결제는 언제든 취소할 수 있습니다.\n계속 진행 시 이용약관 및 개인정보처리방침에 동의하게 됩니다.',
      style: GoogleFonts.outfit(
        fontSize: 12,
        color: context.wellness.textTertiary,
        height: 1.5,
      ),
      textAlign: TextAlign.center,
    );
  }
}
