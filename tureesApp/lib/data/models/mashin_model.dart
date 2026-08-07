/// A vehicle a tenant registered for themselves (Машин бүртгэл).
///
/// Mirrors the `/mashin` documents the web app creates in
/// `components/mashinNemekh.tsx` — the app only ever writes the
/// "Түрээслэгч" / "Гадна" combination, the rest of the fields are the owner's
/// own details so the parking desk can match a plate to a tenant.
class MashinModel {
  final String id;
  final String dugaar;
  final String ezemshigchiinNer;
  final String ezemshigchiinUtas;
  final String turul;
  final String zogsooliinTurul;

  /// Set by the parking manager (Үнэгүй / Хөнгөлөлттэй / Харилцагч); empty
  /// until they review the car the tenant registered.
  final String tuluv;
  final String gereeniiDugaar;
  final String talbainDugaar;

  const MashinModel({
    required this.id,
    required this.dugaar,
    this.ezemshigchiinNer = '',
    this.ezemshigchiinUtas = '',
    this.turul = '',
    this.zogsooliinTurul = '',
    this.tuluv = '',
    this.gereeniiDugaar = '',
    this.talbainDugaar = '',
  });

  factory MashinModel.fromJson(Map<String, dynamic> json) {
    return MashinModel(
      id: json['_id']?.toString() ?? '',
      dugaar: json['dugaar']?.toString() ?? '',
      ezemshigchiinNer: json['ezemshigchiinNer']?.toString() ?? '',
      ezemshigchiinUtas: json['ezemshigchiinUtas']?.toString() ?? '',
      turul: json['turul']?.toString() ?? '',
      zogsooliinTurul: json['zogsooliinTurul']?.toString() ?? '',
      tuluv: json['tuluv']?.toString() ?? '',
      gereeniiDugaar: json['gereeniiDugaar']?.toString() ?? '',
      talbainDugaar: json['ezemshigchiinTalbainDugaar']?.toString() ?? '',
    );
  }
}
