import 'dart:async';

import 'package:weather_app/weather.dart';
import 'package:weather_app/weather_api_client.dart';

// Погода для тестов: +18°, влажность 62%, ветер 3 м/с, давление ~760 мм
Weather sampleWeather({String cityName = 'Москва'}) {
  return Weather(
    cityName: cityName,
    temperature: 18.4,
    feelsLike: 16.2,
    humidity: 62,
    windSpeed: 3.1,
    pressureHpa: 1013.25,
    weatherCode: 3,
    loadedAt: DateTime(2026, 11, 9, 15, 30),
    days: [
      for (var i = 0; i < 5; i++)
        DayForecast(
          date: DateTime(2026, 11, 9 + i), // 9 ноября 2026 — понедельник
          weatherCode: i == 1 ? 0 : 3,
          maxTemp: 18.0 + i,
          minTemp: 10.0 + i,
        ),
    ],
  );
}

// Подмена настоящего клиента: сеть не нужна, ответом управляет тест
class FakeWeatherApi implements WeatherApiClient {
  WeatherException? error; // если задана, любой запрос падает с ней
  bool cityExists = true;
  Completer<void>? gate; // пока не завершён, запрос «висит»
  final List<String> requestedCities = [];

  @override
  Future<City?> findCity(String name) async {
    requestedCities.add(name);
    await gate?.future;
    if (error != null) throw error!;
    if (!cityExists) return null;
    return City(name: name, latitude: 55.75, longitude: 37.62);
  }

  @override
  Future<Weather> loadWeather(City city) async {
    if (error != null) throw error!;
    return sampleWeather(cityName: city.name);
  }
}
