import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectionService {
  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionChangeController =
      StreamController<bool>.broadcast();

  Stream<bool> get connectionChange => _connectionChangeController.stream;

  ConnectionService() {
    _connectivity.onConnectivityChanged.listen(_connectionChange);
  }

  void _connectionChange(ConnectivityResult result) {
    bool hasConnection = result != ConnectivityResult.none;
    _connectionChangeController.add(hasConnection);
  }

  Future<bool> checkConnection() async {
    var result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  void dispose() {
    _connectionChangeController.close();
  }
}

final connectionService = ConnectionService();
