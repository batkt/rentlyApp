import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';

/// Санал/гомдол/дуудлага, мэдэгдэлд хавсаргасан зургуудын жижиг зураг.
/// Дарахад бүтэн дэлгэцээр (томруулж, гүйлгэж) харуулна.
class ZurgiinJagsaalt extends StatelessWidget {
  final List<String> zurguud;
  final String baiguullagiinId;
  final double khemjee;

  const ZurgiinJagsaalt({
    super.key,
    required this.zurguud,
    required this.baiguullagiinId,
    this.khemjee = 64,
  });

  @override
  Widget build(BuildContext context) {
    if (zurguud.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < zurguud.length; i++)
          GestureDetector(
            onTap: () => _butenKharakh(context, i),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: ApiConstants.zuragAvya(baiguullagiinId, zurguud[i]),
                width: khemjee,
                height: khemjee,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  width: khemjee,
                  height: khemjee,
                  color: context.appInputFill,
                ),
                errorWidget: (_, __, ___) => Container(
                  width: khemjee,
                  height: khemjee,
                  color: context.appInputFill,
                  child: Icon(Icons.broken_image_outlined,
                      color: context.appTextTertiary),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _butenKharakh(BuildContext context, int ekhlel) {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (dialogContext) => Stack(
        children: [
          PageView.builder(
            controller: PageController(initialPage: ekhlel),
            itemCount: zurguud.length,
            itemBuilder: (_, i) => InteractiveViewer(
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: ApiConstants.zuragAvya(baiguullagiinId, zurguud[i]),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(dialogContext),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Менежерийн (turees вэб) хариунууд — текст ба зураг.
class KhariultuudKharuulakh extends StatelessWidget {
  final List<Map<String, dynamic>> khariultuud;
  final String baiguullagiinId;

  const KhariultuudKharuulakh({
    super.key,
    required this.khariultuud,
    required this.baiguullagiinId,
  });

  @override
  Widget build(BuildContext context) {
    if (khariultuud.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final kh in khariultuud)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.support_agent_rounded,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        (kh['ajiltniiNer']?.toString().isNotEmpty ?? false)
                            ? 'Менежер · ${kh['ajiltniiNer']}'
                            : 'Менежерийн хариу',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      AppFormatters.date(kh['ognoo']?.toString()),
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
                if ((kh['message']?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(kh['message'].toString(), style: theme.textTheme.bodySmall),
                ],
                if (zurguudUnshikh(kh['zurguud']).isNotEmpty) ...[
                  const SizedBox(height: 6),
                  ZurgiinJagsaalt(
                    zurguud: zurguudUnshikh(kh['zurguud']),
                    baiguullagiinId: baiguullagiinId,
                    khemjee: 56,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

List<String> zurguudUnshikh(dynamic utga) => (utga is List)
    ? utga.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
    : const [];

List<Map<String, dynamic>> khariultuudUnshikh(dynamic utga) => (utga is List)
    ? utga
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList()
    : const [];

/// Хүсэлтийн маягт дээрх зураг сонгогч (дээд тал нь [deedKhyazgaar]).
class ZuragSongogch extends StatelessWidget {
  final List<File> zurguud;
  final ValueChanged<List<File>> onChanged;
  final bool idevkhgui;
  final int deedKhyazgaar;

  const ZuragSongogch({
    super.key,
    required this.zurguud,
    required this.onChanged,
    this.idevkhgui = false,
    this.deedKhyazgaar = 5,
  });

  Future<void> _nemekh() async {
    final sonsgoson = await ImagePicker().pickMultiImage(imageQuality: 80);
    if (sonsgoson.isEmpty) return;
    final shine = [...zurguud, ...sonsgoson.map((x) => File(x.path))];
    onChanged(shine.take(deedKhyazgaar).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < zurguud.length; i++)
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(zurguud[i],
                    width: 64, height: 64, fit: BoxFit.cover),
              ),
              if (!idevkhgui)
                Positioned(
                  top: -6,
                  right: -6,
                  child: GestureDetector(
                    onTap: () =>
                        onChanged([...zurguud]..removeAt(i)),
                    child: const CircleAvatar(
                      radius: 10,
                      backgroundColor: Colors.black54,
                      child: Icon(Icons.close, size: 12, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        if (zurguud.length < deedKhyazgaar)
          GestureDetector(
            onTap: idevkhgui ? null : _nemekh,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: context.appInputFill,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.appDivider),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      color: context.appTextTertiary),
                  Text('Зураг',
                      style: TextStyle(
                          fontSize: 10, color: context.appTextTertiary)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
