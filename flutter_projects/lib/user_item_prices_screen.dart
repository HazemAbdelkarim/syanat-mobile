import 'package:flutter/material.dart';
import '../firebase_service.dart';

const Color syanatBlue = Color(0xFF3C21C8);

class UserItemPricesScreen extends StatefulWidget {
  final String technicianId;
  final String technicianName;

  const UserItemPricesScreen({
    required this.technicianId,
    required this.technicianName,
    super.key,
  });

  @override
  State<UserItemPricesScreen> createState() => _UserItemPricesScreenState();
}

class _UserItemPricesScreenState extends State<UserItemPricesScreen> {
  List<Map<String, dynamic>> _inventory = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    setState(() => _loading = true);
    try {
      _inventory =
          await FirebaseService.getInventory(widget.technicianId);
    } catch (e) {
      debugPrint('Load inventory error: $e');
    }
    setState(() => _loading = false);
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
              title: Text(
                "${widget.technicianName}'s Item Prices",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                        'Available Items & Prices',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Check prices before booking to know the full operation cost',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                // White content area
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _loading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: syanatBlue,
                            ),
                          )
                        : _inventory.isEmpty
                            ? const Center(
                                child: Text(
                                  'No items available',
                                  style: TextStyle(
                                    color: Colors.black54,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _inventory.length,
                                itemBuilder: (context, index) {
                                  final item = _inventory[index];
                                  final name = item['itemName'] ?? '';
                                  final quantity = item['quantity'] ?? 0;
                                  final cost = item['costPerItem'] ?? 0.0;
                                  final description =
                                      item['description'] ?? '';

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(15),
                                      border: Border.all(
                                          color: Colors.grey.shade300),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withOpacity(0.05),
                                          blurRadius: 6,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                name,
                                                style: const TextStyle(
                                                  color: Colors.black,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: (quantity > 0
                                                        ? Colors.green
                                                        : Colors.red)
                                                    .withOpacity(0.08),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: quantity > 0
                                                      ? Colors.green
                                                      : Colors.red,
                                                ),
                                              ),
                                              child: Text(
                                                quantity > 0
                                                    ? 'In Stock'
                                                    : 'Out of Stock',
                                                style: TextStyle(
                                                  color: quantity > 0
                                                      ? Colors.green
                                                      : Colors.red,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Price: \$${cost.toStringAsFixed(2)} per item',
                                          style: const TextStyle(
                                            color: Colors.black87,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Available Quantity: $quantity',
                                          style: const TextStyle(
                                            color: Colors.black54,
                                          ),
                                        ),
                                        if (description.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            'Description: $description',
                                            style: const TextStyle(
                                              color: Colors.black54,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                },
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
