import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:geolocator/geolocator.dart';

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

class ArrivalEvent {
  final String message;
  final DateTime timestamp;

  const ArrivalEvent({required this.message, required this.timestamp});
}

class LocationTrackingService {
  WebSocket? _socket;
  final _locationController = StreamController<TechnicianLocation>.broadcast();
  final _statusController = StreamController<String>.broadcast();
  final _arrivedController = StreamController<ArrivalEvent>.broadcast();
  StreamSubscription<Position>? _gpsSubscription;

  Stream<TechnicianLocation> get locationStream => _locationController.stream;
  Stream<String> get statusStream => _statusController.stream;
  Stream<ArrivalEvent> get arrivedStream => _arrivedController.stream;

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
            } else if (msg['type'] == 'arrived') {
              _arrivedController.add(ArrivalEvent(
                message: msg['message'] as String? ?? 'El técnico ha llegado',
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

  Future<void> connectAsTechnician(String incidentId) async {
    await disconnect();

    final token = await LocalStorage.getToken();
    if (token == null) return;

    final wsBase = AppConfig.wsUrl;
    final url = '$wsBase/ws/location/$incidentId?token=$token&role=technician';

    try {
      _socket = await WebSocket.connect(url);
      _statusController.add('connected');

      // Send initial position immediately
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        _sendLocation(pos.latitude, pos.longitude);
      } catch (_) {}

      // Listen to position changes and push updates to the WebSocket
      _gpsSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // send update if moved by 10 meters
        ),
      ).listen((Position pos) {
        _sendLocation(pos.latitude, pos.longitude);
      });

      _socket!.listen(
        (dynamic data) {},
        onError: (_) => _statusController.add('error'),
        onDone: () => disconnect(),
      );
    } catch (_) {
      _statusController.add('error');
    }
  }

  void _sendLocation(double lat, double lng) {
    if (_socket != null) {
      _socket!.add(jsonEncode({
        'type': 'update_location',
        'lat': lat,
        'lng': lng,
      }));
    }
  }

  Future<void> disconnect() async {
    await _gpsSubscription?.cancel();
    _gpsSubscription = null;
    await _socket?.close();
    _socket = null;
    _statusController.add('disconnected');
  }

  void dispose() {
    disconnect();
    _locationController.close();
    _statusController.close();
    _arrivedController.close();
  }
}

