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
                if (bookingData['scheduledDateTime'] != null)
                  ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: Text(_formatScheduledDateTime(
                        bookingData['scheduledDateTime'])),
                    subtitle: const Text('Scheduled Date & Time'),
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

  String _formatScheduledDateTime(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Bookings History',
          style: TextStyle(
            color: Color(0xFF4E54C8),
            fontWeight: FontWeight.bold,
          ),
        ),
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
              child: CircularProgressIndicator(color: Color(0xFF4E54C8)),
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
                    color: Color(0xFF4E54C8).withOpacity(0.3),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No booking history yet',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'Completed bookings will appear here',
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
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final booking = snapshot.data!.docs[index];
              final bookingData = booking.data() as Map<String, dynamic>;
              bookingData['id'] = booking.id;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Dismissible(
                  key: Key(bookingData['id']),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    decoration: BoxDecoration(
                      color: Colors.red[400],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (direction) async {
                    return await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: const Text('Delete Booking?'),
                        content:
                            const Text('Remove this booking from history?'),
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
                  onDismissed: (direction) =>
                      _deleteBooking(context, bookingData['id']),
                  child: InkWell(
                    onTap: () => _showBookingDetails(context, bookingData),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 25,
                                backgroundColor: const Color(0xFF4E54C8),
                                child: Text(
                                  bookingData['customerName']?.isNotEmpty ==
                                          true
                                      ? bookingData['customerName'][0]
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      bookingData['customerName'] ?? 'Unknown',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      bookingData['serviceType'] ?? '',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _buildStatusBadge(bookingData['status'] ?? ''),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            children: [
                              Icon(Icons.location_on,
                                  size: 20, color: Colors.grey[600]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  bookingData['serviceAddress'] ?? '',
                                  style: TextStyle(color: Colors.grey[600]),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.calendar_today,
                                  size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 8),
                              Text(
                                bookingData['scheduledDateTime'] != null
                                    ? _formatScheduledDateTime(
                                        bookingData['scheduledDateTime'])
                                    : _formatDate(bookingData['bookingDate']
                                        as Timestamp),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
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
            },
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    IconData icon;
    switch (status) {
      case 'Completed':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'Cancelled':
        color = Colors.red;
        icon = Icons.cancel;
        break;
      case 'Confirmed':
        color = Colors.blue;
        icon = Icons.thumb_up;
        break;
      default:
        color = Colors.orange;
        icon = Icons.schedule;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
