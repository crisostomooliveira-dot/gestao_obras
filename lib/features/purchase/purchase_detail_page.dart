import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gestao_obras/features/purchase/widgets/step_2_pricing_widget.dart';
import 'package:gestao_obras/features/purchase/widgets/step_3_payment_widget.dart';
import 'package:flutter/material.dart';

class PurchaseDetailPage extends StatelessWidget {
  final String purchaseRequestId;

  const PurchaseDetailPage({super.key, required this.purchaseRequestId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes da Compra'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            tooltip: 'Excluir Pedido',
            onPressed: () => _showDeleteConfirmationDialog(context),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('purchase_requests').doc(purchaseRequestId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Erro ao carregar dados.'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: Text('Solicitação não encontrada.'));

          final data = snapshot.data!.data() as Map<String, dynamic>;

          final items = data['items'] as List<dynamic>?;
          if (items == null || items.isEmpty) {
            return const Center(child: Text('Esta solicitação não contém itens.'));
          }

          return _buildStepWidget(context, data);
        },
      ),
    );
  }

  Widget _buildStepWidget(BuildContext context, Map<String, dynamic> data) {
    final status = data['status'];

    switch (status) {
      case 'Solicitado':
        return Step2PricingWidget(purchaseRequestId: purchaseRequestId, requestData: data);
      case 'Pedido Criado':
      case 'Finalizado':
        return Step3PaymentWidget(purchaseRequestId: purchaseRequestId, requestData: data);
      default:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Status atual: $status', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ),
        );
    }
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Confirmar Exclusão'),
          content: const Text('Tem certeza de que deseja excluir este pedido de compra? Esta ação não pode ser desfeita.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Excluir'),
              onPressed: () {
                _deletePurchaseRequest(context);
                Navigator.of(ctx).pop(); // Fecha o diálogo
              },
            ),
          ],
        );
      },
    );
  }

  void _deletePurchaseRequest(BuildContext context) async {
    try {
      // O Firestore não deleta subcoleções em cascata, então temos que fazer manualmente.
      // 1. Deletar a subcoleção de cotações
      final quotations = await FirebaseFirestore.instance.collection('purchase_requests').doc(purchaseRequestId).collection('quotations').get();
      for (var doc in quotations.docs) {
        await doc.reference.delete();
      }

      // 2. Deletar o documento principal do pedido
      await FirebaseFirestore.instance.collection('purchase_requests').doc(purchaseRequestId).delete();
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pedido de compra excluído com sucesso!')));
      Navigator.of(context).pop(); // Volta para a tela anterior (lista de compras)
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao excluir pedido: $e')));
    }
  }
}
