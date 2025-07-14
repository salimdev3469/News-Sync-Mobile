// lib/models/exchange_rate_model.dart

class MarketData {
  final double? usdToTry;
  final double? eurToTry;
  final double? goldPriceTry; // Gram altın fiyatı (TRY)

  MarketData({
    this.usdToTry,
    this.eurToTry,
    this.goldPriceTry,
  });

  // Bu factory constructor'ı, API servisinden gelen birleşik veriyi parse etmek için kullanılacak.
  // API servis katmanında farklı API'lerden gelen veriler birleştirilip bu modele uygun hale getirilecek.
  // Bu yüzden burada doğrudan bir fromJson metodu (tek bir API yanıtına özel) eklemiyoruz.
  // Servis katmanı bu modeli doldurmaktan sorumlu olacak.

  // Verilerin yüklenip yüklenmediğini kontrol etmek için yardımcı getter'lar
  bool get hasUsdData => usdToTry != null && usdToTry! > 0;
  bool get hasEurData => eurToTry != null && eurToTry! > 0;
  bool get hasGoldData => goldPriceTry != null && goldPriceTry! > 0;
}
