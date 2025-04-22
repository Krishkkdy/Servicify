import 'package:flutter/material.dart';
import '../components/my_button.dart';
import '../components/my_textfield.dart';
import 'signup_page.dart';
import '../services/auth_service.dart';
import 'customer_home_page.dart';
import 'provider_home_page.dart';
import '../components/forgot_password_dialog.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService _authService = AuthService();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  // sign user in method
  void signUserIn() async {
    if (usernameController.text.isNotEmpty &&
        passwordController.text.isNotEmpty) {
      final userCredential = await _authService.signInWithEmailAndPassword(
        usernameController.text,
        passwordController.text,
      );

      if (!mounted) return; // Add this check

      if (userCredential != null) {
        String? role = await _authService.getCurrentUserRole();
        if (!mounted) return; // Add this check

        if (role != null) {
          // Navigate based on user role
          if (role == 'Customer') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => CustomerHomePage()),
            );
          } else if (role == 'Service Provider') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => ProviderHomePage()),
            );
          }
        }
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid login credentials')),
        );
      }
    }
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => const ForgotPasswordDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF6C63FF), // Updated primary color
              const Color(0xFF3F3D9B), // Updated secondary color
              Colors.white,
            ],
            stops: const [0.0, 0.5, 0.9],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 50),

                // Logo with animation
                TweenAnimationBuilder(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 800),
                  builder: (context, double value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(100),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons
                              .person_outline, // Change from Icons.lock to Icons.person_outline
                          size: 80,
                          color: Color(0xFF4E54C8),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 50),

                // Sign in card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 25),
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Welcome back!',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 25),
                      MyTextField(
                        controller: usernameController,
                        hintText: 'Email',
                        obscureText: false,
                        prefixIcon: Icons.email,
                      ),

                      const SizedBox(height: 10),

                      MyTextField(
                        controller: passwordController,
                        hintText: 'Password',
                        obscureText: true,
                        prefixIcon: Icons.lock,
                        isPassword: true, // Add this line
                      ),

                      // Add Forgot Password link
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _showForgotPasswordDialog,
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(
                              color: Color(0xFF4E54C8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // sign in button
                      MyButton(
                        onTap: signUserIn,
                      ),

                      const SizedBox(height: 25),

                      // Register now link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Not a member?',
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SignUpPage(),
                              ),
                            ),
                            child: const Text(
                              'Register now',
                              style: TextStyle(
                                color: Color(0xFF4E54C8),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 25),
                    ],
                  ),
                ),

                const SizedBox(height: 25),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
