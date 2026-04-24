import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:project_app/dynamic_tab_page.dart';

class AssignVendorPage extends StatefulWidget {
  final int shippingId;

  const AssignVendorPage({super.key, required this.shippingId});

  @override
  State<AssignVendorPage> createState() => _AssignVendorPageState();
}

class _AssignVendorPageState extends State<AssignVendorPage> {
  final supabase = Supabase.instance.client;
  StreamSubscription? _realtimeSubscription;
  bool _isLoading = true;

  List<Map<String, dynamic>> _recommendations = [];
  List<Map<String, dynamic>> _allVendors = [];
  Map<String, dynamic>? _selectedVendor;
  Map<String, dynamic>? _shippingData;
  List<String> targetCities = [];

  // 🔥 VARIABEL OPTIMASI (Agar tidak lemot)
  double _tnwTotal = 0;
  double _qtyTotal = 0;
  double _nwTotal = 0;
  String _requiredUnit = "";

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupRealtime();
  }

  void _setupRealtime() {
    // Memantau perubahan hanya pada baris data yang sedang dibuka
    _realtimeSubscription = supabase
        .from('shipping_request')
        .stream(primaryKey: ['shipping_id'])
        .eq('shipping_id', widget.shippingId)
        .listen((data) {
          // Jika ada perubahan di database (misal status berubah atau data diedit admin lain)
          // panggil _loadData() untuk memperbarui kalkulasi NW/TNW dan rekomendasi vendor.
          if (data.isNotEmpty) {
            _loadData();
          }
        });
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel(); // WAJIB: mematikan stream saat keluar halaman
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      // // 1. Ambil group_id
      // final header = await supabase
      //     .from('shipping_request')
      //     .select('group_id')
      //     .eq('shipping_id', widget.shippingId)
      //     .single();

// 1. Ambil data shipping utama
    final response = await supabase
        .from('shipping_request')
        .select('''
          *,
          delivery_order(
            *,
            customer(*),
            do_details(
              qty,
              material:material_id (material_id, material_name, net_weight)
            )
          ),
          shipping_assignments(
            status_assignment,
            responded_at,
            master_vendor(vendor_name)
          )
        ''')
        .eq('shipping_id', widget.shippingId)
        .single();

      // final groupId = header['group_id'];
      // dynamic rawData;

      // // 2. Ambil data dengan Join lengkap
      // String queryStr = '''
      //   *,
      //   delivery_order(
      //     *,
      //     customer(*),
      //     do_details(
      //       qty,
      //       material:material_id (
      //         material_id,
      //         material_name,
      //         net_weight
      //       )
      //     )
      //   )
      // ''';

      final groupId = response['group_id'];
    List<Map<String, dynamic>> shippingList = [];

    // 2. Jika grup, ambil semua anggota grup
    if (groupId != null) {
      final groupData = await supabase
          .from('shipping_request')
          .select('''
            *,
            delivery_order(
              *,
              customer(*),
              do_details(
                qty,
                material:material_id (material_id, material_name, net_weight)
              )
            ),
            shipping_assignments(
            status_assignment,
            responded_at,
            master_vendor(vendor_name)
          )
          ''')
          .eq('group_id', groupId);
      shippingList = List<Map<String, dynamic>>.from(groupData);
    } else {
      shippingList = [response];
    }

    // // --- Ambil Riwayat Reject Unik dari seluruh grup ---
    // List<Map<String, dynamic>> combinedRejectHistory = [];
    // for (var ship in shippingList) {
    //   final rejects = ship['shipping_assignments'] as List? ?? [];
    //   for (var r in rejects) {
    //     if (r['status_assignment'] == 'rejected') {
    //       combinedRejectHistory.add(r);
    //     }
    //   }
    // }
    // --- Ambil Riwayat Reject Unik dari seluruh grup ---
    // Gunakan Map untuk memastikan vendor_name bersifat unik
    Map<String, Map<String, dynamic>> uniqueRejects = {};
    
    for (var ship in shippingList) {
      final rejects = ship['shipping_assignments'] as List? ?? [];
      for (var r in rejects) {
        if (r['status_assignment'] == 'rejected') {
          String vendorName = r['master_vendor']?['vendor_name'] ?? "Unknown Vendor";
          // Masukkan ke Map, jika nama sama maka akan tertimpa (menjadi unik)
          uniqueRejects[vendorName] = r;
        }
      }
    }

    // Ubah kembali menjadi List untuk disimpan di state
    List<Map<String, dynamic>> combinedRejectHistory = uniqueRejects.values.toList();

      // if (groupId != null) {
      //   rawData = await supabase
      //       .from('shipping_request')
      //       .select(queryStr)
      //       .eq('group_id', groupId)
      //       .order('shipping_id');
      // } else {
      //   rawData = await supabase
      //       .from('shipping_request')
      //       .select(queryStr)
      //       .eq('shipping_id', widget.shippingId)
      //       .single();
      // }

      // List<Map<String, dynamic>> shippingList = groupId != null
      //     ? List<Map<String, dynamic>>.from(rawData)
      //     : [rawData];

     // 3. Inisialisasi variabel perhitungan
      List allDOs = [];
      List<String> cities = [];
      double sumQty = 0;
      double sumNW = 0;

      // 4. Loop data untuk mengumpulkan DO, Kota, dan Berat
      for (var ship in shippingList) {
        allDOs.addAll(ship['delivery_order'] ?? []);
        
        for (var doItem in ship['delivery_order'] ?? []) {
          // Ambil Kota Tujuan
          String city = doItem['customer']?['city']?.toString().trim() ?? "";
          if (city.isNotEmpty && !cities.contains(city)) {
            cities.add(city);
          }

          // Hitung Berat (Logika tidak berubah)
          for (var det in doItem['do_details'] ?? []) {
            double qty = double.tryParse(det['qty']?.toString() ?? "0") ?? 0;
            // Akses net_weight dari hasil join material
            double unitWeight = double.tryParse(det['material']?['net_weight']?.toString() ?? "0") ?? 0;
            
            sumNW += (qty * unitWeight);
            sumQty += qty;
          }
        }
      }
      

      // 🔥 3. AMBIL STORAGE LOCATION (Titik Muat)
    // Kita ambil dari baris pertama shipping_request_details
    // final detailsList = shippingList.first['shipping_request_details'] as List? ?? [];
    // String storageLoc = "";
    // if (detailsList.isNotEmpty) {
    //   storageLoc = detailsList[0]['storage_location']?.toString().trim() ?? "";
    // }

      // 3. Hitung Kota Tujuan
      
      // for (var doItem in allDOs) {
      //   var cust = doItem['customer'];
      //   if (cust is Map<String, dynamic>) {
      //     String city = cust['city']?.toString().trim() ?? "";
      //     if (city.isNotEmpty && !cities.contains(city)) {
      //       cities.add(city);
      //     }
     

      // 🔥 4. OPTIMASI: HITUNG TOTALITAS SEKALI SAJA DI SINI
      // double sumQty = 0;
      // double sumNW = 0;
      // for (var doItem in allDOs) {
      //   final details = doItem['do_details'] as List? ?? [];
      //   for (var det in details) {
      //     double qty = double.tryParse(det['qty']?.toString() ?? "0") ?? 0;
      //     dynamic matSource = det['material'];
      //     Map<String, dynamic>? materialMap;
      //     if (matSource is List && matSource.isNotEmpty) {
      //       materialMap = matSource.first as Map<String, dynamic>;
      //     } else if (matSource is Map<String, dynamic>) {
      //       materialMap = matSource;
      //     }
      //     double unitWeight = 0;
      //     if (materialMap != null) {
      //       var nw = materialMap['net_weight'];
      //       unitWeight = nw is num ? nw.toDouble() : (double.tryParse(nw?.toString() ?? "0") ?? 0);
      // //     }
      // for (var det in doItem['do_details'] ?? []) {
      //       double qty = double.tryParse(det['qty']?.toString() ?? "0") ?? 0;
      //       double unitWeight = double.tryParse(det['material']?['net_weight']?.toString() ?? "0") ?? 0;
      //     sumNW += (qty * unitWeight);
      //     sumQty += qty;
      //   }
      // }
      // }

String storageLoc = shippingList.first['storage_location']?.toString().trim() ?? "";
      double tnwCalculated = sumNW / 1000;
      String unitRequired = _determineUnitByWeight(tnwCalculated);

      // 5. Ambil vendor
      final responses = await Future.wait([
        supabase
            .from('vendor_transportasi')
            .select()
            .eq('type_unit', unitRequired)
            .filter('city', 'in', '(${cities.map((e) => '"$e"').join(',')})')
            .ilike('lokasi_gudang', '%$storageLoc%')
            .order('winner_rank', ascending: true)
            .order('alokasi_persen', ascending: false)
            .limit(4),
        supabase
            .from('vendor_transportasi')
            .select()
            .order('vendor_name', ascending: true)
      ]);

      setState(() {
        _shippingData = {
          'group_id': groupId,
          'shipping_id': widget.shippingId,
          'all_ids': shippingList.map((e) => e['shipping_id']).toList(), // Untuk proses insert assignments
          'so': shippingList.first['so'],
          'delivery_order': allDOs,
          'rdd': shippingList.first['rdd'],
          'stuffing_date': shippingList.first['stuffing_date'],
          'storage_location': storageLoc,
          'is_dedicated': shippingList.first['is_dedicated'],
          'reject_list': combinedRejectHistory, // Simpan riwayat reject di sini
        };
        targetCities = cities;
        _qtyTotal = sumQty;
        _nwTotal = sumNW;
        _tnwTotal = tnwCalculated;
        _requiredUnit = unitRequired;
        _recommendations = List<Map<String, dynamic>>.from(responses[0]);
        _allVendors = List<Map<String, dynamic>>.from(responses[1]);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Error loading data: $e", Colors.red);
    }
  }

  String _determineUnitByWeight(double ton) {
    if (ton <= 2.0) return "CDE";
    if (ton <= 4.0) return "CDD";
    if (ton <= 10.0) return "FUSO";
    return "WB";
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      // appBar: AppBar(
      //   title: const Text("Assign Transport Vendor", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      //   backgroundColor: Colors.red.shade700,
      //   foregroundColor: Colors.white,
      //   elevation: 0,
      // ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailedSummary(),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Text("🏆 REKOMENDASI VENDOR (SISTEM)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        ..._recommendations.map((v) => _buildVendorTile(v)),
                        if (_recommendations.isEmpty) _emptyRecommendationBox(),
                      ],
                    ),
                  
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Text("🔍 PILIH MANUAL VENDOR LAIN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildManualDropdown(),
                  ),
                ],
              ),
            ),
              ),  
              _buildBottomAction(),
              ],
            ),
    );
  }

  Widget _buildBottomAction() {
    return Container(
              decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -2))]),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildCalculationFooter(),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, minimumSize: const Size(double.infinity, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: _selectedVendor == null ? null : _processToDatabase,
                      child: const Text("KONFIRMASI & ASSIGN VENDOR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedSummary() {
    final data = _shippingData ?? {};
    final bool isGroup = data['group_id'] != null;
    final List dos = data['delivery_order'] ?? [];
    final List rejectList = data['reject_list'] ?? [];
    //final List rawDetails = data['shipping_request_details'] ?? [];
    //final Map<String, dynamic> details = rawDetails.isNotEmpty ? rawDetails[0] : {};

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: isGroup ? Colors.blue.shade700 : Colors.red.shade700, width: 6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(isGroup ? "📦 GROUP SHIPMENT" : "🚚 SINGLE SHIPMENT", style: TextStyle(fontWeight: FontWeight.bold, color: isGroup ? Colors.blue.shade900 : Colors.red.shade900, letterSpacing: 1.1, fontSize: 11)),
                    _buildBadge(data['storage_location']?.toString().toUpperCase() ?? "-", Colors.red.shade700),
                  ],
                ),
                const SizedBox(height: 8),
                Text(isGroup ? "ID Grup: ${data['group_id']}" : "ID Shipping: ${data['shipping_id']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _infoBox("RDD", _formatDate(data['rdd'])),
                    _infoBox("Stuffing", _formatDate(data['stuffing_date'])),
                    _infoBox("Dedicated", (data['is_dedicated'] ?? "-").toString().toUpperCase()),
                  ],
                ),
                // --- BAGIAN RIWAYAT REJECT ---
              if (rejectList.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange.shade900),
                          const SizedBox(width: 6),
                          Text("RIWAYAT REJECT VENDOR:", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ...rejectList.map((rej) {
                        String vendorName = rej['master_vendor']?['vendor_name'] ?? "Unknown Vendor";
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text("• $vendorName", style: const TextStyle(fontSize: 11, color: Colors.black87)),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ],
            ],
          ),
              
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.grey.shade100,
            child: const Text("DETAIL ITEM & CUSTOMER", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          ),
          ...dos.map((doItem) {
            final List doDetails = doItem['do_details'] ?? [];
            final String soNum = data['so']?.toString() ?? "-";
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.description_outlined, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text("DO: ${doItem['do_number']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 20),
                      Text("SO: $soNum", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text("👤 ${doItem['customer']?['customer_id'] ?? '-'} - ${doItem['customer']?['customer_name'] ?? '-'}", style: const TextStyle(fontSize: 12, color: Colors.black87)),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade200)),
                    child: Table(
                      columnWidths: const {0: FlexColumnWidth(1.2), 1: FlexColumnWidth(3), 2: FlexColumnWidth(0.8), 3: FlexColumnWidth(1.3)},
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: Colors.grey.shade200),
                          children: [
                            _tableCell("ID Mat", isBold: true, isHeader: true),
                            _tableCell("Name", isBold: true, isHeader: true),
                            _tableCell("Qty", isBold: true, align: TextAlign.right, isHeader: true),
                            _tableCell("NW (Kg)", isBold: true, align: TextAlign.right, isHeader: true),
                          ],
                        ),
                        ...doDetails.map((det) {
                          double qty = double.tryParse(det['qty']?.toString() ?? "0") ?? 0;
                          var matSource = det['material'];
                          Map<String, dynamic>? matData = (matSource is List && matSource.isNotEmpty) ? matSource[0] : (matSource is Map ? matSource as Map<String, dynamic> : null);
                          double unitWeight = double.tryParse(matData?['net_weight']?.toString() ?? "0") ?? 0;
                          return TableRow(
                            children: [
                              _tableCell(matData?['material_id']?.toString() ?? "-"),
                              _tableCell(matData?['material_name']?.toString() ?? "-"),
                              _tableCell(qty.toInt().toString(), align: TextAlign.right, isBold: true),
                              _tableCell((qty * unitWeight).toStringAsFixed(2), align: TextAlign.right),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildVendorTile(Map<String, dynamic> vendor) {
    bool hasManualSelection = _selectedVendor != null && !_recommendations.any((v) => v['id'] == _selectedVendor?['id']);
    bool isSelected = _selectedVendor?['id'] == vendor['id'];
    int rank = vendor['winner_rank'] ?? 0;
    bool isMatchingCity = targetCities.contains(vendor['city']);

    dynamic rawAlokasi = vendor['alokasi_persen'] ?? 0;
    double alokasiVal = double.tryParse(rawAlokasi.toString()) ?? 0;
    String displayPersen = alokasiVal <= 1 ? "${(alokasiVal * 100).toInt()}%" : "${alokasiVal.toInt()}%";

    return IgnorePointer(
      ignoring: hasManualSelection,
      child: Opacity(
        opacity: hasManualSelection ? 0.5 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.green.shade50 : Colors.white,
            border: Border.all(color: isSelected ? Colors.green : Colors.grey.shade300, width: isSelected ? 2 : 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: rank == 1 ? Colors.amber.shade100 : Colors.blue.shade50,
                child: Icon(rank == 1 ? Icons.workspace_premium : Icons.local_shipping, color: rank == 1 ? Colors.orange : Colors.blue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vendor['vendor_name'] ?? "-", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text("Unit: ${vendor['type_unit']} | Rank: $rank", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    Text("City: ${vendor['city']}", style: TextStyle(fontSize: 11, fontWeight: isMatchingCity ? FontWeight.bold : FontWeight.normal, color: isMatchingCity ? Colors.green.shade700 : Colors.grey.shade500)),
                    // 🔥 TAMBAHKAN INFORMASI GUDANG DI SINI
                  const SizedBox(height: 2),
                  Text("🏠 Gudang: ${vendor['lokasi_gudang'] ?? '-'}", 
                    style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
                    const SizedBox(height: 4),
                    _miniBadge("Alokasi: $displayPersen", Colors.green),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
              children: [
                if (isSelected)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.check_circle, color: Colors.red, size: 20),
                  ),

              SizedBox(
                width: 100,
                height: 32,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: isSelected ? Colors.red.shade700 : Colors.grey.shade100,
                    foregroundColor: isSelected ? Colors.white : Colors.black87,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: isSelected ? Colors.green.shade700 : Colors.grey.shade300)),
                  ),
                  onPressed: () {
                    setState(() {
                      if (isSelected) {
                        _selectedVendor = null;
                      } else {
                        _selectedVendor = vendor;
                      }
                    });
                  },
                  child: Text(isSelected ? "TERPILIH" : "PILIH", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
              ],
            ),
            ],
          ),        ),
      ),    );
  }

  Widget _buildManualDropdown() {
    bool isFromRec = _recommendations.any((v) => v['id'] == _selectedVendor?['id']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownSearch<Map<String, dynamic>>(
          items: (filter, loadProps) => _allVendors,
          compareFn: (item, sItem) => item['id'] == sItem['id'],
          filterFn: (vendor, filter) {
            final String query = filter.toLowerCase().trim();
            final String name = (vendor['vendor_name'] ?? "").toString().toLowerCase();
            final String city = (vendor['city'] ?? "").toString().toLowerCase();
             final String unit = (vendor['type_unit'] ?? "").toString().toLowerCase();
    final String warehouse = (vendor['lokasi_gudang'] ?? "").toString().toLowerCase();

            return name.contains(query) ||
           city.contains(query) ||
           unit.contains(query) ||
           warehouse.contains(query);

          },
          itemAsString: (v) => "${v['vendor_name']} (${v['type_unit']}) - ${v['city']}",
          selectedItem: isFromRec ? null : _selectedVendor,
          enabled: _selectedVendor == null || !isFromRec,
          onChanged: (val) => setState(() => _selectedVendor = val),
          popupProps: PopupProps.menu(
            showSearchBox: true,
            searchFieldProps: TextFieldProps(
              decoration: InputDecoration(hintText: "Cari nama vendor atau kota...", prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), isDense: true),
            ),
            itemBuilder: (context, item, isSelected, isHover) {
              double alokasiVal = double.tryParse(item['alokasi_persen'].toString()) ?? 0;
              String p = alokasiVal <= 1 ? "${(alokasiVal * 100).toInt()}%" : "${alokasiVal.toInt()}%";
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 0.5))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['vendor_name'] ?? "-", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                  //   Text("📍 ${item['city']} | Rank: ${item['winner_rank']} | Alokasi: $p", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  //   Text("🏠 Gudang: ${item['lokasi_gudang'] ?? '-'}", style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
                    Row(
                    children: [
                      _miniBadge("${item['type_unit']}", Colors.blue),
                      const SizedBox(width: 4),
                      _miniBadge("Rank ${item['winner_rank']}", Colors.orange),
                      const SizedBox(width: 4),
                      _miniBadge("Alokasi: $p", Colors.green),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // --- DETAIL LOKASI & GUDANG ---
                  Text(
                    "📍 ${item['city']} | 🏠 Gudang: ${item['lokasi_gudang'] ?? '-'}",
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                   ],
                ),
              );
            },
          ),
          decoratorProps: DropDownDecoratorProps(
            decoration: InputDecoration(
              hintText: "Pilih vendor manual...",
              filled: true,
              fillColor: isFromRec ? Colors.grey.shade100 : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              helperText: isFromRec ? "Pilihan terkunci (Rekomendasi terpilih)" : null,
            ),
          ),
        ),
        if (_selectedVendor != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: TextButton.icon(
              onPressed: () => setState(() => _selectedVendor = null),
              icon: const Icon(Icons.refresh, size: 14, color: Colors.red),
              label: const Text("Reset Pilihan", style: TextStyle(fontSize: 11, color: Colors.red)),
            ),
          ),
      ],
    );
  }

  Widget _buildCalculationFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade300))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildFooterItem("TOTAL QTY", _qtyTotal.toInt().toString(), Icons.inventory_2_outlined),
          _buildVerticalDivider(),
          _buildFooterItem("TOTAL NW", "${_nwTotal.toStringAsFixed(2)} KG", Icons.scale_outlined),
          _buildVerticalDivider(),
          _buildFooterItem("TOTAL TNW", "${_tnwTotal.toStringAsFixed(3)} TON", Icons.local_shipping_outlined, isHighlight: true),
        ],
      ),
    );
  }

  Widget _buildFooterItem(String label, String value, IconData icon, {bool isHighlight = false}) {
    return Column(children: [
      Row(children: [Icon(icon, size: 12, color: Colors.grey.shade600), const SizedBox(width: 4), Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade600, fontWeight: FontWeight.bold))]),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isHighlight ? Colors.red.shade700 : Colors.black87)),
    ]);
  }

  Widget _infoBox(String label, String value) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)), const SizedBox(height: 2), Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87))]));
  Widget _tableCell(String text, {bool isBold = false, TextAlign align = TextAlign.left, bool isHeader = false}) => Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), child: Text(text, textAlign: align, style: TextStyle(fontSize: 11, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: isHeader ? Colors.black : Colors.black87)));
  Widget _miniBadge(String label, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withOpacity(0.5), width: 0.5)), child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)));
  Widget _buildBadge(String text, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color, width: 1)), child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)));
  Widget _buildVerticalDivider() => Container(height: 25, width: 1, color: Colors.grey.shade300);
  Widget _emptyRecommendationBox() => Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)), child: const Center(child: Text("Tidak ada rekomendasi cocok.", style: TextStyle(fontSize: 11, color: Colors.grey))));
  void _showSnackBar(String msg, Color color) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating));
  String _formatDate(String? s) => s == null || s.isEmpty ? "-" : DateFormat('dd/MM/yy').format(DateTime.parse(s));
  //Future<void> _processToDatabase() async => _showSnackBar("Vendor ${_selectedVendor!['vendor_name']} dipilih!", Colors.green);

