import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:controle_compras/features/product/product_model.dart';
import 'package:controle_compras/features/purchase/purchase_detail_page.dart';
import 'package:controle_compras/features/purchase/request_item_model.dart';
import 'package:flutter/material.dart';

class PurchaseRequestPage extends StatefulWidget {
  const PurchaseRequestPage({super.key});

  @override
  State<PurchaseRequestPage> createState() => _PurchaseRequestPageState();
}

class _PurchaseRequestPageState extends State<PurchaseRequestPage> {
  // -- State for the entire request --
  final _headerFormKey = GlobalKey<FormState>();
  String? _selectedConstructionId;
  String? _selectedCostCenterId;

  // -- State for adding a single item --
  final _itemFormKey = GlobalKey<FormState>();
  Product? _selectedProduct;
  final _quantityController = TextEditingController();
  
  // -- List of items in the current request --
  final List<RequestItem> _requestItems = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova Solicitação de Compra'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 1. Cabeçalho da Solicitação (Obra e Centro de Custo)
            _buildRequestHeader(),
            const Divider(height: 30),

            // 2. Formulário para Adicionar Itens
            _buildAddItemForm(),
            const Divider(height: 30),

            // 3. Tabela de Itens Adicionados
            const Text('Itens da Solicitação', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildItemsTable(),
            
            const Spacer(),
            // 4. Botão para Salvar e Continuar
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestHeader() {
    return Form(
      key: _headerFormKey,
      child: Row(
        children: [
          Expanded(child: _buildDropdown('constructions', 'Obra', (val) => setState(() => _selectedConstructionId = val))),
          const SizedBox(width: 16),
          Expanded(child: _buildDropdown('cost_centers', 'Centro de Custo', (val) => setState(() => _selectedCostCenterId = val))),
        ],
      ),
    );
  }

  Widget _buildAddItemForm() {
    return Form(
      key: _itemFormKey,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            flex: 3,
            child: _buildProductDropdown(),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 1,
            child: TextFormField(
              controller: _quantityController,
              decoration: const InputDecoration(labelText: 'Quantidade'),
              keyboardType: TextInputType.number,
              validator: (v) => (v == null || v.isEmpty) ? 'Req.' : null,
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: _addItem,
            icon: const Icon(Icons.add),
            label: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsTable() {
    return Expanded(
      child: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Produto')),
            DataColumn(label: Text('Qtd')),
            DataColumn(label: Text('Unidade')),
            DataColumn(label: Text('Ação')),
          ],
          rows: _requestItems.map((item) {
            return DataRow(
              cells: [
                DataCell(Text(item.productDescription)),
                DataCell(Text(item.quantity.toString())),
                DataCell(Text(item.unit)),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                    onPressed: () => setState(() => _requestItems.remove(item)),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

   Widget _buildProductDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('products').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final products = snapshot.data!.docs.map((doc) => Product.fromFirestore(doc)).toList();

        return DropdownButtonFormField<Product>(
          decoration: const InputDecoration(labelText: 'Produto'),
          items: products.map((product) {
            return DropdownMenuItem<Product>(
              value: product,
              child: Text(product.description),
            );
          }).toList(),
          onChanged: (value) => setState(() => _selectedProduct = value),
          validator: (value) => value == null ? 'Selecione' : null,
        );
      },
    );
  }

  Widget _buildDropdown(String collection, String label, ValueChanged<String?> onChanged) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(collection).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var items = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return DropdownMenuItem(value: doc.id, child: Text(data['name'] ?? 'N/A'));
        }).toList();
        return DropdownButtonFormField<String>(
          decoration: InputDecoration(labelText: label),
          items: items,
          onChanged: onChanged,
          validator: (v) => v == null ? 'Selecione' : null,
        );
      },
    );
  }

  void _addItem() {
    if (_itemFormKey.currentState!.validate() && _selectedProduct != null) {
      final quantity = num.tryParse(_quantityController.text);
      if (quantity == null) return;

      final newItem = RequestItem(
        productId: _selectedProduct!.id,
        productDescription: _selectedProduct!.description,
        quantity: quantity,
        unit: _selectedProduct!.unit,
      );

      setState(() {
        _requestItems.add(newItem);
      });

      // Reset form
      _itemFormKey.currentState!.reset();
      _quantityController.clear();
      setState(() => _selectedProduct = null);
    }
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _requestItems.isEmpty ? null : _saveRequest,
        child: const Text('Salvar e Ir para Cotação'),
        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
      ),
    );
  }

  void _saveRequest() async {
    if (!_headerFormKey.currentState!.validate()) return;

    final itemsAsMaps = _requestItems.map((item) => item.toMap()).toList();

    final newRequest = await FirebaseFirestore.instance.collection('purchase_requests').add({
      'constructionId': _selectedConstructionId,
      'costCenterId': _selectedCostCenterId,
      'items': itemsAsMaps, // Salva a lista de itens
      'requestDate': Timestamp.now(),
      'status': 'Solicitado',
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Solicitação criada! Redirecionando para cotação...')),
    );

    // Navega para a próxima etapa
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => PurchaseDetailPage(purchaseRequestId: newRequest.id),
      ),
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }
}
