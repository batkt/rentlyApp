import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppFormatters {
  static final _currencyFormatter = NumberFormat('#,##0.00', 'mn');
  static final _dateFormatter = DateFormat('yyyy.MM.dd');
  static final _dateTimeFormatter = DateFormat('yyyy.MM.dd HH:mm');

  static String currency(num? amount) {
    if (amount == null) return '0₮';
    return '${_currencyFormatter.format(amount)}₮';
  }

  static String date(dynamic value) {
    if (value == null) return '-';
    try {
      final dt = value is DateTime ? value : DateTime.parse(value.toString());
      return _dateFormatter.format(dt);
    } catch (_) {
      return value.toString();
    }
  }

  static String dateTime(dynamic value) {
    if (value == null) return '-';
    try {
      final dt = value is DateTime ? value : DateTime.parse(value.toString());
      return _dateTimeFormatter.format(dt);
    } catch (_) {
      return value.toString();
    }
  }

  static String phone(String? phone) {
    if (phone == null || phone.isEmpty) return '-';
    if (phone.length == 8) {
      return '${phone.substring(0, 4)} ${phone.substring(4)}';
    }
    return phone;
  }

  static String balance(num? amount) {
    if (amount == null) return '0₮';
    final abs = amount.abs();
    final formatted = _currencyFormatter.format(abs);
    if (amount < 0) return '-$formatted₮';
    return '$formatted₮';
  }

  static String shortName(String? ner, String? ovog) {
    if (ner == null && ovog == null) return '-';
    final lastName = ovog?.isNotEmpty == true ? '${ovog![0]}.' : '';
    return '$lastName${ner ?? ''}';
  }
}

extension BalanceColor on num {
  Color get balanceColor {
    if (this > 0) return const Color(0xFFDC2626);
    if (this < 0) return const Color(0xFF16A34A);
    return const Color(0xFF64748B);
  }
}
