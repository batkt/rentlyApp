import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Бүх дэлгэц дээр ижил харагдах буцах товч.
///
/// Буцах хуудас байхгүй үед (жишээ нь доод цэсний таб) огт зурагдахгүй тул
/// AppBar-ын `leading`-д болзолгүй тавьж болно. `Navigator`-ыг эхэлж шалгадаг
/// нь `MaterialPageRoute`-аар (нэхэмжлэхийн HTML харагч) болон go_router-аар
/// нээгдсэн хоёуланд нь ажиллахын тулд.
class BuutsakhTovch extends StatelessWidget {
  /// Хар ногоон AppBar дээр цагаанаар харуулах шаардлагатай үед дамжуулна.
  final Color? ungu;

  const BuutsakhTovch({super.key, this.ungu});

  @override
  Widget build(BuildContext context) {
    if (!buutsakhBolomjtoi(context)) return const SizedBox.shrink();
    return IconButton(
      icon: Icon(Icons.arrow_back_rounded, color: ungu),
      tooltip: 'Буцах',
      onPressed: () => buutsakh(context),
    );
  }
}

/// Энэ дэлгэцээс буцах газар байгаа эсэх.
bool buutsakhBolomjtoi(BuildContext context) =>
    Navigator.of(context).canPop() || context.canPop();

/// Буцах — стек хоосон бол нүүр хуудас руу аваачна.
void buutsakh(BuildContext context) {
  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
  } else if (context.canPop()) {
    context.pop();
  } else {
    context.go('/home');
  }
}