// Future<void> _processToDatabase() async {
//   if (_selectedVendor == null) return;

//   try {
//     setState(() => _isLoading = true);

//     // 1. Ambil NIK (No Vendor) dari vendor yang dipilih
//     final String? noVendor = _selectedVendor!['no_vendor'];

//     if (noVendor == null || noVendor.isEmpty) {
//       throw "Vendor ini tidak memiliki nomor vendor (NIK) yang valid.";
//     }

//     // 2. Cari UUID di tabel profiles yang NIK-nya cocok
//     final vendorProfile = await supabase
//         .from('profiles')
//         .select('id')
//         .eq('nik', noVendor)
//         .maybeSingle();

//     if (vendorProfile == null) {
//       throw "Akun vendor dengan NIK $noVendor belum terdaftar di sistem.";
//     }

//     final String vendorUuid = vendorProfile['id'];

//     // 3. Update Shipping Request (Single atau Group)
//     final groupId = _shippingData!['group_id'];
    
//     if (groupId != null) {
//       // Jika Group, update semua shipping yang memiliki group_id tersebut
//       await supabase
//           .from('shipping_request')
//           .update({
//             'assigned_vendor_id': vendorUuid,
//             'status': 'vendor assigned', // Ubah status agar muncul di dashboard vendor
//           })
//           .eq('group_id', groupId);
//     } else {
//       // Jika Single, update berdasarkan shipping_id saja
//       await supabase
//           .from('shipping_request')
//           .update({
//             'assigned_vendor_id': vendorUuid,
//             'status': 'vendor assigned',
//           })
//           .eq('shipping_id', widget.shippingId);
//     }

