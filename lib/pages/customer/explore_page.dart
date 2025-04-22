import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/app_theme.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage>
    with SingleTickerProviderStateMixin {
  String? selectedCategory;
  bool isSearching = false;
  String searchQuery = '';

  final List<String> categories = const [
    'Cleaning',
    'Plumbing',
    'Electrical',
    'Painting',
    'Carpentry',
    'Gardening',
    'Moving',
    'More',
  ];

  final Map<String, Color> serviceColors = {
    'Cleaning': Color(0xFF4CAF50), // Green
    'Plumbing': Color(0xFF2196F3), // Blue
    'Electrical': Color(0xFFFFC107), // Amber
    'Painting': Color(0xFFE91E63), // Pink
    'Carpentry': Color(0xFF795548), // Brown
    'Gardening': Color(0xFF8BC34A), // Light Green
    'Moving': Color(0xFF9C27B0), // Purple
    'More': Color(0xFF607D8B), // Blue Grey
  };

  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Stream<List<DocumentSnapshot>> _getProvidersStream() {
    Query query = FirebaseFirestore.instance
        .collection('serviceProviders')
        .orderBy('rating', descending: true);

    // If category is selected, filter by services
    if (selectedCategory != null && selectedCategory != 'More') {
      query = query.where('services', arrayContains: selectedCategory);
    }

    return query.snapshots().map((snapshot) {
      if (searchQuery.isEmpty) return snapshot.docs;

      // Client-side filtering for search
      String searchLower = searchQuery.toLowerCase();
      return snapshot.docs.where((doc) {
        var data = doc.data() as Map<String, dynamic>;
        String name = (data['name'] ?? '').toLowerCase();
        String businessName = (data['businessName'] ?? '').toLowerCase();
        String services = (data['services'] as List?)
                ?.map((s) => s.toString().toLowerCase())
                .join(' ') ??
            '';
        return name.contains(searchLower) ||
            businessName.contains(searchLower) ||
            services.contains(searchLower);
      }).toList();
    });
  }

  void _onCategorySelected(String category) {
    print('Category selected: $category'); // Debug print
    setState(() {
      selectedCategory = category;
    });
  }

  Future<void> _addToBookings(DocumentSnapshot provider) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final bookingsRef = FirebaseFirestore.instance
            .collection('customers')
            .doc(user.uid)
            .collection('bookings');

        final existingBookings = await bookingsRef
            .where('providerId', isEqualTo: provider.id)
            .where('status', isEqualTo: 'Pending')
            .get();

        if (existingBookings.docs.isNotEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('You already have a pending booking with this provider'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.pop(context);
          return;
        }

        final providerData = provider.data() as Map<String, dynamic>;

        await bookingsRef.add({
          'providerName': providerData['businessName'],
          'providerId': provider.id,
          'serviceType': (providerData['services'] as List).join(', '),
          'status': 'Pending',
          'bookingDate': Timestamp.now(),
          'customerName': user.displayName ?? '',
          'customerId': user.uid,
          'customerEmail': user.email ?? '',
          'providerEmail': providerData['email'],
          'providerPhone': providerData['mobileNumber'],
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully added to bookings'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error adding to bookings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add to bookings: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: isSearching
            ? TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search services or providers...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  prefixIcon:
                      const Icon(Icons.search, color: Color(0xFF4E54C8)),
                ),
                style: const TextStyle(color: Colors.black, fontSize: 16),
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
              )
            : Text(
                selectedCategory ?? 'Explore Services',
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
        leading: selectedCategory != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    selectedCategory = null;
                  });
                },
              )
            : null,
        actions: [
          IconButton(
            icon: Icon(isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                isSearching = !isSearching;
                if (!isSearching) {
                  // Clear search query when closing search
                  searchQuery = '';
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (!isSearching && selectedCategory == null)
            Container(
              height: 130,
              margin: const EdgeInsets.only(top: 24, bottom: 16),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final color =
                      serviceColors[category] ?? const Color(0xFF4E54C8);

                  return AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) => Transform.scale(
                      scale: 1.0 + (_animation.value * 0.03),
                      child: Container(
                        margin: const EdgeInsets.only(right: 16, top: 8),
                        child: GestureDetector(
                          onTap: () => _onCategorySelected(category),
                          child: Column(
                            children: [
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: color.withOpacity(0.3),
                                  ),
                                ),
                                child: Icon(
                                  _getCategoryIcon(category),
                                  color: color,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                category,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          if (selectedCategory != null && !isSearching)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Service Providers for ${selectedCategory!}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4E54C8),
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.sort, color: Color(0xFF4E54C8)),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<List<DocumentSnapshot>>(
              stream: _getProvidersStream(),
              builder: (context, snapshot) {
                print('Stream builder state: ${snapshot.connectionState}');
                if (snapshot.hasData) {
                  print('Number of docs: ${snapshot.data!.length}');
                }

                if (snapshot.hasError) {
                  return const Center(child: Text('Something went wrong'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/Sad-512.jpg',
                          height: 120,
                          width: 120,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          selectedCategory != null
                              ? 'No service providers available for ${selectedCategory!}'
                              : 'No service providers available',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              selectedCategory = null;
                              searchQuery = '';
                            });
                          },
                          child: const Text('Clear Filters'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(
                      left: 16, right: 16, top: 24, bottom: 16),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    DocumentSnapshot provider = snapshot.data![index];
                    Map<String, dynamic> providerData =
                        provider.data() as Map<String, dynamic>;
                    List<String> services =
                        List<String>.from(providerData['services'] ?? []);

                    return ServiceProviderCard(
                      name: providerData['name'] ?? '',
                      businessName: providerData['businessName'] ?? '',
                      services: services,
                      rating: providerData['rating']?.toDouble() ?? 0.0,
                      mobileNumber: providerData['mobileNumber'] ?? '',
                      onTap: () => _showProviderDetails(context, provider),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showProviderDetails(BuildContext context, DocumentSnapshot provider) {
    final providerData = provider.data() as Map<String, dynamic>;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  providerData['businessName'] ?? '',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Provider: ${providerData['name']}'),
                Text('Mobile: ${providerData['mobileNumber']}'),
                Text('Area: ${providerData['location'] ?? 'Not specified'}'),
                const SizedBox(height: 16),
                const Text(
                  'Services Offered:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: List<String>.from(providerData['services'] ?? [])
                      .map((service) => Chip(label: Text(service)))
                      .toList(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber),
                    Text(
                        ' ${providerData['rating']?.toStringAsFixed(1) ?? '0.0'}'),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () => _addToBookings(provider),
                    child: const Text(
                      'Add to Bookings',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Cleaning':
        return Icons.cleaning_services;
      case 'Plumbing':
        return Icons.plumbing;
      case 'Electrical':
        return Icons.electrical_services;
      case 'Painting':
        return Icons.format_paint;
      case 'Carpentry':
        return Icons.handyman;
      case 'Gardening':
        return Icons.grass;
      case 'Moving':
        return Icons.local_shipping;
      default:
        return Icons.more_horiz;
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      searchQuery = query.trim();
    });
  }
}

class ServiceProviderCard extends StatelessWidget {
  final String name;
  final String businessName;
  final List<String> services;
  final double rating;
  final String mobileNumber;
  final VoidCallback? onTap;

  const ServiceProviderCard({
    super.key,
    required this.name,
    required this.businessName,
    required this.services,
    required this.rating,
    required this.mobileNumber,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF4E54C8).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0] : '',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4E54C8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      businessName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      services.join(' • '),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Rating',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
