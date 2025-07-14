// lib/services/api_service.dart
import 'dart:convert'; // JSON decode/encode için
import 'package:http/http.dart' as http; // HTTP istekleri için
import '../models/exchange_rate_model.dart'; // Oluşturduğumuz MarketData modeli
import '../models/weather_model.dart';    // Oluşturduğumuz Weather modeli

class ApiService {
  // --- Döviz Kurları (Frankfurter.app API'si) ---
  final String _frankfurterBaseUrl = 'https://api.frankfurter.app';

  Future<MarketData> getMarketData() async {
    double? usdTry;
    double? eurTry;
    double? goldTry; // Altın için yer tutucu

    try {
      // USD -> TRY
      final usdResponse = await http.get(Uri.parse('$_frankfurterBaseUrl/latest?from=USD&to=TRY'));
      if (usdResponse.statusCode == 200) {
        final usdData = jsonDecode(usdResponse.body);
        usdTry = (usdData['rates']?['TRY'] as num?)?.toDouble();
      } else {
        print('Frankfurter API USD Error: ${usdResponse.statusCode}');
      }

      // EUR -> TRY
      final eurResponse = await http.get(Uri.parse('$_frankfurterBaseUrl/latest?from=EUR&to=TRY'));
      if (eurResponse.statusCode == 200) {
        final eurData = jsonDecode(eurResponse.body);
        eurTry = (eurData['rates']?['TRY'] as num?)?.toDouble();
      } else {
        print('Frankfurter API EUR Error: ${eurResponse.statusCode}');
      }

      // --- Altın Fiyatı (Yer Tutucu) ---
      // GERÇEK BİR ALTIN API'Sİ BULUP BURAYI GÜNCELLEMENİZ GEREKECEK!
      // Bu API ons altın fiyatını USD olarak veriyorsa, USD/TRY kurunu kullanarak
      // gram altına çevirmeniz gerekir (1 ons ~ 31.1035 gram).
      // Şimdilik örnek bir değer kullanalım.
      // Örneğin, ons altın 2300 USD ve USD/TRY kuru 32.15 ise:
      // Gram Altın (TRY) = (2300 * 32.15) / 31.1035
      if (usdTry != null) {
        // Bu sadece bir simülasyon, gerçek API'ye göre değişir.
        double onsGoldUsd = 2315.50; // Ons altının USD fiyatı (Bu değeri de bir API'den alabilirsiniz)
        goldTry = (onsGoldUsd * usdTry) / 31.1035;
      } else {
        goldTry = 2420.00; // USD kuru alınamazsa varsayılan bir değer
      }


    } catch (e) {
      print('Piyasa verileri alınırken hata oluştu: $e');
      // Hata durumunda null değerler dönecek, UI'da kontrol edilecek
    }

    return MarketData(
      usdToTry: usdTry,
      eurToTry: eurTry,
      goldPriceTry: goldTry,
    );
  }

  // --- Hava Durumu (OpenWeatherMap API'si) ---
  final String _weatherApiKey = '078b2078fc8cd3c744477fe634d8acea'; // SENİN API ANAHTARIN
  final String _weatherBaseUrl = 'https://api.openweathermap.org/data/2.5/weather';

  Future<Weather?> getWeather(String cityName) async {
    // Türkçe karakterleri URL için güvenli hale getirme (basit yöntem)
    // Daha gelişmiş bir çözüm için 'slugify' gibi bir paket kullanılabilir.
    final String cityParam = Uri.encodeComponent(cityName
        .replaceAll('İ', 'I') // Büyük İ
        .replaceAll('ı', 'i')
        .replaceAll('Ö', 'O')
        .replaceAll('ö', 'o')
        .replaceAll('Ü', 'U')
        .replaceAll('ü', 'u')
        .replaceAll('Ş', 'S')
        .replaceAll('ş', 's')
        .replaceAll('Ç', 'C')
        .replaceAll('ç', 'c')
        .replaceAll('Ğ', 'G')
        .replaceAll('ğ', 'g'));

    final String requestUrl =
        '$_weatherBaseUrl?q=$cityParam&appid=$_weatherApiKey&units=metric&lang=tr';
    // units=metric: Sıcaklığı Celsius olarak alır.
    // lang=tr: Açıklamaları Türkçe alır.

    try {
      final response = await http.get(Uri.parse(requestUrl));
      if (response.statusCode == 200) {
        return Weather.fromJson(jsonDecode(response.body));
      } else {
        // API'den hata dönerse (örn: şehir bulunamadı, API anahtarı yanlış)
        print('OpenWeatherMap API Hatası: ${response.statusCode}');
        print('Yanıt: ${response.body}');
        return null; // Hata durumunda null dön
      }
    } catch (e) {
      print('Hava durumu verisi alınırken hata oluştu: $e');
      return null; // Hata durumunda null dön
    }
  }
}