//     _showSnackBar("Berhasil! Request telah dikirim ke akun ${_selectedVendor!['vendor_name']}", Colors.green);
    
//     // Kembali ke halaman sebelumnya setelah sukses
//     if (mounted) Navigator.pop(context, true);

//   } catch (e) {
//     _showSnackBar("Gagal Assign: $e", Colors.red);
//   } finally {
//     if (mounted) setState(() => _isLoading = false);
//   }
// }

Future<void> _processToDatabase() async {
  if (_selectedVendor == null) return;

  try {
    setState(() => _isLoading = true);

    // // 1. Ambil regist_code dari vendor_transportasi
    // final String? registCode = _selectedVendor!['regist_code'];

    // if (registCode == null || registCode.isEmpty) {
    //   throw "Vendor ini tidak memiliki kode vendor (regist_code) yang valid.";
    // }
    // 1. Gunakan NIK dari vendor_transportasi (sesuai tabel baru)
    final String? nikVendor = _selectedVendor!['nik']; // Ambil NIK vendor

    if (nikVendor == null || nikVendor.isEmpty) {
      throw "Vendor ini tidak memiliki NIK yang valid di database.";
    }

//     final groupId = _shippingData!['group_id'];
// final String vendorName = _selectedVendor!['vendor_name'] ?? "Vendor";
//     // 2. Update shipping_request → assign ke VENDOR (bukan user)
//     if (groupId != null) {
//       await supabase
//           .from('shipping_request')
//           .update({
//             'vendor_id': registCode, // ✅ INI YANG PALING PENTING
//             'status': 'vendor assigned',
//           })
//           .eq('group_id', groupId);
//     } else {
//       await supabase
//           .from('shipping_request')
//           .update({
//             'vendor_id': registCode, // ✅ INI YANG PALING PENTING
//             'status': 'vendor assigned',
//           })
//           .eq('shipping_id', widget.shippingId);
//     }
// 2. Siapkan List ID yang akan di-assign (bisa single atau group)
    final List<int> idsToAssign = List<int>.from(_shippingData!['all_ids']);

    // 3. JALANKAN TRANSACTIONAL LOGIC
    // A. Masukkan data ke shipping_assignments
    final List<Map<String, dynamic>> assignmentData = idsToAssign.map((sid) => {
      'shipping_id': sid,
      'nik': nikVendor,
      'status_assignment': 'offered', // Status awal sesuai schema Anda
      'assigned_at': DateTime.now().toIso8601String(),
    }).toList();
    await supabase.from('shipping_assignments').insert(assignmentData);
// if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text("Berhasil! Shipping di-assign ke vendor $vendorName"),
//           backgroundColor: Colors.green,
//           duration: const Duration(seconds: 1), // Pesan muncul sebentar
//           // behavior: SnackBarBehavior.floating,
//         ),
//       );
//     }

    // _showSnackBar(
    //   "Berhasil! Shipping di-assign ke vendor ${_selectedVendor!['vendor_name']}",
    //   Colors.green,
    // );

    // if (mounted) Navigator.pop(context, true);
    // await Future.delayed(const Duration(milliseconds: 500));

    // if (mounted) {
    //   // Menutup halaman detail/assign dan kembali ke halaman sebelumnya
    //   // Parameter 'true' memberi tahu halaman asal untuk me-refresh data
    //   Navigator.of(context).pop(true);
    // }
// B. Update status di shipping_request utama
    await supabase
        .from('shipping_request')
        .update({'status': 'waiting vendor approval'}) // Status baru agar sinkron dengan 'offered'
        .inFilter('shipping_id', idsToAssign);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Berhasil! Vendor ditugaskan."), backgroundColor: Colors.green),
      );
    }

    // --- PERBAIKAN DI SINI ---
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      // 1. Ambil instance dari DynamicTabPage
      final dynamicTab = DynamicTabPage.of(context);
      
      if (dynamicTab != null) {
        // 2. Tutup tab saat ini secara otomatis
        // Fungsi ini akan menghapus tab dari list dan pindah ke tab sebelumnya
        dynamicTab.closeCurrentTab(); 
      } else {
        // Fallback jika dibuka via Navigator biasa
        Navigator.of(context).pop(true);
      }
    }

  } catch (e) {
    _showSnackBar("Gagal Assign: $e", Colors.red);
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
}