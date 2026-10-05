import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../providers/ai_tuslakh_provider.dart';
import '../../providers/chat_provider.dart';

/// Нүүр хуудсан дээрх чирж зөөдөг нэгдсэн чатын товч.
///
/// - Дарахад «AI туслах» / «Захиргаа» табтай чатын дэлгэц нээгдэнэ. Захиргаанаас
///   уншаагүй мессеж байвал шууд «Захиргаа» таб дээр нээгдэж, товч дээр тоо гарна.
/// - Чирээд суллахад хамгийн ойр хажуугийн ирмэгт наалдаж, байрлалаа хадгална.
/// - Доод голын улаан бай руу чирвэл хаагдана (Профайлаас буцааж асаана).
/// - Удаан дарахад сонголтын цэс гарна.
///
/// Эцэг Stack-ийг бүхэлд нь эзэлдэг тул өөрөө `Positioned.fill` болно.
class AiTuslakhTovch extends ConsumerStatefulWidget {
  /// Хэрэглэгч `chat` эрхтэй эсэх — уншаагүй мессежийн тоог харуулах эсэх.
  final bool zakhirgaaniiChattai;

  const AiTuslakhTovch({super.key, this.zakhirgaaniiChattai = true});

  @override
  ConsumerState<AiTuslakhTovch> createState() => _AiTuslakhTovchState();
}

