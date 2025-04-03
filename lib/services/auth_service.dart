import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Get user role from Firestore
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      print('User role: ${userDoc.get('role')}');
      return userCredential;
    } catch (e) {
      print('Sign in error: $e');
      return null;
    }
  }

  // Sign up with email and password
  Future<UserCredential?> signUpWithEmailAndPassword(
      String email, String password, String name, String role,
      {String? businessName,
      List<String>? selectedServices,
      required String mobileNumber,
      String? location}) async {
    // Add location parameter
    try {
      // Create user with email and password
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Store basic user info in users collection
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'name': name,
        'email': email,
        'role': role,
        'mobileNumber': mobileNumber,
        'createdAt': Timestamp.now(),
      });

      // Store role-specific data in separate collections
      if (role == 'Customer') {
        await _firestore
            .collection('customers')
            .doc(userCredential.user!.uid)
            .set({
          'name': name,
          'email': email,
          'mobileNumber': mobileNumber,
          'createdAt': Timestamp.now(),
          'bookings': [], // Array to store service bookings
          'favorites': [], // Array to store favorite service providers
        });
      } else if (role == 'Service Provider') {
        await _firestore
            .collection('serviceProviders')
            .doc(userCredential.user!.uid)
            .set({
          'name': name,
          'email': email,
          'mobileNumber': mobileNumber,
          'businessName': businessName,
          'services': selectedServices ?? [], // Store selected services
          'createdAt': Timestamp.now(),
          'rating': 0.0,
          'totalRatings': 0,
          'isVerified': true, // Change this to true
          'profileComplete': true,
          'availability': {
            'monday': true,
            'tuesday': true,
            'wednesday': true,
            'thursday': true,
            'friday': true,
            'saturday': true,
            'sunday': false,
          },
          'location': location ?? '', // Add location field
          'description': '',
          'experience': '',
          'profileImage': '',
          'reviews': [],
        });
      }

      return userCredential;
    } catch (e) {
      print('Sign up error: $e');
      return null;
    }
  }

  // Get current user role
  Future<String?> getCurrentUserRole() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        return userDoc.get('role') as String?;
      }
      return null;
    } catch (e) {
      print('Error getting user role: $e');
      return null;
    }
  }

  // Get user profile data
  Future<Map<String, dynamic>?> getUserData() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        String? role = await getCurrentUserRole();
        if (role == 'Customer') {
          DocumentSnapshot customerDoc =
              await _firestore.collection('customers').doc(user.uid).get();
          return customerDoc.data() as Map<String, dynamic>?;
        } else if (role == 'Service Provider') {
          DocumentSnapshot providerDoc = await _firestore
              .collection('serviceProviders')
              .doc(user.uid)
              .get();
          return providerDoc.data() as Map<String, dynamic>?;
        }
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  // Add these new methods
  Future<void> updateCustomerProfile(
      String userId, Map<String, dynamic> data) async {
    try {
      // First update customer collection
      final docRef = _firestore.collection('customers').doc(userId);
      final userDoc = await docRef.get();

      if (!userDoc.exists) {
        await docRef.set(data);
      } else {
        await docRef.update(data);
      }

      // Update users collection
      final userRef = _firestore.collection('users').doc(userId);
      final existingUserDoc = await userRef.get();

      if (!existingUserDoc.exists) {
        await userRef.set({
          ...data,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      } else {
        final Map<String, dynamic> userUpdates = {};
        if (data['name'] != null) userUpdates['name'] = data['name'];
        if (data['mobileNumber'] != null)
          userUpdates['mobileNumber'] = data['mobileNumber'];
        userUpdates['lastUpdated'] = FieldValue.serverTimestamp();

        await userRef.update(userUpdates);
      }

      // Update customer details in all service provider requests
      final requestsQuery =
          await _firestore.collection('serviceProviders').get();

      for (var providerDoc in requestsQuery.docs) {
        final requestsSnapshot = await providerDoc.reference
            .collection('requests')
            .where('customerId', isEqualTo: userId)
            .get();

        for (var requestDoc in requestsSnapshot.docs) {
          final updates = <String, dynamic>{};
          if (data['name'] != null) updates['customerName'] = data['name'];
          if (data['mobileNumber'] != null)
            updates['customerPhone'] = data['mobileNumber'];

          if (updates.isNotEmpty) {
            await requestDoc.reference.update(updates);
          }
        }
      }
    } catch (e) {
      print('Error updating customer profile: $e');
      throw e;
    }
  }

  Future<void> updateProviderProfile(
      String userId, Map<String, dynamic> data) async {
    try {
      // Update service provider collection
      await _firestore.collection('serviceProviders').doc(userId).update(data);

      // Update users collection
      final Map<String, dynamic> userUpdates = {};
      if (data['name'] != null) userUpdates['name'] = data['name'];
      if (data['mobileNumber'] != null)
        userUpdates['mobileNumber'] = data['mobileNumber'];
      userUpdates['lastUpdated'] = FieldValue.serverTimestamp();

      await _firestore.collection('users').doc(userId).update(userUpdates);

      // Update provider details in all customer bookings
      final customersQuery = await _firestore.collection('customers').get();

      for (var customerDoc in customersQuery.docs) {
        final bookingsQuery = await customerDoc.reference
            .collection('bookings')
            .where('providerId', isEqualTo: userId)
            .get();

        for (var bookingDoc in bookingsQuery.docs) {
          final updates = <String, dynamic>{};
          if (data['name'] != null)
            updates['providerName'] = data['businessName'] ?? data['name'];
          if (data['mobileNumber'] != null)
            updates['providerPhone'] = data['mobileNumber'];
          if (data['businessName'] != null)
            updates['providerName'] = data['businessName'];
          if (data['services'] != null)
            updates['serviceType'] = (data['services'] as List).join(', ');

          if (updates.isNotEmpty) {
            await bookingDoc.reference.update(updates);
          }
        }
      }
    } catch (e) {
      print('Error updating provider profile: $e');
      throw e;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
