import 'package:flutter/material.dart';

import 'weather_api_client.dart';
import 'weather_cache.dart';
import 'weather_repository.dart';
import 'weather_screen.dart';
import 'weather_state.dart';

void main() {
  final repository = WeatherRepository(
    api: WeatherApiClient(),
    cache: SharedPrefsWeatherCache(),
  );
  runApp(WeatherApp(weatherState: WeatherState(repository)));
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key, required this.weatherState});

  final WeatherState weatherState;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Прогноз погоды',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: WeatherScreen(weatherState: weatherState),
    );
  }
}
