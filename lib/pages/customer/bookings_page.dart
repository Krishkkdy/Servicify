import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../utils/app_theme.dart'; // Add this import

class BookingsPage extends StatefulWidget {
  // Change to StatefulWidget
  const BookingsPage({super.key});

  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage> {
  // Add rating dialog method
  Future<void> _showRatingDialog(
      BuildContext context, Map<String, dynamic> bookingData) async {
    double rating = 0;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        // Add StatefulBuilder
        builder: (context, setState) => AlertDialog(
          title: Column(
            children: [
              const Text('Rate Service',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(bookingData['providerName'] ?? '',
                  style: const TextStyle(fontSize: 16, color: Colors.grey)),
            ],
          ),
          content: SingleChildScrollView(
            // Add SingleChildScrollView
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('How was your service experience?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      constraints: const BoxConstraints(minWidth: 40),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      icon: Icon(
                        index < rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 36,
                      ),
                      onPressed: () {
                        setState(() => rating = index + 1.0);
                      },
                    );
                  }),
                ),
                const SizedBox(height: 8),
                Text(
                  _getRatingText(rating),
                  style: TextStyle(
                    fontSize: 16,
                    color: rating > 0 ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: rating > 0
                  ? () async {
                      await _submitRating(bookingData['providerId'], rating);
                      if (!context.mounted) return;

                      // Update rated status in booking
                      await FirebaseFirestore.instance
                          .collection('customers')
                          .doc(FirebaseAuth.instance.currentUser?.uid)
                          .collection('bookings')
                          .doc(bookingData['id'])
                          .update({'rated': true});

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Thank you for your rating!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                disabledBackgroundColor: Colors.grey.shade300,
              ),
              child:
                  const Text('Submit', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  String _getRatingText(double rating) {
    if (rating == 0) return 'Tap a star to rate';
    if (rating == 5) return 'Excellent!';
    if (rating == 4) return 'Very Good';
    if (rating == 3) return 'Good';
    if (rating == 2) return 'Fair';
    return 'Poor';
  }

  // Add rating submission method
  Future<void> _submitRating(String providerId, double rating) async {
    try {
      final providerRef = FirebaseFirestore.instance
          .collection('serviceProviders')
          .doc(providerId);

      final providerDoc = await providerRef.get();
      final currentRating = providerDoc.data()?['rating'] ?? 0.0;
      final currentTotalRatings = providerDoc.data()?['totalRatings'] ?? 0;

      final newTotalRatings = currentTotalRatings + 1;
      final newRating =
          ((currentRating * currentTotalRatings) + rating) / newTotalRatings;

      await providerRef.update({
        'rating': newRating,
        'totalRatings': newTotalRatings,
      });
    } catch (e) {
      print('Error submitting rating: $e');
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      throw 'Could not launch $launchUri';
    }
  }

  Future<String> _getCurrentAddress() async {
    // Request permission
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      return '';
    }

    try {
      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Convert position to address
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return '${place.street}, ${place.subLocality}, ${place.locality}, ${place.postalCode}';
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
    return '';
  }

  void _showProviderDetails(
      BuildContext context, Map<String, dynamic> bookingData) async {
    final TextEditingController addressController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();

    // Get current address
    String currentAddress = await _getCurrentAddress();
    addressController.text = currentAddress;
    List<String> selectedPurposes = [];

    final providerDoc = await FirebaseFirestore.instance
        .collection('serviceProviders')
        .doc(bookingData['providerId'])
        .get();

    if (!context.mounted) return;

    if (!providerDoc.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Provider details not found')),
      );
      return;
    }

    final providerData = providerDoc.data()!;
    final List<String> providerServices =
        List<String>.from(providerData['services'] ?? []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        // Add StatefulBuilder for checkboxes
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.8, // Increased to show more content
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            // Add date picker function within the builder
            Future<void> _selectDate(BuildContext context) async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 30)),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: AppTheme.primaryColor,
                        onPrimary: Colors.white,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null && picked != selectedDate) {
                setModalState(() {
                  selectedDate = picked;
                });
              }
            }

            // Add time picker function within the builder
            Future<void> _selectTime(BuildContext context) async {
              final TimeOfDay? picked = await showTimePicker(
                context: context,
                initialTime: selectedTime,
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: AppTheme.primaryColor,
                        onPrimary: Colors.white,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null && picked != selectedTime) {
                setModalState(() {
                  selectedTime = picked;
                });
              }
            }

            return SingleChildScrollView(
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Provider: ${providerData['name']}'),
                        IconButton(
                          icon: const Icon(Icons.phone, color: Colors.green),
                          onPressed: () =>
                              _makePhoneCall(providerData['mobileNumber']),
                        ),
                      ],
                    ),
                    Text('Mobile: ${providerData['mobileNumber']}'),
                    Text('Booking Status: ${bookingData['status']}'),
                    Text(
                        'Booking Date: ${_formatDate(bookingData['bookingDate'] as Timestamp)}'),
                    if (bookingData['scheduledDateTime'] != null)
                      Text(
                        'Scheduled Date & Time: ${_formatScheduledDateTime(bookingData['scheduledDateTime'])}',
                      ),
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
                      children:
                          List<String>.from(providerData['services'] ?? [])
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
                    if (bookingData['status'] == 'Pending') ...[
                      TextField(
                        controller: addressController,
                        decoration: const InputDecoration(
                          labelText: 'Service Address',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.location_on),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectDate(context),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Select Date',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.calendar_today),
                                ),
                                child: Text(
                                  '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectTime(context),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Select Time',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.access_time),
                                ),
                                child: Text(
                                  selectedTime.format(context),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Select Service Type:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ...providerServices.map((service) => CheckboxListTile(
                            title: Text(service),
                            value: selectedPurposes.contains(service),
                            onChanged: (bool? value) {
                              setModalState(() {
                                if (value == true) {
                                  selectedPurposes.add(service);
                                } else {
                                  selectedPurposes.remove(service);
                                }
                              });
                            },
                          )),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                              onPressed: () {
                                if (addressController.text.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Please enter service address')),
                                  );
                                  return;
                                }
                                if (selectedPurposes.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Please select at least one purpose')),
                                  );
                                  return;
                                }

