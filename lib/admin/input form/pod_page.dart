import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;

class PODReturnPage extends StatefulWidget {
  const PODReturnPage({super.key});

  @override
  State<PODReturnPage> createState() => _PODReturnPageState();
}

class _PODReturnPageState extends State<PODReturnPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  bool _isSearching = false;
  bool _isSaving = false;
  Map<String, dynamic>? _foundData;

  // Variabel Form
  DateTime? _tanggalBongkar;
  DateTime? _tanggalSJKembali;
  DateTime? _tanggalTibaCustomer;
  //DateTime? _tanggalPODAktual;
  int podAktual = 0;

// Tempat menyimpan daftar hari libur hasil download dari internet
  List<DateTime> _daftarLiburNasional = [];
  bool _isLoadingHolidays = true;

  @override
  void initState() {
    super.initState();
    // Ambil data libur tahun ini saat layar pertama kali dibuka
    _loadHolidaysData();
  }

  Future<void> _loadHolidaysData() async {
    int tahunSekarang = DateTime.now().year; // contoh: 2026
    
    // Panggil fungsi fetching yang dibuat tadi
    List<DateTime> dataLibur = await fetchIndonesianHolidays(tahunSekarang);

// JIKALAU API SEWAKTU-WAKTU GAGAL / BLOCKED
    if (dataLibur.isEmpty) {
      print('Memuat Hari Libur Nasional Cadangan untuk Tahun $tahunSekarang');
      dataLibur = [
        DateTime(tahunSekarang, 1, 1),   // Tahun Baru Masehi
        DateTime(tahunSekarang, 5, 1),   // Hari Buruh Internasional
        DateTime(tahunSekarang, 6, 1),   // Hari Lahir Pancasila
        DateTime(tahunSekarang, 8, 17),  // Hari Kemerdekaan RI
        DateTime(tahunSekarang, 12, 25), // Hari Raya Natal
        // Kamu bisa menambahkan tanggal libur tetap lainnya di sini jika diperlukan
      ];
    }
    setState(() {
      _daftarLiburNasional = dataLibur;
      _isLoadingHolidays = false; // Loading selesai
    });
  }

  // Fungsi Helper Hitung Selisih Hari (Lead Time Aktual)
  int _calculateLeadTime() {
    if (_tanggalTibaCustomer == null || _foundData?['stuffing_date'] == null) return 0;
    try {
    //   DateTime stuffing = DateTime.parse(_foundData!['stuffing_date']);
    //   return _tanggalTibaCustomer!.difference(stuffing).inDays;
    // } catch (e) {
    //   return 0;
    // }
    DateTime stuffingDate = DateTime.parse(_foundData!['stuffing_date']);
      DateTime arrivalDate = _tanggalTibaCustomer!;

      if (stuffingDate.isAfter(arrivalDate)) return 0;

      // Ubah daftar libur nasional ke format string "YYYY-MM-DD" agar pencocokannya akurat
      List<String> formattedHolidays = _daftarLiburNasional.map((date) =>
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}"
      ).toList();

      int totalHariKerja = 0;
      DateTime currentDay = stuffingDate;

      while (currentDay.isBefore(arrivalDate) || currentDay.isAtSameMomentAs(arrivalDate)) {
        // Cek hari Minggu
        bool isSunday = currentDay.weekday == DateTime.sunday;

        // Cek hari Libur Nasional hasil API
        String currentDayStr = "${currentDay.year}-${currentDay.month.toString().padLeft(2, '0')}-${currentDay.day.toString().padLeft(2, '0')}";
        bool isHoliday = formattedHolidays.contains(currentDayStr);

        if (!isSunday && !isHoliday) {
          totalHariKerja++;
        }

        currentDay = currentDay.add(const Duration(days: 1));
      }

      int hasilAkhir = totalHariKerja - 1;
      return hasilAkhir < 0 ? 0 : hasilAkhir;

    } catch (e) {
      return 0;
    }
  }

