import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'api_changes.dart';

/// Foreground REST refresh, not a server-push transport. Tests opt into the timer
/// explicitly; app builds always enable it. Visible screens retain their form/scroll state.
class LiveRefresh {
  static bool enabled = true;
  static const dataInterval = Duration(seconds: 15);
  static const messagingInterval = Duration(seconds: 5);
}

mixin LiveRefreshMixin<T extends StatefulWidget> on State<T> {
  Timer? _liveTimer;
  AppLifecycleListener? _liveLifecycle;
  StreamSubscription<String>? _liveChanges;
  bool _liveBusy = false;
  bool _liveResumed = true;
  bool liveRefreshing = false;

  Duration get liveInterval => LiveRefresh.dataInterval;
  Set<String> get liveTopics =>
      const {'attendance', 'booking', 'payments', 'profile', 'students'};
  bool get canLiveRefresh => true;
  Future<void> refreshLiveData();

  @override
  void initState() {
    super.initState();
    _liveResumed = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _liveLifecycle = AppLifecycleListener(onStateChange: _onLiveLifecycle);
    _liveChanges = ApiChanges.stream.listen((topic) {
      if (topic == 'navigation' || liveTopics.contains(topic))
        _requestLiveRefresh();
    });
    if (LiveRefresh.enabled) {
      _liveTimer = Timer.periodic(liveInterval, (_) => _requestLiveRefresh());
    }
  }

  Future<void> _requestLiveRefresh() async {
    if (!LiveRefresh.enabled ||
        !mounted ||
        !_liveResumed ||
        _liveBusy ||
        !canLiveRefresh) return;
    // TickerMode also reflects an outer navigator covering this shell route.
    if (!TickerMode.of(context) || ModalRoute.of(context)?.isCurrent == false)
      return;
    _liveBusy = true;
    liveRefreshing = true;
    try {
      await refreshLiveData();
    } catch (e) {
      debugPrint('Live refresh failed: ${e.runtimeType}');
    } finally {
      _liveBusy = false;
      liveRefreshing = false;
    }
  }

  void _onLiveLifecycle(AppLifecycleState state) {
    _liveResumed = state == AppLifecycleState.resumed;
    if (_liveResumed) _requestLiveRefresh();
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _liveChanges?.cancel();
    _liveLifecycle?.dispose();
    super.dispose();
  }
}

/// A returned screen refreshes immediately after dialogs, scanner or checkout close.
class LiveRefreshNavigatorObserver extends NavigatorObserver {
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is TransitionRoute) {
      route.completed.then((_) => ApiChanges.emit('navigation'));
    } else {
      scheduleMicrotask(() => ApiChanges.emit('navigation'));
    }
  }
}
