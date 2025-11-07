import 'dart:async';
import 'package:cinephile/core/widgets/bottom_nav_bar.dart';
import 'package:cinephile/views/community_page.dart';
import 'package:cinephile/views/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../core/constants/app_colors.dart';
import '../services/movie_service.dart';
import 'movie_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MovieService movieService = MovieService();

  List<Map<String, dynamic>> topRated = [];
  List<Map<String, dynamic>> mindBending = [];
  List<Map<String, dynamic>> trending = [];
  List<Map<String, dynamic>> popular = [];
  List<Map<String, dynamic>> upcoming = [];
  List<Map<String, dynamic>> searchResults = [];

  bool isSearching = false;
  bool isLoading = true;
  final TextEditingController searchController = TextEditingController();
  Timer? _searchDebounce;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadMovies();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    searchController.dispose();
    movieService.dispose();
    super.dispose();
  }

  Future<void> _loadMovies() async {
    if (mounted) setState(() => isLoading = true);

    try {
      final results = await Future.wait([
        movieService.fetchTopRated(),
        movieService.fetchMindBending(),
        movieService.fetchTrending(),
        movieService.fetchPopular(),
        movieService.fetchUpcoming(),
      ]);

      if (!mounted) return;

      setState(() {
        topRated = List<Map<String, dynamic>>.from(results[0]);
        mindBending = List<Map<String, dynamic>>.from(results[1]);
        trending = List<Map<String, dynamic>>.from(results[2]);
        popular = List<Map<String, dynamic>>.from(results[3]);
        upcoming = List<Map<String, dynamic>>.from(results[4]);
      });

      _prefetchPosters([...topRated, ...trending, ...popular].take(12).toList());
    } catch (e) {
      debugPrint('Load movies error: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _prefetchPosters(List<Map<String, dynamic>> movies) {
    for (var movie in movies) {
      final path = movie['poster_path'];
      if (path != null) {
        final url = movieService.getPosterUrl(path);
        DefaultCacheManager().getSingleFile(url).catchError((_) {});
      }
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();

    if (query.isEmpty) {
      setState(() {
        isSearching = false;
        searchResults = [];
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;
    setState(() => isSearching = true);

    try {
      final results = await movieService.searchMovies(query);
      if (mounted) {
        setState(() {
          searchResults = List<Map<String, dynamic>>.from(results);
        });
      }
    } catch (e) {
      debugPrint('Search error: $e');
      if (mounted) setState(() => searchResults = []);
    }
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;

    if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CommunityPage()),
      );
      return;
    } else if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ProfilePage()),
      );
      return;
    }

    setState(() {
      _selectedIndex = index;
      isSearching = false;
      searchController.clear();
      _searchDebounce?.cancel();
      searchResults.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        centerTitle: true,
        title: !isSearching
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'CINEPHILE',
                    style: TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search, color: AppColors.text),
                    onPressed: () => setState(() => isSearching = true),
                  ),
                ],
              )
            : _buildSearchField(),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : isSearching
              ? _buildSearchResults(isWideScreen)
              : _buildMovieLists(isWideScreen),
      bottomNavigationBar: BottomNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: searchController,
        autofocus: true,
        onChanged: _onSearchChanged,
        style: const TextStyle(color: AppColors.text),
        decoration: InputDecoration(
          hintText: 'Search movies...',
          hintStyle: const TextStyle(color: Colors.grey),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          prefixIcon: const Icon(Icons.search, color: AppColors.text),
          suffixIcon: IconButton(
            icon: const Icon(Icons.close, color: Colors.grey),
            onPressed: () {
              setState(() {
                isSearching = false;
                searchController.clear();
                searchResults.clear();
                _searchDebounce?.cancel();
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMovieLists(bool isWideScreen) {
    return RefreshIndicator(
      onRefresh: _loadMovies,
      color: AppColors.accent,
      child: ListView(
        padding: const EdgeInsets.all(8.0),
        physics: const BouncingScrollPhysics(),
        children: [
          const SizedBox(height: 10),
          _buildRow('IMDb Top Rated', topRated, isWideScreen),
          const SizedBox(height: 20),
          _buildRow('Mind-Bending Movies', mindBending, isWideScreen),
          const SizedBox(height: 20),
          _buildRow('Trending', trending, isWideScreen),
          const SizedBox(height: 20),
          _buildRow('Popular', popular, isWideScreen),
          const SizedBox(height: 20),
          _buildRow('Upcoming', upcoming, isWideScreen),
        ],
      ),
    );
  }

  Widget _buildRow(String title, List<Map<String, dynamic>> movies, bool isWideScreen) {
    if (movies.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            title,
            style: TextStyle(
              fontSize: isWideScreen ? 22 : 18,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: isWideScreen ? 280 : 210,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: movies.length,
            itemBuilder: (context, index) {
              final movie = movies[index];
              final posterPath = movie['poster_path'] as String?;
              final posterUrl = posterPath != null ? movieService.getPosterUrl(posterPath) : '';

              return GestureDetector(
                onTap: () => _openMovieDetail(movie['id'] as int),
                child: Container(
                  width: isWideScreen ? 180 : 130,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: posterUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  cacheManager: MovieService.imageCacheManager,
                                  imageUrl: posterUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) =>
                                      const Center(child: CircularProgressIndicator(color: AppColors.accent)),
                                  errorWidget: (_, __, ___) =>
                                      const Icon(Icons.broken_image, color: Colors.grey),
                                )
                              : const Icon(Icons.movie, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        movie['title'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.text, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults(bool isWideScreen) {
    if (searchController.text.isEmpty) {
      return const Center(child: Text('Type to search movies...', style: TextStyle(color: AppColors.muted)));
    }

    if (searchResults.isEmpty) {
      return const Center(child: Text('No results found', style: TextStyle(color: AppColors.text)));
    }

    final crossAxisCount = isWideScreen ? 5 : 3;

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      physics: const BouncingScrollPhysics(),
      itemCount: searchResults.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.6,
      ),
      itemBuilder: (context, index) {
        final movie = searchResults[index];
        final posterPath = movie['poster_path'] as String?;
        final posterUrl = posterPath != null ? movieService.getPosterUrl(posterPath) : '';

        return GestureDetector(
          onTap: () => _openMovieDetail(movie['id'] as int),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: posterUrl.isNotEmpty
                      ? CachedNetworkImage(
                          cacheManager: MovieService.imageCacheManager,
                          imageUrl: posterUrl,
                          fit: BoxFit.cover,
                        )
                      : const Icon(Icons.movie, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                movie['title'] ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.text, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openMovieDetail(int movieId) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailPage(movieId: movieId)));
  }
}
