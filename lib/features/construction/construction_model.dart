import 'package:cloud_firestore/cloud_firestore.dart';

class Construction {
  final String id;
  final String name;
  final String? city;
  final String? state;
  final String? status;

  Construction({
    required this.id,
    required this.name,
    this.city,
    this.state,
    this.status,
  });

  factory Construction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Construction(
      id: doc.id,
      name: data['name'] ?? 'N/A',
      city: data['city'] ?? '',
      state: data['state'] ?? '',
      status: data['status'] ?? 'N/A',
    );
  }
}