class _AiTuslakhTovchState extends ConsumerState<AiTuslakhTovch>
    with SingleTickerProviderStateMixin {
  static const double _khemjee = 56;
  static const double _irmegiinZai = 12;
  static const Color _ulaan = Color(0xFFFF3B30);

  /// Хадгалсан байрлал. `_y == null` бол анхдагч (баруун тал, голоос доош).
  bool _baruunTald = true;
  double? _y;

  /// Чирж буй үеийн үнэмлэхүй байрлал.
  Offset _chirjBuiBairshil = Offset.zero;
  bool _chirjBaina = false;
  bool _ustgakhDeer = false;
  double _chirsenZai = 0;

  late final AnimationController _animController;
  Animation<Offset>? _naaldakhAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..addListener(() => setState(() {}));
    _bairshilAchaalakh();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _bairshilAchaalakh() async {
    final b = await ref.read(aiTuslakhBairshilProvider).unshikh();
    if (!mounted || b == null) return;
    setState(() {
      _baruunTald = b.baruunTald;
      _y = b.y;
    });
  }

  void _khadgalakh() {
    final y = _y;
    if (y == null) return;
    ref.read(aiTuslakhBairshilProvider).khadgalakh(
          AiTuslakhBairshil(baruunTald: _baruunTald, y: y),
        );
  }

  int get _unshaaguiToo => widget.zakhirgaaniiChattai
      ? ref.read(conversationsProvider).conversations.fold<int>(0, (s, c) => s + c.unreadCount)
      : 0;

  void _chatNeekh() =>
      context.push(_unshaaguiToo > 0 ? '/ai-tuslakh?tab=zakhirgaa' : '/ai-tuslakh');

  /// `from`-оос `to` руу зөөлөн шилжинэ (ирмэгт наалдах, байрлал сэргээх).
  void _animatsi(Offset from, Offset to) {
    _naaldakhAnim = Tween<Offset>(begin: from, end: to).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
    _animController.forward(from: 0);
  }

  Future<void> _khaakh() async {
    // Дахин асаахад анхдагч байрлалаасаа гарна.
    _baruunTald = true;
    _y = null;
    await ref.read(aiTuslakhBairshilProvider).khadgalakh(
          const AiTuslakhBairshil(baruunTald: true, y: -1),
        );
    if (!mounted) return;
    showAppSnackBar(
      context,
      'Чатын товчийг хаалаа. «Профайл» цэснээс хүссэн үедээ дахин гаргах боломжтой.',
      duration: const Duration(seconds: 4),
    );
    // Сүүлд нь унтраана — товч энэ мөчид мод-оос хасагдана.
    await ref.read(aiTuslakhIdevkhteiProvider.notifier).set(false);
  }

  void _songoltiinTses(Offset odoogiin, Offset anhdagch) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.appSurface,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Чат ба AI туслах',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              _SongoltiinMur(
                icon: Icons.chat_bubble_outline_rounded,
                ungu: AppColors.primary,
                garchig: 'Чатлах',
                onTap: () {
                  Navigator.pop(ctx);
                  _chatNeekh();
                },
              ),
              _SongoltiinMur(
                icon: Icons.refresh_rounded,
                ungu: AppColors.info,
                garchig: 'Байрлал шинэчлэх (баруун доор)',
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _baruunTald = true;
                    _y = null;
                  });
                  ref.read(aiTuslakhBairshilProvider).khadgalakh(
                        const AiTuslakhBairshil(baruunTald: true, y: -1),
                      );
                  _animatsi(odoogiin, anhdagch);
                },
              ),
              _SongoltiinMur(
                icon: Icons.delete_outline_rounded,
                ungu: AppColors.error,
                garchig: 'Нүүр хуудаснаас хаах',
                tailbar: 'Профайл цэснээс хүссэн үедээ буцааж гаргах боломжтой',
                onTap: () {
                  Navigator.pop(ctx);
                  _khaakh();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deedZai = MediaQuery.paddingOf(context).top;
    final unread = widget.zakhirgaaniiChattai
        ? ref.watch(conversationsProvider).conversations.fold<int>(0, (s, c) => s + c.unreadCount)
        : 0;
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          final minX = _irmegiinZai;
          final maxX = (w - _khemjee - _irmegiinZai).clamp(minX, double.infinity);
          final minY = deedZai + 8;
          final maxY = (h - _khemjee - 8).clamp(minY, double.infinity);

          // Хадгалсан `y` сөрөг бол «анхдагч» гэсэн үг (сэргээсэн/хаасан).
          final khadgalsanY = _y;
          final anhdagchY = (h * 0.55).clamp(minY, maxY);
          final y = khadgalsanY == null || khadgalsanY < 0
              ? anhdagchY
              : khadgalsanY.clamp(minY, maxY);
          final amarBairshil = Offset(_baruunTald ? maxX : minX, y);
          final anhdagch = Offset(maxX, anhdagchY);

          final bairshil = _chirjBaina
              ? _chirjBuiBairshil
              : (_animController.isAnimating && _naaldakhAnim != null)
                  ? _naaldakhAnim!.value
                  : amarBairshil;

          // Устгах байны төв — доод голд.
          final ustgakhTuv = Offset(w / 2, h - 56);

          return Stack(
            children: [
              // 1. Устгах бай — шошго нь дугуйн ДЭЭР (бөмбөлөг халхлахгүй).
              Positioned(
                left: 0,
                right: 0,
                top: ustgakhTuv.dy - 32 - 44,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _chirjBaina ? 1 : 0,
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      offset: _chirjBaina ? Offset.zero : const Offset(0, 0.4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _ustgakhDeer
                                  ? _ulaan
                                  : const Color(0xFF1E293B).withValues(alpha: 0.88),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              _ustgakhDeer ? 'Хаана' : 'Хаахын тулд энд чирнэ үү',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          AnimatedScale(
                            duration: const Duration(milliseconds: 180),
                            scale: _ustgakhDeer ? 1.15 : 1.0,
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _ustgakhDeer ? _ulaan : _ulaan.withValues(alpha: 0.18),
                                border: Border.all(
                                  color: _ulaan.withValues(alpha: _ustgakhDeer ? 1 : 0.6),
                                  width: 2,
                                ),
                                boxShadow: _ustgakhDeer
                                    ? [
                                        BoxShadow(
                                          color: _ulaan.withValues(alpha: 0.45),
                                          blurRadius: 22,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Icon(
                                Icons.delete_outline_rounded,
                                color: _ustgakhDeer ? Colors.white : _ulaan,
                                size: 26,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 2. Чирдэг товч.
              Positioned(
                left: bairshil.dx,
                top: bairshil.dy,
                child: GestureDetector(
                  onPanStart: (_) {
                    _animController.stop();
                    setState(() {
                      _chirjBuiBairshil = bairshil;
                      _chirjBaina = true;
                      _chirsenZai = 0;
                    });
                    HapticFeedback.selectionClick();
                  },
                  onPanUpdate: (details) {
                    _chirsenZai += details.delta.distance;
                    final shineX = (_chirjBuiBairshil.dx + details.delta.dx).clamp(minX, maxX);
                    final shineY = (_chirjBuiBairshil.dy + details.delta.dy).clamp(minY, maxY);
                    final tuv = Offset(shineX + _khemjee / 2, shineY + _khemjee / 2);
                    final deer = (tuv - ustgakhTuv).distance < 80;
                    if (deer && !_ustgakhDeer) HapticFeedback.mediumImpact();
                    setState(() {
                      _chirjBuiBairshil = Offset(shineX, shineY);
                      _ustgakhDeer = deer;
                    });
                  },
                  onPanEnd: (_) {
                    final suulchiin = _chirjBuiBairshil;
                    final ustgakh = _ustgakhDeer;
                    final tovshilt = _chirsenZai < 8;
                    setState(() {
                      _chirjBaina = false;
                      _ustgakhDeer = false;
                    });

                    if (tovshilt) {
                      // Бага зэрэг хөдөлсөн бол товшилт гэж үзнэ.
                      _chatNeekh();
                      return;
                    }
                    if (ustgakh) {
                      HapticFeedback.heavyImpact();
                      _khaakh();
                      return;
                    }

                    // Хамгийн ойр хажуугийн ирмэгт зөөлөн наалдана.
                    final baruun = suulchiin.dx + _khemjee / 2 >= w / 2;
                    final zorilt = Offset(baruun ? maxX : minX, suulchiin.dy.clamp(minY, maxY));
                    setState(() {
                      _baruunTald = baruun;
                      _y = zorilt.dy;
                    });
                    _animatsi(suulchiin, zorilt);
                    _khadgalakh();
                  },
                  onTap: _chatNeekh,
                  onLongPress: () => _songoltiinTses(bairshil, anhdagch),
                  child: Semantics(
                    button: true,
                    label: unread > 0 ? 'Чат, $unread уншаагүй мессеж' : 'Чат ба AI туслах',
                    child: AnimatedScale(
                      scale: _ustgakhDeer ? 0.82 : (_chirjBaina ? 1.08 : 1.0),
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOutCubic,
                      child: _TovchiinDugui(
                        khemjee: _khemjee,
                        chirjBaina: _chirjBaina,
                        ustgakhDeer: _ustgakhDeer,
                        unread: unread,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TovchiinDugui extends StatelessWidget {
  final double khemjee;
  final bool chirjBaina;
  final bool ustgakhDeer;
  final int unread;

  const _TovchiinDugui({
    required this.khemjee,
    required this.chirjBaina,
    required this.ustgakhDeer,
    this.unread = 0,
  });

  @override
  Widget build(BuildContext context) {
    const ulaan = _AiTuslakhTovchState._ulaan;
    final dugui = Container(
      width: khemjee,
      height: khemjee,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: ustgakhDeer
              ? const [Color(0xFFFF6B6B), ulaan]
              : const [AppColors.primaryLight, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: (ustgakhDeer ? ulaan : AppColors.primary)
                .withValues(alpha: chirjBaina ? 0.5 : 0.32),
            blurRadius: chirjBaina ? 18 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            ustgakhDeer ? Icons.close_rounded : Icons.auto_awesome_rounded,
            size: 26,
            color: Colors.white,
          ),
          if (!chirjBaina && !ustgakhDeer && unread <= 0)
            Positioned(
              top: 10,
              right: 12,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFF4ADE80),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );

    if (unread <= 0) return dugui;

    // Захиргаанаас ирсэн уншаагүй мессежийн тоо (хуучин чатын бөмбөлөгтэй адил).
    return Stack(
      clipBehavior: Clip.none,
      children: [
        dugui,
        Positioned(
          top: -4,
          right: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Center(
              child: Text(
                unread > 99 ? '99+' : '$unread',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SongoltiinMur extends StatelessWidget {
  final IconData icon;
  final Color ungu;
  final String garchig;
  final String? tailbar;
  final VoidCallback onTap;

  const _SongoltiinMur({
    required this.icon,
    required this.ungu,
    required this.garchig,
    required this.onTap,
    this.tailbar,
  });

  @override
  Widget build(BuildContext context) {
    final aldaa = ungu == AppColors.error;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: ungu.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: ungu, size: 20),
      ),
      title: Text(
        garchig,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: aldaa ? AppColors.error : context.appTextPrimary,
        ),
      ),
      subtitle: tailbar == null
          ? null
          : Text(tailbar!, style: TextStyle(fontSize: 11, color: context.appTextSecondary)),
    );
  }
}
