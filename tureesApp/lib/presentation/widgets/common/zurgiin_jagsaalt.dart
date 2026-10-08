import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';

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

List<String> zurguudUnshikh(dynamic utga) => (utga is List)
    ? utga.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
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
