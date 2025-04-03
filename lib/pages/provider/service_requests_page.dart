import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;

class ServiceRequestsPage extends StatelessWidget {
  const ServiceRequestsPage({super.key});

  // Add phone call functionality
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  // Add map navigation functionality
  Future<void> _openInMaps(String address) async {
    try {
      final encodedAddress = Uri.encodeComponent(address);
      Uri? url;

      if (Platform.isAndroid) {
        // Use Google Maps intent on Android
        url = Uri.parse('google.navigation:q=$encodedAddress');
        if (!await launchUrl(url)) {
          // Fallback to web URL if intent fails
          url = Uri.parse(
              'https://www.google.com/maps/search/?api=1&query=$encodedAddress');
        }
      } else if (Platform.isIOS) {
        // Use Apple Maps on iOS
        url = Uri.parse('maps://?q=$encodedAddress');
        if (!await launchUrl(url)) {
          // Fallback to Google Maps URL
          url = Uri.parse('comgooglemaps://?q=$encodedAddress');
        }
      } else {
        // Web URL for other platforms
        url = Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=$encodedAddress');
      }

      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch maps application';
      }
    } catch (e) {
      debugPrint('Error launching maps: $e');
      throw 'Could not launch maps';
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
                  trailing: IconButton(
                    icon: const Icon(Icons.map, color: Color(0xFF4E54C8)),
                    onPressed: () =>
                        _openInMaps(requestData['serviceAddress'] ?? ''),
                  ),
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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Service Requests',
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
            .collection('requests')
            .orderBy('requestedAt', descending: true)
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
                    Icons.assignment_outlined,
                    size: 120,
                    color: Color(0xFF4E54C8).withOpacity(0.3),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No pending requests',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'New service requests will appear here',
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
              final request = snapshot.data!.docs[index];
              final requestData = request.data() as Map<String, dynamic>;
              requestData['requestId'] = request.id;

              final String customerName =
                  requestData['customerName'] ?? 'Guest';
              final String customerInitial =
                  customerName.isNotEmpty ? customerName[0] : 'G';

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
                  key: Key(requestData['requestId']),
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
                  onDismissed: (direction) =>
                      _deleteRequest(context, requestData['requestId']),
                  child: InkWell(
                    onTap: () => _showCustomerDetails(context, requestData),
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
                                  customerInitial,
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
                                      customerName,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      requestData['customerPhone'] ??
                                          'No phone',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _buildStatusBadge(
                                  requestData['status'] ?? 'Pending'),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildServicesList(requestData['purposes'] as List?),
                          const Divider(height: 24),
                          _buildLocationRow(requestData),
                          if (requestData['status'] == 'Pending Approval')
                            _buildActionButtons(context, requestData),
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
      case 'Approved':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'Declined':
        color = Colors.red;
        icon = Icons.cancel;
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

  Widget _buildServicesList(List? services) {
    if (services == null || services.isEmpty) return const SizedBox();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: services
          .map((service) => Chip(
                label: Text(service.toString()),
                backgroundColor: const Color(0xFF4E54C8).withOpacity(0.1),
                labelStyle: const TextStyle(color: Color(0xFF4E54C8)),
              ))
          .toList(),
    );
  }

  Widget _buildLocationRow(Map<String, dynamic> requestData) {
    return Row(
      children: [
        const Icon(Icons.location_on, size: 20, color: Color(0xFF4E54C8)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            requestData['serviceAddress'] ?? 'No address provided',
            style: TextStyle(color: Colors.grey[600]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.map, color: Color(0xFF4E54C8)),
          onPressed: () => _openInMaps(requestData['serviceAddress'] ?? ''),
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildActionButtons(
      BuildContext context, Map<String, dynamic> requestData) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _handleRequest(
              context,
              requestData['requestId'],
              requestData['customerId'],
              requestData['bookingId'],
              'Approved',
            ),
            icon: const Icon(Icons.check),
            label: const Text('Accept'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _handleRequest(
              context,
              requestData['requestId'],
              requestData['customerId'],
              requestData['bookingId'],
              'Declined',
            ),
            icon: const Icon(Icons.close),
            label: const Text('Decline'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

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
