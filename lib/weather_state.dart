import 'package:flutter/foundation.dart';

import 'weather.dart';
import 'weather_api_client.dart';
import 'weather_repository.dart';

enum LoadStatus {
  idle, // ещё ничего не искали
  loading,
  success,
  notFound, // пустой результат: такого города нет
  error,
}

// Что сейчас на экране: загрузка, погода, «не найдено» или ошибка.
class WeatherState extends ChangeNotifier {
  WeatherState(this._repository);

  final WeatherRepository _repository;

  LoadStatus status = LoadStatus.idle;
  Weather? weather;
  String? errorMessage;
  String? inputError; // ошибка под полем ввода
  String lastQuery = '';

  // Номер запроса. Если пока грузилась погода, пользователь запустил новый
  // поиск, ответ от старого запроса нам уже не нужен.
  int _requestNumber = 0;
  bool _disposed = false;

  Future<void> search(String text) async {
    final query = text.trim();

    if (query.isEmpty) {
      inputError = 'Введите название города';
      notifyListeners();
      return;
    }

    inputError = null;
    lastQuery = query;
    status = LoadStatus.loading;
    final myNumber = ++_requestNumber;
    notifyListeners();

    try {
      final result = await _repository.getWeather(query);
      if (_isOutdated(myNumber)) return;

      weather = result;
      status = LoadStatus.success;
    } on WeatherException catch (error) {
      if (_isOutdated(myNumber)) return;

      if (error.type == WeatherErrorType.cityNotFound) {
        status = LoadStatus.notFound;
      } else {
        errorMessage = error.message;
        status = LoadStatus.error;
      }
    } catch (_) {
      if (_isOutdated(myNumber)) return;

      errorMessage = 'Произошла непредвиденная ошибка.';
      status = LoadStatus.error;
    }
    notifyListeners();
  }

  // Кнопка «Повторить»: ещё раз ищем последний город
  Future<void> retry() => search(lastQuery);

  bool _isOutdated(int number) => _disposed || number != _requestNumber;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
