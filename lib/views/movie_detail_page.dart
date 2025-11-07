import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/constants/app_colors.dart';
import '../services/movie_service.dart';

class MovieDetailPage extends StatefulWidget {
  final int movieId;
  const MovieDetailPage({super.key, required this.movieId});

  @override
  State<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends State<MovieDetailPage> {
  final MovieService movieService = MovieService();
  Map<String, dynamic>? movie;
  List<Map<String, dynamic>> cast = [];
  String? trailerUrl;
  bool isLoading = true;
  User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    fetchMovieDetail();
  }

  Future<void> fetchMovieDetail() async {
    setState(() => isLoading = true);
    try {
      final detail = await movieService.fetchMovieDetail(widget.movieId);
      final movieCast = await movieService.fetchMovieCast(widget.movieId);
      final videos = await movieService.fetchMovieVideos(widget.movieId);

      final youtubeTrailer = videos.firstWhere(
        (v) =>
            (v['site']?.toLowerCase() == 'youtube') &&
            (v['type']?.toLowerCase() == 'trailer'),
        orElse: () => {},
      );

      setState(() {
        movie = Map<String, dynamic>.from(detail);
        cast = movieCast.take(10).map((e) => Map<String, dynamic>.from(e)).toList();
        trailerUrl = (youtubeTrailer is Map &&
                youtubeTrailer.isNotEmpty &&
                youtubeTrailer['key'] != null)
            ? 'https://www.youtube.com/watch?v=${youtubeTrailer['key']}'
            : null;
      });

      // Pre-cache poster
      final posterPath = movie?['poster_path'];
      if (posterPath != null) {
        final url = movieService.getPosterUrl(posterPath);
        await MovieService.imageCacheManager.getSingleFile(url).catchError((_) {});
      }
    } catch (e) {
      debugPrint('Detail fetch error: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<Map<String, String>> _getUserInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return {'name': 'Unknown User', 'email': 'unknown@example.com'};

      String name = user.displayName ?? '';
      String email = user.email ?? 'unknown@example.com';

      // If displayName not available, fetch from Firestore
      if (name.isEmpty) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data()?['name'] != null) {
          name = doc.data()!['name'];
        } else {
          name = email.split('@').first; // fallback to email username
        }
      }

      return {'name': name, 'email': email};
    } catch (e) {
      debugPrint('Error fetching user info: $e');
      return {'name': 'Unknown User', 'email': 'unknown@example.com'};
    }
  }

  Future<void> _launchTrailer(String url) async {
    final Uri uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch trailer';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open trailer: $e')),
        );
      }
    }
  }

  bool _isValidYouTubeUrl(String url) {
    final regex = RegExp(
      r'^(https?:\/\/)?(www\.)?(youtube\.com|youtu\.be)\/.+$',
      caseSensitive: false,
    );
    return regex.hasMatch(url.trim());
  }

  Future<void> _uploadExplanationDialog() async {
    final nameController = TextEditingController(text: movie?['title'] ?? '');
    final urlController = TextEditingController();
    final languageController = TextEditingController();
    final List<String> predefinedLanguages = [
      'English',
      'Hindi',
      'Tamil',
      'Telugu',
      'Malayalam'
    ];

    bool isUploading = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Text(
              'Upload Movie Explanation',
              style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: nameController,
                    readOnly: true,
                    style: const TextStyle(color: AppColors.text),
                    decoration: const InputDecoration(
                      labelText: 'Movie Name',
                      labelStyle: TextStyle(color: AppColors.muted),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: languageController,
                    style: const TextStyle(color: AppColors.text),
                    decoration: InputDecoration(
                      labelText: 'Language (Select or Type)',
                      labelStyle: const TextStyle(color: AppColors.muted),
                      suffixIcon: PopupMenuButton<String>(
                        icon: const Icon(Icons.arrow_drop_down, color: AppColors.accent),
                        onSelected: (val) => setState(() {
                          languageController.text = val;
                        }),
                        itemBuilder: (context) => predefinedLanguages
                            .map((lang) => PopupMenuItem(value: lang, child: Text(lang)))
                            .toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: urlController,
                    style: const TextStyle(color: AppColors.text),
                    decoration: const InputDecoration(
                      labelText: 'YouTube Video URL',
                      hintText: 'e.g. https://youtu.be/abcdEFGhi12',
                      labelStyle: TextStyle(color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                onPressed: isUploading
                    ? null
                    : () async {
                        final name = nameController.text.trim();
                        final url = urlController.text.trim();
                        final language = languageController.text.trim();

                        if (name.isEmpty ||
                            url.isEmpty ||
                            language.isEmpty ||
                            !_isValidYouTubeUrl(url)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter valid details.')),
                          );
                          return;
                        }

                        setState(() => isUploading = true);

                        try {
                          final userInfo = await _getUserInfo();

                          await FirebaseFirestore.instance
                              .collection('movie_explanations')
                              .doc(widget.movieId.toString())
                              .collection('videos')
                              .add({
                            'movieName': name,
                            'language': language,
                            'youtubeUrl': url,
                            'uploadedAt': FieldValue.serverTimestamp(),
                            'uploadedByName': userInfo['name'],
                            'uploadedByEmail': userInfo['email'],
                          });

                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('🎬 Video uploaded successfully!')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Upload failed: ${e.toString()}')),
                            );
                          }
                        } finally {
                          setState(() => isUploading = false);
                        }
                      },
                child: isUploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Upload', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        });
      },
    );
  }

  Widget _buildExplanationSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('movie_explanations')
          .doc(widget.movieId.toString())
          .collection('videos')
          .orderBy('uploadedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.accent));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'No explanation videos uploaded yet.',
              style: TextStyle(color: AppColors.muted),
            ),
          );
        }

        final docs = snapshot.data!.docs;
        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(1, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['movieName'] ?? 'Unknown Movie',
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Language: ${data['language'] ?? 'Unknown'}',
                          style: const TextStyle(color: AppColors.muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      final urlStr = data['youtubeUrl'] as String?;
                      if (urlStr != null && _isValidYouTubeUrl(urlStr)) {
                        final uri = Uri.parse(urlStr);
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invalid YouTube link.')),
                        );
                      }
                    },
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent,
                      ),
                      padding: const EdgeInsets.all(10),
                      child: const Icon(Icons.play_arrow, color: Colors.white, size: 28),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget buildCastList() {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: cast.length,
        itemBuilder: (context, index) {
          final c = cast[index];
          final profilePath = c['profile_path'] as String?;
          final profileUrl =
              profilePath != null ? movieService.getPosterUrl(profilePath) : '';

          return Container(
            width: 100,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: profileUrl.isNotEmpty
                      ? CachedNetworkImage(
                          cacheManager: MovieService.imageCacheManager,
                          imageUrl: profileUrl,
                          height: 110,
                          width: 100,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          height: 110,
                          width: 100,
                          color: AppColors.surface,
                          child: const Icon(Icons.person, color: AppColors.muted, size: 40),
                        ),
                ),
                const SizedBox(height: 6),
                Text(
                  c['name'] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.text, fontSize: 12),
                ),
                Text(
                  c['character'] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 10),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(movie?['title'] ?? 'Loading...',
            style: const TextStyle(color: AppColors.text)),
      ),
      extendBodyBehindAppBar: true,
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      if (movie?['poster_path'] != null)
                        CachedNetworkImage(
                          cacheManager: MovieService.imageCacheManager,
                          imageUrl: movieService.getPosterUrl(movie!['poster_path']),
                          height: size.height * 0.6,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      Container(
                        height: size.height * 0.6,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              AppColors.background.withOpacity(0.95)
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 40,
                        left: 0,
                        right: 0,
                        child: Column(
                          children: [
                            Text(
                              movie?['title'] ?? '',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: AppColors.text,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${movie?['release_date']?.split('-').first ?? 'Unknown'} | ★ ${movie?['vote_average']?.toStringAsFixed(1) ?? 'N/A'} | ${(movie?['genres'] as List?)?.map((g) => g['name']).join(", ") ?? ''}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.muted, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (trailerUrl != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _launchTrailer(trailerUrl!),
                        icon: const Icon(Icons.play_arrow, color: Colors.white),
                        label: const Text('Watch Trailer',
                            style: TextStyle(fontSize: 18, color: Colors.white)),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Movie Explanations',
                            style: TextStyle(
                                color: AppColors.text,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add, color: AppColors.accent),
                          onPressed: _uploadExplanationDialog,
                        ),
                      ],
                    ),
                  ),
                  _buildExplanationSection(),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Overview',
                            style: TextStyle(
                                color: AppColors.text,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(
                          movie?['overview'] ?? '',
                          textAlign: TextAlign.justify,
                          style: const TextStyle(
                            color: AppColors.muted,
                            height: 1.6,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (cast.isNotEmpty) ...[
                          const Text('Top Cast',
                              style: TextStyle(
                                  color: AppColors.text,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          buildCastList(),
                        ],
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
