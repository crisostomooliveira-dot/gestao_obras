class RequestItem {
  final String productId;
  final String productDescription;
  final num quantity;
  final String unit;

  RequestItem({
    required this.productId,
    required this.productDescription,
    required this.quantity,
    required this.unit,
  });

  // Converte o item para um mapa, para ser salvo no Firestore
  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productDescription': productDescription,
      'quantity': quantity,
      'unit': unit,
    };
  }
}
