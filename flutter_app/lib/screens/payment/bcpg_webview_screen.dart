import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../services/bcpg_service.dart';

/// In-app WebView that drives the BCPG payment flow.
///
/// 1. Loads the BCPG-issued `paymentUrl` (the bank/FPX UI).
/// 2. Watches every navigation; when the URL contains [returnUrlNeedle]
///    (the merchant returnUrl host/path), closes the WebView.
/// 3. Polls `getFPXPaymentDetails` until terminal and returns the result.
///
/// Result map shape (passed to Navigator.pop):
///   { 'status': 'succeeded'|'expired'|'failed'|'denied'|'cancelled',
///     'verification': <full response from getFPXPaymentDetails or null>,
///     'referenceId': '<ref>' }
class BcpgWebViewScreen extends StatefulWidget {
  /// The `paymentUrl` returned by BCPG `/v1/payments/init`.
  final String paymentUrl;

  /// The merchant `referenceId` that was sent to BCPG.
  final String referenceId;

  /// Substring used to detect that the browser navigated back to our
  /// returnUrl. Typically the path component (e.g. `bcpg_redirect`) or
  /// a custom scheme prefix (`dclix://bcpg-return`).
  final String returnUrlNeedle;

  const BcpgWebViewScreen({
    super.key,
    required this.paymentUrl,
    required this.referenceId,
    this.returnUrlNeedle = 'bcpg_redirect',
  });

  @override
  State<BcpgWebViewScreen> createState() => _BcpgWebViewScreenState();
}

class _BcpgWebViewScreenState extends State<BcpgWebViewScreen> {
  bool _verifying = false;
  bool _returned = false;
  double _progress = 0;

  /// Detect that the browser landed back on our return target. We don't
  /// trust the BCPG status param — always re-verify via the API.
  bool _isReturnUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.contains(widget.returnUrlNeedle);
  }

  Future<void> _handleReturn() async {
    if (_returned) return;
    _returned = true;
    if (!mounted) return;
    setState(() => _verifying = true);
    final result = await BcpgService.pollUntilTerminal(widget.referenceId);
    if (!mounted) return;
    Navigator.of(context).pop({
      'status': (result['status'] ?? 'unknown').toString(),
      'verification': result,
      'referenceId': widget.referenceId,
    });
  }

  Future<bool> _confirmAbort() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel payment?'),
        content: const Text(
            'Closing this screen will abort the payment. You can try again later. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Stay')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cancel payment')),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_verifying) return; // mid-verify: ignore back press
        final abort = await _confirmAbort();
        if (abort && mounted) {
          Navigator.of(context).pop({
            'status': 'cancelled',
            'verification': null,
            'referenceId': widget.referenceId,
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Secure Payment'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              if (_verifying) return;
              final abort = await _confirmAbort();
              if (abort && mounted) {
                Navigator.of(context).pop({
                  'status': 'cancelled',
                  'verification': null,
                  'referenceId': widget.referenceId,
                });
              }
            },
          ),
        ),
        body: Stack(
          children: [
            InAppWebView(
              initialUrlRequest:
                  URLRequest(url: WebUri(widget.paymentUrl)),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                javaScriptCanOpenWindowsAutomatically: true,
                useShouldOverrideUrlLoading: true,
                supportMultipleWindows: false,
                // FPX bank pages often use third-party cookies + storage.
                thirdPartyCookiesEnabled: true,
                domStorageEnabled: true,
                clearCache: false,
              ),
              onProgressChanged: (_, p) =>
                  setState(() => _progress = p / 100.0),
              shouldOverrideUrlLoading: (controller, action) async {
                final url = action.request.url?.toString();
                if (_isReturnUrl(url)) {
                  // Don't actually navigate to the return URL — bounce
                  // back into the app and verify.
                  await _handleReturn();
                  return NavigationActionPolicy.CANCEL;
                }
                return NavigationActionPolicy.ALLOW;
              },
              onLoadStop: (controller, url) async {
                if (_isReturnUrl(url?.toString())) {
                  await _handleReturn();
                }
              },
            ),
            if (_progress > 0 && _progress < 1)
              LinearProgressIndicator(value: _progress),
            if (_verifying)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 12),
                      Text('Verifying payment…',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
