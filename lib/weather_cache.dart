import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'weather.dart';

// Дополнительное задание: хранит последнюю загруженную погоду,
// чтобы без интернета было что показать.
abstract class WeatherCache {
  Future<Weather?> load(String query);
  Future<void> save(String query, Weather weather);
}

// Ключ зависит от того, что ввёл пользователь: «Москва» и «москва» — один город
String _keyFor(String query) => 'weather_${query.trim().toLowerCase()}';

// Сохраняет на устройстве
class SharedPrefsWeatherCache implements WeatherCache {
  @override
  Future<Weather?> load(String query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final text = prefs.getString(_keyFor(query));
      if (text == null) return null;
      return Weather.fromJson(jsonDecode(text) as Map<String, dynamic>);
    } catch (_) {
      // сломанный кэш не должен ломать приложение
      return null;
    }
  }

  @override
  Future<void> save(String query, Weather weather) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyFor(query), jsonEncode(weather.toJson()));
    } catch (_) {
      // не получилось сохранить — ничего страшного
    }
  }
}

// Хранит в памяти, нужен для тестов
class MemoryWeatherCache implements WeatherCache {
  final Map<String, Weather> _items = {};

  @override
  Future<Weather?> load(String query) async => _items[_keyFor(query)];

  @override
  Future<void> save(String query, Weather weather) async {
    _items[_keyFor(query)] = weather;
  }
}
