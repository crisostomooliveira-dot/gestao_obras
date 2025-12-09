import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ApprovalDetailPage extends StatefulWidget {
  final DocumentSnapshot document;

  const ApprovalDetailPage({super.key, required this.document});

  @override
  State<ApprovalDetailPage> createState() => _ApprovalDetailPageState();
}

class _ApprovalDetailPageState extends State<ApprovalDetailPage> {
  Map<String, dynamic> _details = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHumanReadableDetails();
  }

  Future<String> _getDocName(String collection, String? docId) async {
    if (docId == null) return 'Não informado';
    try {
      final doc = await FirebaseFirestore.instance.collection(collection).doc(docId).get();
      return doc.exists ? doc.data()!['name'] ?? 'ID não encontrado' : 'ID não encontrado';
    } catch (e) {
      return 'Erro ao buscar';
    }
  }

  Future<void> _loadHumanReadableDetails() async {
    final data = widget.document.data() as Map<String, dynamic>;
    final isPurchase = widget.document.reference.path.contains('purchase_requests');

    final constructionName = await _getDocName('constructions', data['constructionId']);
    final costCenterName = await _getDocName('cost_centers', data['costCenterId']);

    setState(() {
      _details = {
        'isPurchase': isPurchase,
        'constructionName': constructionName,
        'costCenterName': costCenterName,
        'supplierName': data['supplierName'] ?? data['selectedSupplierName'] ?? 'N/A',
        'totalValue': data['totalValue'] ?? data['totalPrice'] ?? 0.0,
        'items': data['finalItems'] ?? data['items'] ?? [],
      };
      _isLoading = false;
    });
  }

  Future<void> _updateApprovalStatus(String status, {String? observation}) async {
    try {
      final updateData = {
        'approvalStatus': status,
        'approvalDate': Timestamp.now(),
        'approverId': 'SYSTEM', // Futuramente, pegar do AuthProvider
      };

      if (observation != null) {
        updateData['observation'] = observation;
      }

      await widget.document.reference.update(updateData);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pedido ${status.toLowerCase()} com sucesso!'))
      );
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao atualizar status: $e')));
    }
  }

  void _showRejectionDialog() {
    final observationController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rejeitar Pedido'),
        content: TextFormField(
          controller: observationController,
          decoration: const InputDecoration(labelText: 'Motivo da Rejeição (obrigatório)'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (observationController.text.trim().isNotEmpty) {
                Navigator.of(ctx).pop();
                _updateApprovalStatus('Rejeitado', observation: observationController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirmar Rejeição'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes para Aprovação')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildDetailCard(
                  title: 'Detalhes do Pedido',
                  details: {
                    'Tipo': _details['isPurchase'] ? 'Compra' : 'Aluguel',
                    'Obra': _details['constructionName'] ?? '-',
                    'Centro de Custo': _details['costCenterName'] ?? '-',
                    'Fornecedor(es)': _details['supplierName'] ?? '-',
                  },
                ),
                const SizedBox(height: 16),
                _buildItemsCard(_details['items'] ?? []),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'VALOR TOTAL: ${NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(_details['totalValue'])}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _isLoading ? null : _buildActionButtons(),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          ElevatedButton.icon(
            onPressed: () => _updateApprovalStatus('Devolvido'),
            icon: const Icon(Icons.undo),
            label: const Text('Devolver para Correção'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          ),
          ElevatedButton.icon(
            onPressed: _showRejectionDialog,
            icon: const Icon(Icons.close),
            label: const Text('Rejeitar'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
          ElevatedButton.icon(
            onPressed: () => _updateApprovalStatus('Aprovado'),
            icon: const Icon(Icons.check),
            label: const Text('Aprovar'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard({required String title, required Map<String, String> details}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const Divider(height: 20),
            ...details.entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Text('${entry.key}: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(child: Text(entry.value)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsCard(List items) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Itens do Pedido', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Item')),
                  DataColumn(label: Text('Qtd')),
                  DataColumn(label: Text('Valor Unit.')),
                ],
                rows: items.map((item) {
                  final data = item as Map<String, dynamic>;
                  return DataRow(cells: [
                    DataCell(Text(data['productDescription'] ?? '-')),
                    DataCell(Text(data['quantity']?.toString() ?? '-')),
                    DataCell(Text(NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(data['unitPrice'] ?? 0.0))),
                  ]);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
