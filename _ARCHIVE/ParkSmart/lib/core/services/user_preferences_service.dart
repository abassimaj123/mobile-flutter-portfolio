import 'package:shared_preferences/shared_preferences.dart';
import '../models/city.dart';
import '../data/city_registry.dart';
import '../services/rule_engine.dart';

/// Service for persisting user preferences (city, filters, view time).
///
/// Automatically saves/restores:
///   - Selected city ID
///   - Layer filter toggles (free, meter, restricted, noData)
///   - Manual view time (if user set a specific time)
class UserPreferencesService {
  static final UserPreferencesService _instance = UserPreferencesService._();
  factory UserPreferencesService() => _instance;
  UserPreferencesService._();

  static const String _keyCityId = 'selected_city_id';
  static const String _keyFilterFree = 'filter_free';
  static const String _keyFilterMeter = 'filter_meter';
  static const String _keyFilterRestricted = 'filter_restricted';
  static const String _keyFilterNoData = 'filter_nodata';
  static const String _keyViewTime = 'view_time'; // ISO string or empty

  late SharedPreferences _prefs;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  // ── City ──────────────────────────────────────────────────────────────────

  Future<void> setSelectedCity(String cityId) async {
    await _ensureInit();
    await _prefs.setString(_keyCityId, cityId);
  }

  Future<City> getSelectedCity() async {
    await _ensureInit();
    final cityId = _prefs.getString(_keyCityId);
    if (cityId == null) return CityRegistry.defaultCity;
    return CityRegistry.findById(cityId) ?? CityRegistry.defaultCity;
  }

  // ── Filters ───────────────────────────────────────────────────────────────

  Future<void> setFilters(Map<ParkingColor, bool> filters) async {
    await _ensureInit();
    await _prefs.setBool(_keyFilterFree, filters[ParkingColor.free] ?? true);
    await _prefs.setBool(_keyFilterMeter, filters[ParkingColor.meter] ?? true);
    await _prefs.setBool(
        _keyFilterRestricted, filters[ParkingColor.restricted] ?? true);
    await _prefs.setBool(
        _keyFilterNoData, filters[ParkingColor.noData] ?? true);
  }

  Future<Map<ParkingColor, bool>> getFilters() async {
    await _ensureInit();
    return {
      ParkingColor.free: _prefs.getBool(_keyFilterFree) ?? true,
      ParkingColor.meter: _prefs.getBool(_keyFilterMeter) ?? true,
      ParkingColor.restricted: _prefs.getBool(_keyFilterRestricted) ?? true,
      ParkingColor.noData: _prefs.getBool(_keyFilterNoData) ?? true,
    };
  }

  // ── View time (manual time picker) ────────────────────────────────────────

  /// Sets the manual view time (or clears if null).
  Future<void> setViewTime(DateTime? time) async {
    await _ensureInit();
    if (time == null) {
      await _prefs.remove(_keyViewTime);
    } else {
      await _prefs.setString(_keyViewTime, time.toIso8601String());
    }
  }

  /// Gets the last saved view time, or null if none was set.
  Future<DateTime?> getViewTime() async {
    await _ensureInit();
    final timeStr = _prefs.getString(_keyViewTime);
    if (timeStr == null || timeStr.isEmpty) return null;
    try {
      return DateTime.parse(timeStr);
    } catch (_) {
      return null;
    }
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────

  Future<void> clearAll() async {
    await _ensureInit();
    await _prefs.clear();
  }

  Future<void> _ensureInit() async {
    if (!_initialized) await init();
  }
}
