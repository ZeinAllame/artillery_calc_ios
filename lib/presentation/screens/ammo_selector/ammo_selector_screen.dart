import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart'; // تأكد من مسار الثيم

class AmmoSelectorScreen extends StatefulWidget {
  const AmmoSelectorScreen({Key? key}) : super(key: key);

  @override
  State<AmmoSelectorScreen> createState() => _AmmoSelectorScreenState();
}

class _AmmoSelectorScreenState extends State<AmmoSelectorScreen> {
  String? selectedWeapon;
  String? selectedAmmo;
  String? selectedLot;

  final List<Map<String, String>> weapons = [
    {'id': 'm109a6', 'name': 'M109A6 Paladin 155mm'},
    {'id': 'm252', 'name': 'M252 81mm Mortar'},
    {'id': 'd30', 'name': 'D-30 122mm Howitzer'},
  ];

  final List<Map<String, String>> ammoList = [
    {'id': 'he', 'name': 'HE - High Explosive'},
    {'id': 'smoke', 'name': 'WP - White Phosphorus'},
  ];

  final List<Map<String, String>> lots = [
    {'id': 'LOT-2023-A', 'name': 'LOT-2023-A (US)'},
    {'id': 'LOT-2024-B', 'name': 'LOT-2024-B (RU)'},
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;

    return Scaffold(
      backgroundColor: colors['bg'],
      appBar: AppBar(
        title: const Text('اختيار التسليح والذخيرة'),
        backgroundColor: colors['surface'],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDropdown(
              label: 'نوع السلاح / المدفع',
              value: selectedWeapon,
              items: weapons,
              onChanged: (val) => setState(() => selectedWeapon = val),
              colors: colors,
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              label: 'نوع القذيفة',
              value: selectedAmmo,
              items: ammoList,
              onChanged: (val) => setState(() => selectedAmmo = val),
              colors: colors,
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              label: 'حزمة الذخيرة (LOT Number)',
              value: selectedLot,
              items: lots,
              onChanged: (val) => setState(() => selectedLot = val),
              colors: colors,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                // هنا يتم حفظ الاختيار والانتقال للحاسبة
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم تأكيد التسليح والذخيرة بنجاح')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors['primary'],
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.check_circle, size: 28),
              label: const Text(
                'تأكيد (CONFIRM)',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<Map<String, String>> items,
    required Function(String?) onChanged,
    required Map<String, Color> colors,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: colors['text'], fontSize: 16)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: colors['surface'],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors['border']!),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              dropdownColor: colors['surface'],
              value: value,
              hint: Text('اختر...', style: TextStyle(color: colors['text']?.withOpacity(0.5))),
              items: items.map((item) {
                return DropdownMenuItem<String>(
                  value: item['id'],
                  child: Text(item['name']!, style: TextStyle(color: colors['text'])),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}