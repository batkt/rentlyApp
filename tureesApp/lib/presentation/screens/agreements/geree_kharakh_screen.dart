import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart' as webview_flutter;

import '../../../core/theme/app_colors.dart';
import '../../providers/agreement_provider.dart';
import '../../widgets/common/app_loading.dart';

/// Түрээслэгч өөрийн гэрээг эх хувиар нь — байгууллагын загвар, тамга, гарын
/// үсэгтэйгээр — уншиж чадах дэлгэц. turees админ дээрх "Гэрээ харах" товч юу
/// нээдэгтэй ижил баримт.
class GereeKharakhScreen extends ConsumerWidget {
  final String gereeniiId;
  final String gereeniiDugaar;

  const GereeKharakhScreen({
    super.key,
    required this.gereeniiId,
    required this.gereeniiDugaar,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final khuudas = ref.watch(gereeniiKhuudasProvider(gereeniiId));

    return Scaffold(
      appBar: AppBar(
        title: Text(gereeniiDugaar.isEmpty ? 'Гэрээ' : gereeniiDugaar),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        // AppBarTheme.titleTextStyle нь `foregroundColor`-оос давж ажилладаг
        // тул гарчгийн өнгийг тусад нь зааж өгнө.
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: khuudas.when(
        loading: () => const AppLoading(),
        error: (aldaa, _) => AppErrorWidget(
          message: aldaa is GereeKhuudasAldaa
              ? aldaa.message
              : 'Гэрээг татахад алдаа гарлаа',
          onRetry: () => ref.invalidate(gereeniiKhuudasProvider(gereeniiId)),
        ),
        data: (html) => _GereeWebView(html: html),
      ),
    );
  }
}

class _GereeWebView extends StatefulWidget {
  final String html;

  const _GereeWebView({required this.html});

  @override
  State<_GereeWebView> createState() => _GereeWebViewState();
}

class _GereeWebViewState extends State<_GereeWebView> {
  /// Гэрээний загварууд A4 (210mm ≈ 794px) өргөнтэй бичигдсэн байдаг. Утасны
  /// өргөнөөр нь урсгавал хоёр баганат толгой, тамганы байрлал бүгд эвдэрдэг
  /// тул [InvoiceHtmlScreen]-тэй ижил аргаар эх өргөнөөр нь байрлуулж, viewport
  /// -оор бүх хуудсыг жижигрүүлж үзүүлнэ. Чимхэж томруулах боломжтой хэвээр.
  static const int _khuudasniiUrgun = 794;

  late final webview_flutter.WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = webview_flutter.WebViewController()
      ..setJavaScriptMode(webview_flutter.JavaScriptMode.unrestricted)
      ..enableZoom(true)
      ..loadHtmlString(_buurenKhuudas(widget.html));
  }

  String _buurenKhuudas(String biye) => '''
<html><head>
<meta name="viewport" content="width=$_khuudasniiUrgun,user-scalable=yes">
<style>
  /* Цагаан хуудас саарал дэвсгэр дээр — баримт мэт унших. */
  html{background:#EDF0F2;}
  body{margin:0;padding:18px 0 28px;width:${_khuudasniiUrgun}px;
       background:#EDF0F2;
       font-family:'Times New Roman',Times,serif;font-size:12pt;
       line-height:1.15;text-align:justify;color:#000;}
  *{box-sizing:border-box;}
  /* Вэб дээрх хуудасны хэмжээ: 210mm өргөн, 25mm/30mm захтай. */
  .gereeniiKhuudas{width:${_khuudasniiUrgun}px;margin:0 auto 18px;
       padding:25mm 25mm 25mm 30mm;background:#fff;
       box-shadow:0 2px 10px rgba(0,0,0,0.18);position:relative;}
  .khoyorBagana{display:grid;grid-template-columns:1fr 1fr;gap:16px;}
  .zaalt{width:100%;padding:4px 0;position:relative;}
  .khuudasniiGarchig{width:${_khuudasniiUrgun}px;margin:0 auto;
       padding:6px 4px;font-family:sans-serif;font-size:20px;
       font-weight:600;opacity:0.35;}
  /* Загварууд өөрсдийн inline өнгөтэй ирдэг ч цагаан хуудсан дээр хар
     бичвэр л уншигдана. */
  .gereeniiKhuudas *{color:#000 !important;max-width:100%;}
  img{height:auto;}
  table{border-collapse:collapse;max-width:100%;}
  td,th{word-break:normal;overflow-wrap:break-word;}
</style></head>
<body>$biye</body></html>''';

  @override
  Widget build(BuildContext context) {
    return webview_flutter.WebViewWidget(controller: _controller);
  }
}
