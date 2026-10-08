import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/common/app_loading.dart';
import '../chat/chat_detail_screen.dart';

/// Нүүр хуудасны хөвөгч товчоор нээгддэг нэгдсэн чат: «AI туслах» болон
/// захиргаатай шууд чатлах «Захиргаа» таб. Хэрэглэгч `chat` эрхгүй бол зөвхөн
/// AI туслах табгүйгээр харагдана.
class AiTuslakhScreen extends ConsumerStatefulWidget {
  /// `true` бол «Захиргаа» таб дээр нээгдэнэ (эрхтэй үед).
  final bool zakhirgaaTabaar;

  const AiTuslakhScreen({super.key, this.zakhirgaaTabaar = false});

  @override
  ConsumerState<AiTuslakhScreen> createState() => _AiTuslakhScreenState();
}

class _AiTuslakhScreenState extends ConsumerState<AiTuslakhScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
    initialIndex: widget.zakhirgaaTabaar ? 1 : 0,
  )..addListener(_tabSoligdloo);

  final _aiKey = GlobalKey<_AiTuslakhChatState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final conv = ref.read(conversationsProvider);
      if (conv.conversations.isEmpty && !conv.isLoading) {
        ref.read(conversationsProvider.notifier).load();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _tabSoligdloo() {
    if (!_tabController.indexIsChanging && mounted) setState(() {});
  }

  bool get _operatorErkhtei {
    final erkhuud = ref.watch(currentUserProvider)?.appErkhuud ?? const <String>[];
    return erkhuud.isEmpty || erkhuud.contains('chat');
  }

  @override
  Widget build(BuildContext context) {
    final operatorErkhtei = _operatorErkhtei;
    final aiTab = !operatorErkhtei || _tabController.index == 0;
    final tuukhtei = _AiTuslakhChatState._tuukh.isNotEmpty;
    final unread = operatorErkhtei
        ? ref.watch(conversationsProvider).conversations.fold<int>(0, (s, c) => s + c.unreadCount)
        : 0;

    final aiChat = _AiTuslakhChat(
      key: _aiKey,
      onTuukhSoligdson: () {
        if (mounted) setState(() {});
      },
      onOperator: operatorErkhtei ? () => _tabController.animateTo(1) : null,
    );

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.primaryLight, AppColors.primary],
                ),
              ),
              child: Icon(
                aiTab ? Icons.auto_awesome_rounded : Icons.support_agent_rounded,
                color: Colors.white,
                size: 17,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    aiTab ? 'AI туслах' : 'Менежер',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    aiTab ? 'Аппын талаар юу ч асуугаарай' : 'Менежертэй шууд чатлах',
                    style: TextStyle(fontSize: 11, color: context.appTextSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (aiTab && tuukhtei)
            IconButton(
              tooltip: 'Яриаг цэвэрлэх',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => _aiKey.currentState?._tseverlekh(),
            ),
        ],
        bottom: operatorErkhtei
            ? TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: context.appTextSecondary,
                indicatorColor: AppColors.primary,
                dividerColor: context.appDivider,
                tabs: [
                  const Tab(
                    icon: Icon(Icons.auto_awesome_rounded, size: 18),
                    iconMargin: EdgeInsets.only(bottom: 2),
                    text: 'AI туслах',
                  ),
                  Tab(
                    icon: Badge(
                      isLabelVisible: unread > 0,
                      label: Text(unread > 99 ? '99+' : '$unread'),
                      child: const Icon(Icons.support_agent_rounded, size: 18),
                    ),
                    iconMargin: const EdgeInsets.only(bottom: 2),
                    text: 'Менежер',
                  ),
                ],
              )
            : null,
      ),
      body: operatorErkhtei
          ? TabBarView(
              controller: _tabController,
              children: [
                // AI-ийн stream таб солиход тасрахгүйн тулд амьд үлдээнэ.
                _AmidUldeekh(child: aiChat),
                // Захиргааны чат таб нээлттэй үед л «идэвхтэй харилцан яриа»
                // болно — эс бөгөөс шинэ мессеж ирэхэд badge гарахгүй.
                const _ZakhirgaaniiChat(),
              ],
            )
          : aiChat,
    );
  }
}

/// Таб солиход доторх төлөвийг хадгална.
class _AmidUldeekh extends StatefulWidget {
  final Widget child;
  const _AmidUldeekh({required this.child});

  @override
  State<_AmidUldeekh> createState() => _AmidUldeekhState();
}

