import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Step2PricingWidget extends StatefulWidget {
  final String purchaseRequestId;
  final Map<String, dynamic> requestData;

  const Step2PricingWidget({super.key, required this.purchaseRequestId, required this.requestData});

  @override
  State<Step2PricingWidget> createState() => _Step2PricingWidgetState();
}

class _Step2PricingWidgetState extends State<Step2PricingWidget> {
  String? _selectedSupplierId;
  late Map<String, TextEditingController> _priceControllers;

  @override
  void initState() {
    super.initState();
    final items = widget.requestData['items'] as List;
    _priceControllers = { for (var item in items) item['productId'] as String : TextEditingController() };
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const Text('Etapa 2: Cotação de Preços', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildItemsList(),
        const Divider(height: 30),
        _buildAddQuotationForm(),
        const Divider(height: 30),
        const Text('Cotações Adicionadas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        _buildQuotationsList(),
      ],
    );
  }

   Widget _buildItemsList() {
    final items = widget.requestData['items'] as List;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Itens da Solicitação:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ...items.map((item) => ListTile(
          title: Text(item['productDescription']),
          trailing: Text('Qtd: ${item['quantity']} ${item['unit']}'),
        )).toList(),
      ],
    );
  }

  Widget _buildAddQuotationForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('suppliers').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const CircularProgressIndicator();
            return DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Selecione um Fornecedor para Cotar'),
              items: snapshot.data!.docs.map((doc) => DropdownMenuItem(value: doc.id, child: Text(doc['name']))).toList(),
              onChanged: (value) => setState(() => _selectedSupplierId = value),
            );
          },
        ),
        if (_selectedSupplierId != null) ..._buildPriceFields(),
        if (_selectedSupplierId != null)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: ElevatedButton.icon(
              onPressed: _addQuotation,
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Salvar Cotação do Fornecedor'),
            ),
          ),
      ],
    );
  }
  
  List<Widget> _buildPriceFields() {
    return (widget.requestData['items'] as List).map((item) {
      final productId = item['productId'] as String;
      return Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: TextFormField(
          controller: _priceControllers[productId],
          decoration: InputDecoration(labelText: 'Preço Unitário - ${item['productDescription']}'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
      );
    }).toList();
  }

  Widget _buildQuotationsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('purchase_requests').doc(widget.purchaseRequestId).collection('quotations').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Text('Erro ao carregar cotações.');
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('Nenhuma cotação adicionada.')));

        final quotations = snapshot.data!.docs;
        DocumentSnapshot? bestQuotation;

        if (quotations.isNotEmpty) {
          bestQuotation = quotations.reduce((a, b) => (a['totalPrice'] < b['totalPrice']) ? a : b);
        }

        return Column(
          children: [
            ...quotations.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final isBest = doc.id == bestQuotation?.id;
              return Card(
                color: isBest ? Colors.green[100] : null,
                child: ListTile(
                  leading: isBest ? const Icon(Icons.star, color: Colors.green) : null,
                  title: Text(data['supplierName'] ?? 'N/A'),
                  subtitle: Text('Total: R\$ ${(data['totalPrice'] as num).toStringAsFixed(2)}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Excluir Cotação',
                    onPressed: () => _deleteQuotation(doc.id),
                  ),
                ),
              );
            }).toList(),

            if (bestQuotation != null)
              Padding(
                padding: const EdgeInsets.only(top: 24.0),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Criar Pedido com a Melhor Opção'),
                  onPressed: () => _createPurchaseOrder(bestQuotation!),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                ),
              ),
          ],
        );
      },
    );
  }

  void _addQuotation() async {
    if (_selectedSupplierId == null) return;

    final supplierDoc = await FirebaseFirestore.instance.collection('suppliers').doc(_selectedSupplierId).get();
    final supplierName = supplierDoc.data()?['name'] ?? 'N/A';
    
    final items = widget.requestData['items'] as List;
    List<Map<String, dynamic>> pricedItems = [];
    num totalQuotePrice = 0;

    for (var item in items) {
      final productId = item['productId'] as String;
      final priceText = _priceControllers[productId]!.text.replaceAll(',', '.');
      final unitPrice = double.tryParse(priceText) ?? 0.0;
      
      if (unitPrice <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Preencha um preço válido para ${item['productDescription']}!')));
          return;
      }
      final quantity = item['quantity'] as num;
      totalQuotePrice += unitPrice * quantity;
      
      pricedItems.add({ ...item, 'unitPrice': unitPrice });
    }

    await FirebaseFirestore.instance
      .collection('purchase_requests').doc(widget.purchaseRequestId)
      .collection('quotations').doc(_selectedSupplierId)
      .set({
        'supplierId': _selectedSupplierId,
        'supplierName': supplierName,
        'totalPrice': totalQuotePrice,
        'items': pricedItems,
        'addedAt': Timestamp.now(),
      });

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cotação salva!')));
  }

  void _deleteQuotation(String quotationId) {
    FirebaseFirestore.instance
      .collection('purchase_requests').doc(widget.purchaseRequestId)
      .collection('quotations').doc(quotationId)
      .delete();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cotação excluída!')));
  }

  void _createPurchaseOrder(DocumentSnapshot bestQuotationDoc) {
    final bestQuotationData = bestQuotationDoc.data() as Map<String, dynamic>;

    FirebaseFirestore.instance.collection('purchase_requests').doc(widget.purchaseRequestId).update({
      'status': 'Pedido Criado',
      'selectedSupplierId': bestQuotationData['supplierId'],
      'selectedSupplierName': bestQuotationData['supplierName'],
      'totalPrice': bestQuotationData['totalPrice'],
      'finalItems': bestQuotationData['items'],
      'orderCreationDate': Timestamp.now(),
    });

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pedido de compra criado com sucesso!')));
  }

  @override
  void dispose() {
    _priceControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }
}
