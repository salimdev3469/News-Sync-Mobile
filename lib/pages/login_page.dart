import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:news_sync_mobile/pages/home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _resetEmailController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _errorMessage;
  bool _isLoading = false;

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Lütfen e-posta adresinizi girin.';
    }
    bool emailValid = RegExp(
        r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+$")
        .hasMatch(value);
    if (!emailValid) {
      return 'Geçerli bir e-posta adresi girin.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Lütfen şifrenizi girin.';
    }
    return null;
  }

  String _maskPassword(String password) {
    if (password.length <= 3) {
      return List.generate(password.length, (_) => '#').join();
    }
    return '${password.substring(0, 3)}${List.generate(password.length - 3, (_) => '#').join()}';
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      UserCredential userCredential =
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (userCredential.user != null) {
        String currentPassword = _passwordController.text.trim();
        String maskedPassword = _maskPassword(currentPassword);

        await _firestore
            .collection('Users')
            .doc(userCredential.user!.uid)
            .update({
          'MaskedPassword': maskedPassword,
        }).catchError((e) {
          print(
              'Error updating masked password in Firestore after login: $e');
        });
      }

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomePage()),
              (Route<dynamic> route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'user-not-found' ||
            e.code == 'wrong-password' ||
            e.code == 'invalid-credential') {
          _errorMessage =
          'E-posta veya şifre yanlış. Lütfen kontrol edin.';
        } else if (e.code == 'invalid-email') {
          _errorMessage = 'E-posta formatı geçersiz.';
        } else if (e.code == 'too-many-requests') {
          _errorMessage =
          'Çok fazla başarısız giriş denemesi yapıldı. Lütfen daha sonra tekrar deneyin.';
        } else {
          _errorMessage =
          'Giriş yapılırken bir hata oluştu. Lütfen tekrar deneyin.';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage =
        'Bilinmeyen bir hata oluştu. Lütfen tekrar deneyin.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signInAnonymously() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _auth.signInAnonymously();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomePage()),
              (Route<dynamic> route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = 'Misafir girişi başarısız: ${e.message}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendPasswordResetEmail() async {
    if (_resetEmailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Şifre sıfırlamak için lütfen e-posta adresinizi girin.')),
      );
      return;
    }
    String? emailValidationError =
    _validateEmail(_resetEmailController.text.trim());
    if (emailValidationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(emailValidationError)),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _auth.sendPasswordResetEmail(
          email: _resetEmailController.text.trim());
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Şifre sıfırlama e-postası gönderildi. Lütfen gelen kutunuzu kontrol edin.')),
        );
        _resetEmailController.clear();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Sıfırlama e-postası gönderilirken hata: ${e.message}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showPasswordResetDialog() {
    _resetEmailController.clear();
    showDialog(
      context: context,
      barrierDismissible: !_isLoading,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Şifremi Unuttum'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                  'Kayıtlı e-posta adresinizi girin. Şifrenizi sıfırlamak için bir bağlantı göndereceğiz.'),
              const SizedBox(height: 20),
              TextFormField(
                controller: _resetEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'E-posta Adresi',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: _validateEmail,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () {
                Navigator.of(context).pop();
              },
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed:
              _isLoading ? null : _sendPasswordResetEmail,
              child: _isLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
                  : const Text('Bağlantıyı Gönder'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _resetEmailController.dispose();
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
                                color: isDark
                                    ? Colors.white
                                    : Colors.blueAccent,
                              ),
                              duration: Duration(milliseconds: 500),
                              child:
                              Image.asset(
                                isDark
                                    ? 'assets/appBarLogoDark.png'
                                    : 'assets/appBarLogo.png',
                                height: 150,
                              ),
                            ),

                            TextFormField(
                              controller: _emailController,
                              style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : Colors.black),
                              decoration: InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email_outlined,
                                    color: isDark
                                        ? Colors.white70
                                        : null),
                                filled: true,
                                fillColor: isDark
                                    ? Colors.grey[800]
                                    : Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius:
                                  BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              keyboardType:
                              TextInputType.emailAddress,
                              validator: _validateEmail,
                              enabled: !_isLoading,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : Colors.black),
                              decoration: InputDecoration(
                                labelText: 'Şifre',
                                prefixIcon: Icon(Icons.lock_outline,
                                    color: isDark
                                        ? Colors.white70
                                        : null),
                                filled: true,
                                fillColor: isDark
                                    ? Colors.grey[800]
                                    : Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius:
                                  BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              validator: _validatePassword,
                              enabled: !_isLoading,
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : _showPasswordResetDialog,
                                child: Text(
                                  'Şifremi unuttum!',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.blue.shade200
                                        : Colors.blueAccent,
                                  ),
                                ),
                              ),
                            ),
                            if (_errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                    top: 8.0, bottom: 8.0),
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 14),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            const SizedBox(height: 16),
                            _isLoading
                                ? const CircularProgressIndicator()
                                : ElevatedButton.icon(
                              icon: Icon(Icons.login,
                                  size: 20, color: Colors.white),
                              onPressed: _signIn,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(
                                    double.infinity, 50),
                                backgroundColor: isDark
                                    ? Colors.blueAccent
                                    : Colors.indigo,
                                shape:
                                RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(
                                      12),
                                ),
                              ),
                              label: const Text(
                                'Giriş Yap',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight:
                                    FontWeight.bold,
                                    color: Colors.white),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : _signInAnonymously,
                              child: Text(
                                'Misafir olarak devam et',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.blueAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                Navigator.pushNamed(
                                    context, '/register');
                              },
                              child: Text(
                                'Hesabın yok mu? Kaydol!',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.blue.shade200
                                      : Colors.indigo,
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
