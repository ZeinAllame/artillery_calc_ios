import 'package:flutter/material.dart';

import '../../../domain/firing_table.dart';
import '../../../domain/custom_tables_loader.dart';
import '../calculator/table_manager_screen.dart';

class ManualTableScreen extends StatefulWidget {
  final String tableKey;
  final String title;
  const ManualTableScreen({super.key, required this.tableKey, required this.title});

  @override
  State<ManualTableScreen> createState() => _ManualTableScreenState();
}

class _ManualTableScreenState extends State<ManualTableScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    final existing = FiringTables.getTableForWeapon(widget.tableKey);
    final rows = await Navigator.push<List<FiringTableRow>>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EditTableRowsScreen(tableKey: widget.tableKey, initialRows: existing),
      ),
    );
    if (!mounted) return;
    if (rows != null) {
      await CustomTablesLoader.save(widget.tableKey, rows);
      if (!mounted) return;
      Navigator.pop(context, true);
    } else {
      Navigator.pop(context, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('إدخال جدول: ${widget.title}')),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}