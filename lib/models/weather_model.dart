// lib/models/weather_model.dart

class Weather {
  final String cityName;
  final double temperatureCelcius;
  final String description; // Hava durumu açıklaması (örn: "açık", "parçalı bulutlu")
  final String iconCode;    // Hava durumu ikonu için kod (OpenWeatherMap'ten gelir)

  Weather({
    required this.cityName,
    required this.temperatureCelcius,
    required this.description,
    required this.iconCode,
  });

  // JSON'dan Weather nesnesi oluşturan factory constructor
  factory Weather.fromJson(Map<String, dynamic> json) {
    return Weather(
      cityName: json['name'] ?? 'Bilinmiyor',
      // Sıcaklık Kelvin olarak gelir, Celsius'a çevrilir.
      // API servisinde de yapılabilir ama modelde de olabilir.
      // OpenWeatherMap 'units=metric' ile zaten Celsius verir.
      temperatureCelcius: (json['main']?['temp'] as num?)?.toDouble() ?? 0.0,
      description: (json['weather'] != null && (json['weather'] as List).isNotEmpty)
          ? json['weather'][0]['description'] ?? 'Açıklama yok'
          : 'Açıklama yok',
      iconCode: (json['weather'] != null && (json['weather'] as List).isNotEmpty)
          ? json['weather'][0]['icon'] ?? ''
          : '',
    );
  }

  // Hava durumu ikonunu göstermek için URL (OpenWeatherMap formatı)
  String get iconUrl {
    if (iconCode.isEmpty) return ''; // Eğer ikon kodu yoksa boş URL
    return 'https://openweathermap.org/img/wn/$iconCode@2x.png';
  }
}
