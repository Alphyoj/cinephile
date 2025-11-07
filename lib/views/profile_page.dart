import 'package:flutter/material.dart';
import 'package:cinephile/core/constants/app_colors.dart';
import 'package:cinephile/core/widgets/bottom_nav_bar.dart';
import 'package:cinephile/views/home_page.dart';
import 'package:cinephile/views/community_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _selectedIndex = 2;

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;
    if (index == 0) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
    } else if (index == 1) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CommunityPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Profile"),
        backgroundColor: AppColors.surface,
        centerTitle: true,
      ),
      body: const Center(
        child: Text("Profile Details Coming Soon", style: TextStyle(color: AppColors.text, fontSize: 18)),
      ),
      bottomNavigationBar: BottomNavBar(selectedIndex: _selectedIndex, onItemTapped: _onItemTapped),
    );
  }
}
