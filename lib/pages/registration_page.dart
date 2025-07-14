import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:news_sync_mobile/pages/home_page.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _errorMessage;
  bool _isLoading = false;

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Lütfen mail adresinizi yazın.';
    }
    bool emailValid = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(value);
    if (!emailValid) {
      return 'Geçerli bir mail adresi yazın.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Lütfen şifrenizi girin.';
    }
    if (value.length < 6) {
      return 'Şifre en az 6 karakter uzunluğunda olmalıdır.';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Lütfen şifrenizi onaylayın.';
    }
    if (value != _passwordController.text) {
      return 'Şifreler eşleşmiyor.';
    }
    return null;
  }

  String _maskPassword(String password) {
    if (password.length <= 3) {
      return List.generate(password.length, (_) => '#').join();
    }
    return '${password.substring(0, 3)}${List.generate(password.length - 3, (_) => '#').join()}';
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (userCredential.user != null) {
        User newUser = userCredential.user!;
        String originalPassword = _passwordController.text.trim();
        String maskedPassword = _maskPassword(originalPassword);

        await _firestore.collection('Users').doc(newUser.uid).set({
          'Email': newUser.email,
          'UserID': newUser.uid,
          'CreatedAt': Timestamp.now(),
          'MaskedPassword': maskedPassword,
        });

        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomePage()),
                (Route<dynamic> route) => false,
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'weak-password') {
          _errorMessage = 'The password provided is too weak (at least 6 characters).';
        } else if (e.code == 'email-already-in-use') {
          _errorMessage = 'The account already exists for that email.';
        } else if (e.code == 'invalid-email') {
          _errorMessage = 'The email address is not valid.';
        } else {
          _errorMessage = 'An error occurred during registration. Please try again.';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Stack(
          children: [
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
            Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Card(
                    color: isDark ? Colors.grey[900] : Colors.white,
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedDefaultTextStyle(
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.blueAccent,
                              ),
                              duration: Duration(milliseconds: 500),
                              child: Text("NewsSync'e Kaydol!"),
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _emailController,
                              style: TextStyle(color: isDark ? Colors.white : Colors.black),
                              decoration: InputDecoration(
                                labelText: 'E-Posta',
                                prefixIcon: Icon(Icons.email_outlined, color: isDark ? Colors.white70 : null),
                                filled: true,
                                fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: _validateEmail,
                              enabled: !_isLoading,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              style: TextStyle(color: isDark ? Colors.white : Colors.black),
                              decoration: InputDecoration(
                                labelText: 'Şifre',
                                prefixIcon: Icon(Icons.lock_outline, color: isDark ? Colors.white70 : null),
                                filled: true,
                                fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              validator: _validatePassword,
                              enabled: !_isLoading,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: true,
                              style: TextStyle(color: isDark ? Colors.white : Colors.black),
                              decoration: InputDecoration(
                                labelText: 'Şifreyi Tekrar Girin',
                                prefixIcon: Icon(Icons.lock_outline, color: isDark ? Colors.white70 : null),
                                filled: true,
                                fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              validator: _validateConfirmPassword,
                              enabled: !_isLoading,
                            ),
                            if (_errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10.0),
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Colors.red, fontSize: 14),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            const SizedBox(height: 24),
                            _isLoading
                                ? const CircularProgressIndicator()
                                : ElevatedButton.icon(
                              icon: Icon(Icons.app_registration, size: 20, color: Colors.white),
                              onPressed: _signUp,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 50),
                                backgroundColor: isDark ? Colors.blueAccent : Colors.indigo,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              label: const Text(
                                'Kaydol',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                Navigator.pushReplacementNamed(context, '/login');
                              },
                              child: Text(
                                'Zaten bir hesabın var mı? Giriş Yap!',
                                style: TextStyle(
                                  color: isDark ? Colors.blue.shade200 : Colors.indigo,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
