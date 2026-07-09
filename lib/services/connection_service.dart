import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectionService {
  static const Duration offlineGracePeriod = Duration(seconds: 4);

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionChangeController =
      StreamController<bool>.broadcast();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  Timer? _offlineTimer;
  bool _lastEmittedConnectionState = true;

  Stream<bool> get connectionChange => _connectionChangeController.stream;

  ConnectionService() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _connectionChange,
    );
  }

  void _connectionChange(ConnectivityResult result) {
    final bool hasConnection = result != ConnectivityResult.none;

    if (hasConnection) {
      _offlineTimer?.cancel();
      _emitConnectionState(true);
      return;
    }

    _offlineTimer?.cancel();
    _offlineTimer = Timer(offlineGracePeriod, () {
      _emitConnectionState(false);
    });
  }

  void _emitConnectionState(bool hasConnection) {
    if (_lastEmittedConnectionState == hasConnection) {
      return;
    }

    _lastEmittedConnectionState = hasConnection;
    _connectionChangeController.add(hasConnection);
  }

  Future<bool> checkConnection() async {
    ConnectivityResult result = await _connectivity.checkConnectivity();
    if (result != ConnectivityResult.none) {
      _offlineTimer?.cancel();
      _emitConnectionState(true);
      return true;
    }

    await Future<void>.delayed(offlineGracePeriod);
    result = await _connectivity.checkConnectivity();
    final bool hasConnection = result != ConnectivityResult.none;
    if (hasConnection) {
      _offlineTimer?.cancel();
    }
    _emitConnectionState(hasConnection);
    return hasConnection;
  }

  void dispose() {
    _offlineTimer?.cancel();
    _connectivitySubscription?.cancel();
    _connectionChangeController.close();
  }
}

final connectionService = ConnectionService();
