import 'package:flutter/material.dart';
import 'dart:async'; // Timer için
import 'package:news_sync_mobile/auth_wrapper.dart'; // AuthWrapper'ı import edin
// import 'package:news_sync_mobile/pages/login_page.dart'; // Eski yönlendirme, artık AuthWrapper'a

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Firebase başlatma işlemi main.dart'ta yapıldığı için
    // burada sadece belirli bir süre bekleyip AuthWrapper'a geçebiliriz.
    Timer(const Duration(seconds: 3), () { // 3 saniye örnek bir süre
      if (mounted) { // Widget hala ağaçtaysa yönlendir
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AuthWrapper()),
        );
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand, // Ekranı tamamen kapla
        children: [
          Image.asset(
            'assets/cover.jpg', // Kendi arka plan görselinin yolunu buraya yaz
            fit: BoxFit.cover, // Tüm ekranı orantılı kapla
          ),
          Center(
            child: Image.asset(
              'assets/appBarLogoDark.png',
              width: MediaQuery.of(context).size.width * 0.8,
              height: MediaQuery.of(context).size.width * 0.8,
              fit: BoxFit.contain,
            ),
          ),

        ],
      ),
    );
  }
}

