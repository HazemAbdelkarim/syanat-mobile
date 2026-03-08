import 'package:flutter/material.dart';
import '../firebase_service.dart';

const Color syanatBlue = Color(0xFF3C21C8);

class TechnicianInventoryScreen extends StatefulWidget {
  const TechnicianInventoryScreen({super.key});

  @override
  State<TechnicianInventoryScreen> createState() =>
      _TechnicianInventoryScreenState();
}

class _TechnicianInventoryScreenState
    extends State<TechnicianInventoryScreen> {
  final _itemNameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _costController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<Map<String, dynamic>> _inventory = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _quantityController.dispose();
    _costController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadInventory() async {
    final user = FirebaseService.getCurrentUser();
    if (user == null) return;

    setState(() => _loading = true);
    try {
      _inventory = await FirebaseService.getInventory(user.uid);
    } catch (e) {
      debugPrint('Load inventory error: $e');
    }
    setState(() => _loading = false);
  }

  Future<void> _addItem() async {
    final user = FirebaseService.getCurrentUser();
    if (user == null) return;

    final name = _itemNameController.text.trim();
    final qty = int.tryParse(_quantityController.text.trim()) ?? 0;
    final cost = double.tryParse(_costController.text.trim()) ?? 0.0;
    final desc = _descriptionController.text.trim();

    if (name.isEmpty || qty <= 0 || cost <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields with valid values'),
        ),
      );
      return;
    }

    try {
      await FirebaseService.addInventoryItem(
        technicianId: user.uid,
        itemName: name,
        quantity: qty,
        costPerItem: cost,
        description: desc,
      );
      _clearForm();
      _loadInventory();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item added successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _editItem(Map<String, dynamic> item) async {
    _itemNameController.text = item['itemName'] ?? '';
    _quantityController.text = (item['quantity'] ?? 0).toString();
    _costController.text = (item['costPerItem'] ?? 0.0).toString();
    _descriptionController.text = item['description'] ?? '';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _itemNameController,
              decoration: const InputDecoration(labelText: 'Item Name'),
            ),
            TextField(
              controller: _quantityController,
              decoration: const InputDecoration(labelText: 'Quantity'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _costController,
              decoration:
                  const InputDecoration(labelText: 'Cost per Item'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _descriptionController,
              decoration:
                  const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: syanatBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (result == true) {
      final name = _itemNameController.text.trim();
      final qty = int.tryParse(_quantityController.text.trim()) ?? 0;
      final cost = double.tryParse(_costController.text.trim()) ?? 0.0;
      final desc = _descriptionController.text.trim();

      if (name.isEmpty || qty <= 0 || cost <= 0) return;

      try {
        await FirebaseService.updateInventoryItem(
          itemId: item['id'],
          itemName: name,
          quantity: qty,
          costPerItem: cost,
          description: desc,
        );
        _clearForm();
        _loadInventory();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item updated successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deleteItem(String itemId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text(
            'Are you sure you want to delete this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseService.deleteInventoryItem(itemId);
        _loadInventory();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item deleted successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _clearForm() {
    _itemNameController.clear();
    _quantityController.clear();
    _costController.clear();
    _descriptionController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection:
          Localizations.localeOf(context).languageCode == 'ar'
              ? TextDirection.rtl
              : TextDirection.ltr,
      child: Container(
        color: syanatBlue,
        child: SafeArea(
          child: Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: syanatBlue,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              title: const Text(
                'Manage Inventory',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            body: Column(
              children: [
                // Blue header strip
                Container(
                  color: syanatBlue,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add and manage your items',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Keep your item list up to date so customers see accurate prices.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                // White content area
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Add Item Form (neutral card)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                                color: Colors.grey.shade300),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    Colors.black.withOpacity(0.05),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Add New Item',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _itemNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Item Name',
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _quantityController,
                                      decoration:
                                          const InputDecoration(
                                        labelText: 'Quantity',
                                      ),
                                      keyboardType:
                                          TextInputType.number,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextField(
                                      controller: _costController,
                                      decoration:
                                          const InputDecoration(
                                        labelText: 'Cost per Item',
                                      ),
                                      keyboardType:
                                          TextInputType.number,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _descriptionController,
                                decoration: const InputDecoration(
                                  labelText: 'Description (optional)',
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _addItem,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: syanatBlue,
                                    foregroundColor: Colors.white,
                                    padding:
                                        const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text('Add Item'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Inventory List
                        Expanded(
                          child: _loading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: syanatBlue,
                                  ),
                                )
                              : _inventory.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'No items in inventory',
                                        style: TextStyle(
                                          color: Colors.black54,
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      itemCount: _inventory.length,
                                      itemBuilder:
                                          (context, index) {
                                        final item =
                                            _inventory[index];
                                        final name =
                                            item['itemName'] ?? '';
                                        final quantity =
                                            item['quantity'] ?? 0;
                                        final cost =
                                            item['costPerItem']
                                                    as num? ??
                                                0;
                                        final description =
                                            item['description'] ?? '';

                                        return Container(
                                          margin:
                                              const EdgeInsets.only(
                                                  bottom: 8),
                                          padding:
                                              const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius:
                                                BorderRadius.circular(
                                                    15),
                                            border: Border.all(
                                                color: Colors
                                                    .grey.shade300),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment
                                                    .start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      name,
                                                      style:
                                                          const TextStyle(
                                                        color: Colors
                                                            .black,
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight
                                                                .bold,
                                                      ),
                                                    ),
                                                  ),
                                                  Row(
                                                    children: [
                                                      IconButton(
                                                        onPressed: () =>
                                                            _editItem(
                                                                item),
                                                        icon:
                                                            const Icon(
                                                          Icons.edit,
                                                          color: Colors
                                                              .black54,
                                                        ),
                                                      ),
                                                      IconButton(
                                                        onPressed: () =>
                                                            _deleteItem(
                                                                item['id']),
                                                        icon:
                                                            const Icon(
                                                          Icons.delete,
                                                          color:
                                                              Colors.red,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Quantity: $quantity',
                                                style: const TextStyle(
                                                  color: Colors.black54,
                                                ),
                                              ),
                                              Text(
                                                'Cost: \$${cost.toStringAsFixed(2)} each',
                                                style: const TextStyle(
                                                  color: Colors.black54,
                                                ),
                                              ),
                                              if (description
                                                  .isNotEmpty) ...[
                                                const SizedBox(
                                                    height: 4),
                                                Text(
                                                  'Description: $description',
                                                  style:
                                                      const TextStyle(
                                                    color:
                                                        Colors.black54,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
