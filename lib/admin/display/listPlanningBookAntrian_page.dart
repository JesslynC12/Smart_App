import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class BookingPlanningListPage extends StatefulWidget {
  const BookingPlanningListPage({super.key});

  @override
  State<BookingPlanningListPage> createState() => _BookingPlanningListPageState();
}

class _BookingPlanningListPageState extends State<BookingPlanningListPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _planningList = [];

// Variabel Filter Baru
  DateTime _selectedDate = DateTime.now();
  String _dateFilterType = 'stuffing_date'; // Default: Shipping Date
  //final TextEditingController _searchController = TextEditingController();


  @override
  void initState() {
    super.initState();
  
    _fetchPlanningData();
  }

  // Future<void> _fetchPlanningData() async {
  //   try {
  //     setState(() => _isLoading = true);
  //     final response = await supabase
  //         .from('shipping_assignments')
  //         .select('*, request:shipping_id(*, delivery_order(*, customer(*)))')
  //         .eq('status_assignment', 'accepted')
  //         .not('jam_booking', 'is', null)
  //         .order('jam_booking', ascending: true);

  //     setState(() {
  //       _planningList = response;
  //       _isLoading = false;
  //     });
  //   } catch (e) {
  //     setState(() => _isLoading = false);
  //     debugPrint("Error: $e");
  //   }
  // }
  Future<void> _fetchPlanningData() async {
  try {
    setState(() => _isLoading = true);

    // Format tanggal ke string YYYY-MM-DD untuk filter database
    String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    String columnPath = "request.$_dateFilterType";
    // Query dengan join lengkap ke vendor, customer, dan material
   final response = await supabase
        .from('shipping_assignments')
        .select('''
          *,
          master_vendor:nik (vendor_name), 
          request:shipping_id (
            shipping_id,
            so,
            rdd,
            stuffing_date,
            group_id,
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
        .eq('status_assignment', 'accepted')
        .not('jam_booking', 'is', null)
        // Filter tepat pada tanggal yang dipilih
       .eq('request.$_dateFilterType', formattedDate)
       .order('jam_booking', ascending: true);
    
    setState(() {
      _planningList = response;
      _isLoading = false;
    });
  } catch (e) {
    setState(() => _isLoading = false);
    debugPrint("Error Fetch Planning: $e");
  }
}


  // @override
  // Widget build(BuildContext context) {
  //   return Scaffold(
  //     // appBar: AppBar(
  //     //   title: const Text("ANTRIAN PLANNING BOOKING", 
  //     //     style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
  //     //   backgroundColor: Colors.red.shade800,
  //     // ),
  //     body: _isLoading
  //         ? const Center(child: CircularProgressIndicator())
  //         : RefreshIndicator(
  //             onRefresh: _fetchPlanningData,
  //             child: _planningList.isEmpty
  //                 ? _buildEmptyState()
  //                 : ListView.builder(
  //                     padding: const EdgeInsets.all(12),
  //                     itemCount: _planningList.length,
  //                     itemBuilder: (context, index) => _buildPlanningCard(_planningList[index]),
  //                   ),
  //           ),
  //   );
  // }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildTopFilterBar(), // Tambahkan baris filter
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetchPlanningData,
                    child: _planningList.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _planningList.length,
                            itemBuilder: (context, index) => _buildPlanningCard(_planningList[index]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
Widget _buildTopFilterBar() {
  // Mengecek apakah tanggal yang dipilih adalah hari ini untuk menentukan warna
  bool isToday = DateFormat('yyyy-MM-dd').format(_selectedDate) == 
                 DateFormat('yyyy-MM-dd').format(DateTime.now());

  return Container(
    padding: const EdgeInsets.all(12),
    color: Colors.white,
    child: Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              // Beri warna merah jika bukan hari ini (menandakan filter aktif)
              color: !isToday ? Colors.red.shade700 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                // 1. Dropdown Tipe Tanggal
                Container(
                  padding: const EdgeInsets.only(left: 12, right: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: !isToday ? Colors.white30 : Colors.grey.shade400,
                        width: 1,
                      ),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _dateFilterType == 'stuffing_date' ? "Stuffing" : "RDD",
                      isDense: true,
                      dropdownColor: !isToday ? Colors.orange[300] : Colors.white,
                      iconEnabledColor: !isToday ? Colors.white : Colors.black87,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: !isToday ? Colors.white : Colors.black87,
                      ),
                      items: ["RDD", "Stuffing"].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _dateFilterType = val == "RDD" ? "rdd" : "stuffing_date";
                        });
                        _fetchPlanningData();
                      },
                    ),
                  ),
                ),
                // 2. Tombol Pilih Tanggal Tunggal
                Expanded(
                  child: InkWell(
                    onTap: _selectSingleDate,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: !isToday ? Colors.white : Colors.black87,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            DateFormat('dd MMMM yyyy', 'id_ID').format(_selectedDate),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: !isToday ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Tombol Reset ke Hari Ini
        if (!isToday)
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.red),
            onPressed: () {
              setState(() {
                _selectedDate = DateTime.now();
                _dateFilterType = "stuffing_date";
              });
              _fetchPlanningData();
            },
          ),
      ],
    ),
  );
}


Future<void> _selectSingleDate() async {
  final DateTime? picked = await showDatePicker(
    context: context,
    initialDate: _selectedDate,
    firstDate: DateTime(2023),
    lastDate: DateTime(2100),
    locale: const Locale('id', 'ID'),
    builder: (context, child) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: Colors.red.shade700),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
            child: child!,
          ),
        ),
      );
    },
  );

  if (picked != null && picked != _selectedDate) {
    setState(() => _selectedDate = picked);
    _fetchPlanningData();
  }
}
  // Widget _buildPlanningCard(Map<String, dynamic> item) {
  //   final request = item['request'] ?? {};
  //   final bool isGroup = request['group_id'] != null;
  //   final List dos = request['delivery_order'] ?? [];

  //   return Card(
  //     margin: const EdgeInsets.symmetric(vertical: 8),
  //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  //     elevation: 2,
  //     child: InkWell(
  //       onTap: () {
  //         // Navigasi ke halaman Vehicle Control Form (Bagian Transporter/Security)
  //         // Navigator.push(context, MaterialPageRoute(builder: (c) => VehicleCheckForm(data: item)));
  //       },
  //       child: Column(
  //         children: [
  //           // Header: Jam Booking & ID
  //           Container(
  //             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  //             decoration: BoxDecoration(
  //               color: Colors.blue.shade700,
  //               borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
  //             ),
  //             child: Row(
  //               mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //               children: [
  //                 Row(
  //                   children: [
  //                     const Icon(Icons.alarm, color: Colors.white, size: 16),
  //                     const SizedBox(width: 8),
  //                     Text(
  //                       item['jam_booking'] ?? "-",
  //                       style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
  //                     ),
  //                   ],
  //                 ),
  //                 Text(
  //                   isGroup ? "GROUP: ${request['group_id']}" : "SINGLE SHIP",
  //                   style: const TextStyle(color: Colors.white70, fontSize: 10),
  //                 ),
  //               ],
  //             ),
  //           ),
            
  //           Padding(
  //             padding: const EdgeInsets.all(12),
  //             child: Column(
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               children: [
  //                 Row(
  //                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                   children: [
  //                     _infoColumn("SHIP ID", "#${request['shipping_id']}"),
  //                     _infoColumn("GUDANG", request['storage_location']?.toString().toUpperCase() ?? "-"),
  //                     _infoColumn("STATUS", "PLANNING", color: Colors.orange.shade800),
  //                   ],
  //                 ),
  //                 const Divider(height: 20),
                  
  //                 // Info Customer & DO (Hanya ambil yang pertama sebagai ringkasan)
  //                 if (dos.isNotEmpty) ...[
  //                   Row(
  //                     children: [
  //                       const Icon(Icons.person, size: 14, color: Colors.grey),
  //                       const SizedBox(width: 8),
  //                       Expanded(
  //                         child: Text(
  //                           dos[0]['customer']?['customer_name'] ?? "-",
  //                           style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
  //                           overflow: TextOverflow.ellipsis,
  //                         ),
  //                       ),
  //                     ],
  //                   ),
  //                   const SizedBox(height: 4),
  //                   Row(
  //                     children: [
  //                       const Icon(Icons.description, size: 14, color: Colors.grey),
  //                       const SizedBox(width: 8),
  //                       Text(
  //                         "DO: ${dos[0]['do_number']} ${dos.length > 1 ? '(+${dos.length - 1} DO lainnya)' : ''}",
  //                         style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
  //                       ),
  //                     ],
  //                   ),
  //                 ],
                  
  //                 const SizedBox(height: 12),
  //                 // Footer Card: Info Truck
  //                 Row(
  //                   mainAxisAlignment: MainAxisAlignment.end,
  //                   children: [
  //                     const Text("Klik untuk mulai check unit ", 
  //                       style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey)),
  //                     Icon(Icons.arrow_forward_ios, size: 10, color: Colors.grey.shade400),
  //                   ],
  //                 )
  //               ],
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

// Widget _buildPlanningCard(Map<String, dynamic> item) {
//   final request = item['request'] ?? {};
//   final vendor = item['master_vendor'] ?? {};
//   final List dos = request['delivery_order'] ?? [];

//   return Card(
//     margin: const EdgeInsets.only(bottom: 16),
//     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//     child: Column(
//       children: [
//         // Header: Jam & Status Assignment
//         Container(
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//           decoration: BoxDecoration(
//             color: Colors.blue.shade800,
//             borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
//           ),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Text("⏰ ${item['jam_booking']}", 
//                 style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
//                 decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
//                 child: Text(item['status_assignment'].toString().toUpperCase(), 
//                   style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
//               ),
//             ],
//           ),
//         ),

//         Padding(
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // Info Utama (RDD, Stuffing, SO)
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   _infoBox("RDD", _formatDate(request['rdd'])),
//                   _infoBox("STUFFING", _formatDate(request['stuffing_date'])),
//                   _infoBox("SO #", request['so']?.toString() ?? "-"),
//                 ],
//               ),
//               const Divider(height: 24),

//               // Info Vendor
//               Row(
//                 children: [
//                   const Icon(Icons.local_shipping, size: 16, color: Colors.red),
//                   const SizedBox(width: 8),
//                   Expanded(
//                     child: Text(
//                       "${item['nik']} - ${vendor['vendor_name'] ?? 'Unknown Vendor'}",
//                       style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 12),

//               // Detail per DO & Material
//               ...dos.map((doItem) {
//                 final List details = doItem['do_details'] ?? [];
//                 return Container(
//                   margin: const EdgeInsets.only(bottom: 12),
//                   padding: const EdgeInsets.all(10),
//                   decoration: BoxDecoration(
//                     color: Colors.grey.shade50,
//                     borderRadius: BorderRadius.circular(8),
//                     border: Border.all(color: Colors.grey.shade200),
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text("DO: ${doItem['do_number']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue)),
//                       Text("👤 ${doItem['customer']?['customer_id']} - ${doItem['customer']?['customer_name']}", style: const TextStyle(fontSize: 11)),
//                       const Divider(),
//                       // Looping Material
//                       ...details.map((det) {
//                         final mat = det['material'] ?? {};
//                         return Padding(
//                           padding: const EdgeInsets.only(bottom: 4),
//                           child: Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                             children: [
//                               Expanded(
//                                 child: Text("${mat['material_id']} - ${mat['material_name']}", 
//                                   style: const TextStyle(fontSize: 10, color: Colors.black87)),
//                               ),
//                               Text("${det['qty']}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
//                             ],
//                           ),
//                         );
//                       }).toList(),
//                     ],
//                   ),
//                 );
//               }).toList(),
//             ],
//           ),
//         ),
//       ],
//     ),
//   );
// }

// Widget _buildPlanningCard(Map<String, dynamic> item) {
//   final request = item['request'] ?? {};
//   final vendor = item['master_vendor'] ?? {};
//   final List dos = request['delivery_order'] ?? [];
  
//   // Logika penentuan Single atau Group
//   final bool isGroup = request['group_id'] != null;

//   return Card(
//     margin: const EdgeInsets.only(bottom: 16),
//     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//     elevation: 3,
//     child: Column(
//       children: [
//         // Header: Jam, Status, dan Label Group/Single
//         Container(
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//           decoration: BoxDecoration(
//             color: isGroup ? Colors.purple.shade700 : Colors.blue.shade800,
//             borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
//           ),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Row(
//                 children: [
//                   const Icon(Icons.access_time_filled, color: Colors.white, size: 18),
//                   const SizedBox(width: 8),
//                   Text(
//                     item['jam_booking'] ?? "-",
//                     style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//                   ),
//                 ],
//               ),
//               // LABEL INDIKATOR GROUP / SINGLE
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//                 decoration: BoxDecoration(
//                   color: Colors.white.withOpacity(0.2),
//                   borderRadius: BorderRadius.circular(20),
//                   border: Border.all(color: Colors.white, width: 1),
//                 ),
//                 child: Row(
//                   children: [
//                     Icon(
//                       isGroup ? Icons.groups_rounded : Icons.person_rounded,
//                       color: Colors.white,
//                       size: 14,
//                     ),
//                     const SizedBox(width: 4),
//                     Text(
//                       isGroup ? "GROUP SHIP (#${request['group_id']})" : "SINGLE SHIP",
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontSize: 10,
//                         fontWeight: FontWeight.bold,
//                         letterSpacing: 0.5,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),

//         Padding(
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // Baris 1: RDD, Shipping Date (Stuffing), SO
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   _infoBox("RDD", _formatDate(request['rdd'])),
//                   _infoBox("SHIPPING DATE", _formatDate(request['stuffing_date'])),
//                   _infoBox("SO NUMBER", request['so']?.toString() ?? "-"),
//                 ],
//               ),
//               const Divider(height: 24),

//               // Baris 2: Info Vendor & Status Assignment
//               Row(
//                 children: [
//                   const Icon(Icons.store, size: 18, color: Colors.red),
//                   const SizedBox(width: 8),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         const Text("VENDOR", style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
//                         Text(
//                           "${item['nik']} - ${vendor['vendor_name'] ?? 'Unknown Vendor'}",
//                           style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
//                         ),
//                       ],
//                     ),
//                   ),
//                   _infoBox("STATUS", item['status_assignment'].toString().toUpperCase()),
//                 ],
//               ),
//               const SizedBox(height: 16),

//               // Bagian Detail DO, Customer, dan Material
//               const Text("LIST DELIVERY ORDER & MATERIALS", 
//                 style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
//               const SizedBox(height: 8),
              
//               ...dos.map((doItem) {
//                 final List details = doItem['do_details'] ?? [];
//                 return Container(
//                   margin: const EdgeInsets.only(bottom: 12),
//                   padding: const EdgeInsets.all(12),
//                   decoration: BoxDecoration(
//                     color: Colors.grey.shade50,
//                     borderRadius: BorderRadius.circular(10),
//                     border: Border.all(color: Colors.grey.shade200),
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       // Customer Info
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Text("DO: ${doItem['do_number']}", 
//                             style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 12)),
//                           Text("Cust ID: ${doItem['customer']?['customer_id'] ?? '-'}", 
//                             style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
//                         ],
//                       ),
//                       Text("👤 ${doItem['customer']?['customer_name'] ?? '-'}", 
//                         style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
//                       const Padding(
//                         padding: EdgeInsets.symmetric(vertical: 8.0),
//                         child: Divider(thickness: 0.5),
//                       ),
//                       // Material List
//                       ...details.map((det) {
//                         final mat = det['material'] ?? {};
//                         return Padding(
//                           padding: const EdgeInsets.only(bottom: 6),
//                           child: Row(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               const Icon(Icons.inventory_2_outlined, size: 12, color: Colors.grey),
//                               const SizedBox(width: 6),
//                               Expanded(
//                                 child: Text("${mat['material_id']} - ${mat['material_name']}", 
//                                   style: const TextStyle(fontSize: 10, color: Colors.black87)),
//                               ),
//                               Text("${det['qty']} Unit", 
//                                 style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
//                             ],
//                           ),
//                         );
//                       }).toList(),
//                     ],
//                   ),
//                 );
//               }).toList(),
//             ],
//           ),
//         ),
//       ],
//     ),
//   );
// }

// Widget _buildPlanningCard(Map<String, dynamic> item) {
//   final request = item['request'] ?? {};
//   final vendor = item['master_vendor'] ?? {};
//   final List dos = request['delivery_order'] ?? [];
//   final bool isGroup = request['group_id'] != null;

//   return Card(
//     margin: const EdgeInsets.only(bottom: 16),
//     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//     elevation: 3,
//     child: Column(
//       children: [
//         // Header: Jam, Status, dan Label Group/Single
//         Container(
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//           decoration: BoxDecoration(
//             color: isGroup ? Colors.purple.shade700 : Colors.blue.shade800,
//             borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
//           ),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Row(
//                 children: [
//                   const Icon(Icons.access_time_filled, color: Colors.white, size: 18),
//                   const SizedBox(width: 8),
//                   Text(
//                     item['jam_booking'] ?? "-",
//                     style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//                   ),
//                 ],
//               ),
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//                 decoration: BoxDecoration(
//                   color: Colors.white.withOpacity(0.2),
//                   borderRadius: BorderRadius.circular(20),
//                   border: Border.all(color: Colors.white, width: 1),
//                 ),
//                 child: Text(
//                   isGroup ? "GROUP SHIP (#${request['group_id']})" : "SINGLE SHIP",
//                   style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
//                 ),
//               ),
//             ],
//           ),
//         ),

//         Padding(
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // --- PENAMBAHAN INFO TIME LOG (Kecil) ---
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Text(
//                     "Assigned: ${_formatDateTime(item['assigned_at'])}",
//                     style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
//                   ),
//                   Text(
//                     "Responded: ${_formatDateTime(item['responded_at'])}",
//                     style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 8),
              
//               // Baris 1: RDD, Shipping Date, SO
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   _infoBox("RDD", _formatDate(request['rdd'])),
//                   _infoBox("SHIPPING DATE", _formatDate(request['stuffing_date'])),
//                   _infoBox("SO NUMBER", request['so']?.toString() ?? "-"),
//                 ],
//               ),
//               const Divider(height: 20),

//               // Baris 2: Info Vendor
//               Row(
//                 children: [
//                   const Icon(Icons.store, size: 18, color: Colors.red),
//                   const SizedBox(width: 8),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         const Text("VENDOR", style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
//                         Text(
//                           "${item['nik']} - ${vendor['vendor_name'] ?? 'Unknown Vendor'}",
//                           style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
//                         ),
//                       ],
//                     ),
//                   ),
//                   _infoBox("STATUS", item['status_assignment'].toString().toUpperCase()),
//                 ],
//               ),
//               const SizedBox(height: 16),

//               // Detail Item (Customer & Material)
//               ...dos.map((doItem) {
//                 final List details = doItem['do_details'] ?? [];
//                 return Container(
//                   margin: const EdgeInsets.only(bottom: 12),
//                   padding: const EdgeInsets.all(12),
//                   decoration: BoxDecoration(
//                     color: Colors.grey.shade50,
//                     borderRadius: BorderRadius.circular(10),
//                     border: Border.all(color: Colors.grey.shade200),
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Text("DO: ${doItem['do_number']}", 
//                             style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 12)),
//                           Text("Cust ID: ${doItem['customer']?['customer_id'] ?? '-'}", 
//                             style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
//                         ],
//                       ),
//                       Text("👤 ${doItem['customer']?['customer_name'] ?? '-'}", 
//                         style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
//                       const Divider(height: 16),
//                       ...details.map((det) {
//                         final mat = det['material'] ?? {};
//                         return Padding(
//                           padding: const EdgeInsets.only(bottom: 4),
//                           child: Row(
//                             children: [
//                               const Icon(Icons.circle, size: 4, color: Colors.grey),
//                               const SizedBox(width: 6),
//                               Expanded(
//                                 child: Text("${mat['material_id']} - ${mat['material_name']}", 
//                                   style: const TextStyle(fontSize: 10)),
//                               ),
//                               Text("${det['qty']} Unit", 
//                                 style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
//                             ],
//                           ),
//                         );
//                       }).toList(),
//                     ],
//                   ),
//                 );
//               }).toList(),
//             ],
//           ),
//         ),
//       ],
//     ),
//   );
// }

Widget _buildPlanningCard(Map<String, dynamic> item) {
  // PENTING: Ambil data dari key 'request'
 final Map<String, dynamic> request = item['request'] ?? {};
  final vendor = item['master_vendor'] ?? {};

  if (request.isEmpty) return const SizedBox.shrink();
  final List dos = request['delivery_order'] as List? ?? [];
  final bool isGroup = request['group_id'] != null;

// Mengambil data warehouse hasil join
  final warehouse = request['warehouse'];
  String warehouseDisplay = "-";
  if (warehouse != null) {
    warehouseDisplay = "${warehouse['lokasi'] ?? ''} - ${warehouse['warehouse_name'] ?? ''}";
  }

  return Card(
    margin: const EdgeInsets.only(bottom: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 3,
    child: Column(
      children: [
        // Header: Jam, Status, dan Label Group/Single
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isGroup ? Colors.purple.shade700 : Colors.blue.shade800,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.access_time_filled, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    item['jam_booking'] ?? "-",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: Text(
                  isGroup ? "GROUP SHIP ${request['group_id']}" : "SINGLE SHIP ${request['shipping_id']}",
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info TIME LOG (Kecil)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Assigned: ${_formatDateTime(item['assigned_at'])}",
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                  ),
                  Text(
                    "Responded: ${_formatDateTime(item['responded_at'])}",
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Baris 1: RDD, SHIPPING DATE, STORAGE LOCATION (Pengganti SO)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _infoBox("RDD", _formatDate(request['rdd'])),
                  _infoBox("STUFFING DATE", _formatDate(request['stuffing_date'])),
                  _infoBox("TYPE", (request['is_dedicated'] ?? "-").toString().toUpperCase()),
                  // PERUBAHAN: Sekarang menampilkan Lokasi Gudang
                  _infoBox("WAREHOUSE", warehouseDisplay.toUpperCase()),
                ],
              ),
              const Divider(height: 20),

              // Baris 2: Info Vendor
              Row(
                children: [
                  const Icon(Icons.store, size: 18, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("VENDOR", style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                        Text(
                          "${item['nik']} - ${vendor['vendor_name'] ?? 'Unknown Vendor'}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  _infoBox("STATUS ORDER", item['status_assignment'].toString().toUpperCase()),
                ],
              ),
              const SizedBox(height: 16),

              // Detail Item (Customer & Material)
              ...dos.map((doItem) {
                final List details = doItem['do_details'] ?? [];
                // Mengambil nomor SO dari request utama atau item DO
                final String soDisplay = request['so']?.toString() ?? "-";
                final String custId = doItem['customer']?['customer_id']?.toString() ?? '-';
                final String custName = doItem['customer']?['customer_name'] ?? '-';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("DO: ${doItem['do_number']}", 
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 12)),
                          // PERUBAHAN: Menampilkan Nomor SO
                         Text("SO: ${request['so']?.toString() ?? '-'}",
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // PERUBAHAN: Customer ID digabung ke sebelah Nama
                      Text("👤 $custId - $custName", 
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      const Divider(height: 16),
                      ...details.map((det) {
                        final mat = det['material'] ?? {};
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.circle, size: 4, color: Colors.grey),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text("${mat['material_id']?.toString() ?? '-'} - ${mat['material_name'] ?? '-'}", 
                                  style: const TextStyle(fontSize: 10)),
                              ),
                              Text("${det['qty']}", 
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ],
    ),
  );
}

// Helper untuk format tanggal dan jam (Assigned & Responded)
String _formatDateTime(String? dateStr) {
  if (dateStr == null) return "-";
  DateTime dt = DateTime.parse(dateStr).toLocal();
  return DateFormat('dd/MM/yy HH:mm').format(dt);
}

Widget _infoBox(String label, String value) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
      Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
    ],
  );
} 

  Widget _infoColumn(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color ?? Colors.black87)),
      ],
    );
  }


  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "-";
    try { return DateFormat('dd MMM yyyy').format(DateTime.parse(dateStr)); } catch (e) { return "-"; }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_note, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("Tidak ada antrian planning saat ini", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}