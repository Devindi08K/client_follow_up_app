import 'dart:async';
import 'dart:io';

/// Lightweight connectivity checker — no external package required.
/// Polls a DNS lookup periodically; anything in the app can listen for
/// changes or force an immediate re-check (e.g. on pull-to-refresh or
/// when the app resumes from background).
class ConnectivityService {
  ConnectivityService._internal() {
    _startPolling();
  }

  static final ConnectivityService instance = ConnectivityService._internal();

  static const _pollInterval = Duration(seconds: 5);
  static const _lookupHost = 'supabase.co';

  final _controller = StreamController<bool>.broadcast();
  final _reconnectController = StreamController<void>.broadcast();
  Timer? _timer;
  bool _lastKnown = true;

  Stream<void> get onReconnected => _reconnectController.stream;

  Stream<bool> get onStatusChanged => _controller.stream;
  bool get isOnlineLastKnown => _lastKnown;

  void _startPolling() {
    _checkNow();
    _timer = Timer.periodic(_pollInterval, (_) => _checkNow());
  }

  Future<void> _checkNow() async {
    final online = await _hasConnection();
    if (online != _lastKnown) {
      final wasOffline = !_lastKnown;
      _lastKnown = online;
      _controller.add(online);
      if (wasOffline && online) _reconnectController.add(null);
    }
  }

  /// Forces an immediate check outside the normal poll cycle.
  Future<bool> checkNow() async {
    final online = await _hasConnection();
    if (online != _lastKnown) {
      _lastKnown = online;
      _controller.add(online);
    }
    return online;
  }

  Future<bool> _hasConnection() async {
    try {
      final result = await InternetAddress.lookup(_lookupHost)
          .timeout(const Duration(seconds: 4));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}