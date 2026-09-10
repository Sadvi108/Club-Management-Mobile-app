/// Cross-platform facade for triggering a file download.
///
/// On the web the `printing` plugin's `sharePdf` throws
/// `MissingPluginException(... net.nfet.printing)`, so we download the bytes
/// directly via a Blob + anchor instead. Native platforms save + open the file
/// themselves and never call this (the stub throws if they do).
export 'web_download_stub.dart' if (dart.library.html) 'web_download_web.dart';
