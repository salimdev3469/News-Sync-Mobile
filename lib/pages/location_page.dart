import 'package:flutter/material.dart';
import 'package:news_sync_mobile/pages/main_layout.dart';

class LocationPage extends StatefulWidget {
  const LocationPage({super.key});

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  final List<String> cities = const [
    'Adana', 'Adıyaman', 'Afyonkarahisar', 'Ağrı', 'Aksaray', 'Amasya',
    'Ankara', 'Antalya', 'Ardahan', 'Artvin', 'Aydın', 'Balıkesir', 'Bartın',
    'Batman', 'Bayburt', 'Bilecik', 'Bingöl', 'Bitlis', 'Bolu', 'Burdur',
    'Bursa', 'Çanakkale', 'Çankırı', 'Çorum', 'Denizli', 'Diyarbakır',
    'Düzce', 'Edirne', 'Elazığ', 'Erzincan', 'Erzurum', 'Eskişehir',
    'Gaziantep', 'Giresun', 'Gümüşhane', 'Hakkâri', 'Hatay', 'Iğdır',
    'Isparta', 'İstanbul', 'İzmir', 'Kahramanmaraş', 'Karabük', 'Karaman',
    'Kars', 'Kastamonu', 'Kayseri', 'Kilis', 'Kırıkkale', 'Kırklareli',
    'Kırşehir', 'Kocaeli', 'Konya', 'Kütahya', 'Malatya', 'Manisa', 'Mardin',
    'Mersin', 'Muğla', 'Muş', 'Nevşehir', 'Niğde', 'Ordu', 'Osmaniye',
    'Rize', 'Sakarya', 'Samsun', 'Siirt', 'Sinop', 'Sivas', 'Şanlıurfa',
    'Şırnak', 'Tekirdağ', 'Tokat', 'Trabzon', 'Tunceli', 'Uşak', 'Van',
    'Yalova', 'Yozgat', 'Zonguldak',
  ];

  String searchQuery = '';
  late List<String> filteredCities;

  @override
  void initState() {
    super.initState();
    filteredCities = cities;
  }

  void updateSearch(String query) {
    setState(() {
      searchQuery = query;
      filteredCities = cities
          .where((city) => city.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MainLayout(
      currentIndex: 1,
      child: Scaffold(
        body: Stack(
          children: [
            // Gradient background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [Colors.black87, Colors.grey.shade900]
                      : [Colors.blue.shade300, Colors.blueAccent.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.white),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                        Expanded(
                          child: AnimatedDefaultTextStyle(
                            duration: Duration(milliseconds: 500),
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            child: Text('Konum Seçin'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                    child: Card(
                      color: isDark ? Colors.grey[900] : Colors.white,
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextField(
                        style: TextStyle(color: isDark ? Colors.white : Colors.black),
                        decoration: InputDecoration(
                          hintText: 'Şehir ara...',
                          prefixIcon: Icon(Icons.search, color: isDark ? Colors.white70 : Colors.blueAccent),
                          filled: true,
                          fillColor: isDark ? Colors.grey[900] : Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: updateSearch,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                      child: filteredCities.isEmpty
                          ? Center(
                        child: Text(
                          "Sonuç bulunamadı.",
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      )
                          : ListView.separated(
                        itemCount: filteredCities.length,
                        separatorBuilder: (_, __) => SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final cityName = filteredCities[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.pop(context, cityName);
                            },
                            child: Card(
                              color: isDark ? Colors.grey[850] : Colors.white,
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                title: Text(
                                  cityName,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black87,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                trailing: Icon(Icons.arrow_forward_ios,
                                    color: isDark ? Colors.white : Colors.blueAccent),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}
