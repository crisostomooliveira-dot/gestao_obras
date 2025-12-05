import 'package:gestao_obras/common/widgets/dashboard_card.dart';
import 'package:gestao_obras/features/home/tabs/purchases_tab.dart';
import 'package:gestao_obras/features/home/tabs/registrations_tab.dart';
import 'package:gestao_obras/features/home/tabs/tracking_tab.dart';
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Controle de Compras'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2, // 2 colunas
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            DashboardCard(
              icon: Icons.app_registration,
              title: 'Cadastros',
              onTap: () => _navigateToPage(context, const RegistrationsTab(), 'Cadastros'),
            ),
            DashboardCard(
              icon: Icons.shopping_cart,
              title: 'Compras',
              onTap: () => _navigateToPage(context, const PurchasesTab(), 'Compras'),
            ),
            DashboardCard(
              icon: Icons.track_changes,
              title: 'Acompanhamento',
              onTap: () => _navigateToPage(context, const TrackingTab(), 'Acompanhamento'),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToPage(BuildContext context, Widget page, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: page,
        ),
      ),
    );
  }
}
