import 'package:flutter/material.dart';

// Сервис отдаёт погоду числом (код WMO). Здесь переводим его в текст и значок.

String weatherDescription(int code) {
  if (code == 0) return 'Ясно';
  if (code == 1) return 'Преимущественно ясно';
  if (code == 2) return 'Переменная облачность';
  if (code == 3) return 'Пасмурно';
  if (code == 45 || code == 48) return 'Туман';
  if (code >= 51 && code <= 57) return 'Морось';
  if (code == 66 || code == 67) return 'Ледяной дождь';
  if (code >= 61 && code <= 65) return 'Дождь';
  if (code >= 71 && code <= 77) return 'Снег';
  if (code >= 80 && code <= 82) return 'Ливень';
  if (code == 85 || code == 86) return 'Снегопад';
  if (code >= 95 && code <= 99) return 'Гроза';
  return 'Нет данных';
}

IconData weatherIcon(int code) {
  if (code == 0 || code == 1) return Icons.wb_sunny;
  if (code == 2) return Icons.wb_cloudy;
  if (code == 3) return Icons.cloud;
  if (code == 45 || code == 48) return Icons.blur_on;
  if (code >= 51 && code <= 67) return Icons.water_drop;
  if (code >= 71 && code <= 77) return Icons.ac_unit;
  if (code >= 80 && code <= 82) return Icons.water_drop;
  if (code == 85 || code == 86) return Icons.ac_unit;
  if (code >= 95 && code <= 99) return Icons.flash_on;
  return Icons.help_outline;
}
