import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class VendorOrderHistoryPage extends StatefulWidget {
  final String vendorNik;

  const VendorOrderHistoryPage({super.key, required this.vendorNik});

  @override
  State<VendorOrderHistoryPage> createState() => _VendorOrderHistoryPageState();
}

class _VendorOrderHistoryPageState extends State<VendorOrderHistoryPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _historyData = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      setState(() => _isLoading = true);
      
      final response = await supabase
          .from('shipping_assignments')
          .select('''
            *,
            request:shipping_id (
              shipping_id,
              so,
              rdd,
              group_id,
              stuffing_date,
              storage_location,
              is_dedicated,
              warehouse:warehouse(warehouse_id, warehouse_name, lokasi),
              delivery_order (
                do_number,
                customer (customer_id, customer_name),
                do_details (
                  qty,
                  material:material_id (material_id, material_name)
                )
              )
            )
          ''')
          .eq('nik', widget.vendorNik)
          .inFilter('status_assignment', ['completed', 'rejected', 'no response'])
          .order('responded_at', ascending: false);

      List<dynamic> rawData = response as List;
      List<Map<String, dynamic>> processedHistory = [];
      Map<int, Map<String, dynamic>> groupedHistory = {};

      for (var item in rawData) {
        final request = item['request'];
        if (request == null) continue;
        final int? groupId = request['group_id'];

        if (groupId != null) {
          if (!groupedHistory.containsKey(groupId)) {
            groupedHistory[groupId] = Map<String, dynamic>.from(item);
            groupedHistory[groupId]!['all_requests'] = [request];
          } else {
            groupedHistory[groupId]!['all_requests'].add(request);
          }
        } else {
          Map<String, dynamic> singleItem = Map<String, dynamic>.from(item);
          singleItem['all_requests'] = [request];
          processedHistory.add(singleItem);
        }
      }

      processedHistory.addAll(groupedHistory.values);
      processedHistory.sort((a, b) => (b['responded_at'] ?? "").compareTo(a['responded_at'] ?? ""));
        
      setState(() {
        _historyData = processedHistory;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal memuat riwayat: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : _historyData.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _fetchHistory,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _historyData.length,
                    itemBuilder: (context, index) => _buildHistoryCard(_historyData[index]),
                  ),
                ),
    );
  }

  // Widget _buildHistoryCard(Map<String, dynamic> item) {
  //   final List allRequests = item['all_requests'] ?? [];
  //   if (allRequests.isEmpty) return const SizedBox.shrink();

  //   final bool isRejected = item['status_assignment'] == 'rejected' || item['status_assignment'] == 'no response';
  //   final request = allRequests[0]; 
  //   final bool isGroup = request['group_id'] != null;

  //   return Card(
  //     margin: const EdgeInsets.only(bottom: 16),
  //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //     elevation: 2,
  //     child: Column(
  //       children: [
  //         // HEADER: Status Selesai/Batal
  //         Container(
  //           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  //           decoration: BoxDecoration(
  //             color: isRejected ? Colors.red.shade700 : Colors.green.shade700,
  //             borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
  //           ),
  //           child: Row(
  //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //             children: [
  //               Row(
  //                 children: [
  //                   Icon(isGroup ? Icons.layers : Icons.local_shipping, color: Colors.white, size: 18),
  //                   const SizedBox(width: 8),
  //                   Text(
  //                     isGroup ? "GROUP ID: ${request['group_id']}" : "SHIP ID: ${request['shipping_id']}",
  //                     style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
  //                   ),
  //                 ],
  //               ),
  //               Text(
  //                 item['status_assignment'].toString().toUpperCase(),
  //                 style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
  //               ),
  //             ],
  //           ),
  //         ),

  //         Padding(
  //           padding: const EdgeInsets.all(16),
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               // Info Waktu Selesai (Sub-header info)
  //               Row(
  //                 children: [
  //                   const Icon(Icons.history, size: 14, color: Colors.grey),
  //                   const SizedBox(width: 6),
  //                   Text(
  //                     "Selesai pada: ${_formatDateTime(item['responded_at'])}",
  //                     style: const TextStyle(fontSize: 11, color: Colors.black54),
  //                   ),
  //                 ],
  //               ),
  //               const SizedBox(height: 12),

  //               // BARIS INFO UTAMA (RDD, Stuffing, Status, Warehouse) - Seragam dengan OnProcess
  //               Row(
  //                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                 children: [
  //                   _infoBox("RDD", _formatDate(request['rdd'])),
  //                   _infoBox("STUFFING", _formatDate(request['stuffing_date'])),
  //                   _infoBox("STATUS", (request['is_dedicated'] ?? "-").toString().toUpperCase()),
  //                   _infoBox(
  //                     "WAREHOUSE", 
  //                     request['warehouse'] != null 
  //                       ? "${request['warehouse']['lokasi']} - ${request['warehouse']['warehouse_name']}".toUpperCase() 
  //                       : "-", 
  //                     color: Colors.red.shade700
  //                   ),
  //                 ],
  //               ),
  //               const Divider(height: 32),

  //               const Text("RINCIAN MUATAN", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
  //               const SizedBox(height: 10),

  //               // Looping Semua Request dalam Assignment ini (Support Group)
  //               ...allRequests.map((req) {
  //                 final List dos = req['delivery_order'] ?? [];
  //                 return Column(
  //                   children: dos.map((doItem) => _buildDoMiniCard(doItem, req['so'])).toList(),
  //                 );
  //               }).toList(),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }
  Widget _buildHistoryCard(Map<String, dynamic> item) {
    final List allRequests = item['all_requests'] ?? [];
    if (allRequests.isEmpty) return const SizedBox.shrink();

    // Logika Warna: Merah untuk rejected/no response, Hijau untuk completed
    final String status = item['status_assignment']?.toString().toLowerCase() ?? "";
    final bool isNegativeStatus = status == 'rejected' || status == 'no response';
    final Color headerColor = isNegativeStatus ? Colors.red.shade700 : Colors.green.shade700;

    final request = allRequests[0]; 
    final bool isGroup = request['group_id'] != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Column(
        children: [
          // HEADER: Warna dinamis berdasarkan status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: headerColor, // Menggunakan variabel headerColor
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(isGroup ? Icons.layers : Icons.local_shipping, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      isGroup ? "GROUP ID: ${request['group_id']}" : "SHIP ID: ${request['shipping_id']}",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
                Text(
                  status.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Waktu Selesai/Batal
                Row(
                  children: [
                    Icon(
                      isNegativeStatus ? Icons.cancel_outlined : Icons.check_circle_outline, 
                      size: 14, 
                      color: Colors.grey
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isNegativeStatus 
                        ? "Dibatalkan pada: ${_formatDateTime(item['responded_at'])}"
                        : "Selesai pada: ${_formatDateTime(item['responded_at'])}",
                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // BARIS INFO UTAMA (RDD, Stuffing, Status, Warehouse)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _infoBox("RDD", _formatDate(request['rdd'])),
                    _infoBox("STUFFING", _formatDate(request['stuffing_date'])),
                    _infoBox("STATUS", (request['is_dedicated'] ?? "-").toString().toUpperCase()),
                    _infoBox(
                      "WAREHOUSE", 
                      request['warehouse'] != null 
                        ? "${request['warehouse']['lokasi']} - ${request['warehouse']['warehouse_name']}".toUpperCase() 
                        : "-", 
                      color: Colors.red.shade700
                    ),
                  ],
                ),
                const Divider(height: 32),

                const Text("RINCIAN MUATAN", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 10),

                // Looping Semua Request dalam Assignment ini
                ...allRequests.map((req) {
                  final List dos = req['delivery_order'] ?? [];
                  return Column(
                    children: dos.map((doItem) => _buildDoMiniCard(doItem, req['so'])).toList(),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoMiniCard(Map<String, dynamic> doItem, dynamic parentSo) {
    final customer = doItem['customer'] ?? {};
    final String customerDisplay = "${customer['customer_id'] ?? ''} - ${customer['customer_name'] ?? ''}";
    final List details = doItem['do_details'] ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("DO: ${doItem['do_number']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 11)),
              Text("SO: ${parentSo ?? '-'}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.person, size: 14, color: Colors.blue),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  customerDisplay.toUpperCase(),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Divider(height: 20, thickness: 0.5),
          ...details.map((det) {
            final mat = det['material'] ?? {};
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.circle, size: 6, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "${mat['material_id'] ?? '-'} - ${mat['material_name'] ?? '-'}",
                            style: const TextStyle(fontSize: 10, color: Colors.black87),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text("${det['qty']}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _infoBox(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color ?? Colors.black87)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("Belum ada riwayat pekerjaan.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  String _formatDate(String? s) => s == null ? "-" : DateFormat('dd MMM yyyy').format(DateTime.parse(s));
  String _formatDateTime(String? s) => s == null ? "-" : DateFormat('dd/MM/yy HH:mm').format(DateTime.parse(s));
}