                                // Create DateTime object combining date and time
                                final DateTime scheduledDateTime = DateTime(
                                  selectedDate.year,
                                  selectedDate.month,
                                  selectedDate.day,
                                  selectedTime.hour,
                                  selectedTime.minute,
                                );

                                _updateBookingStatus(
                                  context,
                                  bookingData['id'],
                                  'Request Sent', // Changed from 'Confirmed'
                                  addressController.text,
                                  selectedPurposes,
                                  scheduledDateTime, // Add this parameter
                                );
                              },
                              child: const Text(
                                'Confirm Booking',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                              onPressed: () => _updateBookingStatus(
                                context,
                                bookingData['id'],
                                'Cancelled',
                                null,
                                null,
                              ),
                              child: const Text(
                                'Cancel Booking',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatScheduledDateTime(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _updateBookingStatus(
      BuildContext context, String bookingId, String status,
      [String? address,
      List<String>? purposes,
      DateTime? scheduledDateTime]) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Fetch current customer data first
      final customerDoc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(currentUser.uid)
          .get();
      final customerData = customerDoc.data()!;

      final bookingRef = FirebaseFirestore.instance
          .collection('customers')
          .doc(currentUser.uid)
          .collection('bookings')
          .doc(bookingId);

      // Get the booking data first
      final bookingDoc = await bookingRef.get();
      if (!bookingDoc.exists) return;

      final bookingData = bookingDoc.data()!;
      Map<String, dynamic> updateData = {'status': status};

      if (status == 'Request Sent' && address != null && purposes != null) {
        // Changed from 'Confirmed' to 'Request Sent'
        updateData.addAll({
          'serviceAddress': address,
          'purposes': purposes,
          'scheduledDateTime': scheduledDateTime, // Add this
          'confirmedAt': Timestamp.now(),
        });

        // Create request in provider's collection with customer details
        await FirebaseFirestore.instance
            .collection('serviceProviders')
            .doc(bookingData['providerId'])
            .collection('requests')
            .add({
          'bookingId': bookingId,
          'customerId': currentUser.uid,
          'customerName': customerData['name'] ?? '', // Get from customer data
          'customerEmail': customerData['email'] ?? '',
          'customerPhone':
              customerData['mobileNumber'] ?? '', // Get from customer data
          'serviceAddress': address,
          'purposes': purposes,
          'status':
              'Pending Approval', // This stays as 'Pending Approval' for provider
          'requestedAt': Timestamp.now(),
          'serviceType': bookingData['serviceType'],
          'scheduledDateTime': scheduledDateTime, // Add this
        });
      }

      await bookingRef.update(updateData);

      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Booking $status successfully'),
          duration: const Duration(seconds: 2), // Show for 2 seconds
        ),
      );

      // If status is 'Cancelled', delete the booking after 5 seconds
      if (status == 'Cancelled') {
        await Future.delayed(const Duration(seconds: 5));
        await FirebaseFirestore.instance
            .collection('customers')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .collection('bookings')
            .doc(bookingId)
            .delete();

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cancelled booking removed'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update booking: ${e.toString()}')),
      );
    }
  }

  Future<void> _deleteBooking(BuildContext context, String bookingId) async {
    try {
      // First get the booking details
      final bookingDoc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .collection('bookings')
          .doc(bookingId)
          .get();

      if (!bookingDoc.exists) return;
      final bookingData = bookingDoc.data()!;

      // If status is "Request Sent", also delete the corresponding request
      if (bookingData['status'] == 'Request Sent') {
        // Get all requests from provider that match the booking ID
        final requestsQuery = await FirebaseFirestore.instance
            .collection('serviceProviders')
            .doc(bookingData['providerId'])
            .collection('requests')
            .where('bookingId', isEqualTo: bookingId)
            .get();

        // Delete each matching request
        for (var doc in requestsQuery.docs) {
          await FirebaseFirestore.instance
              .collection('serviceProviders')
              .doc(bookingData['providerId'])
              .collection('requests')
              .doc(doc.id)
              .delete();
        }
      }

      // Delete the booking
      await FirebaseFirestore.instance
          .collection('customers')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .collection('bookings')
          .doc(bookingId)
          .delete();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking removed successfully')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing booking: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking History'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryColor,
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: const Color(0xFF4E54C8),
        onRefresh: () async {
          // Add pull-to-refresh functionality
          setState(() {});
          await Future.delayed(const Duration(seconds: 1));
        },
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('customers')
              .doc(FirebaseAuth.instance.currentUser?.uid)
              .collection('bookings')
              .orderBy('bookingDate', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(
                      'Something went wrong',
                      style: TextStyle(color: Colors.grey[700], fontSize: 16),
                    ),
                  ],
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history_outlined,
                      size: 120,
                      color: AppTheme.primaryColor.withOpacity(0.3),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No bookings yet',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Your booking history will appear here',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                var bookingDoc = snapshot.data!.docs[index];
                var bookingData = bookingDoc.data() as Map<String, dynamic>;
                bookingData['id'] =
                    bookingDoc.id; // Add document ID to the data

                return Dismissible(
                  // Wrap BookingCard with Dismissible
                  key: Key(bookingData['id']),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20.0),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (direction) {
                    _deleteBooking(context, bookingData['id']);
                  },
                  confirmDismiss: (direction) async {
                    return await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Booking?'),
                        content: const Text(
                            'Are you sure you want to remove this booking?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: TextButton.styleFrom(
                                foregroundColor: Colors.red),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: BookingCard(
                    serviceProvider: bookingData['providerName'] ?? '',
                    serviceType: bookingData['serviceType'] ?? '',
                    bookingDate:
                        (bookingData['bookingDate'] as Timestamp).toDate(),
                    status: bookingData['status'] ?? '',
                    bookingId: bookingDoc.id,
                    onTap: () => _showProviderDetails(context, bookingData),
                    bookingData: bookingData, // Add this
                    onRateService: _showRatingDialog, // Add this
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// Add this as a static method in BookingCard class or make it top-level function
String formatScheduledDateTime(Timestamp timestamp) {
  final date = timestamp.toDate();
  return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
}

// Update BookingCard class
class BookingCard extends StatelessWidget {
  final String serviceProvider;
  final String serviceType;
  final DateTime bookingDate;
  final String status;
  final String bookingId;
  final VoidCallback onTap;
  final Map<String, dynamic>? bookingData; // Add this
  final Function(BuildContext, Map<String, dynamic>)? onRateService; // Add this

  const BookingCard({
    super.key,
    required this.serviceProvider,
    required this.serviceType,
    required this.bookingDate,
    required this.status,
    required this.bookingId,
    required this.onTap,
    this.bookingData, // Add this
    this.onRateService, // Add this
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        constraints: const BoxConstraints(minHeight: 120, maxHeight: 220),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.08),
              spreadRadius: 2,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Stack(
                children: [
                  // Status indicator line
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 4,
                    child: Container(
                      color: _getStatusColor(status),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _getServiceIcon(serviceType),
                                color: AppTheme.primaryColor,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    serviceProvider,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    serviceType,
                                    style: const TextStyle(
                                      color: AppTheme.subtitleColor,
                                      fontSize: 14,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            _buildStatusBadge(status),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _buildInfoChip(
                              icon: Icons.calendar_today,
                              text: bookingData?['scheduledDateTime'] != null
                                  ? formatScheduledDateTime(
                                      bookingData!['scheduledDateTime'])
                                  : '${bookingDate.day}/${bookingDate.month}/${bookingDate.year}',
                            ),
                            if (bookingData?['serviceAddress'] != null) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildInfoChip(
                                  icon: Icons.location_on,
                                  text: bookingData!['serviceAddress'],
                                ),
                              ),
                            ],
                          ],
                        ),
                        // Action buttons with modern styling
                        if (status == 'Completed' &&
                            bookingData != null &&
                            !(bookingData!['rated'] ?? false))
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  icon: const Icon(Icons.star,
                                      color: Colors.amber),
                                  label: const Text('Rate Service'),
                                  onPressed: () => onRateService?.call(
                                      context, bookingData!),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.amber,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (status == 'Pending' || status == 'Request Sent')
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  icon: const Icon(Icons.cancel_outlined,
                                      color: Colors.red),
                                  label: const Text('Cancel'),
                                  onPressed: () =>
                                      _showCancelConfirmation(context),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String text}) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppTheme.subtitleColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  color: AppTheme.subtitleColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getServiceIcon(String serviceType) {
    if (serviceType.toLowerCase().contains('clean'))
      return Icons.cleaning_services;
    if (serviceType.toLowerCase().contains('plumb')) return Icons.plumbing;
    if (serviceType.toLowerCase().contains('electric'))
      return Icons.electrical_services;
    if (serviceType.toLowerCase().contains('paint')) return Icons.format_paint;
    if (serviceType.toLowerCase().contains('garden')) return Icons.grass;
    if (serviceType.toLowerCase().contains('move')) return Icons.local_shipping;
    return Icons.handyman;
  }

  // Add this method to show cancel confirmation dialog
  Future<void> _showCancelConfirmation(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (result == true && bookingData != null) {
      // Call _updateBookingStatus to cancel the booking
      await _updateBookingStatus(
        context,
        bookingData!['id'],
        'Cancelled',
      );
    }
  }

  // Add this method to handle booking status update
  Future<void> _updateBookingStatus(
      BuildContext context, String bookingId, String status) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final bookingRef = FirebaseFirestore.instance
          .collection('customers')
          .doc(user.uid)
          .collection('bookings')
          .doc(bookingId);

      // Get the booking data to get providerId
      final bookingDoc = await bookingRef.get();
      if (!bookingDoc.exists) return;
      final bookingData = bookingDoc.data()!;

      await bookingRef.update({
        'status': status,
        'cancelledAt': Timestamp.now(),
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking cancelled successfully'),
          backgroundColor: Colors.red,
        ),
      );

      // Add delay and delete booking and request
      await Future.delayed(const Duration(seconds: 2));

      // Delete provider's request if exists
      if (bookingData['status'] == 'Request Sent') {
        final requestsQuery = await FirebaseFirestore.instance
            .collection('serviceProviders')
            .doc(bookingData['providerId'])
            .collection('requests')
            .where('bookingId', isEqualTo: bookingId)
            .get();

        for (var doc in requestsQuery.docs) {
          await doc.reference.delete();
        }
      }

      // Delete the booking
      await bookingRef.delete();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking removed'),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.grey,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cancelling booking: ${e.toString()}')),
      );
    }
  }

  Widget _buildStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _getStatusColor(status).withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getStatusIcon(status),
            size: 16,
            color: _getStatusColor(status),
          ),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              color: _getStatusColor(status),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Completed':
        return Colors.green;
      case 'Cancelled':
        return Colors.red;
      case 'Request Sent':
        return Colors.orange;
      case 'Confirmed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Completed':
        return Icons.check_circle;
      case 'Cancelled':
        return Icons.cancel;
      case 'Request Sent':
        return Icons.schedule;
      case 'Confirmed':
        return Icons.thumb_up;
      default:
        return Icons.info;
    }
  }
}
