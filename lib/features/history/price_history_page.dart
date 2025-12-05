import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PriceHistoryPage extends StatefulWidget {
  const PriceHistoryPage({super.key});

  @override
  State<PriceHistoryPage> createState() => _PriceHistoryPageState();
}

class _PriceHistoryPageState extends State<PriceHistoryPage> {
  Map<String, Map<String, dynamic>> _constructionData = {};
  Map<String, String?> _requestToConstructionMap = {};
  List<String> _allProducts = [];
  String _currentSearchTerm = '';

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    final constructionsFuture = FirebaseFirestore.instance.collection('constructions').get();
    final productsFuture = FirebaseFirestore.instance.collection('products').get();
    final requestsFuture = FirebaseFirestore.instance.collection('purchase_requests').get();
    final results = await Future.wait([constructionsFuture, productsFuture, requestsFuture]);

    final constructionData = { for (var doc in (results[0] as QuerySnapshot).docs) doc.id : doc.data() as Map<String, dynamic> };
    final productNames = (results[1] as QuerySnapshot).docs.map((doc) => (doc.data() as Map<String, dynamic>)['description'] as String).toList();
    final requestToConstructionMap = { for (var doc in (results[2] as QuerySnapshot).docs) doc.id : (doc.data() as Map<String, dynamic>)['constructionId'] as String? };

    if (mounted) {
      setState(() {
        _constructionData = constructionData;
        _allProducts = productNames;
        _requestToConstructionMap = requestToConstructionMap;
      });
    }
  }

  void _onSearchChanged(String searchTerm) {
    setState(() {
      _currentSearchTerm = searchTerm.toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.length < 3) return const Iterable<String>.empty();
                return _allProducts.where((option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
              },
              onSelected: (selection) => _onSearchChanged(selection),
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: (value) => _onSearchChanged(value),
                  decoration: const InputDecoration(labelText: 'Buscar por descrição do produto', suffixIcon: Icon(Icons.search)),
                );
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _currentSearchTerm.length < 3
                  ? const Center(child: Text('Digite 3 ou mais letras para buscar.'))
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collectionGroup('quotations').snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) return const Text('Ocorreu um erro na busca.');
                        if (snapshot.connectionState == ConnectionState.waiting) return const CircularProgressIndicator();
                        
                        final allItems = _extractAndFilterItems(snapshot.data?.docs ?? []);

                        if (allItems.isEmpty) return const Center(child: Text('Nenhum histórico encontrado para este produto.'));
                        
                        return ListView.builder(
                          itemCount: allItems.length,
                          itemBuilder: (context, index) => _buildHistoryCard(allItems[index]),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _extractAndFilterItems(List<QueryDocumentSnapshot> quotationDocs) {
    List<Map<String, dynamic>> filteredItems = [];
    for (var doc in quotationDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>?) ?? [];
      
      final purchaseRequestId = doc.reference.parent.parent?.id;
      final constructionId = purchaseRequestId != null ? _requestToConstructionMap[purchaseRequestId] : null;

      for (var item in items) {
        if ((item['productDescription'] as String).toLowerCase().contains(_currentSearchTerm)) {
          filteredItems.add({
            ...item,
            'orderDate': (data['addedAt'] as Timestamp?)?.toDate(),
            'constructionId': constructionId,
            'supplierName': data['supplierName'],
          });
        }
      }
    }
    filteredItems.sort((a, b) => (b['orderDate'] as DateTime).compareTo(a['orderDate'] as DateTime));
    return filteredItems;
  }

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    final date = item['orderDate'] as DateTime?;
    final formattedDate = date != null ? DateFormat('dd/MM/yyyy').format(date) : '-';
    final supplierName = item['supplierName'] ?? '-';
    final unitPrice = (item['unitPrice'] as num?)?.toDouble() ?? 0.0;
    
    final constructionInfo = _constructionData[item['constructionId']];
    final constructionName = constructionInfo?['name'] ?? 'Obra não encontrada';
    final constructionLocation = '${constructionInfo?['city'] ?? ''} - ${constructionInfo?['state'] ?? ''}';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(item['productDescription']),
        subtitle: Text('Fornecedor: $supplierName | Data: $formattedDate\nObra: $constructionName ($constructionLocation)'),
        isThreeLine: true,
        trailing: Text(NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(unitPrice), style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
