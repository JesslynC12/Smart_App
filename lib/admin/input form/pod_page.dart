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

  DateTime? _tanggalBongkar;
  DateTime? _tanggalSJKembali;
  DateTime? _tanggalTibaCustomer;
  int podAktual = 0;

  List<DateTime> _daftarLiburNasional = [];
  //bool _isLoadingHolidays = true;

  @override
  void initState() {
    super.initState();
    _loadHolidaysData();
  }

  Future<void> _loadHolidaysData() async {
    int tahunSekarang = DateTime.now().year;
    
    List<DateTime> dataLibur = await getHolidays(tahunSekarang);

    if (dataLibur.isEmpty) {
      //print('Memuat Hari Libur Nasional Cadangan untuk Tahun $tahunSekarang');
      dataLibur = [
        DateTime(tahunSekarang, 1, 1),
        DateTime(tahunSekarang, 5, 1),
        DateTime(tahunSekarang, 6, 1),   
        DateTime(tahunSekarang, 8, 17), 
        DateTime(tahunSekarang, 12, 25), 
      ];
    }
    setState(() {
      _daftarLiburNasional = dataLibur;
    });
  }

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

        bool isSunday = currentDay.weekday == DateTime.sunday;
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

int _calculatePODActual() {
  if (_tanggalBongkar == null || _tanggalSJKembali == null) return 0;
  if (_foundData?['stuffing_date'] == null) return 0;
  try {
    DateTime startDate = _tanggalBongkar!;
    DateTime endDate = _tanggalSJKembali!;

    if (startDate.isAfter(endDate)) return 0;

    List<String> formattedHolidays = _daftarLiburNasional.map((date) =>
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}"
    ).toList();

    int totalHariKerja = 0;
    DateTime currentDay = startDate;

    while (currentDay.isBefore(endDate) || currentDay.isAtSameMomentAs(endDate)) {
      bool isSunday = currentDay.weekday == DateTime.sunday;

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
Future<List<DateTime>> getHolidays(int year) async {
  final supabase = Supabase.instance.client;

  // Cache first
  final cached = await supabase
      .from('holidays')
      .select('date')
      .eq('year', year);

  if (cached.isNotEmpty) {
    return cached
        .map<DateTime>(
          (row) => DateTime.parse(row['date'] as String),
        )
        .toList()
      ..sort();
  }

  List<DateTime> dates = [];

  try {
    final response = await http.get(
      Uri.parse(
        'https://libur.deno.dev/api?year=$year',
      ),
    );

    if (response.statusCode == 200) {
      final holidays =
          jsonDecode(response.body) as List<dynamic>;

      dates = holidays
          .where(
            (holiday) =>
                holiday['is_national_holiday'] == true,
          )
          .map<DateTime>(
            (holiday) =>
                DateTime.parse(holiday['date'] as String),
          )
          .toSet()
          .toList()
        ..sort();
    }
  } catch (_) {
    // Fall through to default holidays
  }

  // Fallback if API/cache unavailable
  if (dates.isEmpty) {
    dates = _defaultIndonesiaHolidays(year);
  }

  // Cache
  if (dates.isNotEmpty) {
    await supabase.from('holidays').upsert(
      dates
          .map(
            (date) => {
              'year': year,
              'date': date.toIso8601String().split('T').first,
            },
          )
          .toList(),
      onConflict: 'year,date',
    );
  }

  return dates;
}

List<DateTime> _defaultIndonesiaHolidays(int year) {
  return [
    DateTime(year, 1, 1),   // Tahun Baru Masehi
    DateTime(year, 5, 1),   // Hari Buruh
    DateTime(year, 6, 1),   // Hari Lahir Pancasila
    DateTime(year, 8, 17),  // Hari Kemerdekaan
    DateTime(year, 12, 25), // Natal
  ];
}
// Future<List<DateTime>> fetchIndonesianHolidays(int year) async {
//   // Ubah sesuai dengan path endpoint API internal Anda
//   final String url = 'https://api.co.id/holidays?year=$year'; 

//   try {
//     final response = await http.get(
//       Uri.parse(url),
//       headers: {
//         "Accept": "application/json",
//         // Jika API internal membutuhkan autentikasi (Token/API Key), tambahkan di sini:
//         // "Authorization": "Bearer TOKEN_ANDA", 
//       },
//     );

//     if (response.statusCode == 200) {
//       final List<dynamic> responseData = json.decode(response.body);
//       List<DateTime> holidayList = [];

//       for (var item in responseData) {
//         // PERHATIAN: Sesuaikan key 'holiday_date' jika API internal Anda menggunakan nama field berbeda
//         // Contoh: jika di API Anda namanya 'tanggal', ubah menjadi item['tanggal']
//         if (item['holiday_date'] != null) {
//           DateTime parsedDate = DateTime.parse(item['holiday_date']);
//           holidayList.add(parsedDate);
//         }
//       }
//       return holidayList;
//     } else {
//       return [];
//     }
//   } catch (e) {
//     debugPrint('Gagal memuat API internal: $e');
//     return [];
//   }
// }

  Future<void> _searchDO() async {
    final search = _searchController.text.trim();
    if (search.isEmpty) return;

    setState(() {
      _isSearching = true;
      _foundData = null;
    });

    try {
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
      final assignmentCheck = await supabase
          .from('shipping_assignments')
          .select('status_assignment')
          .eq('shipping_id', shipId);

      final List assignmentsList = assignmentCheck as List;
      bool alreadyCompleted = assignmentsList.any((a) => 
        a['status_assignment']?.toString().toLowerCase() == 'completed'
      );

      if (alreadyCompleted) {
        setState(() => _isSearching = false);
        _searchController.clear(); 
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: const Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 28),
                  SizedBox(width: 10),
                  Text("Data Sudah Ada", style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: const Text(
                "POD untuk nomor DO ini sudah pernah diinput sebelumnya dan berstatus Completed.",
                style: TextStyle(fontSize: 14),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade800,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("TUTUP", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        }
        return;
      }
      final shipRes = await supabase
          .from('shipping_request')
          .select('group_id')
          .eq('shipping_id', shipId)
          .single();

      final int? groupId = shipRes['group_id'];
      var query = supabase.from('shipping_request').select('''
            *,
            warehouse(warehouse_id, warehouse_name, lokasi),
            delivery_order(
              do_number,
              customer(customer_id, customer_name, city, area),
              do_details(qty, material(material_id, material_name, net_weight))
            ),
            shipping_assignments(
              status_assignment,
              responded_at,
              reason_rejected,
              catatan,
              id_vendor_details,
              no_polisi,
              checkIn_at,        
              keluar_at,
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
            
            'no_polisi': activeAssign?['no_polisi'] ?? "-",
            'checkin_at': activeAssign?['checkIn_at'],
            'keluar_at': activeAssign?['keluar_at'],
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
      final profileRes = await supabase
          .from('profiles')
          .select('name')
          .eq('id', currentUser.id)
          .maybeSingle();
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

      await supabase.from('shipping_request').update({
        'status': 'completed',
      }).inFilter('shipping_id', shipIds);
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
                const SizedBox(height: 12),
                _buildDatePicker("Tanggal Bongkar / Unloading", _tanggalBongkar, (val) => setState(() => _tanggalBongkar = val)),
                const SizedBox(height: 12),
                // _buildDatePicker("Tanggal POD Aktual", _tanggalPODAktual, (val) => setState(() => _tanggalPODAktual = val)),
                // const SizedBox(height: 12),
                _buildDatePicker("Tanggal SJ Kembali ke Logistik", _tanggalSJKembali, (val) => setState(() => _tanggalSJKembali = val)),
                const SizedBox(height: 32),
                Row(
  children: [
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
              "Lead Time Aktual:",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              "${_calculateLeadTime()} Hari",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
            ),
          ],
        ),
      ),
    ),

    const SizedBox(width: 12),
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
            const SizedBox(height: 4),
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
    //final List rejectList = (data['reject_list'] as List? ?? []);

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

          //const SizedBox(height: 3),
          //const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      Icon(Icons.local_shipping_outlined, size: 12, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text("No. Polisi: ${data['no_polisi']}", style: TextStyle(fontSize: 12,color: Colors.grey.shade800)),
                      const SizedBox(width: 16),
                      Icon(Icons.login_rounded, size: 12, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text("Check-in: ${data['checkin_at'] != null ? DateFormat('dd/MM HH:mm').format(DateTime.parse(data['checkin_at'])) : '-'}", style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                      const SizedBox(width: 16),
                      Icon(Icons.logout_rounded, size: 12, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text("Keluar: ${data['keluar_at'] != null ? DateFormat('dd/MM HH:mm').format(DateTime.parse(data['keluar_at'])) : '-'}", style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
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
                        }),
                      ],
                    ),
                  ),
                   const SizedBox(height: 12),
                  const Divider(height: 1),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _infoBox(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)), Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))]);

  Widget _tableCell(String text, {bool isBold = false, TextAlign align = TextAlign.left, bool isHeader = false}) => Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), child: Text(text, textAlign: align, style: TextStyle(fontSize: 11, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: isHeader ? Colors.black : Colors.black87)));

  Widget _buildBadge(String text, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color, width: 1)), child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)));

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