class _AmidUldeekhState extends State<_AmidUldeekh> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// Одоо байгаа захиргааны чатыг (ChatDetailScreen) AppBar-гүйгээр суулгана.
class _ZakhirgaaniiChat extends ConsumerStatefulWidget {
  const _ZakhirgaaniiChat();

  @override
  ConsumerState<_ZakhirgaaniiChat> createState() => _ZakhirgaaniiChatState();
}

class _ZakhirgaaniiChatState extends ConsumerState<_ZakhirgaaniiChat> {
  String? _unshsanId;

  @override
  Widget build(BuildContext context) {
    final convState = ref.watch(conversationsProvider);
    final conv = convState.conversations.firstOrNull;

    if (conv == null) {
      if (convState.error != null && !convState.isLoading) {
        return AppErrorWidget(
          message: convState.error,
          onRetry: () => ref.read(conversationsProvider.notifier).load(),
        );
      }
      return const AppLoading();
    }

    // Таб нээгдэх бүрд (мөн чат солигдоход) уншаагүй тоог тэглэнэ.
    if (_unshsanId != conv.id || conv.unreadCount > 0) {
      _unshsanId = conv.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(conversationsProvider.notifier).markRead(conv.id);
      });
    }

    return ChatDetailScreen(
      key: ValueKey(conv.id),
      conversationId: conv.id,
      conversation: conv,
      embedded: true,
    );
  }
}

class _Messej {
  final String role; // user | assistant
  String content;
  bool aldaa = false;

  /// Хэрэглэгч зогсоосон (дутуу) хариу — үнэлгээ авахгүй.
  bool tasalsan = false;

  /// Сервер `X-Ai-Log-Id` толгойгоор өгсөн log-ийн id (үнэлгээнд хэрэглэнэ).
  String? logId;

  /// 1 = 👍, -1 = 👎, null = үнэлээгүй.
  int? unelgee;
  _Messej(this.role, this.content);
}

/// AI туслахын яриа — Scaffold-гүй, нэгдсэн чатын дэлгэц дотор суулгана.
class _AiTuslakhChat extends ConsumerStatefulWidget {
  /// Яриа нэмэгдэх/цэвэрлэгдэхэд дэлгэцийн AppBar-ын товчийг шинэчлэх.
  final VoidCallback onTuukhSoligdson;

  /// «Захиргаа» таб руу шилжих. `null` бол хэрэглэгч чатын эрхгүй.
  final VoidCallback? onOperator;

  const _AiTuslakhChat({super.key, required this.onTuukhSoligdson, this.onOperator});

  @override
  ConsumerState<_AiTuslakhChat> createState() => _AiTuslakhChatState();
}

class _AiTuslakhChatState extends ConsumerState<_AiTuslakhChat> {
  /// Апп нээлттэй байх хугацаанд яриа хадгалагдана (вэбийн sessionStorage-тэй адил).
  static final List<_Messej> _tuukh = [];

  /// Сервер рүү илгээх өмнөх мессежийн дээд тоо.
  static const _tuukhiinKhyazgaar = 12;

  final _controller = TextEditingController();
  final _scroll = ScrollController();
  CancelToken? _cancelToken;
  StreamSubscription<String>? _sub;
  Completer<void>? _duussan;
  bool _khuleej = false;
  bool _zogsooson = false;

  static const _sanaluud = [
    'Төлбөрөө яаж төлөх вэ?',
    'Нэхэмжлэхээ хаанаас харах вэ?',
    'Машины дугаар яаж бүртгэх вэ?',
    'Гэрээний хугацаа хэзээ дуусах вэ?',
    'Нууц үгээ мартсан бол яах вэ?',
  ];

