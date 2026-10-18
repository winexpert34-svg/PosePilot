import 'dart:ui' as ui;

class PoseLanguage {
  static bool get russian =>
      ui.PlatformDispatcher.instance.locale.languageCode.toLowerCase() == 'ru';

  static String text(String english, String russianText) =>
      russian ? russianText : english;

  static const Map<String, String> _translations = {
    'Step into frame': 'Встаньте в кадр',
    'Perfect ✨ Hold still': 'Отлично ✨ Не двигайтесь',
    'Move back so I can see you': 'Отойдите немного назад',
    'Relax your shoulders': 'Расслабьте плечи',
    'Shift your hips slightly': 'Слегка сместите бёдра',
    'Open your arms a little': 'Немного разведите руки',
    'Bring your arms in slightly': 'Немного приблизьте руки к телу',
    'Widen your stance slightly': 'Поставьте ноги чуть шире',
    'Bring your feet a little closer': 'Поставьте ноги чуть ближе',
    'Almost — hold that': 'Почти получилось — замрите',
    'Perfect ✨': 'Отлично ✨',
  };

  static String translate(String value) =>
      russian ? (_translations[value] ?? value) : value;
}
