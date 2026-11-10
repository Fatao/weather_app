import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'weather.dart';

enum WeatherErrorType {
  noConnection,
  timeout,
  cityNotFound, // такого города нет
  notFound, // сервер ответил 404
  rateLimited,
  server,
  badResponse,
}

// Ошибка с текстом, который можно сразу показать пользователю
class WeatherException implements Exception {
  const WeatherException(this.type, this.message);

  final WeatherErrorType type;
  final String message;

  @override
  String toString() => 'WeatherException($type): $message';
}

// Здесь все запросы в сеть. Адреса API лежат только в этом файле,
// в интерфейсе их нет. Ключ не нужен: Open-Meteo работает без него.
class WeatherApiClient {
  WeatherApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _geocodingUrl = 'https://geocoding-api.open-meteo.com/v1/search';
  static const _forecastUrl = 'https://api.open-meteo.com/v1/forecast';
  static const _timeout = Duration(seconds: 8);

  // Ищет город по названию. Если ничего не нашлось — возвращает null.
  Future<City?> findCity(String name) async {
    final uri = Uri.parse(_geocodingUrl).replace(queryParameters: {
      'name': name,
      'count': '1',
      'language': 'ru',
      'format': 'json',
    });
    final json = await _getJson(uri);

    // Когда город не найден, поле results в ответе отсутствует
    final results = json['results'];
    if (results is! List || results.isEmpty) return null;

    try {
      final first = results.first as Map<String, dynamic>;
      return City(
        name: first['name'] as String,
        latitude: (first['latitude'] as num).toDouble(),
        longitude: (first['longitude'] as num).toDouble(),
      );
    } catch (_) {
      throw _badResponse();
    }
  }

  // Погода сейчас и прогноз на 5 дней
  Future<Weather> loadWeather(City city) async {
    final uri = Uri.parse(_forecastUrl).replace(queryParameters: {
      'latitude': '${city.latitude}',
      'longitude': '${city.longitude}',
      'current': 'temperature_2m,apparent_temperature,relative_humidity_2m,'
          'surface_pressure,wind_speed_10m,weather_code',
      'daily': 'weather_code,temperature_2m_max,temperature_2m_min',
      'wind_speed_unit': 'ms',
      'timezone': 'auto',
      'forecast_days': '5',
    });
    final json = await _getJson(uri);

    try {
      return Weather.fromApiJson(city.name, json);
    } catch (_) {
      // не хватает поля или оно другого типа
      throw _badResponse();
    }
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final response = await _get(uri);
    final status = response.statusCode;

    if (status == 404) {
      throw const WeatherException(
        WeatherErrorType.notFound,
        'Сервер не нашёл данные (ошибка 404).',
      );
    }
    if (status == 429) {
      throw const WeatherException(
        WeatherErrorType.rateLimited,
        'Слишком много запросов. Подождите немного.',
      );
    }
    if (status >= 500) {
      throw WeatherException(
        WeatherErrorType.server,
        'Ошибка сервера (код $status). Попробуйте позже.',
      );
    }
    if (status != 200) {
      throw WeatherException(
        WeatherErrorType.server,
        'Не удалось получить данные (код $status).',
      );
    }

    try {
      // читаем байты как UTF-8, чтобы русские названия не портились
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // пришёл не JSON — ниже выбросим ошибку
    }
    throw _badResponse();
  }

  Future<http.Response> _get(Uri uri) async {
    try {
      return await _client.get(uri).timeout(_timeout);
    } on TimeoutException {
      throw const WeatherException(
        WeatherErrorType.timeout,
        'Сервер слишком долго отвечает. Попробуйте ещё раз.',
      );
    } on http.ClientException {
      // нет интернета, не нашёлся сервер или оборвалось соединение
      throw const WeatherException(
        WeatherErrorType.noConnection,
        'Нет подключения к интернету.',
      );
    }
  }

  WeatherException _badResponse() {
    return const WeatherException(
      WeatherErrorType.badResponse,
      'Сервер вернул непонятный ответ.',
    );
  }
}
