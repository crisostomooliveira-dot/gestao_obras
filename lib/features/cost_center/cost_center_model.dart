import 'package:cloud_firestore/cloud_firestore.dart';

class CostCenter {
  final String id;
  final String name;
  final String? category;

  CostCenter({
    required this.id,
    required this.name,
    this.category,
  });

  factory CostCenter.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CostCenter(
      id: doc.id,
      name: data['name'] ?? 'N/A',
      category: data['category'] ?? 'N/A',
    );
  }
}
