import 'dart:typed_data';

/// Native/no-op placeholder — only the web implementation is ever used (native
/// platforms save + open the file via dart:io / OpenFilex instead).
void downloadBytesWeb(Uint8List bytes, String filename, String mime) {
  throw UnsupportedError('downloadBytesWeb is only available on the web.');
}
