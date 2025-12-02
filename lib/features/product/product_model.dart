import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class Product {
  final String id;
  final String description;
  final String unit;
  final String usageCategory;

  const Product({
    required this.id,
    required this.description,
    required this.unit,
    required this.usageCategory,
  });

  factory Product.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      description: data['description'] ?? 'N/A',
      unit: data['unit'] ?? 'N/A',
      usageCategory: data['usageCategory'] ?? 'N/A',
    );
  }

  // Estas duas funções ensinam o Flutter a comparar dois produtos.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
