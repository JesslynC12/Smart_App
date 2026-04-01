import 'package:flutter/material.dart';
import 'package:project_app/admin/display/pemilihanvendor_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class VendorRequestPage extends StatefulWidget {
  const VendorRequestPage({super.key});

  @override
  State<VendorRequestPage> createState() => _VendorRequestPageState();
}

class _VendorRequestPageState extends State<VendorRequestPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = false;
  List<Map<String, dynamic>> _dataList = [];

  // Filter States
  String _selectedFilterLoc = "SEMUA";
  DateTimeRange? _selectedDateRange;
String _dateFilterType = "RDD"; // Default filter ke RDD

  @override
  void initState() {
    super.initState();
    _fetchVendorTargetData();
  }

  Future<void> _fetchVendorTargetData() async {
    try {
      setState(() => _isLoading = true);

      var query = supabase.from('shipping_request').select('''
            *,
            so,
            shipping_request_details!inner(
              storage_location,
              is_dedicated
            ),
            delivery_order(
              do_number,
              customer(customer_id, customer_name),
              do_details(qty, material(material_id, material_name))
            )
          ''').eq('status', 'waiting vendor delivery request');

      if (_selectedFilterLoc != "SEMUA") {
        query = query.eq('shipping_request_details.storage_location', _selectedFilterLoc.toLowerCase());
      }

      if (_selectedDateRange != null) {
        // Menentukan kolom mana yang difilter berdasarkan pilihan dropdown
      String dateColumn = _dateFilterType == "RDD" ? 'rdd' : 'stuffing_date';
        query = query
           .gte(dateColumn, _selectedDateRange!.start.toIso8601String())
          .lte(dateColumn, _selectedDateRange!.end.toIso8601String());
      }

      final response = await query.order('shipping_id', ascending: false);
      
      setState(() {
        _dataList = _getGroupedDisplayData(List<Map<String, dynamic>>.from(response));
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Error: $e", Colors.red);
    }
  }

  List<Map<String, dynamic>> _getGroupedDisplayData(List<Map<String, dynamic>> source) {
    Map<int, Map<String, dynamic>> groupedMap = {};
    List<Map<String, dynamic>> finalResult = [];

    for (var req in source) {
      if (req['group_id'] == null) {
        finalResult.add(Map<String, dynamic>.from(req));
      } else {
        int gId = req['group_id'];
        if (!groupedMap.containsKey(gId)) {
          groupedMap[gId] = Map<String, dynamic>.from(req);
          groupedMap[gId]!['grouped_ids'] = [req['shipping_id']];
        // Simpan SO induk ke dalam setiap DO di grup pertama
        if (groupedMap[gId]!['delivery_order'] != null) {
          for (var doItem in groupedMap[gId]!['delivery_order']) {
            doItem['parent_so'] = req['so']; 
          }
        }
      } else {
        groupedMap[gId]!['grouped_ids'].add(req['shipping_id']);
        
        // Ambil DO baru dan tempelkan nomor SO-nya
        List newDos = List.from(req['delivery_order'] ?? []);
        for (var ndo in newDos) {
          ndo['parent_so'] = req['so']; // Menandai SO asal untuk tiap DO
        }

        List currentDos = List.from(groupedMap[gId]!['delivery_order'] ?? []);
        currentDos.addAll(newDos);
        groupedMap[gId]!['delivery_order'] = currentDos;
      }
    }
  }
    finalResult.addAll(groupedMap.values);
    finalResult.sort((a, b) => (b['shipping_id'] as int).compareTo(a['shipping_id'] as int));
    return finalResult;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Permintaan Vendor Tracking", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _dataList.isEmpty 
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: _dataList.length,
                    itemBuilder: (context, index) => _buildVendorCard(_dataList[index]),
                  ),
          ),
        ],
      ),
    );
  }

  // Widget _buildFilterBar() {
  //   return Container(
  //     padding: const EdgeInsets.all(12),
  //     decoration: const BoxDecoration(color: Colors.white),
  //     child: Row(
  //       children: [
  //         Expanded(
  //           child: DropdownButtonFormField<String>(
  //             value: _selectedFilterLoc,
  //             decoration: _filterInputDecoration("Lokasi Gudang"),
  //             items: ["SEMUA", "RUNGKUT", "TAMBAK LANGON"].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12)))).toList(),
  //             onChanged: (val) {
  //               setState(() => _selectedFilterLoc = val!);
  //               _fetchVendorTargetData();
  //             },
  //           ),
  //         ),
  //         const SizedBox(width: 8),

  //         Expanded(
  //           child: InkWell(
  //             onTap: _pickDateRange,
  //             child: Container(
  //               padding: const EdgeInsets.all(10),
  //               decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(8)),
  //               child: Row(
  //                 children: [
  //                   const Icon(Icons.calendar_month, size: 16, color: Colors.red),
  //                   const SizedBox(width: 8),
  //                   Text(_selectedDateRange == null ? "Filter RDD" : DateFormat('dd/MM').format(_selectedDateRange!.start), style: const TextStyle(fontSize: 12)),
  //                 ],
  //               ),
  //             ),
  //           ),
  //         ),
  //         IconButton(
  //           onPressed: () { 
  //             setState(() { _selectedFilterLoc = "SEMUA"; _selectedDateRange = null; }); 
  //             _fetchVendorTargetData(); 
  //           }, 
  //           icon: const Icon(Icons.refresh, color: Colors.red)
  //         )
  //       ],
  //     ),
  //   );
  // }

