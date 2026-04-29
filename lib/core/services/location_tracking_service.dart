import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../config/env.dart';
import '../storage/local_storage.dart';

class TechnicianLocation {
  final double lat;
  final double lng;
  final String technicianName;
  final DateTime timestamp;

  const TechnicianLocation({
    required this.lat,
    required this.lng,
    required this.technicianName,
    required this.timestamp,
  });
}

class LocationTrackingService {
  WebSocket? _socket;
  final _locationController = StreamController<TechnicianLocation>.broadcast();
  final _statusController = StreamController<String>.broadcast();

  Stream<TechnicianLocation> get locationStream => _locationController.stream;
  Stream<String> get statusStream => _statusController.stream;

  Future<void> connectAsViewer(String incidentId) async {
    await disconnect();

    final token = await LocalStorage.getToken();
    if (token == null) return;

    final wsBase = AppConfig.wsUrl;
    final url = '$wsBase/ws/location/$incidentId?token=$token&role=viewer';

    try {
      _socket = await WebSocket.connect(url);
      _statusController.add('connected');

      _socket!.listen(
        (dynamic data) {
          try {
            final msg = jsonDecode(data as String) as Map<String, dynamic>;
            if (msg['type'] == 'location') {
              _locationController.add(TechnicianLocation(
                lat: (msg['lat'] as num).toDouble(),
                lng: (msg['lng'] as num).toDouble(),
                technicianName: msg['technician_name'] as String? ?? 'Técnico',
                timestamp: DateTime.tryParse(msg['timestamp'] as String? ?? '') ?? DateTime.now(),
              ));
            }
          } catch (_) {}
        },
        onError: (_) => _statusController.add('error'),
        onDone: () => _statusController.add('disconnected'),
      );
    } catch (_) {
      _statusController.add('error');
    }
  }

  Future<void> disconnect() async {
    await _socket?.close();
    _socket = null;
  }

  void dispose() {
    disconnect();
    _locationController.close();
    _statusController.close();
  }
}
