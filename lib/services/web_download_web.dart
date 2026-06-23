import 'dart:html' as html;
import 'dart:typed_data';

/// Trigger a browser download of [bytes] as [filename]. Uses a Blob + a
/// temporary anchor so it does NOT depend on the `printing` plugin (whose web
/// `sharePdf` throws MissingPluginException in this build).
void downloadBytesWeb(Uint8List bytes, String filename, String mime) {
  final blob = html.Blob(<dynamic>[bytes], mime);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
