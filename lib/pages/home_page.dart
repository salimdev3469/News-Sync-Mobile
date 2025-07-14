import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async'; // For Timer.periodic
import 'package:news_sync_mobile/services/notification_service.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart'; // Konum için eklendi
import 'package:geocoding/geocoding.dart';   // Konumdan şehir adı almak için eklendi
import '../controllers/theme_controller.dart';
import '../widgets/news_card.dart';
import '../services/api_service.dart';
import '../models/exchange_rate_model.dart';
import '../models/weather_model.dart';
import 'package:news_sync_mobile/pages/news_detail_page.dart';

Future<List<Map<String, dynamic>>> fetchLastFiveBreakingNews() async {
  final snapshot = await FirebaseFirestore.instance
      .collection('Articles')
      .where('category', isEqualTo: 'Son Dakika')
      .orderBy('created_at_server', descending: true)
      .limit(5)
      .get();

  return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
}

Future<void> scheduleBreakingNewsNotifications() async {
  final List<Map<String, dynamic>> newsList = await fetchLastFiveBreakingNews();

  for (int i = 0; i < newsList.length; i++) {
    final Map<String, dynamic> article = newsList[i];

    final String title = article['title'] ?? 'Son Dakika Haberi';
    final String body = (article['content'] as String?)?.substring(0, 80) ?? '';

    final scheduledTime = DateTime.now().add(Duration(hours: i * 2));

    await flutterLocalNotificationsPlugin.zonedSchedule(
      i, // unique notification id
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'breaking_news_channel',
          'Breaking News',
          channelDescription: 'Son Dakika haber bildirimleri',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}



class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> _cachedArticles = [];
  bool _isCacheUsed = false;
  List<Map<String, dynamic>> _articles = [];
  bool _isLoadingArticles = false;
  bool _hasMoreArticles = true;
  DocumentSnapshot? _lastDocument;
  ScrollController _scrollController = ScrollController();

  String? _selectedCityForNews; // NULL → tüm haberler gelsin
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;
  bool isDarkMode = false;
  bool _isSearching = false;
  String _searchQuery = "";
  String _selectedCategory = "Tümü";
  int _selectedIndex = 0;
  final TextEditingController _newPasswordController = TextEditingController();
  final ApiService _apiService = ApiService();
  MarketData? _marketData;
  Weather? _weatherData;

  final int _pageSize = 9;


  Widget _getWeatherIconByDescription(String description) {
    final lowerDesc = description.toLowerCase();

    if (lowerDesc.contains("clear")) {
      return Icon(Icons.wb_sunny, size: 24, color: Colors.yellowAccent);
    } else if (lowerDesc.contains("cloud")) {
      return Icon(Icons.cloud, size: 24, color: Colors.grey[300]);
    } else if (lowerDesc.contains("rain")) {
      return Icon(Icons.grain, size: 24, color: Colors.blueAccent);
    } else if (lowerDesc.contains("snow")) {
      return Icon(Icons.ac_unit, size: 24, color: Colors.white);
    } else {
      return Icon(Icons.wb_sunny_outlined, size: 24, color: Colors.white);
    }
  }


  bool _isLoadingMarketData = true;
  bool _isLoadingWeatherData = true;
  bool _isFetchingDeviceLocation = false; // Cihaz konumu alınırken loading state'i
  Timer? _dataRefreshTimer;
  String _currentCityForWeather = "Istanbul";// Varsayılan veya son bilinen şehir


  Map<String, String> getCategoryTranslations() {
    return {
      "Tümü": "All",
      "Manşet": "manset",
      "Son Dakika":"son-dakika",
      "Türkiye": "turkiye",
      "Dünya": "dunya",
      "Ekonomi": "ekonomi",
      "Spor": "spor",
      "Sağlık": "saglik",
      "Kültür Sanat": "kultur-sanat",
      "Eğitim": "egitim",
      "Bilim Teknoloji": "bilim-teknoloji",
      "Çevre": "cevre",
      "Yaşam": "yasam",
      "Foto Galeri": "foto-galeri",
      "Video Galeri": "video-galeri",
      "Analiz": "analiz",
      "Özel Haber": "ozel-haber",
      "Yurt": "yurt",
      "Politika": "politika",
      "Asayiş": "asayis",
      "Gündem": "gundem",
    };

  }


  @override
  void initState() {
    super.initState();
    _loadInitialArticles();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMoreArticles();
      }
    });
    isDarkMode = themeNotifier.value == ThemeMode.dark;
    _currentUser = _auth.currentUser;
    _auth.authStateChanges().listen((user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }

    });

    _fetchInitialData();

    _dataRefreshTimer = Timer.periodic(const Duration(minutes: 15), (timer) {
      if (mounted) {
        _fetchMarketData();
        if (!_isFetchingDeviceLocation) { // Cihaz konumu alınıyorsa otomatik güncellemeyi atla
          _fetchWeatherData(_currentCityForWeather);
        }
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _dataRefreshTimer?.cancel();
    _newPasswordController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    _cachedArticles.clear();
    await Future.wait([
      _fetchMarketData(),
      _fetchWeatherData(_currentCityForWeather),
    ]);
    await _loadInitialArticles();
  }


  Future<void> _fetchMarketData() async {
    if (!mounted) return;
    setState(() => _isLoadingMarketData = true);
    try {
      final marketDataResponse = await _apiService.getMarketData();
      if (mounted) {
        setState(() {
          _marketData = marketDataResponse;
        });
      }
    } catch (e) {
      print("Error fetching market data (HomePage): $e");
    } finally {
      if (mounted) {
        setState(() => _isLoadingMarketData = false);
      }
    }
  }

  Future<void> _loadInitialArticles() async {
    if (_cachedArticles.isNotEmpty) {
      print("Loading articles from cache...");
      setState(() {
        _articles = List.from(_cachedArticles);
        _hasMoreArticles = true;
        _isCacheUsed = true;
      });
      return;
    } else {
      _articles.clear();
      _lastDocument = null;
      _hasMoreArticles = true;
      await _loadMoreArticles();
    }
  }


  Future<void> _loadMoreArticles() async {
    if (_isLoadingArticles || !_hasMoreArticles) return;

    setState(() => _isLoadingArticles = true);

    try {
      Query query = FirebaseFirestore.instance.collection('Articles');

      if (_selectedCategory != "Tümü") {
        query = query.where(
          'category',
          isEqualTo: _selectedCategory.trim(),
        );
      }

      if (_selectedCityForNews != null && _selectedCityForNews!.isNotEmpty) {
        query = query.where(
          'cities',
          arrayContains: _selectedCityForNews,
        );
      }

      query = query
          .orderBy('created_at_server', descending: true)
          .limit(_pageSize);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      QuerySnapshot snapshot = await query.get();

      print("FIRESTORE QUERY - CATEGORY: $_selectedCategory - CITY: $_selectedCityForNews - FOUND: ${snapshot.docs.length}");

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;

        final newArticles = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          String newsCardDate = 'No date';
          String detailPagePublishDate = 'No publish date';

          var createdAtField = data['created_at_server'];
          if (createdAtField != null) {
            if (createdAtField is Timestamp) {
              newsCardDate = createdAtField.toDate().toIso8601String().substring(0, 10);
            } else if (createdAtField is String) {
              newsCardDate = createdAtField.length > 10
                  ? createdAtField.substring(0, 10)
                  : createdAtField;
            }
          }

          var publishDateField = data['publish_date_str'];
          if (publishDateField != null) {
            if (publishDateField is Timestamp) {
              detailPagePublishDate =
                  publishDateField.toDate().toIso8601String();
            } else if (publishDateField is String) {
              detailPagePublishDate = publishDateField;
            }
          }

          return {
            'id': doc.id,
            'title': data['title'] ?? 'No Title',
            'image': data['image_url'] ?? '',
            'date': newsCardDate,
            'content': data['content'] ?? '',
            'category': data['category'] ?? '',
            'publish_date_str': detailPagePublishDate,
            'source_name': data['source_name'] ?? '',
            'url': data['url'],
          };
        }).toList();

        setState(() {
          _articles.addAll(newArticles);
          _cachedArticles = List.from(_articles);
        });

        if (snapshot.docs.length < _pageSize) {
          _hasMoreArticles = false;
        }
      } else {
        print("FIRESTORE QUERY returned NO results for category: $_selectedCategory and city: $_selectedCityForNews");
        _hasMoreArticles = false;
      }
    } catch (e) {
      print("Error loading articles: $e");
    } finally {
      setState(() => _isLoadingArticles = false);
    }
  }






  Future<void> _fetchWeatherData(String cityName) async {
    if (!mounted) return;
    // Kullanıcı bir şehir seçtiğinde veya ilk yüklemede _currentCityForWeather'ı güncelle
    if (_currentCityForWeather != cityName && !_isFetchingDeviceLocation) {
      setState(() {
        _currentCityForWeather = cityName;
      });
    }
    setState(() => _isLoadingWeatherData = true);
    try {
      final weatherResponse = await _apiService.getWeather(cityName);
      if (mounted) {
        setState(() {
          _weatherData = weatherResponse;
          // API'den gelen şehir adını kullanmak daha doğru olabilir (örn: "Istanbul" -> "İstanbul")
          if (weatherResponse != null && weatherResponse.cityName.isNotEmpty) {
            _currentCityForWeather = weatherResponse.cityName;
          } else if (weatherResponse == null) {
            print("Weather data for $cityName could not be fetched. Displaying last known or default.");
            // Burada _currentCityForWeather'ı eski değerine döndürmek veya bir hata mesajı göstermek düşünülebilir.
          }
        });
      }
    } catch (e) {
      print("Error fetching weather for $cityName (HomePage): $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$cityName için hava durumu alınamadı.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingWeatherData = false);
      }
    }
  }

  // Cihazın mevcut konumunu alıp hava durumunu getiren fonksiyon
  Future<void> _fetchWeatherForDeviceLocation() async {
    if (!mounted) return;
    setState(() {
      _isFetchingDeviceLocation = true; // Yükleniyor durumunu başlat
      _isLoadingWeatherData = true; // Genel hava durumu yükleniyorunu da true yapalım
    });

    bool serviceEnabled;
    LocationPermission permission;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Konum servisleri kapalı. Lütfen açın.')),
          );
        }
        return; // setState'leri finally içinde false'a çek
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Konum izni reddedildi.')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Konum izni kalıcı olarak reddedildi. Ayarlardan izin vermeniz gerekiyor.')),
          );
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium); // veya .high

      // Konumdan şehir adını al (geocoding)
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String? city = place.locality; // locality genellikle şehir adını verir
        if (city == null || city.isEmpty) {
          city = place.subAdministrativeArea; // Bazı durumlarda ilçe adı şehir yerine geçebilir
        }

        if (city != null && city.isNotEmpty) {
          if (mounted) {
            setState(() {
              _currentCityForWeather = city!; // Cihazdan alınan şehri ayarla
            });
            await _fetchWeatherData(city); // Yeni şehir için hava durumunu getir
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Konumdan şehir adı alınamadı.')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Konum bilgisi çözümlenemedi.')),
          );
        }
      }
    } catch (e) {
      print("Error fetching device location or weather: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Konum alınırken bir hata oluştu: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingDeviceLocation = false;
          _isLoadingWeatherData = false; // Genel yükleniyor durumunu da bitir
        });
      }
    }
  }


  Future<void> _signOut() async {
    await _auth.signOut();
  }

  void _onBottomNavTapped(int index) async {
    final ModalRoute? currentRoute = ModalRoute.of(context);

    if (_selectedIndex == index && index == 0 && currentRoute?.settings.name == '/home') {
      return;
    }
    if (_selectedIndex == index && index != 0 && index != 1) {
      return;
    }

    if (index != 1 && _selectedIndex != index && mounted) {
      setState(() {
        _selectedIndex = index;
      });
    }

    switch (index) {
      case 0:
        if (currentRoute?.settings.name != '/home') {
          Navigator.pushReplacementNamed(context, '/home');
        }
        break;
      case 1:
        if (mounted && _selectedIndex != 1) {
          setState(() {
            _selectedIndex = 1;
          });
        }
        final selectedCity = await Navigator.pushNamed(context, '/location');
        if (mounted) {
          setState(() {
            _selectedIndex = 0;
          });
          if (selectedCity is String && selectedCity.isNotEmpty) {
            setState(() {
              _selectedCityForNews = selectedCity;
              _articles.clear();
              _lastDocument = null;
              _hasMoreArticles = true;
            });
            await _fetchWeatherData(selectedCity);
            await _loadMoreArticles();
          }
        }
        break;

      case 2:
      // ignore: unused_local_variable
        final result = await Navigator.pushNamed(context, '/saved_news');
        if (mounted) {
          setState(() {
            _selectedIndex = 0;
          });
        }
        break;
    }
  }

  String _maskPassword(String password) {
    if (password.length <= 3) {
      return List.generate(password.length, (_) => '#').join();
    }
    return '${password.substring(0, 3)}${List.generate(password.length - 3, (_) => '#').join()}';
  }

  Future<void> _changePassword(String newPassword) async {
    User? user = _auth.currentUser;

    if (user != null) {
      try {
        await user.updatePassword(newPassword);

        String maskedPassword = _maskPassword(newPassword);
        await _firestore.collection('Users').doc(user.uid).update({
          'MaskedPassword': maskedPassword,
        });

        if (!mounted) return;

        // Önce dialog kapat
        Navigator.of(context, rootNavigator: true).pop();

        // Sonra Drawer varsa onu da kapat
        Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);

        // Artık Snackbar güvenle üstte çıkar
        ScaffoldMessenger.of(
          Navigator.of(context, rootNavigator: true).context,
        ).showSnackBar(
          const SnackBar(
            content: Text('Parola başarıyla değiştirildi ve veritabanı güncellendi!'),
            behavior: SnackBarBehavior.floating,
          ),
        );

      } on FirebaseAuthException catch (e) {
        if (!mounted) return;

        Navigator.of(context, rootNavigator: true).pop();
        Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);

        String errorMessage;

        switch (e.code) {
          case 'weak-password':
            errorMessage = 'Parola en az 6 karakter olmalıdır.';
            break;
          case 'requires-recent-login':
            errorMessage = 'Parola değiştirmek için tekrar giriş yapmanız gerekiyor.';
            break;
          case 'email-already-in-use':
            errorMessage = 'Bu e-posta adresi zaten kullanımda.';
            break;
          case 'invalid-email':
            errorMessage = 'Geçersiz e-posta adresi.';
            break;
          default:
            errorMessage = 'Parola değiştirilirken bir hata oluştu.';
            break;
        }

        ScaffoldMessenger.of(
          Navigator.of(context, rootNavigator: true).context,
        ).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

    } else {
      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pop();
      Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);

      ScaffoldMessenger.of(
        Navigator.of(context, rootNavigator: true).context,
      ).showSnackBar(
        const SnackBar(
          content: Text('Şu anda giriş yapmış bir kullanıcı yok.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }



  void _showChangePasswordDialog() {
    _newPasswordController.clear();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Parola Güncelle'),
          content: TextField(
            controller: _newPasswordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Yeni Parola'),
            onSubmitted: (_) {
              if (_newPasswordController.text.isNotEmpty) {
                _changePassword(_newPasswordController.text);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Parola kısmı boş olamaz.')),
                );
              }
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Vazgeç'),
              onPressed: () {
                Navigator.of(context).pop();
                _newPasswordController.clear();
              },
            ),
            TextButton(
              child: const Text('Güncelle'),
              onPressed: () {
                if (_newPasswordController.text.isNotEmpty) {
                  _changePassword(_newPasswordController.text);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Parola kısmı boş olamaz.')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryChip(String category) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(category),
        selected: _selectedCategory == category,
        onSelected: (bool selected) {
          setState(() {
            _selectedCategory = category;
            _articles.clear();
            _lastDocument = null;
            _hasMoreArticles = true;
          });
          _fetchInitialData();
        },
        backgroundColor: Theme.of(context).chipTheme.backgroundColor,
        selectedColor: Colors.lightBlueAccent,
        labelStyle: Theme.of(context).chipTheme.labelStyle,
      ),
    );
  }


  Widget _buildInfoColumn(String emoji, String label, String? value, {bool isLoading = false}) {
    String displayValue = "...";
    if (isLoading) {
      displayValue = "...";
    } else if (value != null && value.isNotEmpty) {
      displayValue = value;
    } else {
      displayValue = "N/A";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Colors.white),
        ),
        SizedBox(
          height: 20,
          child: isLoading
              ? const SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
              : Text(
            displayValue,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.white,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }


  Widget _buildWeatherInfo() {
    String cityNameDisplay = _currentCityForWeather;
    String tempDisplay = "...";
    Widget weatherIconWidget = Icon(Icons.sunny, size: 35, color: Colors.orange);

    bool showLoading = _isLoadingWeatherData || _isFetchingDeviceLocation;

    if (showLoading) {
      cityNameDisplay = _isFetchingDeviceLocation ? "Konum alınıyor..." : "...";
      tempDisplay = "...";
      weatherIconWidget = const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    } else if (_weatherData != null) {
      cityNameDisplay = _weatherData!.cityName;
      tempDisplay = "${_weatherData!.temperatureCelcius.toStringAsFixed(0)}°C";

      if (_weatherData!.iconUrl.isNotEmpty) {
        weatherIconWidget = Image.network(
          _weatherData!.iconUrl,
          width: 28,
          height: 28,
          colorBlendMode: BlendMode.srcIn,
          errorBuilder: (context, error, stackTrace) {
            return _getWeatherIconByDescription(_weatherData!.description);
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            );
          },
        );
      } else {
        weatherIconWidget = _getWeatherIconByDescription(_weatherData!.description);
      }
    } else {
      cityNameDisplay = _currentCityForWeather;
      tempDisplay = "N/A";
      weatherIconWidget = Icon(Icons.error_outline, size: 24, color: Colors.white);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on_outlined, size: 18, color: Colors.white),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                cityNameDisplay,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            weatherIconWidget,
            const SizedBox(width: 3),
            Text(
              tempDisplay,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        SizedBox(
          height: 28,
          child: TextButton.icon(
            icon: const Icon(Icons.my_location, size: 16, color: Colors.white),
            label: const Text(
              "Konumumu Kullan",
              style: TextStyle(
                fontSize: 12,
                color: Colors.white,
              ),
            ),
            style: TextButton.styleFrom(
              side: const BorderSide(color: Colors.white, width: 1),
              backgroundColor: Colors.white.withOpacity(0.2),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: _isFetchingDeviceLocation ? null : _fetchWeatherForDeviceLocation,
          ),
        ),
      ],
    );
  }


  Widget _buildMarketDataCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo, Colors.blueAccent],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildInfoColumn("💵", "Dolar", _marketData?.usdToTry?.toStringAsFixed(2), isLoading: _isLoadingMarketData),
          _buildInfoColumn("💶", "Euro", _marketData?.eurToTry?.toStringAsFixed(2), isLoading: _isLoadingMarketData),
          _buildInfoColumn("🪙", "Altın", _marketData?.goldPriceTry?.toStringAsFixed(2), isLoading: _isLoadingMarketData),
          Flexible(child: _buildWeatherInfo()),
        ],
      ),
    );
  }




  @override
  Widget build(BuildContext context) {
    final isDarkModeTheme = Theme.of(context).brightness == Brightness.dark;
    final String drawerLogoPath = isDarkModeTheme ? 'assets/appBarLogoDark.png' : 'assets/appBarLogo.png';
    final String appBarLogoPath = isDarkModeTheme ? 'assets/appBarLogoDark.png' : 'assets/appBarLogo.png';
    final List<Map<String, dynamic>> filteredArticles = _articles.where((article) {
      final title = (article['title'] ?? '').toString().toLowerCase();
      final query = _searchQuery.trim().toLowerCase();
      return query.isEmpty || title.contains(query);
    }).toList();

    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.indigo, Colors.blueAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Image.asset(
                  drawerLogoPath,
                  height: 120,
                ),
              ),
            ),

            if (_currentUser != null && _currentUser!.email != null)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                title: Text(
                  'Merhaba, ${_currentUser!.email!}',
                  style: const TextStyle(fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            if (_currentUser != null && !(_currentUser?.isAnonymous ?? true))
              ListTile(
                title: const Text('Parola Güncelle'),
                leading: const Icon(Icons.lock_outline),
                onTap: () {
                  Navigator.pop(context);         // Drawer'ı kapat
                  _showChangePasswordDialog();    // Sonra dialog aç
                },
              ),

            const Divider(height: 1),

            SwitchListTile(
              title: const Text('Tema'),
              value: isDarkModeTheme,
              onChanged: (val) {
                themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
              },
            ),

            if (_currentUser == null || (_currentUser?.isAnonymous ?? true))
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('Giriş Yap'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/login');
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Çıkış Yap'),
                onTap: () async {
                  Navigator.pop(context);
                  await _signOut();
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                        (Route<dynamic> route) => false,
                  );
                },
              ),
          ],
        ),
      ),
      appBar: AppBar(
        elevation: 1,
        title: AnimatedSwitcher(
          duration: Duration(milliseconds: 400),
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: _isSearching
              ? TextField(
            key: ValueKey(true),
            autofocus: true,
            decoration: InputDecoration(
              hintText: "Ara..",
              border: InputBorder.none,
              hintStyle: TextStyle(color: Colors.grey.shade600),
            ),
            style: TextStyle(color: isDarkModeTheme ? Colors.white : Colors.black),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          )
              : Image.asset(
            appBarLogoPath,
            height: 100,
            key: ValueKey(false),
          ),
        ),

        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) _searchQuery = "";
              });
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchInitialData,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildCategoryChip('Tümü'),
                      _buildCategoryChip('Manşet'),
                      _buildCategoryChip('Son Dakika'),
                      _buildCategoryChip('Türkiye'),
                      _buildCategoryChip('Dünya'),
                      _buildCategoryChip('Ekonomi'),
                      _buildCategoryChip('Spor'),
                      _buildCategoryChip('Sağlık'),
                      _buildCategoryChip('Kültür Sanat'),
                      _buildCategoryChip('Eğitim'),
                      _buildCategoryChip('Bilim Teknoloji'),
                      _buildCategoryChip('Çevre'),
                      _buildCategoryChip('Yaşam'),
                      _buildCategoryChip('Analiz'),
                      _buildCategoryChip('Özel Haber'),
                      _buildCategoryChip('Yurt'),
                      _buildCategoryChip('Politika'),
                      _buildCategoryChip('Asayiş'),
                      _buildCategoryChip('Gündem'),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                ),
                child: _buildMarketDataCard(),
              ),
            ),
            if (_selectedCityForNews != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Filtre: $_selectedCityForNews",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedCityForNews = null;
                            _articles.clear();
                            _lastDocument = null;
                            _hasMoreArticles = true;
                          });
                          _fetchInitialData();
                        },

                        child: const Text("Filtreyi Kaldır"),
                      )
                    ],
                  ),
                ),
              ),
            // DİKKAT: SliverToBoxAdapter içine koyuyoruz
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  if (index < filteredArticles.length) {
                    final article = filteredArticles[index];
                    return NewsCard(
                      title: article['title'] ?? 'No Title',
                      imageUrl: article['image'] ?? '',
                      date: article['date'] ?? 'No Date',
                      onTap: () {
                        Navigator.of(context).push(
                          PageRouteBuilder(
                            settings: RouteSettings(
                              name: '/news_detail',
                              arguments: article,
                            ),
                            pageBuilder: (context, animation, secondaryAnimation) {
                              return NewsDetailPage();
                            },
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              final offsetAnimation = Tween<Offset>(
                                begin: Offset(0.0, 0.1),
                                end: Offset.zero,
                              ).animate(animation);

                              return SlideTransition(
                                position: offsetAnimation,
                                child: FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                              );
                            },
                            transitionDuration: Duration(milliseconds: 500),
                          ),
                        );
                      },
                    );
                  } else if (_hasMoreArticles && !_isLoadingArticles) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Center(
                        child: ElevatedButton(
                          onPressed: _loadMoreArticles,
                          child: Text("Daha Fazla"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,         // buton arka plan rengi
                            foregroundColor: Colors.white,        // buton yazı rengi
                            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),

                      ),
                    );
                  } else if (_isLoadingArticles) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  } else {
                    return SizedBox.shrink();
                  }
                },
                childCount: filteredArticles.length + 1,
              ),
            ),

          ],
        ),
      ),





      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onBottomNavTapped,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Anasayfa'),
          BottomNavigationBarItem(icon: Icon(Icons.location_on), label: 'Konum'),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark_add), label: 'Kaydedilenler'),
        ],
      ),
    );
  }
}