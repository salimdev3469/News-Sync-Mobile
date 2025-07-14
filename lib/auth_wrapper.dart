import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:news_sync_mobile/pages/home_page.dart';
import 'package:news_sync_mobile/pages/login_page.dart';
import 'package:news_sync_mobile/pages/splash_screen.dart'; // SplashScreen'inizi import edin

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // İlk bağlantı kurulana kadar (Firebase ve Auth durumu kontrol edilene kadar)
        // SplashScreen'i göster.
        if (snapshot.connectionState == ConnectionState.waiting) {
          // return const Scaffold(
          //   body: Center(
          //     child: CircularProgressIndicator(),
          //   ),
          // );
          return SplashScreen(); // Kendi SplashScreen widget'ınızı burada çağırın
        } else if (snapshot.hasData) {
          // Kullanıcı giriş yapmış ve veri gelmiş
          return HomePage();
        } else {
          // Kullanıcı giriş yapmamış ve veri gelmiş (veya hata var ama veri yok)
          return LoginPage();
        }
      },
    );
  }
}