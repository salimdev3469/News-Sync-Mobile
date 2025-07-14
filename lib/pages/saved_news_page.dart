import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
// MainLayout importunuzu doğrulayın
import 'package:news_sync_mobile/pages/main_layout.dart'; // Projenizdeki doğru yolu kullandığınızdan emin olun


class SavedNewsPage extends StatefulWidget {
  const SavedNewsPage({super.key});

  @override
  _SavedNewsPageState createState() => _SavedNewsPageState();
}

class _SavedNewsPageState extends State<SavedNewsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _auth.authStateChanges().listen((user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    });
  }

  String _formatTimestamp(dynamic timestampInput) {
    if (timestampInput == null) return 'Tarih yok';
    Timestamp timestamp;
    if (timestampInput is Timestamp) {
      timestamp = timestampInput;
    } else if (timestampInput is Map && timestampInput.containsKey('_seconds') && timestampInput.containsKey('_nanoseconds')) {
      timestamp = Timestamp(timestampInput['_seconds'], timestampInput['_nanoseconds']);
    } else {
      print("SavedNewsPage - Invalid timestamp format for _formatTimestamp: $timestampInput, type: ${timestampInput.runtimeType}");
      return 'Geçersiz tarih formatı';
    }
    try {
      return DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR').format(timestamp.toDate().toLocal());
    } catch (e) {
      print("SavedNewsPage - Error formatting timestamp: $e");
      return 'Tarih formatlama hatası';
    }
  }

  String _formatPublishDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      DateTime dateTime = DateTime.parse(dateStr).toLocal();
      return 'Yayın: ${DateFormat('dd MMM yyyy, HH:mm', 'tr_TR').format(dateTime)}';
    } catch (e) {
      print("SavedNewsPage - Error parsing or formatting publish_date '$dateStr': $e");
      return 'Yayın: Tarih formatı hatalı';
    }
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_currentUser == null) {
      return MainLayout(
        currentIndex: 2,
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: true, // default back butonunu kapatıyoruz
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            title: const Text(
              "Kaydedilen Haberler",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          extendBodyBehindAppBar: true,
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [Colors.black87, Colors.grey.shade900]
                    : [Colors.blue.shade300, Colors.blueAccent.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 100, color: Colors.white.withOpacity(0.7)),
                  const SizedBox(height: 16),
                  Text(
                    'Kaydedilen haberleri görmek için lütfen giriş yapın.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: Icon(Icons.login),
                    label: Text("Giriş Yap"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blueAccent,
                    ),
                    onPressed: () {
                      Navigator.pushNamed(context, '/login');
                    },
                  )
                ],
              ),
            ),
          ),
        ),
      );




    }

    return MainLayout(
      currentIndex: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          title: const Text(
            "Kaydedilen Haberler",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        extendBodyBehindAppBar: true,
        body: Stack(
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
            SafeArea(
              child: Column(
                children: [
                  // Artık başlık buraya değil AppBar'a taşındı.
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black87 : Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _firestore
                            .collection('SavedNews')
                            .where('userId', isEqualTo: _currentUser!.uid)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                'Kaydedilen haberler yüklenirken bir hata oluştu.\nDetay: ${snapshot.error}',
                                textAlign: TextAlign.center,
                              ),
                            );
                          }
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator());
                          }
                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return Center(
                              child: Text(
                                "Henüz kaydedilmiş haber yok.",
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : Colors.grey[700],
                                  fontSize: 18,
                                ),
                              ),
                            );
                          }

                          final savedNewsDocs = snapshot.data!.docs;

                          return ListView.builder(
                            padding: EdgeInsets.all(16),
                            itemCount: savedNewsDocs.length,
                            itemBuilder: (context, index) {
                              final newsDocument = savedNewsDocs[index];
                              final newsData = newsDocument.data() as Map<String, dynamic>;

                              final String title = newsData['title'] ?? 'Başlık Yok';
                              final String? imageUrl = newsData['image'] as String?;
                              final String sourceName = newsData['source_name'] ?? 'Kaynak Yok';
                              final String? originalArticleId = newsData['originalArticleId'] as String?;
                              final String? publishDateStr = newsData['publish_date'] as String?;

                              String formattedPublishDate = _formatPublishDate(publishDateStr);
                              String savedDate = _formatTimestamp(newsData['savedAt']);

                              return GestureDetector(
                                onTap: () async {
                                  if (originalArticleId != null) {
                                    try {
                                      DocumentSnapshot articleDoc = await _firestore
                                          .collection('Articles')
                                          .doc(originalArticleId)
                                          .get();

                                      if (articleDoc.exists) {
                                        Map<String, dynamic> articleData =
                                        articleDoc.data() as Map<String, dynamic>;

                                        Map<String, dynamic> newsDetailArgs =
                                        Map.from(newsData);
                                        newsDetailArgs['content'] = articleData['content'];
                                        newsDetailArgs['id'] = originalArticleId;

                                        Navigator.of(context).pushNamed(
                                          '/news_detail',
                                          arguments: newsDetailArgs,
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Haberin orijinal içeriği bulunamadı.'),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Haber içeriği yüklenirken bir hata oluştu.'),
                                        ),
                                      );
                                    }
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Haber detayı açılamadı (ID bulunamadı).'),
                                      ),
                                    );
                                  }
                                },
                                child: Card(
                                  elevation: 5,
                                  margin: EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      /// SOL → Resim
                                      ClipRRect(
                                        borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(12),
                                          bottomLeft: Radius.circular(12),
                                        ),
                                        child: imageUrl != null && imageUrl.isNotEmpty
                                            ? Image.network(
                                          imageUrl,
                                          width: 120,
                                          height: 120,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              width: 120,
                                              height: 120,
                                              color: Colors.grey[300],
                                              child: Icon(
                                                Icons.broken_image,
                                                color: Colors.grey[500],
                                                size: 40,
                                              ),
                                            );
                                          },
                                        )
                                            : Container(
                                          width: 120,
                                          height: 120,
                                          color: Colors.grey[300],
                                          child: Icon(
                                            Icons.article_outlined,
                                            color: Colors.grey[500],
                                            size: 40,
                                          ),
                                        ),
                                      ),

                                      /// ORTA → Haber bilgileri
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                title,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: isDark ? Colors.white : Colors.black87,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                sourceName,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: isDark ? Colors.white70 : Colors.grey[700],
                                                ),
                                              ),
                                              if (formattedPublishDate.isNotEmpty) ...[
                                                SizedBox(height: 2),
                                                Text(
                                                  formattedPublishDate,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isDark ? Colors.white54 : Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                              SizedBox(height: 2),
                                              Text(
                                                "Kaydedilme: $savedDate",
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: isDark ? Colors.white54 : Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      /// SAĞ → Sil butonu (Bookmark remove)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                        child: Center(
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(50),
                                            onTap: () async {
                                              /// Firestore dokümanını sil
                                              try {
                                                await _firestore
                                                    .collection('SavedNews')
                                                    .doc(newsDocument.id)
                                                    .delete();

                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text("Haber kaydı silindi."),
                                                    duration: Duration(seconds: 2),
                                                  ),
                                                );
                                              } catch (e) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text("Silme hatası: $e"),
                                                  ),
                                                );
                                              }
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: Icon(
                                                Icons.bookmark_remove_sharp,
                                                color: Colors.red.shade700,
                                                size: 28,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),



                              );
                            },
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