import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class BookingsHistoryPage extends StatelessWidget {
  const BookingsHistoryPage({super.key});

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Future<void> _updateBookingStatus(BuildContext context, String bookingId,
      String customerId, String status) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Update provider's booking
      await FirebaseFirestore.instance
          .collection('serviceProviders')
          .doc(user.uid)
          .collection('bookings')
          .doc(bookingId)
          .update({
        'status': status,
        'lastUpdated': Timestamp.now(),
      });

      // Update customer's booking
      await FirebaseFirestore.instance
          .collection('customers')
          .doc(customerId)
          .collection('bookings')
          .doc(bookingId)
          .update({
        'status': status,
        'lastUpdated': Timestamp.now(),
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Booking marked as $status'),
          backgroundColor: status == 'Completed' ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating booking: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteBooking(BuildContext context, String bookingId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Simply delete the booking from provider's collection
      await FirebaseFirestore.instance
          .collection('serviceProviders')
          .doc(user.uid)
          .collection('bookings')
          .doc(bookingId)
          .delete();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking removed from history'),
          backgroundColor: Colors.grey,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing booking: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showBookingDetails(
      BuildContext context, Map<String, dynamic> bookingData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.5,
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
                  'Booking Details',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(bookingData['customerName'] ?? ''),
                  subtitle: const Text('Customer Name'),
                ),
                ListTile(
                  leading: const Icon(Icons.phone),
                  title: Text(bookingData['customerPhone'] ?? ''),
                  subtitle: const Text('Phone Number'),
                  trailing: IconButton(
                    icon: const Icon(Icons.call, color: Colors.green),
                    onPressed: () =>
                        _makePhoneCall(bookingData['customerPhone']),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.location_on),
                  title: Text(bookingData['serviceAddress'] ?? ''),
                  subtitle: const Text('Service Address'),
                ),
                ListTile(
                  leading: const Icon(Icons.handyman),
                  title: Text(bookingData['serviceType'] ?? ''),
                  subtitle: const Text('Service Type'),
                ),
                if (bookingData['purposes'] != null) ...[
                  const Divider(),
                  const Text(
                    'Requested Services:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: (bookingData['purposes'] as List)
                        .map((service) => Chip(label: Text(service.toString())))
                        .toList(),
                  ),
                ],
                const Divider(),
                if (bookingData['status'] == 'Confirmed')
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Mark as Completed'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          onPressed: () => _updateBookingStatus(
                            context,
                            bookingData['id'],
                            bookingData['customerId'],
                            'Completed',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.cancel),
                          label: const Text('Mark as Cancelled'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          onPressed: () => _updateBookingStatus(
                            context,
                            bookingData['id'],
                            bookingData['customerId'],
                            'Cancelled',
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Completed':
        return Colors.green;
      case 'Cancelled':
        return Colors.red;
      case 'Confirmed':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookings History'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('serviceProviders')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .collection('bookings')
            .orderBy('lastUpdated', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No booking history'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final booking = snapshot.data!.docs[index];
              final bookingData = booking.data() as Map<String, dynamic>;
              bookingData['id'] = booking.id;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Dismissible(
                  key: Key(bookingData['id']),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20.0),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (direction) async {
                    return await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Booking?'),
                        content: const Text(
                            'Are you sure you want to remove this booking from history?'),
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
                  onDismissed: (direction) {
                    _deleteBooking(context, bookingData['id']);
                  },
                  child: ListTile(
                    onTap: () => _showBookingDetails(context, bookingData),
                    title: Text(bookingData['customerName'] ?? ''),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(bookingData['serviceType'] ?? ''),
                        Text(bookingData['serviceAddress'] ?? ''),
                        Text(
                            'Date: ${_formatDate(bookingData['bookingDate'] as Timestamp)}'),
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getStatusColor(bookingData['status']),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        bookingData['status'] ?? '',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
