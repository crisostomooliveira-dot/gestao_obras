import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:controle_compras/features/purchase/purchase_detail_page.dart';
import 'package:controle_compras/features/purchase/purchase_request_page.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PurchasesTab extends StatelessWidget {
  const PurchasesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('purchase_requests').orderBy('requestDate', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Ocorreu um erro ao carregar as solicitações'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('Nenhuma solicitação de compra encontrada.\nClique no botão + para criar uma.', textAlign: TextAlign.center),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(8.0),
            children: snapshot.data!.docs.map((doc) => _buildRequestCard(context, doc)).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const PurchaseRequestPage())),
        child: const Icon(Icons.add),
        tooltip: 'Nova Solicitação de Compra',
      ),
    );
  }

  Widget _buildRequestCard(BuildContext context, DocumentSnapshot document) {
    final data = document.data()! as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>?) ?? [];
    final status = data['status'] ?? 'N/A';
    final date = (data['requestDate'] as Timestamp?)?.toDate();
    final formattedDate = date != null ? DateFormat('dd/MM/yyyy HH:mm').format(date) : 'Data indisponível';

    String summary = 'Nenhum item na solicitação.';
    if (items.isNotEmpty) {
      summary = '${items.length} itens: ${items.map((i) => i['productDescription']).join(', ')}';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: ListTile(
          title: Text('Status: $status'),
          subtitle: Text('Criada em: $formattedDate\n$summary'),
          isThreeLine: true,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (status == 'Solicitado')
                ElevatedButton.icon(
                  icon: const Icon(Icons.attach_money),
                  label: const Text('Cotar Preços'),
                  onPressed: () => _navigateToDetails(context, document.id),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                tooltip: 'Excluir Solicitação',
                onPressed: () => _showDeleteConfirmationDialog(context, document.id),
              ),
            ],
          ),
          onTap: () => _navigateToDetails(context, document.id),
        ),
      ),
    );
  }

  void _navigateToDetails(BuildContext context, String purchaseRequestId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => PurchaseDetailPage(purchaseRequestId: purchaseRequestId)),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, String purchaseRequestId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: const Text('Tem certeza de que deseja excluir esta solicitação? Esta ação é permanente.'),
        actions: [
          TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(ctx).pop()),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
            onPressed: () {
              _deletePurchaseRequest(context, purchaseRequestId);
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  void _deletePurchaseRequest(BuildContext context, String purchaseRequestId) async {
    try {
      final requestRef = FirebaseFirestore.instance.collection('purchase_requests').doc(purchaseRequestId);
      
      final quotations = await requestRef.collection('quotations').get();
      for (var doc in quotations.docs) {
        await doc.reference.delete();
      }

      await requestRef.delete();
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solicitação excluída com sucesso!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao excluir: $e')));
    }
  }
}
