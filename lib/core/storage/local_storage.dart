import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class LocalStorage {
  static const String _userKey = 'ars_user_data';
  static const String _tokenKey = 'ars_auth_token';
  static const String _clientIdKey = 'ars_client_id';
  static const String _vehiclesCacheKey = 'ars_vehicles_cache';
  static const String _pendingIncidentKey = 'ars_pending_offline_incident';

  static Future<SharedPreferences> getPrefs() async {
    return await SharedPreferences.getInstance();
  }

  // ── Token ──────────────────────────────────────────────────────────────────

  static Future<bool> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // ── User ───────────────────────────────────────────────────────────────────

  static Future<bool> saveUser(User user, String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, json.encode(user.toJson()));
      await prefs.setString(_tokenKey, token);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<User?> getUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_userKey);
      if (raw == null) return null;
      return User.fromJson(json.decode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> updateUser(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, json.encode(user.toJson()));
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> hasUser() async {
    final user = await getUser();
    final token = await getToken();
    return user != null && token != null;
  }

  // ── Client ID (para saber qué vehículos cargar) ────────────────────────────

  static Future<void> saveClientId(String clientId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clientIdKey, clientId);
  }

  static Future<String?> getClientId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_clientIdKey);
  }

  // ── Cache de vehículos (para usar el formulario sin conexión) ───────────────

  static Future<void> saveVehiclesCache(List<Map<String, dynamic>> vehicles) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_vehiclesCacheKey, json.encode(vehicles));
  }

  static Future<List<Map<String, dynamic>>> getVehiclesCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_vehiclesCacheKey);
      if (raw == null) return [];
      final list = json.decode(raw) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  // ── Solicitud de auxilio pendiente por enviar (modo offline) ────────────────
  // Solo puede existir UNA a la vez, para evitar múltiples solicitudes al
  // recuperar la conexión.

  static Future<void> savePendingIncident(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingIncidentKey, json.encode(data));
  }

  static Future<Map<String, dynamic>?> getPendingIncident() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pendingIncidentKey);
      if (raw == null) return null;
      return json.decode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> hasPendingIncident() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_pendingIncidentKey);
  }

  static Future<void> clearPendingIncident() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingIncidentKey);
  }

  // ── Clear ──────────────────────────────────────────────────────────────────

  static Future<bool> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
      await prefs.remove(_tokenKey);
      await prefs.remove(_clientIdKey);
      await prefs.remove(_vehiclesCacheKey);
      await prefs.remove(_pendingIncidentKey);
      return true;
    } catch (_) {
      return false;
    }
  }
}
