import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Material 3-ын цонхны ангилал. Galaxy Z Fold: гадна дэлгэц ~360-410 (compact),
/// дэлгэсэн дотор дэлгэц ~700-900 (medium/expanded), таблет >= 840.
class Breakpoints {
  static const double medium = 600;
  static const double expanded = 840;

  /// Уншихад тухтай агуулгын дээд өргөн.
  static const double contentMaxWidth = 720;
}

extension ResponsiveContext on BuildContext {
  double get delgetsniiUrgun => MediaQuery.sizeOf(this).width;

  /// NavigationRail зэрэг өргөн дэлгэцийн байрлал хэрэглэх эсэх.
  bool get urgunDelgets => delgetsniiUrgun >= Breakpoints.medium;

  /// Агуулгыг [maxWidth]-ээс хэтрэхгүйгээр голлуулах хэвтээ зай. Нарийн дэлгэц
  /// дээр [min] хэвээр. build дотроо дуудна — эвхэх/дэлгэхэд автоматаар дахин тооцогдоно.
  double tovZai({double maxWidth = Breakpoints.contentMaxWidth, double min = 12}) {
    final zai = (delgetsniiUrgun - maxWidth) / 2;
    return zai > min ? zai : min;
  }
}

/// Утсан дээр босоо байрлалд түгжинэ; дэлгэсэн Fold/таблет (богино тал >= 600)
/// дээр бүх чиглэлийг зөвшөөрнө. Эвхэх/дэлгэх үед дахин тохируулна.
class ChiglelKhyanagch extends StatefulWidget {
  final Widget child;

  const ChiglelKhyanagch({super.key, required this.child});

  @override
  State<ChiglelKhyanagch> createState() => _ChiglelKhyanagchState();
}

class _ChiglelKhyanagchState extends State<ChiglelKhyanagch> {
  bool? _tomDelgets;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tom = MediaQuery.sizeOf(context).shortestSide >= Breakpoints.medium;
    if (tom == _tomDelgets) return;
    _tomDelgets = tom;
    SystemChrome.setPreferredOrientations(
      tom
          ? DeviceOrientation.values
          : const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