// --- Fungsi Helper Hitung Selisih Hari Kerja (POD Aktual) ---
int _calculatePODActual() {
  // 1. Validasi awal: Jika tanggal bongkar atau tanggal SJ kembali belum diisi, kembalikan 0
  if (_tanggalBongkar == null || _tanggalSJKembali == null) return 0;
  
  // Pengecekan tambahan: Jika stuffing_date (BA26 di Excel) belum ada di data DO, kembalikan 0
  if (_foundData?['stuffing_date'] == null) return 0;

  // 2. Pengecekan tipe layanan (M26="LOCO" atau M26="TAKE AWAY")
 // String? serviceType = _foundData?['service_type']?.toString().toUpperCase();
  // if (serviceType == "LOCO" || serviceType == "TAKE AWAY") {
  //   return 0;
  // }

  try {
    DateTime startDate = _tanggalBongkar!;
    DateTime endDate = _tanggalSJKembali!;

    // Antisipasi jika user salah input tanggal (Tanggal Bongkar melewati Tanggal SJ Kembali)
    if (startDate.isAfter(endDate)) return 0;

    // 3. Ubah daftar libur nasional ke format string "YYYY-MM-DD" agar pencocokan akurat
    List<String> formattedHolidays = _daftarLiburNasional.map((date) =>
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}"
    ).toList();

    int totalHariKerja = 0;
    DateTime currentDay = startDate;

    // 4. Mulai perhitungan NETWORKDAYS.INTL (Opsi 11: Hanya Minggu yang libur)
    while (currentDay.isBefore(endDate) || currentDay.isAtSameMomentAs(endDate)) {
      // Cek apakah hari Minggu
      bool isSunday = currentDay.weekday == DateTime.sunday;

      // Cek apakah hari Libur Nasional
      String currentDayStr = "${currentDay.year}-${currentDay.month.toString().padLeft(2, '0')}-${currentDay.day.toString().padLeft(2, '0')}";
      bool isHoliday = formattedHolidays.contains(currentDayStr);

      // Jika bukan hari Minggu DAN bukan hari libur nasional, hitung sebagai hari kerja
      if (!isSunday && !isHoliday) {
        totalHariKerja++;
      }

      // Bergeser ke hari berikutnya
      currentDay = currentDay.add(const Duration(days: 1));
    }

    // 5. Dikurangi 1 di akhir rumus seperti: (...)-1
    int hasilAkhir = totalHariKerja - 1;
    
    // Antisipasi nilai minus
    return hasilAkhir < 0 ? 0 : hasilAkhir;

  } catch (e) {
    return 0;
  }
}
/// Fungsi untuk mengambil data hari libur nasional berdasarkan tahun tertentu
/// Fungsi untuk mengambil data hari libur nasional berdasarkan tahun tertentu
  Future<List<DateTime>> fetchIndonesianHolidays(int year) async {
    final String url = 'https://api-harilibur.vercel.app/api?year=$year';

    try {
      // Menambahkan Header User-Agent agar tidak diblokir oleh beberapa server API
      final response = await http.get(
        Uri.parse(url),
        headers: {
          "Accept": "application/json",
          "Access-Control-Allow-Origin": "*", // Antisipasi CORS di Web
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);
        List<DateTime> holidayList = [];

        for (var item in responseData) {
          if (item['holiday_date'] != null) {
            DateTime parsedDate = DateTime.parse(item['holiday_date']);
            holidayList.add(parsedDate);
          }
        }
        return holidayList;
      } else {
        print('Gagal memuat data API. Status: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      // Menampilkan log error di konsol, tapi tidak akan membuat aplikasi crash
      print('Sistem beralih ke data cadangan karena API gagal: $e');
      return [];
    }
  }  // --- FUNGSI CARI DO & GRUP ---
  Future<void> _searchDO() async {
    final search = _searchController.text.trim();
    if (search.isEmpty) return;

    setState(() {
      _isSearching = true;
      _foundData = null;
    });

    try {
      // 1. Cari shipping_id berdasarkan nomor DO
      final doRes = await supabase
          .from('delivery_order')
          .select('shipping_id')
          .eq('do_number', search)
          .maybeSingle();

      if (doRes == null) {
        _showSnackBar("Nomor DO tidak ditemukan", Colors.orange);
        setState(() => _isSearching = false);
        return;
      }

      final int shipId = doRes['shipping_id'];

      // 2. Ambil group_id
      final shipRes = await supabase
          .from('shipping_request')
          .select('group_id')
          .eq('shipping_id', shipId)
          .single();

      final int? groupId = shipRes['group_id'];

      // 3. Query Lengkap (Join ke Vendor Transportasi untuk LT & POD Standard)
      var query = supabase.from('shipping_request').select('''
            *,
            warehouse(warehouse_id, warehouse_name, lokasi),
            delivery_order(
              do_number,
              customer(customer_id, customer_name),
              do_details(qty, material(material_id, material_name, net_weight))
            ),
            shipping_assignments(
              status_assignment,
              responded_at,
              reason_rejected,
              catatan,
              id_vendor_details,
              master_vendor:nik (vendor_name),
              vendor_transportasi:id_vendor_details(
                lead_time,
                pod_return
              )
            )
          ''');

      dynamic finalData;
      if (groupId != null) {
        finalData = await query.eq('group_id', groupId);
      } else {
        finalData = await query.eq('shipping_id', shipId);
      }

      final List list = finalData as List;
      if (list.isNotEmpty) {
        final header = list[0];
        
        // Ambil data assignment aktif untuk Standard Info
        final assignments = header['shipping_assignments'] as List? ?? [];
        final activeAssign = assignments.firstWhere(
          (a) => !['rejected', 'rejected unit', 'cancel booking'].contains(a['status_assignment']),
          orElse: () => null,
        );

        setState(() {
          _foundData = {
            'group_id': groupId,
            'shipping_id': shipId,
            'warehouse': header['warehouse'] != null 
                ? "${header['warehouse']['lokasi']} - ${header['warehouse']['warehouse_name']}" 
                : "-",
            'stuffing_date': header['stuffing_date'],
            'is_dedicated': header['is_dedicated'],
            
            // Info Standar dari Database (Hanya Tampil)
            'std_lead_time': activeAssign?['vendor_transportasi']?['lead_time'] ?? 0,
            'std_pod_return': activeAssign?['vendor_transportasi']?['pod_return'] ?? "-",

            'delivery_order': list.expand((s) {
              final List dos = s['delivery_order'] as List? ?? [];
              return dos.map((d) {
                d['rdd_origin'] = s['rdd'];
                d['so_origin'] = s['so'];
                return d;
              });
            }).toList(),

            'reject_list': list.expand((s) {
              final List assigns = s['shipping_assignments'] as List? ?? [];
              return assigns.where((a) => ['rejected', 'rejected unit', 'cancel booking'].contains(a['status_assignment']));
            }).toList(),

            'all_shipping_ids': list.map((e) => e['shipping_id'] as int).toList(),
          };
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
      _showSnackBar("Terjadi kesalahan saat mencari data", Colors.red);
    } finally {
      setState(() => _isSearching = false);
    }
  }

  // --- FUNGSI SIMPAN POD ---
  Future<void> _submitPOD() async {
    if (_tanggalBongkar == null || _tanggalSJKembali == null || 
        _tanggalTibaCustomer == null) {
      _showSnackBar("Mohon lengkapi semua tanggal!", Colors.orange);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        _showSnackBar("Sesi Anda telah berakhir, silakan login ulang.", Colors.red);
        return;
      }

      // 2. Ambil data 'name' dari tabel 'profiles' berdasarkan UUID user
      final profileRes = await supabase
          .from('profiles')
          .select('name')
          .eq('id', currentUser.id)
          .maybeSingle();

      // Gunakan nama dari profile. Jika kosong/null, gunakan email sebagai cadangan
      final String activeUserName = profileRes?['name'] ?? currentUser.email ?? 'System POD';
      final List<int> shipIds = List<int>.from(_foundData!['all_shipping_ids']);

      await supabase.from('shipping_assignments').update({
        'tanggal_bongkar': _tanggalBongkar!.toIso8601String(),
        'sj_kembali': _tanggalSJKembali!.toIso8601String(),
        'tanggal_tiba_customer': _tanggalTibaCustomer!.toIso8601String(),
        'lead_time_aktual': _calculateLeadTime(),
        'pod_return_aktual': _calculatePODActual(),
        'status_assignment': 'completed',
        'createdpod_at': DateTime.now().toIso8601String(),
        'createdpod_by': activeUserName,
      }).inFilter('shipping_id', shipIds);

// B. Update tabel shipping_request menjadi 'completed' (TAMBAHAN BARU)
      await supabase.from('shipping_request').update({
        'status': 'completed',
      }).inFilter('shipping_id', shipIds);
// Menggunakan DateFormat untuk mengirim tanggal saja ke database
// await supabase.from('shipping_assignments').update({
//   'tanggal_bongkar': DateFormat('yyyy-MM-dd').format(_tanggalBongkar!),
//   'sj_kembali': DateFormat('yyyy-MM-dd').format(_tanggalSJKembali!),
//   'tanggal_tiba_customer': DateFormat('yyyy-MM-dd').format(_tanggalTibaCustomer!),
//   // ...
// });

      _showSnackBar("Data POD Berhasil Disimpan", Colors.green);
      setState(() {
        _foundData = null;
        _searchController.clear();
        _tanggalBongkar = _tanggalSJKembali = _tanggalTibaCustomer = null;
      });
    } catch (e) {
      _showSnackBar("Gagal menyimpan: $e", Colors.red);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          _buildSearchBox(),
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : (_foundData == null ? _buildEmptySearch() : _buildFormContent()),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: "Masukkan Nomor DO...",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _searchDO(),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _searchDO,
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade800,
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20)),
            child: const Text("CARI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildFormContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildDetailedSummary(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("INPUT DETAIL PENGIRIMAN & POD", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 16),
                _buildDatePicker("Tanggal Tiba di Customer", _tanggalTibaCustomer, (val) => setState(() => _tanggalTibaCustomer = val)),
                // const SizedBox(height: 12),
                // Container(
                //   padding: const EdgeInsets.all(16),
                //   decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade100)),
                //   child: Row(
                //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //     children: [
                //       const Text("Lead Time Aktual:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                //       Text("${_calculateLeadTime()} Hari", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                //     ],
                //   ),
                // ),
                const SizedBox(height: 12),
                _buildDatePicker("Tanggal Bongkar / Unloading", _tanggalBongkar, (val) => setState(() => _tanggalBongkar = val)),
                const SizedBox(height: 12),
                // _buildDatePicker("Tanggal POD Aktual", _tanggalPODAktual, (val) => setState(() => _tanggalPODAktual = val)),
                // const SizedBox(height: 12),
                _buildDatePicker("Tanggal SJ Kembali ke Logistik", _tanggalSJKembali, (val) => setState(() => _tanggalSJKembali = val)),
                const SizedBox(height: 32),
                // Container(
                //   padding: const EdgeInsets.all(16),
                //   decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade100)),
                //   child: Row(
                //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //     children: [
                //       const Text("Lead Time Aktual:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                //       Text("${_calculateLeadTime()} Hari", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                //       //const SizedBox(width: 50),
                //     const Text("POD Aktual:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                //       Text("${_calculatePODActual()} Hari", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                    
                //     ],
                //   ),
                  
                // ),
                Row(
  children: [
    // KOTAK 1: LEAD TIME AKTUAL
    Expanded(
      child: Container(
        padding: const EdgeInsets.all(12), // Sedikit diperkecil agar pas di dalam kotak kecil
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade100),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Lead Time Aktual:",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4), // Jarak vertikal antara label dan angka
            Text(
              "${_calculateLeadTime()} Hari",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
            ),
          ],
        ),
      ),
    ),

    const SizedBox(width: 12), // JARAK ANTARA KOTAK KIRI DAN KOTAK KANAN

    // KOTAK 2: POD AKTUAL
    Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade100),
        ),
       child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "POD Aktual:",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4), // Jarak vertikal antara label dan angka
            Text(
              "${_calculatePODActual()} Hari",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
            ),
          ],
        ),
      ),
    ),
  ],
),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _submitPOD,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text("SIMPAN DATA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                //const SizedBox(height: 50),
                //const SizedBox(height: 12),
                
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedSummary() {
    final data = _foundData ?? {};
    final bool isGroup = data['group_id'] != null;
    final List dos = (data['delivery_order'] as List? ?? []);
    final List rejectList = (data['reject_list'] as List? ?? []);

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
                    Text(isGroup ? "📦 GROUP SHIPMENT" : "🚚 SINGLE SHIPMENT", style: TextStyle(fontWeight: FontWeight.bold, color: isGroup ? Colors.blue.shade900 : Colors.red.shade900, letterSpacing: 1.1, fontSize: 12)),
                    _buildBadge(data['warehouse']?.toString().toUpperCase() ?? "-", Colors.red.shade700),
                  ],
                ),
                const SizedBox(height: 8),
                Text(isGroup ? "ID Grup: ${data['group_id']}" : "ID Shipping: ${data['shipping_id']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _infoBox("Stuffing Date", _formatDate(data['stuffing_date'])),
                    const SizedBox(width: 80),
                    _infoBox("Lead Time Standard", "${data['std_lead_time']} Hari"),
                    const SizedBox(width: 80),
                    _infoBox("POD Standard", "${data['std_pod_return']} Hari"),
                    const Spacer(),
                    _infoBox("Status", (data['is_dedicated'] ?? "-").toString().toUpperCase()),
                  ],
                ),
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
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: Colors.red.shade700),
                      const SizedBox(width: 6),
                      Text("RDD: ${_formatDate(doItem['rdd_origin'])}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Text("DO: ${doItem['do_number']} | SO: ${doItem['so_origin'] ?? '-'}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  // Text("👤 ${doItem['customer']?['customer_name'] ?? '-'}", style: const TextStyle(fontSize: 12, color: Colors.black87)),
                  // const SizedBox(height: 10),
                   Row(
                    children: [
                      const Icon(Icons.description_outlined, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text("DO: ${doItem['do_number']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 20),
                      Text("SO: ${doItem['so_origin'] ?? '-'}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text("👤 ${doItem['customer']?['customer_id'] ?? '-'} - ${doItem['customer']?['customer_name'] ?? '-'}", style: const TextStyle(fontSize: 12, color: Colors.black87)),
                  const SizedBox(height: 10),
                  Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade300)),
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
                          var mat = det['material'] ?? {};
                          double nw = double.tryParse(mat['net_weight']?.toString() ?? "0") ?? 0;
                          return TableRow(
                            children: [
                              _tableCell(mat['material_id']?.toString() ?? "-"),
                              _tableCell(mat['material_name'] ?? "-"),
                              _tableCell(qty.toInt().toString(), align: TextAlign.right, isBold: true),
                              _tableCell((qty * nw).toStringAsFixed(2), align: TextAlign.right),
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

  Widget _infoBox(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)), Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))]);

  Widget _tableCell(String text, {bool isBold = false, TextAlign align = TextAlign.left, bool isHeader = false}) => Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), child: Text(text, textAlign: align, style: TextStyle(fontSize: 11, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: isHeader ? Colors.black : Colors.black87)));

  Widget _buildBadge(String text, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color, width: 1)), child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)));

  String _formatDate(String? d) => d == null || d.isEmpty ? "-" : DateFormat('dd MMM yyyy').format(DateTime.parse(d));

  Widget _buildDatePicker(String label, DateTime? selectedDate, Function(DateTime) onSelect) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(context: context, initialDate: selectedDate ?? DateTime.now(), firstDate: DateTime(2023), lastDate: DateTime.now());
        if (picked != null) onSelect(picked);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(8), color: Colors.white),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)), Text(selectedDate == null ? "Pilih Tanggal" : DateFormat('dd MMMM yyyy').format(selectedDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))]),
            const Icon(Icons.calendar_today, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySearch() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.document_scanner_outlined, size: 80, color: Colors.grey.shade200), const SizedBox(height: 16), const Text("Cari Nomor DO untuk memulai POD", style: TextStyle(color: Colors.grey))]));

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating));
  }
}