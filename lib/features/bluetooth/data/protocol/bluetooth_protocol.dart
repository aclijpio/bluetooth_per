import 'dart:convert';
import 'dart:typed_data';

/// Bluetooth SPP protocol helper for the mobile app ↔ device interaction.
///
/// Frame format: 2-byte length (big-endian) + UTF-8 payload.
///
/// Supported commands (typos are preserved deliberately to match firmware):
///   • UPDATE_ACRHIVE          – request device to refresh archive on server
///   • UPDATING_ACHIVE         – device → app: archive is being refreshed
///   • ACRHIVE_UPDATED         – device → app: archive is ready for download
///   • GET_ACRHIVE:<filename>  – request device to start file transfer
class BluetoothProtocol {
  BluetoothProtocol._();

  // ───── out-going ─────
  static Uint8List updateArchiveCmd() => _encode('UPDATE_ACRHIVE');
  static Uint8List getArchiveCmd(String name) => _encode('GET_ACRHIVE:$name');

  // ───── in-coming checks ─────
  static bool isArchiveUpdating(Uint8List data) =>
      _decode(data) == 'UPDATING_ACHIVE';

  static bool isArchiveUpdated(Uint8List data) =>
      _decode(data) == 'ACRHIVE_UPDATED';

  // ───── helpers ─────
  static Uint8List _encode(String msg) {
    final utf = utf8.encode(msg);
    final len = utf.length;
    final res = Uint8List(2 + len);
    res[0] = (len >> 8) & 0xFF;
    res[1] = len & 0xFF;
    res.setAll(2, utf);
    return res;
  }

  /// Attempts to decode a full frame; returns empty string if not enough bytes.
  static String _decode(Uint8List data) {
    if (data.length < 2) return '';
    final len = (data[0] << 8) | data[1];
    if (data.length < 2 + len) return '';
    return utf8.decode(data.sublist(2, 2 + len));
  }
}
