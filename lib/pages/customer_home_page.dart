import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../pages/customer/explore_page.dart';
import '../pages/customer/bookings_page.dart';
import '../pages/customer/profile_page.dart';
import '../pages/customer/welcome_page.dart';

class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({super.key}); // Add const constructor

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  final AuthService _authService = AuthService();
  int _selectedIndex = 0;

  // Add this method
  void updateIndex(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      CustomerWelcomePage(onNavigate: updateIndex), // Update this line
      const ExplorePage(),
      const BookingsPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
