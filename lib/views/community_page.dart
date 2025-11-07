// community_page.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import 'home_page.dart';
import 'profile_page.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final User? _me = FirebaseAuth.instance.currentUser;
  final ImagePicker _picker = ImagePicker();

  int _selectedIndex = 1;
  bool _showSearch = false;
  String _searchQuery = '';

  // Create post controls
  final TextEditingController _postController = TextEditingController();
  File? _pickedImage;
  bool _posting = false;

  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
    if (index == 0) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
    } else if (index == 2) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ProfilePage()));
    }
  }

  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked != null) {
      setState(() => _pickedImage = File(picked.path));
    }
  }

  Future<String?> _uploadImage(File file, String postId) async {
    try {
      final ref = _storage.ref().child('post_images/$postId.jpg');
      final task = await ref.putFile(file);
      final url = await task.ref.getDownloadURL();
      return url;
    } catch (e) {
      debugPrint('Upload failed: $e');
      return null;
    }
  }

  Future<void> _openCreatePostSheet({String? editingPostId, Map<String, dynamic>? existing}) async {
    if (editingPostId != null && existing != null) {
      _postController.text = existing['content'] ?? '';
      _pickedImage = null;
    } else {
      _postController.clear();
      _pickedImage = null;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        final mq = MediaQuery.of(context);
        return Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: mq.viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(8)
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      editingPostId == null ? 'Create a post' : 'Edit post', 
                      style: const TextStyle(
                        fontWeight: FontWeight.bold, 
                        fontSize: 20,
                        color: AppColors.text
                      )
                    ),
                  ),
                  if (_posting) 
                    const SizedBox(
                      width: 20, 
                      height: 20, 
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)
                    )
                ],
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.background.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  controller: _postController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Share your thoughts or a movie link/name...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_pickedImage != null) ...[
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12), 
                      child: Image.file(_pickedImage!, height: 160, width: double.infinity, fit: BoxFit.cover)
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => setState(() => _pickedImage = null),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextButton.icon(
                      onPressed: _pickImage,
                      icon: Icon(Icons.image_outlined, color: AppColors.accent),
                      label: Text('Add image', style: TextStyle(color: AppColors.accent)),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _posting
                        ? null
                        : () async {
                            final content = _postController.text.trim();
                            if (content.isEmpty && _pickedImage == null) return;
                            setState(() => _posting = true);

                            try {
                              if (editingPostId == null) {
                                final newDoc = _firestore.collection('posts').doc();
                                String? imageUrl;
                                if (_pickedImage != null) {
                                  imageUrl = await _uploadImage(_pickedImage!, newDoc.id);
                                }
                                await newDoc.set({
                                  'userId': _me?.uid ?? 'guest',
                                  'username': _me?.displayName ?? (_me?.email?.split('@').first ?? 'User'),
                                  'photoUrl': _me?.photoURL ?? '',
                                  'content': content,
                                  'imageUrl': imageUrl ?? '',
                                  'timestamp': FieldValue.serverTimestamp(),
                                  'likes': <String>[],
                                });
                              } else {
                                await _firestore.collection('posts').doc(editingPostId).update({
                                  'content': content,
                                  'editedAt': FieldValue.serverTimestamp(),
                                });
                              }
                            } finally {
                              if (!mounted) return;
                              setState(() {
                                _posting = false;
                                _pickedImage = null;
                              });
                              _postController.clear();
                              Navigator.pop(context);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(editingPostId == null ? 'Post' : 'Save'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  String _timeAgo(Timestamp? t) {
    if (t == null) return '';
    final d = DateTime.now().difference(t.toDate());
    if (d.inSeconds < 60) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return '${t.toDate().day}/${t.toDate().month}/${t.toDate().year}';
  }

  Future<void> _toggleLikePost(DocumentSnapshot postSnap) async {
    final postRef = postSnap.reference;
    final meId = _me?.uid ?? 'guest';
    final data = postSnap.data() as Map<String, dynamic>? ?? {};
    final likes = List<String>.from(data['likes'] ?? []);
    if (likes.contains(meId)) {
      likes.remove(meId);
    } else {
      likes.add(meId);
    }
    await postRef.update({'likes': likes});
  }

  Future<void> _deletePost(String postId) async {
    await _firestore.collection('posts').doc(postId).delete();
  }

  Future<void> _addComment(String postId, String text) async {
    if (text.trim().isEmpty) return;
    await _firestore.collection('posts').doc(postId).collection('comments').add({
      'userId': _me?.uid ?? 'guest',
      'username': _me?.displayName ?? (_me?.email?.split('@').first ?? 'User'),
      'photoUrl': _me?.photoURL ?? '',
      'text': text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
      'reactions': <String, dynamic>{},
    });
  }

  // MAIN BUILD
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      bottomNavigationBar: BottomNavBar(selectedIndex: _selectedIndex, onItemTapped: _onItemTapped),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openCreatePostSheet(),
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      title: _showSearch 
          ? Container(
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                decoration: const InputDecoration(
                  hintText: 'Search posts, movies, users...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                ),
              ),
            )
          : const Text(
              'Community',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: AppColors.text,
              ),
            ),
      centerTitle: false,
      actions: [
        if (!_showSearch)
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.text),
            onPressed: () => setState(() => _showSearch = true),
          ),
        if (_showSearch)
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.text),
            onPressed: () => setState(() {
              _searchQuery = '';
              _showSearch = false;
            }),
          ),
      ],
    );
  }

  Widget _buildBody() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('posts').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.grey[400], size: 64),
                const SizedBox(height: 16),
                Text(
                  'Error loading posts',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }
        
        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          );
        }
        
        final docs = snap.data!.docs.where((d) {
          if (_searchQuery.isEmpty) return true;
          final data = d.data() as Map<String, dynamic>;
          final content = (data['content'] ?? '').toString().toLowerCase();
          final username = (data['username'] ?? '').toString().toLowerCase();
          return content.contains(_searchQuery) || username.contains(_searchQuery);
        }).toList();

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.forum_outlined, color: Colors.grey[400], size: 80),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isEmpty ? 'No posts yet' : 'No posts found',
                  style: const TextStyle(
                    fontSize: 18,
                    color: AppColors.text,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _searchQuery.isEmpty 
                      ? 'Be the first to share something!'
                      : 'Try a different search term',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                if (_searchQuery.isEmpty) 
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: ElevatedButton(
                      onPressed: () => _openCreatePostSheet(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text('Create Post'),
                    ),
                  ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await Future.delayed(const Duration(milliseconds: 400));
          },
          color: AppColors.accent,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              final padding = isWide ? constraints.maxWidth * 0.15 : 16.0;
              
              return ListView.builder(
                padding: EdgeInsets.symmetric(vertical: 16, horizontal: padding),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final doc = docs[i];
                  final data = doc.data() as Map<String, dynamic>;
                  return _buildPostCard(doc.id, data, isWide);
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPostCard(String postId, Map<String, dynamic> data, bool isWide) {
    final username = data['username'] ?? 'User';
    final photo = (data['photoUrl'] as String?) ?? '';
    final content = data['content'] ?? '';
    final imageUrl = (data['imageUrl'] as String?) ?? '';
    final timestamp = data['timestamp'] as Timestamp?;
    final likes = List<String>.from(data['likes'] ?? []);
    final isLiked = likes.contains(_me?.uid ?? 'guest');
    final userId = data['userId'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                _avatar(photo, username, radius: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _timeAgo(timestamp),
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if ((_me?.uid ?? '') == (userId ?? ''))
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') _openCreatePostSheet(editingPostId: postId, existing: data);
                      if (v == 'delete') _deletePost(postId);
                    },
                    icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Content text
            if (content.toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  content,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: AppColors.text,
                  ),
                ),
              ),
            
            // Image
            if (imageUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: isWide ? 16 / 7 : 16 / 9,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (c, child, loading) {
                        if (loading == null) return child;
                        return Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(color: AppColors.accent),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            
            // Actions row
            Row(
              children: [
                // Like button
                GestureDetector(
                  onTap: () => _firestore.collection('posts').doc(postId).get().then((snap) => _toggleLikePost(snap)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isLiked ? Colors.red.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          color: isLiked ? Colors.red : Colors.grey,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${likes.length}',
                          style: TextStyle(
                            color: isLiked ? Colors.red : Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Comment button
                GestureDetector(
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: AppColors.surface,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    builder: (_) => CommentBottomSheet(postId: postId),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.comment_outlined, color: Colors.grey, size: 18),
                        const SizedBox(width: 6),
                        StreamBuilder<QuerySnapshot>(
                          stream: _firestore.collection('posts').doc(postId).collection('comments').snapshots(),
                          builder: (context, s) {
                            if (!s.hasData) return const Text('0', style: TextStyle(color: Colors.grey));
                            return Text(
                              '${s.data!.docs.length}',
                              style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                
                const Spacer(),
                
                // Share button
                IconButton(
                  icon: const Icon(Icons.share_outlined, color: Colors.grey),
                  onPressed: () {
                    // Share functionality would go here
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(String? photoUrl, String username, {double radius = 18}) {
    final name = (username.isNotEmpty ? username : 'U');
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(photoUrl),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.accent,
      child: Text(
        name[0].toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ----------------------- Comment Bottom Sheet -----------------------
class CommentBottomSheet extends StatefulWidget {
  final String postId;
  const CommentBottomSheet({super.key, required this.postId});

  @override
  State<CommentBottomSheet> createState() => _CommentBottomSheetState();
}

class _CommentBottomSheetState extends State<CommentBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _me = FirebaseAuth.instance.currentUser;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _addComment() async {
    final t = _commentController.text.trim();
    if (t.isEmpty) return;
    await _firestore.collection('posts').doc(widget.postId).collection('comments').add({
      'userId': _me?.uid ?? 'guest',
      'username': _me?.displayName ?? (_me?.email?.split('@').first ?? 'User'),
      'photoUrl': _me?.photoURL ?? '',
      'text': t,
      'timestamp': FieldValue.serverTimestamp(),
      'reactions': <String, dynamic>{},
    });
    _commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        height: 4,
                        width: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Comments',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Comments list
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('posts').doc(widget.postId).collection('comments').orderBy('timestamp', descending: false).snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Center(
                        child: Text(
                          'Error loading comments',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      );
                    }
                    
                    if (!snap.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: AppColors.accent),
                      );
                    }
                    
                    final comments = snap.data!.docs;
                    
                    if (comments.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.comment_outlined, color: Colors.grey[400], size: 64),
                            const SizedBox(height: 16),
                            Text(
                              'No comments yet',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Be the first to comment!',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    return ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.all(20),
                      itemCount: comments.length,
                      itemBuilder: (context, i) {
                        final c = comments[i];
                        return CommentTileSheet(
                          postId: widget.postId,
                          commentId: c.id,
                          data: c.data() as Map<String, dynamic>,
                        );
                      },
                    );
                  },
                ),
              ),
              
              // Comment input
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                    top: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: TextField(
                          controller: _commentController,
                          decoration: const InputDecoration(
                            hintText: 'Add a comment...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _addComment,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.send, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ----------------------- Comment Tile -----------------------
class CommentTileSheet extends StatefulWidget {
  final String postId;
  final String commentId;
  final Map<String, dynamic> data;
  const CommentTileSheet({super.key, required this.postId, required this.commentId, required this.data});

  @override
  State<CommentTileSheet> createState() => _CommentTileSheetState();
}

class _CommentTileSheetState extends State<CommentTileSheet> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool showReplies = false;
  final List<String> _reactionEmojis = ['❤️', '😂', '😮', '😢'];
  final TextEditingController _replyController = TextEditingController();
  bool _showReplyInput = false;

  // FIXED: Added _timeAgo method to this class
  String _timeAgo(Timestamp? t) {
    if (t == null) return '';
    final diff = DateTime.now().difference(t.toDate());
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${t.toDate().day}/${t.toDate().month}/${t.toDate().year}';
  }

  Future<void> _toggleReaction(String emoji) async {
    final commentRef = _firestore.collection('posts').doc(widget.postId).collection('comments').doc(widget.commentId);
    final snap = await commentRef.get();
    if (!snap.exists) return;
    final me = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    final data = snap.data() as Map<String, dynamic>;
    final Map<String, dynamic> reactions = Map<String, dynamic>.from(data['reactions'] ?? {});
    final List current = List<String>.from(reactions[emoji] ?? []);
    if (current.contains(me)) {
      current.remove(me);
    } else {
      current.add(me);
    }
    reactions[emoji] = current;
    await commentRef.update({'reactions': reactions});
  }

  Future<void> _addReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    final me = FirebaseAuth.instance.currentUser;
    await _firestore
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .doc(widget.commentId)
        .collection('replies')
        .add({
      'userId': me?.uid ?? 'guest',
      'username': me?.displayName ?? (me?.email?.split('@').first ?? 'User'),
      'photoUrl': me?.photoURL ?? '',
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });
    _replyController.clear();
    setState(() => _showReplyInput = false);
  }

  Future<void> _deleteComment() async {
    await _firestore.collection('posts').doc(widget.postId).collection('comments').doc(widget.commentId).delete();
  }

  @override
  Widget build(BuildContext context) {
    final username = widget.data['username'] ?? 'User';
    final photo = widget.data['photoUrl'] ?? '';
    final text = widget.data['text'] ?? '';
    final timestamp = widget.data['timestamp'] as Timestamp?;
    final reactions = Map<String, dynamic>.from(widget.data['reactions'] ?? {});
    final userId = widget.data['userId'];
    final isMyComment = userId == FirebaseAuth.instance.currentUser?.uid;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.accent,
                backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                child: photo.isEmpty 
                    ? Text(
                        username[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                username,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _timeAgo(timestamp), // FIXED: Now using local method
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            text,
                            style: const TextStyle(fontSize: 14, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    
                    // Reactions and actions
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 8),
                      child: Wrap(
                        spacing: 12,
                        children: [
                          // Reactions
                          Wrap(
                            spacing: 8,
                            children: _reactionEmojis.map((emoji) {
                              final count = (reactions[emoji] as List<dynamic>?)?.length ?? 0;
                              final isMyReaction = (reactions[emoji] as List<dynamic>?)?.contains(FirebaseAuth.instance.currentUser?.uid ?? 'guest') == true;
                              
                              return GestureDetector(
                                onTap: () => _toggleReaction(emoji),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isMyReaction ? AppColors.accent.withOpacity(0.1) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isMyReaction ? AppColors.accent : Colors.grey[300]!,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(emoji, style: const TextStyle(fontSize: 14)),
                                      if (count > 0) ...[
                                        const SizedBox(width: 4),
                                        Text(
                                          '$count',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isMyReaction ? AppColors.accent : Colors.grey,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          
                          // Reply button
                          GestureDetector(
                            onTap: () => setState(() => _showReplyInput = !_showReplyInput),
                            child: Text(
                              'Reply',
                              style: TextStyle(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          
                          // View replies toggle
                          StreamBuilder<QuerySnapshot>(
                            stream: _firestore.collection('posts').doc(widget.postId).collection('comments').doc(widget.commentId).collection('replies').snapshots(),
                            builder: (context, s) {
                              if (!s.hasData) return const SizedBox();
                              final replyCount = s.data!.docs.length;
                              if (replyCount == 0) return const SizedBox();
                              
                              return GestureDetector(
                                onTap: () => setState(() => showReplies = !showReplies),
                                child: Text(
                                  showReplies ? 'Hide replies' : 'View $replyCount ${replyCount == 1 ? 'reply' : 'replies'}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    
                    // Reply input
                    if (_showReplyInput) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: TextField(
                                controller: _replyController,
                                decoration: const InputDecoration(
                                  hintText: 'Write a reply...',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _addReply,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.send, color: Colors.white, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              
              // More options (for user's own comments)
              if (isMyComment)
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'delete') {
                      await _deleteComment();
                    }
                  },
                  icon: Icon(Icons.more_vert, size: 16, color: Colors.grey[500]),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          
          // Replies list
          if (showReplies)
            Padding(
              padding: const EdgeInsets.only(left: 42, top: 12),
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('posts').doc(widget.postId).collection('comments').doc(widget.commentId).collection('replies').orderBy('timestamp', descending: false).snapshots(),
                builder: (context, s) {
                  if (!s.hasData) return const SizedBox();
                  final replies = s.data!.docs;
                  
                  return Column(
                    children: replies.map((r) {
                      final d = r.data() as Map<String, dynamic>;
                      final replyTime = d['timestamp'] as Timestamp?;
                      final replyPhoto = d['photoUrl'] ?? '';
                      final replyUsername = d['username'] ?? 'User';
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: AppColors.accent,
                              backgroundImage: replyPhoto.isNotEmpty ? NetworkImage(replyPhoto) : null,
                              child: replyPhoto.isEmpty
                                  ? Text(
                                      replyUsername[0].toUpperCase(),
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          replyUsername,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _timeAgo(replyTime), // FIXED: Now using local method
                                          style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      d['text'] ?? '',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}