
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VendorOrdersPage extends StatefulWidget {
  @override
  State<VendorOrdersPage> createState() => _VendorOrdersPageState();
}

class _VendorOrdersPageState extends State<VendorOrdersPage> {
  final supabase = Supabase.instance.client;

  // Fungsi untuk mengambil data khusus vendor yang sedang login
  Future<List<Map<String, dynamic>>> _getVendorOrders() async {
    final vendorId = supabase.auth.currentUser!.id;

    // Query ini akan mengambil shipping_request yang ID-nya sudah di-assign ke vendor ini
    final response = await supabase
        .from('shipping_request')
        .select('''
          *,
          delivery_order(
            *,
            customer(*)
          )
        ''')
        .eq('assigned_vendor_id', vendorId) // Filter Utama
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pesanan Saya")),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _getVendorOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("Belum ada tugas pengiriman."));
          }

          final orders = snapshot.data!;
          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return ListTile(
                title: Text("SO: ${order['so']}"),
                subtitle: Text("Status: ${order['status']}"),
                onTap: () {
                  // Navigasi ke detail pengiriman
                },
              );
            },
          );
        },
      ),
    );
  }
}