class AppUser {
  final String uid;
  final String email;
  final String? username;
  final String? photoUrl;
  final String role; 

  AppUser({
    required this.uid,
    required this.email,
    this.username,
    this.photoUrl,
    this.role = 'user',
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'photoUrl': photoUrl,
      'role': role,
    };
  }

  static AppUser fromMap(Map<String, dynamic> m) {
    return AppUser(
      uid: m['uid'],
      email: m['email'],
      username: m['username'],
      photoUrl: m['photoUrl'],
      role: m['role'] ?? 'user',
    );
  }
}
