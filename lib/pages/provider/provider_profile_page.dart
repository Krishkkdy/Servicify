import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/components/change_password_dialog.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProviderProfilePage extends StatefulWidget {
  const ProviderProfilePage({super.key});
  @override
  State<ProviderProfilePage> createState() => _ProviderProfilePageState();
}

class _ProviderProfilePageState extends State<ProviderProfilePage> {
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _businessNameController;
  late TextEditingController _mobileController;
  late TextEditingController _locationController;
  List<String> selectedServices = [];
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _businessNameController = TextEditingController();
    _mobileController = TextEditingController();
    _locationController = TextEditingController();
    _loadProfileImage();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _businessNameController.dispose();
    _mobileController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        await AuthService().updateProviderProfile(user.uid, {
          'name': _nameController.text,
          'businessName': _businessNameController.text,
          'mobileNumber': _mobileController.text,
          'location': _locationController.text,
          'services': selectedServices,
        });

        setState(() => _isEditing = false);

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (pickedFile == null) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });

        await AuthService().updateProviderProfile(user.uid, {
          'profileImage': pickedFile.path,
        });

        final userData = await AuthService().getUserData();
        if (userData != null && userData['profileImage'] != null) {
          final File imageFile = File(userData['profileImage']);
          if (await imageFile.exists()) {
            setState(() {
              _imageFile = imageFile;
            });
          }
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error updating profile picture: ${e.toString()}')),
      );
    }
  }

  Future<void> _loadProfileImage() async {
    try {
      final userData = await AuthService().getUserData();
      if (userData != null && userData['profileImage'] != null) {
        final String imagePath = userData['profileImage'];
        final File imageFile = File(imagePath);

        if (await imageFile.exists()) {
          setState(() {
            _imageFile = imageFile;
          });
        }
      }
    } catch (e) {
      print('Error loading profile image: $e');
    }
  }

  void _showImagePickerModal() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AuthService _authService = AuthService();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _isEditing
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => setState(() => _isEditing = false),
              )
            : null,
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.key),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => ChangePasswordDialog(
                    onSuccess: () => setState(() {}),
                  ),
                );
              },
            ),
          IconButton(
            icon:
                Icon(_isEditing ? Icons.save : Icons.edit, color: Colors.white),
            onPressed: () {
              if (_isEditing) {
                _updateProfile();
              } else {
                setState(() => _isEditing = true);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await _authService.signOut();
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                  context, '/login', (route) => false);
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _authService.getUserData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('Error loading profile'));
          }

          final userData = snapshot.data!;

          if (!_isEditing) {
            _nameController.text = userData['name'] ?? '';
            _businessNameController.text = userData['businessName'] ?? '';
            _mobileController.text = userData['mobileNumber'] ?? '';
            _locationController.text = userData['location'] ?? '';
            selectedServices = List<String>.from(userData['services'] ?? []);
          }

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF4E54C8).withOpacity(0.8),
                  const Color(0xFF4E54C8).withOpacity(0.6),
                  Colors.white,
                ],
                stops: const [0.0, 0.2, 0.4],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      _buildProfileHeader(userData),
                      const SizedBox(height: 20),
                      _buildBusinessCard(userData),
                      const SizedBox(height: 20),
                      if (_isEditing) _buildServiceSelection(),
                      if (!_isEditing) _buildStatsSection(userData),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> userData) {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color.fromARGB(148, 183, 180, 255),
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _isEditing ? _showImagePickerModal : null,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: const Color(0xFF4E54C8).withOpacity(0.1),
                      backgroundImage: _imageFile != null
                          ? FileImage(_imageFile!) as ImageProvider
                          : null,
                      child: _imageFile == null
                          ? const Icon(
                              Icons.person_outline,
                              size: 50,
                              color: Color(0xFF4E54C8),
                            )
                          : null,
                    ),
                    if (_isEditing)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4E54C8),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    if (_isEditing && _imageFile != null)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _imageFile = null;
                            });
                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null) {
                              AuthService().updateProviderProfile(user.uid, {
                                'profileImage': '',
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                userData['businessName'] ?? 'Business Name',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4E54C8),
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                userData['location'] ?? 'Location',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBusinessCard(Map<String, dynamic> userData) {
    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Business Information',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF4E54C8),
                ),
          ),
          const SizedBox(height: 20),
          _buildInfoField(
            icon: Icons.business,
            label: 'Business Name',
            value: userData['businessName'] ?? '',
            controller: _businessNameController,
            isEditing: _isEditing,
          ),
          const SizedBox(height: 16),
          _buildInfoField(
            icon: Icons.person,
            label: 'Owner Name',
            value: userData['name'] ?? '',
            controller: _nameController,
            isEditing: _isEditing,
          ),
          const SizedBox(height: 16),
          _buildInfoField(
            icon: Icons.phone,
            label: 'Mobile Number',
            value: userData['mobileNumber'] ?? '',
            controller: _mobileController,
            isEditing: _isEditing,
          ),
          const SizedBox(height: 16),
          _buildInfoField(
            icon: Icons.location_on,
            label: 'Location',
            value: userData['location'] ?? '',
            controller: _locationController,
            isEditing: _isEditing,
          ),
        ],
      ),
    );
  }

  Widget _buildServiceSelection() {
    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Services Offered',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF4E54C8),
                ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              'Cleaning',
              'Plumbing',
              'Electrical',
              'Painting',
              'Carpentry',
              'Gardening',
              'Moving',
              'Appliance Repair',
            ].map((service) {
              final isSelected = selectedServices.contains(service);
              return FilterChip(
                selected: isSelected,
                label: Text(service),
                onSelected: (bool selected) {
                  setState(() {
                    if (selected) {
                      selectedServices.add(service);
                    } else {
                      selectedServices.remove(service);
                    }
                  });
                },
                selectedColor: const Color(0xFF4E54C8).withOpacity(0.2),
                checkmarkColor: const Color(0xFF4E54C8),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(Map<String, dynamic> userData) {
    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Statistics',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF4E54C8),
                ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                icon: Icons.star,
                value: userData['rating']?.toStringAsFixed(1) ?? '0.0',
                label: 'Rating',
              ),
              _buildStatItem(
                icon: Icons.people,
                value: userData['totalRatings']?.toString() ?? '0',
                label: 'Reviews',
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Services Offered',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4E54C8),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (userData['services'] as List<dynamic>?)
                    ?.map((service) => Chip(
                          label: Text(service),
                          backgroundColor:
                              const Color(0xFF4E54C8).withOpacity(0.1),
                          labelStyle: const TextStyle(color: Color(0xFF4E54C8)),
                        ))
                    .toList() ??
                [],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoField({
    required IconData icon,
    required String label,
    required String value,
    TextEditingController? controller,
    bool isEditing = false,
  }) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF4E54C8)),
        const SizedBox(width: 16),
        Expanded(
          child: isEditing
              ? TextFormField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: label,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? '$label is required' : null,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF4E54C8).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF4E54C8)),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF4E54C8),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
