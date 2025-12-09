import 'package:gestao_obras/features/approvals/approvals_page.dart';
import 'package:gestao_obras/features/auth/auth_provider.dart';
import 'package:gestao_obras/features/auth/user_management_page.dart';
import 'package:gestao_obras/features/dashboard/dashboard_page.dart';
import 'package:gestao_obras/features/history/price_history_page.dart';
import 'package:gestao_obras/features/home/tabs/purchases_tab.dart';
import 'package:gestao_obras/features/home/tabs/registrations_tab.dart';
import 'package:gestao_obras/features/home/tabs/tracking_tab.dart';
import 'package:flutter/material.dart';
import 'package:gestao_obras/features/rental/rental_page.dart';
import 'package:provider/provider.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  final Map<String, Map<String, dynamic>> _menuItems = {
    'dashboard': {'widget': const DashboardPage(), 'title': 'Dashboard', 'icon': Icons.dashboard},
    'aprovacoes': {'widget': const ApprovalsPage(), 'title': 'Aprovações', 'icon': Icons.approval}, // Adicionado
    'compras': {'widget': const PurchasesTab(), 'title': 'Compras', 'icon': Icons.shopping_cart},
    'acompanhamento': {'widget': const TrackingTab(), 'title': 'Acompanhamento', 'icon': Icons.track_changes},
    'aluguel': {'widget': const RentalPage(), 'title': 'Aluguel', 'icon': Icons.build_circle},
    'historico': {'widget': const PriceHistoryPage(), 'title': 'Histórico de Preços', 'icon': Icons.history},
    'cadastros': {'widget': const RegistrationsTab(), 'title': 'Cadastros', 'icon': Icons.app_registration},
  };

  List<String> _allowedPages = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateAllowedPages();
  }

  void _updateAllowedPages() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _allowedPages = _menuItems.keys.where((key) => authProvider.hasPermission(key)).toList();
    if (_selectedIndex >= _allowedPages.length) {
      _selectedIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isMaster = authProvider.user?.isMaster ?? false;

    _updateAllowedPages();

    if (_allowedPages.isEmpty && !isMaster) {
      return Scaffold(body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Text('Você não tem permissão para acessar nenhuma área.'), const SizedBox(height: 16), ElevatedButton(onPressed: () => authProvider.logout(), child: const Text('Sair'))])));
    }

    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 250,
            child: Drawer(
              elevation: 1,
              child: Column(
                children: [
                  DrawerHeader(
                    decoration: const BoxDecoration(color: Colors.white),
                    child: Center(
                      child: Image.asset('assets/images/logotipo.png', errorBuilder: (context, error, stackTrace) => const Text('Logotipo não encontrado')),
                    ),
                  ),
                  ..._allowedPages.map((key) {
                    final item = _menuItems[key]!;
                    return _buildNavItem(item['icon'], item['title'], _allowedPages.indexOf(key));
                  }).toList(),
                  const Spacer(),
                  const Divider(),
                  if (isMaster) _buildNavItem(Icons.admin_panel_settings, 'Gerenciar Usuários', -1),
                  _buildNavItem(Icons.exit_to_app, 'Sair', -2, isLogout: true),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          Expanded(
            child: Scaffold(
              appBar: AppBar(title: Text(_allowedPages.isNotEmpty ? _menuItems[_allowedPages[_selectedIndex]]!['title'] : 'Gestão de Obras')), 
              body: _allowedPages.isNotEmpty ? _menuItems[_allowedPages[_selectedIndex]]!['widget'] : const Center(child: Text('Selecione uma opção no menu.')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String title, int index, {bool isLogout = false}) {
    final isSelected = _selectedIndex == index;
    return ListTile(
      leading: Icon(icon, size: 24, color: isLogout ? Colors.red : null),
      title: Text(title, style: TextStyle(color: isLogout ? Colors.red : null)),
      selected: isSelected,
      selectedTileColor: Theme.of(context).primaryColor.withOpacity(0.1),
      onTap: () {
        if (isLogout) {
          Provider.of<AuthProvider>(context, listen: false).logout();
        } else if (index == -1) { 
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UserManagementPage()));
        } else {
          setState(() => _selectedIndex = index);
        }
      },
    );
  }
}
