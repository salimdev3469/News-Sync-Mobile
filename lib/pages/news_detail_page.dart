import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

// Yorum Modeli
class CommentModel {
  final String id;
  final String articleId;
  final String userId;
  final String userEmailPrefix;
  final String text;
  final Timestamp timestamp;

  CommentModel({
    required this.id,
    required this.articleId,
    required this.userId,
    required this.userEmailPrefix,
    required this.text,
    required this.timestamp,
  });

  factory CommentModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return CommentModel(
      id: doc.id,
      articleId: data['articleId'] ?? '',
      userId: data['userId'] ?? '',
      userEmailPrefix: data['userEmailPrefix'] ?? 'U***',
      text: data['text'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
    );
  }
}

class NewsDetailPage extends StatefulWidget {
  const NewsDetailPage({super.key});

  @override
  _NewsDetailPageState createState() => _NewsDetailPageState();
}

class _NewsDetailPageState extends State<NewsDetailPage> {
  final TextEditingController _commentController = TextEditingController();
  final FlutterTts flutterTts = FlutterTts();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  double _fontSize = 19.0;
  bool _isBookmarked = false;
  bool _showFontSizeSlider = false;
  String? _articleId;
  Map<String, dynamic>? _currentNewsData;

  Future<void> _initializeTts() async {
    await flutterTts.setLanguage("tr-TR");
    await flutterTts.setPitch(1.0);
  }

  @override
  void initState() {
    _initializeTts();
    initializeDateFormatting('tr_TR', null).then((_) {
      print("Türkçe locale yüklendi.");
      setState(() {});
    });
    super.initState();
  }

  @override
  void dispose() {
    flutterTts.stop(); // Sesli okumayı durdur
    _commentController.dispose(); // TextEditingController'ı da serbest bırak
    super.dispose();
  }

