import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'pages/login_page.dart';
import 'pages/customer_home_page.dart';
import 'pages/provider_home_page.dart';
import 'services/auth_service.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyCiwRX400frbETgwM8W88gImlEdxpNNb6w",
      appId: "1:794064849326:android:226bde1060294c8bb8e03f",
      messagingSenderId: "794064849326",
      projectId: "home-service-18475",
      storageBucket: "home-service-18475.firebasestorage.app",
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasData) {
            // User is logged in, check their role
            return FutureBuilder<String?>(
              future: AuthService().getCurrentUserRole(),
              builder: (context, roleSnapshot) {
                if (roleSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (roleSnapshot.data == 'Customer') {
                  return CustomerHomePage();
                } else if (roleSnapshot.data == 'Service Provider') {
                  return ProviderHomePage();
                }

                return LoginPage();
              },
            );
          }

          // User is not logged in
          return LoginPage();
        },
      ),
    );
  }
}
