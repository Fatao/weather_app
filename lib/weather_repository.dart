import 'weather.dart';
import 'weather_api_client.dart';
import 'weather_cache.dart';

// Интерфейсу всё равно, откуда берётся погода: из сети или из кэша.
// Он просто просит getWeather и получает результат.
class WeatherRepository {
  WeatherRepository({required WeatherApiClient api, required WeatherCache cache})
      : _api = api,
        _cache = cache;

  final WeatherApiClient _api;
  final WeatherCache _cache;

  Future<Weather> getWeather(String query) async {
    try {
      final city = await _api.findCity(query);
      if (city == null) {
        throw const WeatherException(
          WeatherErrorType.cityNotFound,
          'Город не найден.',
        );
      }

      final weather = await _api.loadWeather(city);
      await _cache.save(query, weather);
      return weather;
    } on WeatherException catch (error) {
      // Несуществующий город — это не сбой сети, кэш тут не поможет
      if (error.type == WeatherErrorType.cityNotFound) rethrow;

      // С сетью что-то не так: пробуем показать сохранённые данные
      final saved = await _cache.load(query);
      if (saved != null) {
        return saved.copyWith(fromCache: true);
      }
      rethrow;
    }
  }
}