  @override
  void dispose() {
    _sub?.cancel();
    _cancelToken?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _dooshGuilgekh() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _ilgeekh([String? tekst]) async {
    final asuult = (tekst ?? _controller.text).trim();
    if (asuult.isEmpty || _khuleej) return;
    HapticFeedback.lightImpact();
    _controller.clear();

    final tuukhiinMessej = _tuukh
        .where((m) => !m.aldaa && m.content.trim().isNotEmpty)
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();
    final khariu = _Messej('assistant', '');
    setState(() {
      _tuukh.add(_Messej('user', asuult));
      _tuukh.add(khariu);
      _khuleej = true;
      _zogsooson = false;
    });
    widget.onTuukhSoligdson();
    _dooshGuilgekh();

    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    final duussan = Completer<void>();

    try {
      final barilgiinId = ref.read(selectedBarilgiinIdProvider);
      // Token-ыг DioClient-ийн interceptor өөрөө (`bearer <token>`) нэмнэ.
      final res = await ref.read(dioClientProvider).post(
            ApiConstants.aiTuslakh,
            data: {
              'messages': [
                ...tuukhiinMessej.length > _tuukhiinKhyazgaar
                    ? tuukhiinMessej.sublist(tuukhiinMessej.length - _tuukhiinKhyazgaar)
                    : tuukhiinMessej,
                {'role': 'user', 'content': asuult},
              ],
              'mode': 'orshinSuugch',
              'khuudasniiNer': 'Rently апп',
              if (barilgiinId.isNotEmpty) 'barilgiinId': barilgiinId,
            },
            options: Options(
              responseType: ResponseType.stream,
              // AI эхний хэсгийг гаргах хүртэл удаж болно — ерөнхий 30 сек хүрэлцэхгүй.
              receiveTimeout: const Duration(seconds: 90),
              headers: {'Accept': 'text/plain, application/json'},
            ),
            cancelToken: cancelToken,
          );

      khariu.logId = res.headers.value('x-ai-log-id');
      final body = res.data as ResponseBody;
      if (cancelToken.isCancelled) return;
      _duussan = duussan;
      _sub = body.stream.cast<List<int>>().transform(utf8.decoder).listen(
        (chunk) {
          if (!mounted) return;
          setState(() => khariu.content += chunk);
          _dooshGuilgekh();
        },
        onError: (Object e) {
          if (!duussan.isCompleted) duussan.completeError(e);
        },
        onDone: () {
          if (!duussan.isCompleted) duussan.complete();
        },
        cancelOnError: true,
      );
      await duussan.future;

      if (!_zogsooson && khariu.content.trim().isEmpty) {
        throw Exception('AI туслах хариу өгсөнгүй. Дахин оролдоно уу.');
      }
    } catch (e) {
      if (e is DioException) {
        khariu.logId ??= e.response?.headers.value('x-ai-log-id');
      }
      if (!mounted || _zogsooson || (e is DioException && CancelToken.isCancel(e))) {
        // Хэрэглэгч өөрөө зогсоосон — алдаа харуулахгүй.
        khariu.tasalsan = true;
      } else {
        final msg = await _aldaaniiMessej(e);
        if (mounted) {
          setState(() {
            khariu.aldaa = true;
            khariu.content = khariu.content.trim().isNotEmpty
                ? '${khariu.content}\n\n(Хариу тасалдлаа. Дахин оролдоно уу.)'
                : msg;
          });
        }
      }
    } finally {
      // Зогсоосны дараа шинэ асуулт эхэлсэн бол түүний холбоосыг дарахгүй.
      if (identical(_duussan, duussan)) {
        _sub = null;
        _duussan = null;
      }
      if (identical(_cancelToken, cancelToken)) _cancelToken = null;
      if (mounted) {
        setState(() {
          // Зогсоосон бөгөөд юу ч ирээгүй бол хоосон бөмбөлөг үлдээхгүй.
          if (khariu.content.isEmpty) _tuukh.remove(khariu);
          _khuleej = false;
        });
        widget.onTuukhSoligdson();
      }
      _dooshGuilgekh();
    }
  }

  /// Stream эхлэхээс өмнөх алдааг сервер `{ message, aldaa }` JSON-оор буцаана.
  /// `ResponseType.stream` үед хариуны бие нь мөн stream тул өөрсдөө уншина.
  Future<String> _aldaaniiMessej(Object e) async {
    const ankhdagch = 'AI туслахтай холбогдож чадсангүй. Дахин оролдоно уу.';
    if (e is! DioException) {
      final s = e.toString().replaceFirst('Exception: ', '');
      return s.isNotEmpty ? s : ankhdagch;
    }

    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
        return 'Интернэт холболтоо шалгаад дахин оролдоно уу.';
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'AI туслах удаан хариу өгч байна. Дахин оролдоно уу.';
      default:
        break;
    }

    final res = e.response;
    if (res == null) return ankhdagch;

    String? serverMsg;
    try {
      final data = res.data;
      final tekst = data is ResponseBody
          ? await utf8.decodeStream(data.stream)
          : data is String
              ? data
              : null;
      final d = tekst != null ? json.decode(tekst) : data;
      if (d is Map) {
        serverMsg = [d['message'], d['aldaa']]
            .where((x) => x != null && x.toString().isNotEmpty)
            .map((x) => x.toString())
            .toSet()
            .join('\n');
      }
    } catch (_) {}
    if (serverMsg != null && serverMsg.isNotEmpty) return serverMsg;

    switch (res.statusCode) {
      case 429:
        return 'Хэт олон асуулт илгээлээ. Түр хүлээгээд дахин оролдоно уу.';
      case 401:
      case 403:
        return 'Нэвтрэх эрх дууссан байна. Дахин нэвтэрнэ үү.';
      default:
        return ankhdagch;
    }
  }

