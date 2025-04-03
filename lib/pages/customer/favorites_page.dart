import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('customers')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          List<dynamic> favorites = snapshot.data?['favorites'] ?? [];

          if (favorites.isEmpty) {
            return const Center(child: Text('No favorites yet'));
          }

          return ListView.builder(
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('serviceProviders')
                    .doc(favorites[index])
                    .get(),
                builder: (context, providerSnapshot) {
                  if (!providerSnapshot.hasData) {
                    return const SizedBox();
                  }

                  var provider = providerSnapshot.data!;
                  return FavoriteCard(
                    providerId: provider.id,
                    name: provider['name'],
                    businessName: provider['businessName'],
                    serviceType: provider['serviceType'],
                    rating: provider['rating'].toDouble(),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class FavoriteCard extends StatelessWidget {
  final String providerId;
  final String name;
  final String businessName;
  final String serviceType;
  final double rating;

  const FavoriteCard({
    super.key,
    required this.providerId,
    required this.name,
    required this.businessName,
    required this.serviceType,
    required this.rating,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF4E54C8),
          child: Text(name[0]),
        ),
        title: Text(businessName),
        subtitle: Text(serviceType),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star, color: Colors.amber),
            Text(rating.toStringAsFixed(1)),
            IconButton(
              icon: const Icon(Icons.favorite, color: Colors.red),
              onPressed: () {
                // TODO: Implement remove from favorites
              },
            ),
          ],
        ),
        onTap: () {
          // TODO: Navigate to provider details
        },
      ),
    );
  }
}
