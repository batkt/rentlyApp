import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/khuvilbar_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routing/app_router.dart';

/// Апп нээгдэх болон дахин идэвхжих бүрд шинэ хувилбар байгаа эсэхийг
/// шалгаж, «Шинэчлэх» цонх гаргана. Заавал шинэчлэх бол цонхыг хаах боломжгүй.
class KhuvilbarShalgagch extends StatefulWidget {
  final Widget child;

  const KhuvilbarShalgagch({super.key, required this.child});

  @override
  State<KhuvilbarShalgagch> createState() => _KhuvilbarShalgagchState();
}

class _KhuvilbarShalgagchState extends State<KhuvilbarShalgagch>
    with WidgetsBindingObserver {
  bool _neeltei = false;

  /// Заавал биш шинэчлэлтийг нэг сешнд нэг л удаа санал болгоно.
  bool _sanalBolgoson = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Router, Navigator бэлэн болох хүртэл бага зэрэг хүлээнэ.
    Future.delayed(const Duration(milliseconds: 1500), _shalgakh);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Store-оос буцаж ирэхэд (шинэчлээгүй бол) дахин шалгана.
    if (state == AppLifecycleState.resumed) _shalgakh();
  }

  Future<void> _shalgakh() async {
    if (!mounted || _neeltei) return;
    final m = await KhuvilbarService.shalgakh();
    if (m == null || !mounted || _neeltei) return;
    if (!m.zaaval && _sanalBolgoson) return;
    final ctx =
        tureesNavKey.currentState?.overlay?.context ?? tureesNavKey.currentContext;
    if (ctx == null) return;
    _neeltei = true;
    _sanalBolgoson = true;
    try {
      await showDialog<void>(
        context: ctx,
        barrierDismissible: !m.zaaval,
        builder: (_) => KhuvilbarTsonkh(medeelel: m),
      );
    } catch (_) {
      // Цонх гарч чадаагүй ч апп ажиллах ёстой.
    } finally {
      _neeltei = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class KhuvilbarTsonkh extends StatelessWidget {
  final KhuvilbarMedeelel medeelel;

  const KhuvilbarTsonkh({super.key, required this.medeelel});

  Future<void> _shinechlekh() async {
    final url = await KhuvilbarService.storeUrl(medeelel);
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: !medeelel.zaaval,
      child: Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _Logo(),
                const SizedBox(height: 16),
                Text(
                  'Анхааруулга',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  medeelel.message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF4B5563),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Шинэ хувилбар ${medeelel.version}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _shinechlekh,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Шинэчлэх',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ),
                ),
                if (!medeelel.zaaval)
                  TextButton(
                    onPressed: () {
                      KhuvilbarService.algasakh(medeelel.version);
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      'Дараа нь',
                      style: TextStyle(color: Color(0xFF6B7280)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Дугуй дотор Rently лого, баруун дээд буланд шар анхааруулгын тэмдэг.
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(10),
            child: ClipOval(
              child: Image.asset('assets/images/rently.png', fit: BoxFit.cover),
            ),
          ),
          Positioned(
            right: 0,
            top: 2,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: const Color(0xFFFBBF24),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.priority_high_rounded,
                  size: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