  /// 👍/👎 — UI-д шууд тусгаж, амжилтгүй бол буцаана. 0 = үнэлгээг цуцлах.
  Future<bool> _unelgeeIlgeekh(_Messej m, int unelgee, [String? tailbar]) async {
    final logId = m.logId;
    if (logId == null) return false;
    final umnukh = m.unelgee;
    setState(() => m.unelgee = unelgee == 0 ? null : unelgee);
    try {
      await ref.read(dioClientProvider).post(
        ApiConstants.aiTuslakhUnelgee,
        data: {
          'logId': logId,
          'unelgee': unelgee,
          if (tailbar != null && tailbar.isNotEmpty) 'tailbar': tailbar,
        },
      );
      return true;
    } catch (_) {
      if (mounted) {
        setState(() => m.unelgee = umnukh);
        showAppSnackBar(context, 'Үнэлгээ хадгалж чадсангүй', turul: SnackTurul.aldaa);
      }
      return false;
    }
  }

  void _zogsookh() {
    _zogsooson = true;
    _cancelToken?.cancel();
    _sub?.cancel();
    final duussan = _duussan;
    if (duussan != null && !duussan.isCompleted) duussan.complete();
    setState(() => _khuleej = false);
  }

  void _tseverlekh() {
    if (_khuleej) _zogsookh();
    setState(() => _tuukh.clear());
    widget.onTuukhSoligdson();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          children: [
            Expanded(
              child: _tuukh.isEmpty
                  ? _buildMendchilgee(widget.onOperator != null)
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: _tuukh.length,
                      itemBuilder: (context, i) => _buildMessej(
                        _tuukh[i],
                        suuliin: i == _tuukh.length - 1,
                      ),
                    ),
            ),
            _buildOruulga(),
          ],
        ),
      ),
    );
  }

  Widget _buildMendchilgee(bool operatorErkhtei) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      children: [
        Text(
          'Сайн байна уу! 👋',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: context.appTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Төлбөр төлөх, нэхэмжлэх харах, гэрээ болон машин бүртгэл зэрэг аппын '
          'бүх зүйлийг тайлбарлаж өгнө. Жишээ нь:',
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: context.appTextSecondary,
          ),
        ),
        const SizedBox(height: 16),
        ..._sanaluud.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: context.appCardBg,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _ilgeekh(s),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.appDivider),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          s,
                          style: TextStyle(fontSize: 14, color: context.appTextPrimary),
                        ),
                      ),
                      Icon(
                        Icons.arrow_outward_rounded,
                        size: 16,
                        color: context.appTextTertiary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (operatorErkhtei) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.onOperator,
              icon: const Icon(Icons.support_agent_rounded, size: 18),
              label: const Text('Менежертэй шууд чатлах'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMessej(_Messej m, {bool suuliin = false}) {
    final user = m.role == 'user';
    final khoosonKhariu = !user && m.content.isEmpty && _khuleej;
    final unelgeeKharuulakh = !user &&
        m.logId != null &&
        !m.aldaa &&
        !m.tasalsan &&
        m.content.trim().isNotEmpty &&
        !(_khuleej && suuliin);
    final bubble = _buildBubble(
      m,
      user: user,
      khoosonKhariu: khoosonKhariu,
      dooshZai: unelgeeKharuulakh ? 0 : 10,
    );
    if (!unelgeeKharuulakh) return bubble;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        bubble,
        _UnelgeeMur(
          key: ValueKey('unelgee_${m.logId}'),
          unelgee: m.unelgee,
          onUnelgee: (utga, [tailbar]) => _unelgeeIlgeekh(m, utga, tailbar),
        ),
      ],
    );
  }

  Widget _buildBubble(
    _Messej m, {
    required bool user,
    required bool khoosonKhariu,
    double dooshZai = 10,
  }) {
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: LayoutBuilder(
        builder: (context, constraints) => Container(
          margin: EdgeInsets.only(bottom: dooshZai),
          constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.82),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: user
                ? AppColors.primary
                : m.aldaa
                    ? context.appErrorLight
                    : context.appCardBg,
            border: user || m.aldaa ? null : Border.all(color: context.appDivider),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(user ? 18 : 6),
              bottomRight: Radius.circular(user ? 6 : 18),
            ),
          ),
          child: khoosonKhariu
              ? const _BichijBaina()
              : user
                  ? Text(
                      m.content,
                      style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                    )
                  : _MarkdownLite(
                      text: m.content,
                      color: m.aldaa ? AppColors.error : context.appTextPrimary,
                    ),
        ),
      ),
    );
  }

  Widget _buildOruulga() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: context.appCardBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: context.appDivider),
                    ),
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: 2000,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _ilgeekh(),
                      style: TextStyle(fontSize: 14, color: context.appTextPrimary),
                      // Аппын ерөнхий InputDecorationTheme дүүргэлт, хүрээ нэмж
                      // «хайрцаг дотор хайрцаг» болгодог тул бүгдийг унтраана.
                      decoration: InputDecoration(
                        hintText: 'Асуултаа бичнэ үү...',
                        counterText: '',
                        filled: false,
                        isDense: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        hintStyle: TextStyle(color: context.appTextTertiary, fontSize: 14),
                        contentPadding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: AppColors.primary,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _khuleej ? _zogsookh : () => _ilgeekh(),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        _khuleej ? Icons.stop_rounded : Icons.arrow_upward_rounded,
                        color: Colors.white,
                        size: 22,
                        semanticLabel: _khuleej ? 'Зогсоох' : 'Илгээх',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'AI алдаа гаргаж болно. Чухал зүйлийг шалгаарай.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5, color: context.appTextTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Хариултын доорх жижиг 👍/👎 товч. Сонгосныг дахин дарвал цуцална (0).
/// 👎 дээр «Юу буруу байсан бэ?» нэг мөр тайлбар (заавал биш) асууна.
class _UnelgeeMur extends StatefulWidget {
  final int? unelgee;
  final Future<bool> Function(int unelgee, [String? tailbar]) onUnelgee;

  const _UnelgeeMur({super.key, required this.unelgee, required this.onUnelgee});

  @override
  State<_UnelgeeMur> createState() => _UnelgeeMurState();
}

class _UnelgeeMurState extends State<_UnelgeeMur> {
  final _tailbar = TextEditingController();
  bool _tailbarNeelttei = false;
  bool _ilgeej = false;

  @override
  void dispose() {
    _tailbar.dispose();
    super.dispose();
  }

  Future<bool> _dar(int utga, [String? tailbar]) async {
    if (_ilgeej) return false;
    setState(() => _ilgeej = true);
    final ok = await widget.onUnelgee(utga, tailbar);
    if (mounted) setState(() => _ilgeej = false);
    return ok;
  }

  Future<void> _sain() async {
    HapticFeedback.selectionClick();
    setState(() => _tailbarNeelttei = false);
    await _dar(widget.unelgee == 1 ? 0 : 1);
  }

  Future<void> _muu() async {
    HapticFeedback.selectionClick();
    if (widget.unelgee == -1) {
      setState(() => _tailbarNeelttei = false);
      await _dar(0);
      return;
    }
    final ok = await _dar(-1);
    if (ok && mounted) {
      _tailbar.clear();
      setState(() => _tailbarNeelttei = true);
    }
  }

  Future<void> _tailbarIlgeekh() async {
    final tekst = _tailbar.text.trim();
    if (tekst.isEmpty) {
      setState(() => _tailbarNeelttei = false);
      return;
    }
    final ok = await _dar(-1, tekst);
    if (ok && mounted) {
      setState(() => _tailbarNeelttei = false);
      showAppSnackBar(context, 'Санал хүсэлтэд баярлалаа', turul: SnackTurul.amjilt);
    }
  }

  Widget _tovch({
    required IconData icon,
    required bool songogdson,
    required String tailbar,
    required VoidCallback onTap,
  }) {
    return IconButton(
      onPressed: _ilgeej ? null : onTap,
      tooltip: tailbar,
      icon: Icon(icon, size: 16),
      color: songogdson ? AppColors.primary : context.appTextTertiary,
      disabledColor: songogdson ? AppColors.primary : context.appTextTertiary,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 30, height: 30),
      isSelected: songogdson,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sain = widget.unelgee == 1;
    final muu = widget.unelgee == -1;
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _tovch(
                icon: sain ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined,
                songogdson: sain,
                tailbar: 'Сайн хариулт',
                onTap: _sain,
              ),
              _tovch(
                icon: muu ? Icons.thumb_down_alt_rounded : Icons.thumb_down_alt_outlined,
                songogdson: muu,
                tailbar: 'Муу хариулт',
                onTap: _muu,
              ),
            ],
          ),
          if (_tailbarNeelttei && muu)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: context.appCardBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: context.appDivider),
                      ),
                      alignment: Alignment.centerLeft,
                      child: TextField(
                        controller: _tailbar,
                        autofocus: true,
                        maxLength: 500,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _tailbarIlgeekh(),
                        style: TextStyle(fontSize: 13, color: context.appTextPrimary),
                        decoration: InputDecoration(
                          hintText: 'Юу буруу байсан бэ?',
                          counterText: '',
                          filled: false,
                          isDense: true,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          hintStyle: TextStyle(color: context.appTextTertiary, fontSize: 13),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _ilgeej ? null : _tailbarIlgeekh,
                    tooltip: 'Илгээх',
                    icon: const Icon(Icons.send_rounded, size: 18),
                    color: AppColors.primary,
                    visualDensity: VisualDensity.compact,
                  ),
                  TextButton(
                    onPressed: () => setState(() => _tailbarNeelttei = false),
                    style: TextButton.styleFrom(
                      foregroundColor: context.appTextSecondary,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                    ),
                    child: const Text('Алгасах', style: TextStyle(fontSize: 12.5)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Хариу хүлээж байх үеийн гурван цэг.
class _BichijBaina extends StatefulWidget {
  const _BichijBaina();

  @override
  State<_BichijBaina> createState() => _BichijBainaState();
}

class _BichijBainaState extends State<_BichijBaina> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ungu = context.appTextSecondary;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final t = ((_c.value * 3) - i).clamp(0.0, 1.0);
          final o = 0.3 + 0.7 * (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0);
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: ungu.withValues(alpha: o),
              shape: BoxShape.circle,
            ),
          );
        }),
      ),
    );
  }
}