Widget _buildFilterBar() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 2,
          offset: const Offset(0, 2),
        )
      ],
    ),
    child: Row(
      children: [
        // 1. Dropdown Lokasi Gudang (Flex 2)
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<String>(
            value: _selectedFilterLoc,
            decoration: _filterInputDecoration("Gudang"),
            style: const TextStyle(fontSize: 11, color: Colors.black),
            items: ["SEMUA", "RUNGKUT", "TAMBAK LANGON"].map((e) => 
              DropdownMenuItem(value: e, child: Text(e))
            ).toList(),
            onChanged: (val) {
              setState(() => _selectedFilterLoc = val!);
              _fetchVendorTargetData();
            },
          ),
        ),
        const SizedBox(width: 8),

        // 2. Dropdown Tipe Tanggal (Flex 2)
        
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<String>(
            value: _dateFilterType,
            decoration: _filterInputDecoration("Berdasarkan"),
            style: const TextStyle(fontSize: 11, color: Colors.black),
            items: ["RDD", "STUFFING"].map((e) => 
              DropdownMenuItem(value: e, child: Text(e))
            ).toList(),
            onChanged: (val) {
              setState(() => _dateFilterType = val!);
              if (_selectedDateRange != null) _fetchVendorTargetData();
            },
          ),
        ),
        const SizedBox(width: 6),

        // 3. Tombol Pilih Rentang Tanggal (Flex 3)
        Expanded(
          flex: 3,
          child: InkWell(
            onTap: _pickDateRange,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_month, size: 14, color: Colors.red),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      _selectedDateRange == null 
                          ? "Pilih Tgl" 
                          : "${DateFormat('dd/MM').format(_selectedDateRange!.start)}-${DateFormat('dd/MM').format(_selectedDateRange!.end)}",
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 4. Tombol Reset (Kecil)
        IconButton(
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.only(left: 4),
          onPressed: () { 
            setState(() { 
              _selectedFilterLoc = "SEMUA"; 
              _selectedDateRange = null; 
              _dateFilterType = "RDD";
            }); 
            _fetchVendorTargetData(); 
          }, 
          icon: const Icon(Icons.refresh, color: Colors.red, size: 20)
        )
      ],
    ),
  );
}

  Widget _buildVendorCard(Map<String, dynamic> item) {
    final bool isGroup = item['group_id'] != null;
    final List dos = item['delivery_order'] ?? [];
    
    // Perbaikan akses detail (Menangani List dari inner join)
    final List rawDetails = item['shipping_request_details'] ?? [];
    final Map<String, dynamic> details = rawDetails.isNotEmpty ? rawDetails[0] : {};

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Group & Lokasi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isGroup ? Colors.blue.shade50 : Colors.red.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(isGroup ? Icons.layers : Icons.local_shipping, size: 18, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Text(
                  isGroup ? "GROUP ID: ${item['group_id']}" : "SHIP ID: ${item['shipping_id']}",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const Spacer(),
                _buildBadge(details['storage_location']?.toString().toUpperCase() ?? "-", Colors.red.shade700),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Tanggal
                Row(
                  children: [
                    _infoText("📅 RDD:", _formatDate(item['rdd'])),
                    const SizedBox(width: 20),
                    _infoText("🚛 Stuffing:", _formatDate(item['stuffing_date'],)),
                     const SizedBox(width: 20),
                      _infoText("🛠️ Status:", details['is_dedicated']?.toString().toUpperCase() ?? "-"),
const Divider(height: 40),
                  ],
                  
                ),
                // const SizedBox(height: 4),
                // _infoText("🛠️ Status:", details['is_dedicated']?.toString().toUpperCase() ?? "-"),
                // const Divider(height: 20),

                // List Table per DO
                ...dos.map((doItem) {
                  final List doDetails = doItem['do_details'] ?? [];
                  final String custName = doItem['customer']?['customer_name'] ?? "-";
                  final String custId = doItem['customer']?['customer_id']?.toString() ?? "-";

                  // return Container(
                  //   margin: const EdgeInsets.only(bottom: 12),
                  //   decoration: BoxDecoration(
                  //     border: Border.all(color: Colors.grey.shade200),
                  //     borderRadius: BorderRadius.circular(8),
                  //   ),
                  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.grey[300]!), // Border abu tipis
    ),
    child: Column(
      children: [
        // HEADER BOX (DO - SO - CUSTOMER)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.pink.shade50, // Background abu sangat muda sesuai gambar
            borderRadius: const BorderRadius.only(
             
            ),
          ),
                    child: Row(
                      children: [
                        // Container(
                        //   padding: const EdgeInsets.all(8),
                        //   color: Colors.grey.shade50,
                        //   child: Row(
                        //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        //     children: [
                              Text("DO: ${doItem['do_number']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black)),
                              const Spacer(),
                              Text(
                  "SO: ${doItem['parent_so'] ?? item['so'] ?? '-'}", // Pastikan key 'so_number' sesuai data Anda
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                              Text("${doItem['customer']?['customer_id'] ?? '-'} - ${doItem['customer']?['customer_name'] ?? '-'}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        Table(
                          columnWidths: const {
                            0: FlexColumnWidth(1.2), // No Mat
                            1: FlexColumnWidth(4),   // Nama Mat
                            2: FlexColumnWidth(1),   // Qty
                          },
                          children: doDetails.map((det) => TableRow(
                            children: [
                              _tablePadding(det['material']?['material_id']?.toString() ?? "-"),
                              _tablePadding(det['material']?['material_name'] ?? "-"),
                              _tablePadding(det['qty']?.toString() ?? "0", isBold: true, align: TextAlign.right),
                            ],
                          )).toList(),
                        ),
                      ],
                   
       
    ),
    
                  );
                

                }).toList(),
              ],
            ),
          ),

          // Tombol Proses
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
               onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AssignVendorPage(shippingId: item['shipping_id']),
        ),
      );
    },
              icon: const Icon(Icons.send, color: Colors.white, size: 18),
              label: Text(
                // isGroup ? "PROSES GRUP (${(item['grouped_ids'] as List).length} DATA)" : 
                "PROSES PERMINTAAN VENDOR",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- UI Helpers ---
  Widget _infoText(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.bold),
        children: [
          TextSpan(text: "$label "),
          TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _tablePadding(String text, {bool isBold = false, TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(fontSize: 10, fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: color, width: 0.5)),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  InputDecoration _filterInputDecoration(String label) => InputDecoration(labelText: label, labelStyle: const TextStyle(fontSize: 11), isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)));

  Widget _buildEmptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.done_all, size: 64, color: Colors.grey[300]), const SizedBox(height: 16), const Text("Semua data sudah diproses", style: TextStyle(color: Colors.grey))]));

  // // --- Logic ---
  // Future<void> _submitToVendor(Map<String, dynamic> item) async {
  //   final List ids = item['group_id'] != null ? item['grouped_ids'] : [item['shipping_id']];
  //   try {
  //     setState(() => _isLoading = true);
  //     await supabase.from('shipping_request').update({'status': 'waiting vendor assignment'}).inFilter('shipping_id', ids);
  //     final inserts = ids.map((id) => {'shipping_id': id, 'status': 'requested', 'id_profile': supabase.auth.currentUser?.id}).toList();
  //     await supabase.from('vendor_delivery_request').insert(inserts);
  //     _showSnackBar("Berhasil dikirim ke Vendor!", Colors.green);
  //     _fetchVendorTargetData();
  //   } catch (e) {
  //     setState(() => _isLoading = false);
  //     _showSnackBar("Gagal: $e", Colors.red);
  //   }
  // }

  Future<void> _pickDateRange() async {
    DateTimeRange? picked = await showDateRangePicker(context: context, firstDate: DateTime(2023), lastDate: DateTime(2100), builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: Colors.red.shade700)), child: child!));
    if (picked != null) { setState(() => _selectedDateRange = picked); _fetchVendorTargetData(); }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "-";
    try { return DateFormat('dd MMM yyyy').format(DateTime.parse(dateStr)); } catch (e) { return "-"; }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }
}