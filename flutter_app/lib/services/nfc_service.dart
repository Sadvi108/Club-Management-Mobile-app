import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:nfc_manager/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';

/// Thin wrapper around `nfc_manager` for the attendance flows.
///
/// A tag is "linked" to a student by writing the student's official code
/// (`ST-00022410` — same string as the printed QR) as an NDEF text record.
/// There is no server-side tag registry; the tag is self-contained, so
/// reading it posts the exact same /Attendance/Add body as a QR scan.
///
/// Android-only by design (releases ship as APKs); every entry point
/// degrades gracefully when NFC is missing, disabled, or the platform
/// is unsupported (web, desktop, emulator).
class NfcService {
  NfcService._();

  /// Whether NFC is supported AND currently enabled on this device.
  static Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      return await NfcManager.instance.checkAvailability() ==
          NfcAvailability.enabled;
    } catch (_) {
      return false; // unsupported platform / plugin missing
    }
  }

  /// Continuously read tags; [onCode] fires with the decoded text of each
  /// NDEF tag (e.g. `ST-00022410`). [onUnreadable] fires for tags without
  /// a decodable payload. Call [stop] to end the session.
  static Future<void> startReadSession({
    required void Function(String code) onCode,
    void Function()? onUnreadable,
  }) {
    return NfcManager.instance.startSession(
      pollingOptions: const {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
      onDiscovered: (NfcTag tag) async {
        final code = await _readCode(tag);
        if (code != null && code.isNotEmpty) {
          onCode(code);
        } else {
          onUnreadable?.call();
        }
      },
    );
  }

  /// Write [code] (e.g. `ST-00022410`) to the next tag presented, as an
  /// NDEF text record, then read it back to verify. One-shot session.
  static Future<void> startWriteSession({
    required String code,
    required void Function() onSuccess,
    required void Function(String message) onError,
  }) {
    return NfcManager.instance.startSession(
      pollingOptions: const {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
      onDiscovered: (NfcTag tag) async {
        try {
          final ndef = NdefAndroid.from(tag);
          if (ndef == null) {
            onError('Tag does not support NDEF.');
            return;
          }
          if (!ndef.isWritable) {
            onError('Tag is write-protected.');
            return;
          }
          final message = NdefMessage(records: [_textRecord(code)]);
          if (message.byteLength > ndef.maxSize) {
            onError('Tag is too small (${ndef.maxSize}B).');
            return;
          }
          await ndef.writeNdefMessage(message);
          // Read-back verify.
          final back = await ndef.getNdefMessage();
          final got = back == null ? null : _decodeMessage(back);
          if (got == code) {
            onSuccess();
          } else {
            onError('Verification failed — try again.');
          }
        } catch (e) {
          onError('Write failed: ${e.toString().replaceFirst('Exception: ', '')}');
        }
      },
    );
  }

  static Future<void> stop() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {/* session already gone */}
  }

  // -- NDEF helpers ----------------------------------------------------------

  /// NDEF well-known Text record ('T'), UTF-8, language 'en'.
  static NdefRecord _textRecord(String text) {
    final lang = ascii.encode('en');
    final body = utf8.encode(text);
    final payload = Uint8List(1 + lang.length + body.length);
    payload[0] = lang.length; // UTF-8 flag (bit7=0) + language length
    payload.setRange(1, 1 + lang.length, lang);
    payload.setRange(1 + lang.length, payload.length, body);
    return NdefRecord(
      typeNameFormat: TypeNameFormat.wellKnown,
      type: Uint8List.fromList(const [0x54]), // 'T'
      identifier: Uint8List(0),
      payload: payload,
    );
  }

  static Future<String?> _readCode(NfcTag tag) async {
    try {
      final ndef = NdefAndroid.from(tag);
      if (ndef == null) return null;
      final message =
          ndef.cachedNdefMessage ?? await ndef.getNdefMessage();
      if (message == null) return null;
      return _decodeMessage(message);
    } catch (_) {
      return null;
    }
  }

  /// First decodable text in the message: well-known Text records get the
  /// status byte + language stripped; anything else falls back to a UTF-8
  /// decode of the raw payload.
  static String? _decodeMessage(NdefMessage message) {
    for (final r in message.records) {
      final p = r.payload;
      if (p.isEmpty) continue;
      if (r.typeNameFormat == TypeNameFormat.wellKnown &&
          r.type.length == 1 &&
          r.type[0] == 0x54) {
        final langLen = p[0] & 0x3F;
        if (p.length > 1 + langLen) {
          return utf8.decode(p.sublist(1 + langLen), allowMalformed: true).trim();
        }
        continue;
      }
      final text = utf8.decode(p, allowMalformed: true).trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }
}