/// Вэбийнхтэй ижил хөнгөн markdown: **тод**, жагсаалт (1. / - / •), # гарчиг.
class _MarkdownLite extends StatelessWidget {
  final String text;
  final Color color;
  const _MarkdownLite({required this.text, required this.color});

  static final _todRe = RegExp(r'\*\*(.+?)\*\*');
  static final _garchigRe = RegExp(r'^#{1,6}\s+(.*)');
  static final _dugaartaiRe = RegExp(r'^\s*(\d+)[.)]\s+(.*)');
  static final _tsegtRe = RegExp(r'^\s*[-•*]\s+(.*)');

  List<TextSpan> _todruulga(String line, TextStyle base) {
    final spans = <TextSpan>[];
    var i = 0;
    for (final m in _todRe.allMatches(line)) {
      if (m.start > i) spans.add(TextSpan(text: line.substring(i, m.start), style: base));
      spans.add(TextSpan(text: m.group(1), style: base.copyWith(fontWeight: FontWeight.w700)));
      i = m.end;
    }
    if (i < line.length) spans.add(TextSpan(text: line.substring(i), style: base));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(color: color, fontSize: 14, height: 1.45);
    final widgets = <Widget>[];
    for (final raw in text.split('\n')) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 6));
        continue;
      }
      final garchig = _garchigRe.firstMatch(line);
      final dugaartai = _dugaartaiRe.firstMatch(line);
      final tsegt = _tsegtRe.firstMatch(line);
      if (garchig != null) {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text.rich(TextSpan(
            children: _todruulga(garchig.group(1)!, base.copyWith(fontWeight: FontWeight.w700)),
          )),
        ));
      } else if (dugaartai != null || tsegt != null) {
        final tag = dugaartai != null ? '${dugaartai.group(1)}.' : '•';
        final body = dugaartai != null ? dugaartai.group(2)! : tsegt!.group(1)!;
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 20,
                child: Text(tag, style: base.copyWith(fontWeight: FontWeight.w700)),
              ),
              Expanded(child: Text.rich(TextSpan(children: _todruulga(body, base)))),
            ],
          ),
        ));
      } else {
        widgets.add(Text.rich(TextSpan(children: _todruulga(line, base))));
      }
    }
    return SelectionArea(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets),
    );
  }
}