  void _showLoginRequiredDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).dialogBackgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.lock_outline, color: isDark ? Colors.amber : Colors.redAccent),
              SizedBox(width: 8),
              Text(
                "Giriş Gerekli",
                style: TextStyle(
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
            ],
          ),
          content: Text(
            "Kaydetmek için giriş yapmalısınız.",
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: isDark ? Colors.grey[300] : Colors.grey.shade700,
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("Vazgeç"),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.indigoAccent : Colors.blueAccent,
                iconColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: Icon(Icons.login, size: 18, color: Colors.white),
              label: Text(
                "Giriş Yap",
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushNamed(context, '/login');
              },
            )
          ],
        );
      },
    );
  }




  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Map<String, dynamic>? newsArgs = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (newsArgs != null) {
      _currentNewsData = newsArgs;
      _articleId = newsArgs['id'] as String?; // Haber dokümanının orijinal ID'si
      print("NewsDetailPage - _currentNewsData initialized: $_currentNewsData"); // LOG
      print("NewsDetailPage - _articleId initialized: $_articleId"); // LOG

      if (_auth.currentUser != null && _articleId != null && _articleId!.isNotEmpty) {
        _checkIfBookmarked();
      }
    } else {
      print("NewsDetailPage - newsArgs is null!"); // LOG
    }
  }

  String _maskEmail(String? email) {
    if (email == null || email.isEmpty) return "Anonim";
    if (!email.contains('@')) return email.length > 1 ? "${email[0]}***" : "$email***";
    List<String> parts = email.split('@');
    String localPart = parts[0];
    String domainPart = parts[1];
    if (localPart.isEmpty) return "***@$domainPart";
    if (localPart.length == 1) return "${localPart[0]}***@$domainPart";
    int prefixLength = (localPart.length * 0.4).ceil().clamp(1, 4);
    return "${localPart.substring(0, prefixLength)}${"*" * (localPart.length - prefixLength > 3 ? 3 : (localPart.length - prefixLength).clamp(0, localPart.length - prefixLength))}@$domainPart";
  }

  String _getSavedNewsDocId(String userId, String articleId) {
    return "${userId}_$articleId";
  }

  Future<void> _checkIfBookmarked() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null && _articleId != null && _articleId!.isNotEmpty) {
      final String savedNewsDocId = _getSavedNewsDocId(currentUser.uid, _articleId!);
      try {
        print("Checking bookmark status for doc ID: $savedNewsDocId"); // LOG
        final docSnap = await _firestore.collection('SavedNews').doc(savedNewsDocId).get();
        if (mounted) {
          setState(() {
            _isBookmarked = docSnap.exists;
            print("Bookmark status: $_isBookmarked"); // LOG
          });
        }
      } catch (e) {
        print("Error checking bookmark status: $e");
      }
    }
  }

  Future<void> _toggleBookmark() async {
    print("Attempting to toggle bookmark..."); // LOG
    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.isAnonymous) {
      print("Anonymous user or not logged in → bookmarking blocked."); // LOG
      if (mounted) {
        _showLoginRequiredDialog();
      }
      return;
    }


    if (_articleId == null || _articleId!.isEmpty || _currentNewsData == null) {
      print("Article ID or currentNewsData is null/empty for bookmarking."); // LOG
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Haber bilgileri bulunamadı.')),
        );
      }
      return;
    }

    final String savedNewsDocId = _getSavedNewsDocId(currentUser.uid, _articleId!);
    final docRef = _firestore.collection('SavedNews').doc(savedNewsDocId);

    try {
      if (_isBookmarked) {
        print("Attempting to delete bookmark: $savedNewsDocId"); // LOG
        await docRef.delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red,
              content: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(child: Text("Haber kaydedilenlerden çıkarıldı!",style: TextStyle(color: Colors.white))),
                ],
              ),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );

        }
      } else {
        Map<String, dynamic> newsToSave = {};
        // Gerekli alanları _currentNewsData'dan dikkatlice alalım
        newsToSave['userId'] = currentUser.uid;
        newsToSave['originalArticleId'] = _articleId;
        newsToSave['savedAt'] = FieldValue.serverTimestamp();

        // Güvenlik kuralı 'title' alanını bekliyor.
        if (_currentNewsData!.containsKey('title') && _currentNewsData!['title'] is String) {
          newsToSave['title'] = _currentNewsData!['title'];
        } else {
          // Eğer title yoksa veya string değilse, bir varsayılan atayabilir veya işlemi durdurabilirsiniz.
          // Şimdilik bir varsayılan atayalım, ancak ideal olanı _currentNewsData'nın doğru gelmesidir.
          newsToSave['title'] = _currentNewsData!['title']?.toString() ?? 'Başlık Yok';
          print("Warning: 'title' field was missing or not a string in _currentNewsData. Using default."); // LOG
        }

        // Diğer isteğe bağlı ama faydalı olabilecek alanları da ekleyelim
        newsToSave['source_name'] = _currentNewsData!['source_name'] ?? 'Kaynak Yok';
        newsToSave['image'] = _currentNewsData!['image']; // null olabilir
        newsToSave['url'] = _currentNewsData!['url'];
        newsToSave['content'] = _currentNewsData!['content'];// null olabilir
        newsToSave['publish_date_str'] = _currentNewsData!['publish_date_str']; // null veya Timestamp olabilir

        print("Attempting to save bookmark. Data: $newsToSave for doc ID: $savedNewsDocId"); // LOG
        await docRef.set(newsToSave);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.indigo,
              content: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(child: Text("Haber kaydedildi!",style: TextStyle(color: Colors.white))),
                ],
              ),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );

        }
      }
      if (mounted) {
        setState(() {
          _isBookmarked = !_isBookmarked;
        });
      }
    } catch (e) {
      print("Error toggling bookmark: $e"); // LOG
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('İşlem sırasında bir hata oluştu: $e')),
        );
      }
    }
  }

  Future<void> _postComment() async {
    print("Attempting to post comment..."); // LOG
    final commentText = _commentController.text.trim();
    final currentUser = _auth.currentUser;

    if (_articleId == null || _articleId!.isEmpty) {
      print("Article ID is null/empty for posting comment."); // LOG
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Haber ID bulunamadığı için yorum yapılamıyor.')),
        );
      }
      return;
    }
    if (commentText.isEmpty) {
      print("Comment text is empty."); // LOG
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen bir yorum yazın.')),
        );
      }
      return;
    }


    if (currentUser != null) {
      final Map<String, dynamic> commentData = {
        'articleId': _articleId,
        'text': commentText,
        'userId': currentUser.uid,
        'userEmailPrefix': _maskEmail(currentUser.email),
        'timestamp': FieldValue.serverTimestamp(),
      };
      print("Attempting to post comment. Data: $commentData"); // LOG

      try {
        await _firestore.collection('Comment').add(commentData);
        _commentController.clear();
        FocusScope.of(context).unfocus();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.indigo,
              content: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(child: Text("Yorumunuz gönderildi!",style: TextStyle(color: Colors.white))),
                ],
              ),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );

        }
      } catch (e) {
        print("Error posting comment: $e"); // LOG
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Yorum gönderilirken bir hata oluştu: $e')),
          );
        }
      }
    } else {
      print("User not logged in for posting comment."); // LOG
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Yorum yapmak için giriş yapmalısınız.')),
        );
      }
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      await _firestore.collection('Comment').doc(commentId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text("Yorum silindi!",style: TextStyle(color: Colors.white))),
              ],
            ),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );

      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yorum silinirken hata oluştu: $e')),
        );
      }
    }
  }


  Future<void> _speakNews(String title, String content) async {
    await flutterTts.stop(); // varsa eski konuşmayı durdur
    await flutterTts.setLanguage("tr-TR");
    await flutterTts.setPitch(1.0);
    await flutterTts.speak("$title. $content");
  }

  void _shareNews(String title, String content, String? newsUrl) {
    final String shareText = newsUrl != null ? '$title\n\n$newsUrl' : '$title\n\n$content';
    Share.share(shareText);
  }

  String _formatPublishDate(dynamic publishDateInput) {
    if (publishDateInput == null || publishDateInput.toString().isEmpty) {
      return 'Yayın tarihi belirtilmemiş';
    }

    DateTime parsedDateTime;

    if (publishDateInput is Timestamp) {
      parsedDateTime = publishDateInput.toDate();
    } else if (publishDateInput is String) {
      try {
        // önce encoding fixle
        final fixedString = fixLatin1(publishDateInput);
        parsedDateTime = DateFormat('d MMMM yyyy, HH:mm', 'tr_TR').parse(fixedString);
      } catch (e) {
        print("Could not parse Turkish date: $publishDateInput. Error: $e");
        return publishDateInput;
      }
    } else {
      return 'Geçersiz tarih formatı';
    }

    return DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR').format(parsedDateTime.toLocal());
  }

  String fixLatin1(String brokenString) {
    return utf8.decode(latin1.encode(brokenString));
  }




  @override
  Widget build(BuildContext context) {
    if (_currentNewsData == null) {
      return Scaffold(
          appBar: AppBar(title: const Text('Yükleniyor...')),
          body: const Center(child: CircularProgressIndicator()));
    }

    final String title = _currentNewsData!['title']?.toString() ?? 'Başlık bulunamadı';
    final String contentText = _currentNewsData!['content']?.toString() ?? 'İçerik bulunamadı.';
    final String? imageUrl = _currentNewsData!['image'] as String?;
    final dynamic rawPublishDate = _currentNewsData!['publish_date_str'];
    final String sourceName = _currentNewsData!['source_name']?.toString() ?? 'Kaynak belirtilmemiş';
    final String? newsUrl = _currentNewsData!['url'] as String?;

    final String displayPublishDate = _formatPublishDate(rawPublishDate);
    final User? currentUser = _auth.currentUser;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final String appBarLogoPath = isDarkMode ? 'assets/appBarLogoDark.png' : 'assets/appBarLogo.png';
    return Scaffold(
      appBar: AppBar(
        title: Image.asset(appBarLogoPath, height: 80),
        actions: [
          AnimatedSwitcher(
            duration: Duration(milliseconds: 500),
            transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
            child: IconButton(
              key: ValueKey<bool>(_isBookmarked),
              icon: Icon(
                _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                color: _isBookmarked ? Colors.amber : Colors.grey,
                size: 28,
              ),
              tooltip: _isBookmarked ? 'Kaydedilenlerden çıkar' : 'Haberi kaydet',
              onPressed: _toggleBookmark,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.text_fields),
            tooltip: 'Yazı Boyutu',
            onPressed: () => setState(() => _showFontSizeSlider = !_showFontSizeSlider),
          ),
          IconButton(
            icon: const Icon(Icons.volume_up),
            tooltip: 'Haberi Seslendir',
            onPressed: () => _speakNews(title, contentText),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Haberi Paylaş',
            onPressed: () => _shareNews(title, contentText, newsUrl),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 70),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_showFontSizeSlider)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.format_size),
                    Expanded(
                      child: Slider(
                        value: _fontSize, min: 16, max: 28, divisions: (28 - 12) ~/ 2,
                        label: "${_fontSize.toInt()} pt",
                        onChanged: (value) => setState(() => _fontSize = value),
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                title,
                style: TextStyle(fontSize: _fontSize*1.5, height: 1.1, fontWeight: FontWeight.bold),
                maxLines: null,
              ),
            ),
            SizedBox(height: 6),

            if (imageUrl != null && imageUrl.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(16, _showFontSizeSlider ? 0 : 8, 16, 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                      if (loadingProgress == null) return child;
                      return SizedBox(
                        height: 220,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
                      return const SizedBox(height: 220, child: Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey)));
                    },
                  ),
                ),
              )
            else
              const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                contentText,
                style: TextStyle(fontSize: _fontSize, height: 1.6, letterSpacing: 0.2),
                maxLines: null,
              ),
            ),
            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Yayın Tarihi: $displayPublishDate', style: TextStyle(fontSize: _fontSize - 2, color: Colors.grey[700], fontStyle: FontStyle.italic),),
                  const SizedBox(height: 4),
                  Text('Kaynak: $sourceName', style: TextStyle(fontSize: _fontSize - 2, color: Colors.grey[700], fontStyle: FontStyle.italic),),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Divider(thickness: 1, indent: 16, endIndent: 16),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Yorumlar', style: TextStyle(fontSize: _fontSize + 2, fontWeight: FontWeight.bold),),
            ),
            if (_articleId != null && _articleId!.isNotEmpty)
              StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('Comment')
                    .where('articleId', isEqualTo: _articleId)
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final comments = snapshot.data!.docs
                      .map((doc) => CommentModel.fromFirestore(doc))
                      .toList();

                  if (comments.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        "Henüz yorum yapılmamış.",
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: comments.map((comment) {
                            final isCurrentUser = _auth.currentUser?.uid == comment.userId;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
                                  child: Text(
                                    comment.text,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${comment.userEmailPrefix} • ${DateFormat('dd MMM yyyy HH:mm', 'tr_TR').format(comment.timestamp.toDate())}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      if (isCurrentUser)
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                          onPressed: () => _deleteComment(comment.id),
                                          padding: EdgeInsets.zero,
                                          constraints: BoxConstraints(),
                                        )
                                    ],
                                  ),
                                ),
                                Divider(height: 1, color: Colors.grey.shade300),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  );

                },
              )


            else
              const Padding(padding: EdgeInsets.all(16.0), child: Center(child: Text("Yorumlar yüklenemedi (Haber ID eksik).")),),

            const SizedBox(height: 20),
            if (currentUser != null && !(currentUser.isAnonymous)) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16,0,16,8),
                child: TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText: 'Yorumunuzu yazın...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    suffixIcon: _commentController.text.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _commentController.clear();
                        setState(() {});
                      },
                    )
                        : null,
                  ),
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  onChanged: (text) => setState(() {}),
                  style: TextStyle(fontSize: _fontSize),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ElevatedButton.icon(
                  onPressed: _commentController.text.trim().isEmpty
                      ? null
                      : _postComment,
                  icon: const Icon(Icons.send),
                  label: const Text('Yorumu Gönder'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    textStyle: TextStyle(
                      fontSize: _fontSize,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Yorum yapmak için lütfen giriş yapın.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => Navigator.pushNamed(context, '/login'),
                        child: const Text('Giriş Yap'),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
