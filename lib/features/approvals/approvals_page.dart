import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:gestao_obras/features/approvals/approval_detail_page.dart';
import 'package:gestao_obras/features/home/tabs/tracking_tab.dart';

class ApprovalsPage extends StatelessWidget {
  const ApprovalsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<DocumentSnapshot>>(
        stream: _getPendingApprovals(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Erro: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('Nenhum item aguardando aprovação.'));

          final items = snapshot.data!;

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final doc = items[index];
              final data = doc.data() as Map<String, dynamic>;
              final isPurchase = doc.reference.path.contains('purchase_requests');
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text('${isPurchase ? 'Compra' : 'Aluguel'}: ${data['supplierName'] ?? data['selectedSupplierName'] ?? 'N/A'}'),
                  subtitle: Text('Obra: ${data['constructionName'] ?? '-'}\nValor: ${data['totalValue'] ?? data['totalPrice'] ?? 0.0}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ApprovalDetailPage(document: doc)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Stream<List<DocumentSnapshot>> _getPendingApprovals() {
    final purchasesStream = FirebaseFirestore.instance
        .collection('purchase_requests')
        .where('approvalStatus', isEqualTo: 'Aguardando Aprovação')
        .snapshots();

    final rentalsStream = FirebaseFirestore.instance
        .collection('rental_invoices')
        .where('approvalStatus', isEqualTo: 'Aguardando Aprovação')
        .snapshots();

    return ZippedStream([purchasesStream, rentalsStream], (snapshots) {
      final allDocs = [...(snapshots[0] as QuerySnapshot).docs, ...(snapshots[1] as QuerySnapshot).docs];
      allDocs.sort((a, b) {
        final aDate = (a.data() as Map<String, dynamic>)['requestDate'] ?? (a.data() as Map<String, dynamic>)['createdAt'];
        final bDate = (b.data() as Map<String, dynamic>)['requestDate'] ?? (b.data() as Map<String, dynamic>)['createdAt'];
        return (bDate as Timestamp?)?.compareTo(aDate as Timestamp? ?? Timestamp(0,0)) ?? -1;
      });
      return allDocs;
    }).asBroadcastStream();
  }
}
