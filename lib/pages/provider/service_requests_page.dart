import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class ServiceRequestsPage extends StatelessWidget {
  const ServiceRequestsPage({super.key});

  // Add phone call functionality
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  // Add method to show customer details
  void _showCustomerDetails(
      BuildContext context, Map<String, dynamic> requestData) {
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
                const Text(
                  'Customer Details',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(requestData['customerName'] ?? ''),
                  subtitle: const Text('Customer Name'),
                ),
                ListTile(
                  leading: const Icon(Icons.phone),
                  title: Text(requestData['customerPhone'] ?? ''),
                  subtitle: const Text('Phone Number'),
                  trailing: IconButton(
                    icon: const Icon(Icons.call, color: Colors.green),
                    onPressed: () =>
                        _makePhoneCall(requestData['customerPhone']),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.email),
                  title: Text(requestData['customerEmail'] ?? ''),
                  subtitle: const Text('Email'),
                ),
                ListTile(
                  leading: const Icon(Icons.location_on),
                  title: Text(requestData['serviceAddress'] ?? ''),
                  subtitle: const Text('Service Address'),
                ),
                const Divider(),
                const Text(
                  'Requested Services:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: (requestData['purposes'] as List<dynamic>)
                      .map((service) => Chip(label: Text(service.toString())))
                      .toList(),
                ),
                const SizedBox(height: 16),
                if (requestData['status'] == 'Pending Approval')
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => _handleRequest(
                            context,
                            requestData['requestId'],
                            requestData['customerId'],
                            requestData['bookingId'],
                            'Approved',
                          ),
                          child: const Text('Accept Request'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => _handleRequest(
                            context,
                            requestData['requestId'],
                            requestData['customerId'],
                            requestData['bookingId'],
                            'Declined',
                          ),
                          child: const Text('Decline Request'),
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

  Future<void> _handleRequest(BuildContext context, String requestId,
      String customerId, String bookingId, String status) async {
    try {
      // Get the full request details first
      final requestDoc = await FirebaseFirestore.instance
          .collection('serviceProviders')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .collection('requests')
          .doc(requestId)
          .get();

      final requestData = requestDoc.data()!;

      // Update request status in provider's collection
      await requestDoc.reference.update({
        'status': status,
        'updatedAt': Timestamp.now(),
      });

      // Update customer's booking status
      final customerBookingRef = FirebaseFirestore.instance
          .collection('customers')
          .doc(customerId)
          .collection('bookings')
          .doc(bookingId);

      // Update the status based on provider's action
      String bookingStatus = status == 'Approved' ? 'Confirmed' : 'Declined';
      await customerBookingRef.update({
        'status': bookingStatus,
        'lastUpdated': Timestamp.now(),
      });

      // Create a booking record in provider's bookings collection if approved
      if (status == 'Approved') {
        final customerBooking = await customerBookingRef.get();
        if (customerBooking.exists) {
          final bookingData = customerBooking.data()!;
          await FirebaseFirestore.instance
              .collection('serviceProviders')
              .doc(FirebaseAuth.instance.currentUser?.uid)
              .collection('bookings')
              .doc(bookingId)
              .set({
            ...bookingData,
            'customerName': requestData['customerName'],
            'customerPhone': requestData['customerPhone'],
            'customerEmail': requestData['customerEmail'],
            'status': 'Confirmed',
            'confirmedAt': Timestamp.now(),
            'serviceAddress': requestData['serviceAddress'],
            'purposes': requestData['purposes'],
          });
        }
      }

      if (!context.mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request ${status.toLowerCase()} successfully'),
          backgroundColor: status == 'Approved' ? Colors.green : Colors.red,
        ),
      );

      // Pop the bottom sheet if it's showing
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteRequest(BuildContext context, String requestId) async {
    try {
      // Simply delete the request from provider's collection
      await FirebaseFirestore.instance
          .collection('serviceProviders')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .collection('requests')
          .doc(requestId)
          .delete();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request removed successfully'),
          backgroundColor: Colors.grey,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing request: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Requests'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('serviceProviders')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .collection('requests')
            .orderBy('requestedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No pending requests'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final request = snapshot.data!.docs[index];
              final requestData = request.data() as Map<String, dynamic>;
              // Add requestId to the data for update operations
              requestData['requestId'] = request.id;

              // Get first letter safely
              final String customerName =
                  requestData['customerName'] ?? 'Guest';
              final String customerInitial =
                  customerName.isNotEmpty ? customerName[0] : 'G';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Dismissible(
                  // Wrap ListTile with Dismissible
                  key: Key(requestData['requestId']),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20.0),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (direction) {
                    _deleteRequest(context, requestData['requestId']);
                  },
                  confirmDismiss: (direction) async {
                    return await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Request?'),
                        content: const Text(
                            'Are you sure you want to remove this request?'),
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
                  child: ListTile(
                    onTap: () => _showCustomerDetails(context, requestData),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF4E54C8),
                      child: Text(customerInitial),
                    ),
                    title: Text(customerName),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'Services: ${(requestData['purposes'] as List?)?.join(", ") ?? "No services specified"}'),
                        Text('Status: ${requestData['status'] ?? "Pending"}'),
                        Text(
                            'Location: ${requestData['serviceAddress'] ?? "No address provided"}'),
                        if (requestData['requestedAt'] != null)
                          Text(
                              'Requested: ${_formatDate(requestData['requestedAt'] as Timestamp)}'),
                      ],
                    ),
                    trailing: requestData['status'] == 'Pending Approval'
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check_circle,
                                    color: Colors.green),
                                onPressed: () => _handleRequest(
                                  context,
                                  requestData['requestId'],
                                  requestData['customerId'],
                                  requestData['bookingId'],
                                  'Approved',
                                ),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.cancel, color: Colors.red),
                                onPressed: () => _handleRequest(
                                  context,
                                  requestData['requestId'],
                                  requestData['customerId'],
                                  requestData['bookingId'],
                                  'Declined',
                                ),
                              ),
                            ],
                          )
                        : requestData['status'] == 'Approved'
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.check_circle,
                                            color: Colors.green, size: 16),
                                        SizedBox(width: 4),
                                        Text('Approved',
                                            style:
                                                TextStyle(color: Colors.green)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.cancel,
                                        color: Colors.red),
                                    onPressed: () => _showDeclineConfirmation(
                                      context,
                                      requestData['requestId'],
                                      requestData['customerId'],
                                      requestData['bookingId'],
                                    ),
                                  ),
                                ],
                              )
                            : Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text('Declined',
                                    style: TextStyle(color: Colors.red)),
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

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  // Add this method to show decline confirmation dialog
  Future<void> _showDeclineConfirmation(
    BuildContext context,
    String requestId,
    String customerId,
    String bookingId,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decline Request?'),
        content: const Text('Are you sure you want to decline this request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Decline'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _handleRequest(
          context, requestId, customerId, bookingId, 'Declined');
    }
  }
}
