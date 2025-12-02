import 'package:flutter/material.dart';

class StateDropdown extends StatelessWidget {
  final String? selectedState;
  final ValueChanged<String?> onChanged;

  const StateDropdown({super.key, required this.selectedState, required this.onChanged});

  static const List<String> _brazilianStates = [
    'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MT', 'MS', 'MG', 'PA', 'PB', 'PR', 'PE', 'PI', 'RJ', 'RN', 'RS', 'RO', 'RR', 'SC', 'SP', 'SE', 'TO'
  ];

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(labelText: 'UF'),
      value: selectedState,
      items: _brazilianStates.map((state) => DropdownMenuItem(value: state, child: Text(state))).toList(),
      onChanged: onChanged,
    );
  }
}
