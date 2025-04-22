import 'package:flutter/material.dart';
import '../components/my_button.dart';
import '../components/my_textfield.dart';
import '../services/auth_service.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final mobileController = TextEditingController(); // Add this line
  final locationController = TextEditingController(); // Add this line
  String selectedRole = 'Customer';

  // Additional controllers for service provider
  final businessNameController = TextEditingController();
  final List<String> availableServices = [
    'Cleaning',
    'Plumbing',
    'Electrical',
    'Painting',
    'Carpentry',
    'Gardening',
    'Moving',
    'Appliance Repair',
  ];
  List<String> selectedServices = [];

  final AuthService _authService = AuthService();

  // Add error state variables
  String? errorMessage;
  bool isLoading = false;

  void signUserUp() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    if (passwordController.text.isEmpty ||
        emailController.text.isEmpty ||
        nameController.text.isEmpty ||
        mobileController.text.isEmpty) {
      // Add this check
      setState(() {
        errorMessage = "Please fill in all fields";
        isLoading = false;
      });
      return;
    }

    // Add mobile number validation
    if (mobileController.text.length != 10) {
      setState(() {
        errorMessage = "Please enter a valid 10-digit mobile number";
        isLoading = false;
      });
      return;
    }

    if (passwordController.text != confirmPasswordController.text) {
      setState(() {
        errorMessage = "Passwords don't match";
        isLoading = false;
      });
      return;
    }

    if (selectedRole == 'Service Provider' &&
        (businessNameController.text.isEmpty ||
            selectedServices.isEmpty ||
            locationController.text.isEmpty)) {
      // Add location check
      setState(() {
        errorMessage = "Please fill in all required fields including location";
        isLoading = false;
      });
      return;
    }

    try {
      final userCredential = await _authService.signUpWithEmailAndPassword(
        emailController.text.trim(),
        passwordController.text,
        nameController.text.trim(),
        selectedRole,
        mobileNumber: mobileController.text, // Add this line
        businessName: selectedRole == 'Service Provider'
            ? businessNameController.text.trim()
            : null,
        selectedServices:
            selectedRole == 'Service Provider' ? selectedServices : null,
        location: selectedRole == 'Service Provider' // Add location
            ? locationController.text.trim()
            : null,
      );

      if (!mounted) return;

      if (userCredential != null) {
        Navigator.pop(context);
      } else {
        setState(() {
          errorMessage = "Failed to create account";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Widget buildServiceSelection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 25),
      decoration: BoxDecoration(
        color: Colors.white, // Changed from grey.shade200 to white
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200, // Added border color
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05), // Added shadow
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.construction, color: Colors.grey[600]), // Added icon
                const SizedBox(width: 12),
                Text(
                  'Select Your Services',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: availableServices.length,
            itemBuilder: (context, index) {
              final service = availableServices[index];
              return CheckboxListTile(
                title: Text(service),
                value: selectedServices.contains(service),
                activeColor: const Color(0xFF4E54C8),
                checkColor: Colors.white,
                onChanged: (bool? value) {
                  setState(() {
                    if (value == true) {
                      selectedServices.add(service);
                    } else {
                      selectedServices.remove(service);
                    }
                  });
                },
              );
            },
          ),
        ],
      ),
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
              const Color(0xFF4E54C8),
              const Color(0xFF4E54C8).withOpacity(0.8),
              Colors.white,
            ],
            stops: const [0.0, 0.5, 0.9],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(25.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 30),

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
                                .account_circle, // Change from Icons.person_add to Icons.account_circle
                            size: 80,
                            color: Color(0xFF4E54C8),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  Text(
                    'Create your account',
                    style: TextStyle(
                      color: const Color.fromARGB(255, 255, 255, 255),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 25),

                  // Error message if any
                  if (errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(15),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        errorMessage!,
                        style: TextStyle(color: Colors.red[900]),
                      ),
                    ),

                  // Role Selection with modern style
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.transparent,
                            spreadRadius: 2,
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: DropdownButtonFormField<String>(
                        value: selectedRole,
                        decoration: InputDecoration(
                          prefixIcon: Icon(
                            Icons.person_outline,
                            color: Colors.grey[600],
                          ),
                          contentPadding: const EdgeInsets.all(20),
                          border: InputBorder.none,
                          hintStyle: TextStyle(color: Colors.grey[500]),
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black,
                        ),
                        dropdownColor: Colors.grey[200],
                        items: ['Customer', 'Service Provider']
                            .map((role) => DropdownMenuItem(
                                  value: role,
                                  child: Text(role),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedRole = value!;
                          });
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Common Fields
                  MyTextField(
                    controller: nameController,
                    hintText: 'Full Name',
                    obscureText: false,
                    prefixIcon: Icons.person,
                  ),

                  const SizedBox(height: 10),

                  MyTextField(
                    controller: emailController,
                    hintText: 'Email',
                    obscureText: false,
                    prefixIcon: Icons.email,
                  ),

                  const SizedBox(height: 10),

                  MyTextField(
                    controller: mobileController,
                    hintText: 'Mobile Number',
                    obscureText: false,
                    prefixIcon: Icons.phone,
                  ),

                  // Service Provider specific fields
                  if (selectedRole == 'Service Provider') ...[
                    const SizedBox(height: 10),
                    MyTextField(
                      controller: businessNameController,
                      hintText: 'Business Name',
                      obscureText: false,
                      prefixIcon: Icons.business,
                    ),
                    const SizedBox(height: 10),
                    MyTextField(
                      controller: locationController,
                      hintText: 'Location/Area',
                      obscureText: false,
                      prefixIcon: Icons.location_on,
                    ),
                    const SizedBox(height: 10),
                    buildServiceSelection(),
                    const SizedBox(height: 10),
                  ],

                  const SizedBox(height: 10),

                  MyTextField(
                    controller: passwordController,
                    hintText: 'Password',
                    obscureText: true,
                    prefixIcon: Icons.lock,
                    isPassword: true, // Add this line
                  ),

                  const SizedBox(height: 10),

                  MyTextField(
                    controller: confirmPasswordController,
                    hintText: 'Confirm Password',
                    obscureText: true,
                    prefixIcon: Icons.lock_clock,
                    isPassword: true, // Add this line
                  ),

                  const SizedBox(height: 25),

                  // sign up button
                  MyButton(
                    onTap: isLoading ? null : signUserUp,
                    text: isLoading ? "Creating Account..." : "Sign Up",
                  ),

                  const SizedBox(height: 30),

                  // Login link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account?',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text(
                          'Login now',
                          style: TextStyle(
                            color: Color(0xFF4E54C8),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
