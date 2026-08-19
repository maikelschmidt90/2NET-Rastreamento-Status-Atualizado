import 'dart:async';
import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:traccar_client_sdk/traccar_client_sdk.dart';

import 'geolocation_service.dart';
import 'preferences.dart';

class TrackerStatus {
  const TrackerStatus({
    required this.trackingActive,
    required this.gpsEnabled,
    required this.locationPermission,
    required this.serverConnected,
    required this.lastCommunication,
    required this.lastServerCheck,
    this.serverMessage,
  });

  final bool trackingActive;
  final bool gpsEnabled;
  final LocationPermission locationPermission;
  final bool serverConnected;
  final DateTime? lastCommunication;
  final DateTime? lastServerCheck;
  final String? serverMessage;

  bool get hasLocationPermission =>
      locationPermission == LocationPermission.always ||
      locationPermission == LocationPermission.whileInUse;

  bool get gpsUsable => gpsEnabled && hasLocationPermission;
}

class StatusService {
  static Future<TrackerStatus> read() async {
    final tracking = await GeolocationService.tracker.isTracking();
    final gpsEnabled = await _locationServiceEnabled();
    final permission = await _locationPermission();
    final logs = await GeolocationService.tracker.getLogs();
    final lastCommunication = _lastSuccessfulUpload(logs);

    final server = await _checkServer();

    return TrackerStatus(
      trackingActive: tracking,
      gpsEnabled: gpsEnabled,
      locationPermission: permission,
      serverConnected: server.connected,
      lastCommunication: lastCommunication,
      lastServerCheck: DateTime.now(),
      serverMessage: server.message,
    );
  }

  static Future<bool> _locationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      return false;
    }
  }

  static Future<LocationPermission> _locationPermission() async {
    try {
      return await Geolocator.checkPermission();
    } catch (_) {
      return LocationPermission.denied;
    }
  }

  static DateTime? _lastSuccessfulUpload(List<LogEntry> logs) {
    DateTime? result;

    for (final entry in logs) {
      final match = RegExp(r'Upload response (\d{3})').firstMatch(entry.message);
      if (match == null) continue;

      final code = int.tryParse(match.group(1)!);
      if (code == null || code < 200 || code >= 300) continue;

      final time = DateTime.fromMillisecondsSinceEpoch(entry.time);
      if (result == null || time.isAfter(result)) {
        result = time;
      }
    }

    return result;
  }

  static Future<_ServerCheck> _checkServer() async {
    final rawUrl = Preferences.instance.getString(Preferences.url);
    if (rawUrl == null || rawUrl.trim().isEmpty) {
      return const _ServerCheck(false, 'Servidor não configurado');
    }

    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) {
      return const _ServerCheck(false, 'Endereço do servidor inválido');
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 4)
      ..idleTimeout = const Duration(seconds: 4);

    try {
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 5));
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      final response = await request.close().timeout(const Duration(seconds: 5));
      await response.drain<void>();

      // Qualquer resposta HTTP comprova que o host/porta/TLS responderam.
      // O status HTTP não precisa ser 2xx porque alguns endpoints do Traccar
      // aceitam somente POST e podem responder 405/400 para um GET.
      return _ServerCheck(true, 'HTTP ${response.statusCode}');
    } catch (error) {
      return _ServerCheck(false, _shortError(error));
    } finally {
      client.close(force: true);
    }
  }

  static String _shortError(Object error) {
    if (error is SocketException) {
      return 'Sem conexão com o servidor';
    }
    if (error is TimeoutException) {
      return 'Tempo de resposta excedido';
    }
    return 'Sem comunicação';
  }
}

class _ServerCheck {
  const _ServerCheck(this.connected, this.message);

  final bool connected;
  final String message;
}
