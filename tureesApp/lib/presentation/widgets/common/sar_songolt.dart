import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

const _sarniiNer = [
  '1-р сар', '2-р сар', '3-р сар', '4-р сар', '5-р сар', '6-р сар',
  '7-р сар', '8-р сар', '9-р сар', '10-р сар', '11-р сар', '12-р сар',
];

/// `2026-08` → `8-р сар`.
String sarniiNer(String sariinTulkhuur) {
  final khesguud = sariinTulkhuur.split('-');
  final sar = int.tryParse(khesguud.length > 1 ? khesguud[1] : '') ?? 0;
  return sar >= 1 && sar <= 12 ? _sarniiNer[sar - 1] : 'Тодорхойгүй';
}

/// `2026-08` → `2026`.
String sariinJil(String sariinTulkhuur) => sariinTulkhuur.split('-').first;

/// `2026-08` key for a date.
String sariinTulkhuur(DateTime? d) =>
    d == null ? '' : '${d.year}-${d.month.toString().padLeft(2, '0')}';

/// Horizontal month picker shared by the invoice screens: one tap per month,
/// always visible, with the number of documents in each.
class SarSongolt extends StatelessWidget {
  /// Month keys (`2026-08`), newest first.
  final List<String> saruud;
  final String songoson;
  final Map<String, int> toolol;
  final ValueChanged<String> onSelect;

  const SarSongolt({
    super.key,
    required this.saruud,
    required this.songoson,
    required this.toolol,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        itemCount: saruud.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final key = saruud[index];
          final songogdson = key == songoson;

          return GestureDetector(
            onTap: () => onSelect(key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: songogdson ? AppColors.primary : context.appCardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: songogdson ? AppColors.primary : context.appDivider,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sarniiNer(key),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: songogdson ? Colors.white : context.appTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${sariinJil(key)} · ${toolol[key] ?? 0} ш',
                    style: TextStyle(
                      fontSize: 11,
                      color: songogdson ? Colors.white70 : context.appTextTertiary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Month calendar for picking a day inside [sar]. Days that actually have a
/// document are the only ones that can be tapped; the rest are dimmed, so the
/// grid doubles as a map of when documents arrived.
class UdriinKhuanli extends StatefulWidget {
  /// Month key, `2026-08`.
  final String sar;

  /// day-of-month → number of documents.
  final Map<int, int> udruud;

  /// Selected day; null = бүх өдөр.
  final int? songoson;
  final ValueChanged<int?> onSelect;

  const UdriinKhuanli({
    super.key,
    required this.sar,
    required this.udruud,
    required this.songoson,
    required this.onSelect,
  });

  @override
  State<UdriinKhuanli> createState() => _UdriinKhuanliState();
}

class _UdriinKhuanliState extends State<UdriinKhuanli> {
  bool _neelttei = true;

  static const _garagiinNer = ['Да', 'Мя', 'Лх', 'Пү', 'Ба', 'Бя', 'Ня'];

  @override
  Widget build(BuildContext context) {
    final khesguud = widget.sar.split('-');
    final jil = int.tryParse(khesguud.first);
    final sar = int.tryParse(khesguud.length > 1 ? khesguud[1] : '');
    if (jil == null || sar == null || sar < 1 || sar > 12) {
      return const SizedBox.shrink();
    }

    final udriinToo = DateTime(jil, sar + 1, 0).day;
    // Monday-first grid, matching the Mongolian week.
    final ekhniiKhooson = DateTime(jil, sar, 1).weekday - 1;
    final niitNudnii = ekhniiKhooson + udriinToo;
    final doloogKhonog = (niitNudnii / 7).ceil();

    final today = DateTime.now();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      decoration: BoxDecoration(
        color: context.appCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appDivider),
      ),
      child: Column(
        children: [
          // Header doubles as the collapse toggle and the "clear" affordance.
          InkWell(
            onTap: () => setState(() => _neelttei = !_neelttei),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    widget.songoson == null
                        ? 'Бүх өдөр'
                        : '$jil.${sar.toString().padLeft(2, '0')}.${widget.songoson.toString().padLeft(2, '0')}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.appTextPrimary,
                        ),
                  ),
                  const Spacer(),
                  if (widget.songoson != null)
                    TextButton(
                      onPressed: () => widget.onSelect(null),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text('Цэвэрлэх', style: TextStyle(fontSize: 12)),
                    ),
                  Icon(
                    _neelttei ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    size: 20,
                    color: context.appTextTertiary,
                  ),
                ],
              ),
            ),
          ),
          if (_neelttei) ...[
            Divider(height: 1, color: context.appDivider),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      for (final garag in _garagiinNer)
                        Expanded(
                          child: Center(
                            child: Text(
                              garag,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: context.appTextTertiary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  for (var doloo = 0; doloo < doloogKhonog; doloo++)
                    Row(
                      children: [
                        for (var garag = 0; garag < 7; garag++)
                          Expanded(
                            child: _Nud(
                              udur: doloo * 7 + garag - ekhniiKhooson + 1,
                              udriinToo: udriinToo,
                              barimt: widget.udruud,
                              songoson: widget.songoson,
                              unuudur: today.year == jil && today.month == sar
                                  ? today.day
                                  : null,
                              onSelect: widget.onSelect,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Nud extends StatelessWidget {
  final int udur;
  final int udriinToo;
  final Map<int, int> barimt;
  final int? songoson;
  final int? unuudur;
  final ValueChanged<int?> onSelect;

  const _Nud({
    required this.udur,
    required this.udriinToo,
    required this.barimt,
    required this.songoson,
    required this.unuudur,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (udur < 1 || udur > udriinToo) return const SizedBox(height: 40);

    final too = barimt[udur] ?? 0;
    final baigaa = too > 0;
    final songogdson = songoson == udur;

    return GestureDetector(
      // Tapping the selected day again goes back to бүх өдөр.
      onTap: baigaa ? () => onSelect(songogdson ? null : udur) : null,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 40,
        child: Center(
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: songogdson
                  ? AppColors.primary
                  : (baigaa ? context.appPrimaryContainer : Colors.transparent),
              shape: BoxShape.circle,
              border: unuudur == udur && !songogdson
                  ? Border.all(color: AppColors.primary, width: 1.5)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$udur',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: baigaa ? FontWeight.w700 : FontWeight.w400,
                    color: songogdson
                        ? Colors.white
                        : (baigaa ? context.appTextPrimary : context.appTextTertiary),
                  ),
                ),
                if (baigaa)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: songogdson ? Colors.white : AppColors.primary,
                      shape: BoxShape.circle,
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
