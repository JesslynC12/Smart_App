import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:project_app/auth/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;

class VendorEvaluationPage extends StatefulWidget {
  const VendorEvaluationPage({super.key});

  @override
  State<VendorEvaluationPage> createState() => _VendorEvaluationPageState();
}

class _VendorEvaluationPageState extends State<VendorEvaluationPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController _vendorSearchController = TextEditingController();

  bool _isLoading = false;
  String? _selectedNik;
  DateTimeRange? _selectedDateRange;
  List<Map<String, dynamic>> _evaluationData = [];
  List<int> _vendorDetailIds = [];
  String _selectedCarFilter = "Tidak Ada";
  RealtimeChannel? _evaluationChannel;

  @override
  void initState() {
    super.initState();
    _initRealtimeStreams();
  }

  @override
  void dispose() {
    if (_evaluationChannel != null) {
      _evaluationChannel!.unsubscribe();
      supabase.removeChannel(_evaluationChannel!);
    }
    _vendorSearchController.dispose();
    super.dispose();
  }

  void _initRealtimeStreams() {
    if (_evaluationChannel != null) {
      supabase.removeChannel(_evaluationChannel!);
    }
    _evaluationChannel = supabase
        .channel('vendor_evaluation_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'shipping_assignments',
          callback: (payload) async {
            debugPrint("Realtime Update: Performa Vendor Berubah");
            if (_selectedNik != null && _selectedDateRange != null) {
              await _fetchEvaluationData(isSilent: true);
            }
          },
        );

    _evaluationChannel!.subscribe((status, [error]) {
      if (status == RealtimeSubscribeStatus.channelError) {
        debugPrint("Realtime Channel Error: $error");
      }
    });
  }

  Future<List<Map<String, dynamic>>> _getVendorSuggestions(String query) async {
    var request = supabase.from('master_vendor').select('nik, vendor_name');

    if (query.isNotEmpty) {
      request = request.or('nik.ilike.%$query%, vendor_name.ilike.%$query%');
    }

    final response = await request
        .limit(10)
        .order('vendor_name', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> _fetchEvaluationData({bool isSilent = false}) async {
    if (_selectedNik == null ||
        _selectedDateRange == null ||
        _vendorDetailIds.isEmpty)
      return;
    if (!isSilent) setState(() => _isLoading = true);

    setState(() => _isLoading = true);
    try {
      final String startDate = _selectedDateRange!.start
          .toIso8601String()
          .split('T')[0];
      final String endDate = _selectedDateRange!.end.toIso8601String().split(
        'T',
      )[0];

      final response = await supabase
          .from('shipping_assignments')
          .select('''
          *,
          lead_time_aktual,
          pod_return_aktual,
      id_vendor_details,
      booking_history (
            id_history,
            jam_lama,
            jam_baru,
            created_at,
            changed_by
          ),
          vendor_transportasi!fk_vendor_transport_details (
            lead_time,
            pod_return
          ),
          shipping_request!inner (
            stuffing_date,
            group_id,
            delivery_order (
              do_number,
              customer (
                customer_name
              ),
              do_details (
                qty,
                material (
                  material_name
                )
              )
            )
          )
        ''')
          .inFilter('status_assignment', [
            'accepted',
            'check in',
            'loading',
            'weighbridge',
            'keluar',
            'completed',
            'cancel booking',
          ])
          .inFilter('id_vendor_details', _vendorDetailIds)
          .gte('shipping_request.stuffing_date', startDate)
          .lte('shipping_request.stuffing_date', endDate)
          .order('loading_at', ascending: false);

      setState(() {
        _evaluationData = List<Map<String, dynamic>>.from(response);
        // print("Data Ditemukan: ${_evaluationData.length}");
      });
    } catch (e) {
      debugPrint("Error Fetch: $e");
      _showSnackBar("Gagal memuat data: $e", Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildFilterArea(),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _evaluationData.isEmpty
                ? const Center(
                    child: Text(
                      "Silakan pilih Vendor & Periode untuk melihat data",
                    ),
                  )
                : _buildTableArea(),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getGroupedDisplayData(
    List<Map<String, dynamic>> source,
  ) {
    if (source.isEmpty) return [];

    Map<String, Map<String, dynamic>> groupedMap = {};

    for (var req in source) {
      final requestNode = req['shipping_request'];
      final int? gId = requestNode?['group_id'];
      String uniqueKey = gId != null ? "G_$gId" : "S_${req['id_assignment']}";

      if (!groupedMap.containsKey(uniqueKey)) {
        groupedMap[uniqueKey] = Map<String, dynamic>.from(req);
        groupedMap[uniqueKey]!['all_shipping_ids'] = {req['shipping_id']};

        List dos = requestNode?['delivery_order'] is List
            ? List.from(requestNode['delivery_order'])
            : [];
        groupedMap[uniqueKey]!['collective_dos'] = dos;
      } else {
        (groupedMap[uniqueKey]!['all_shipping_ids'] as Set).add(
          req['shipping_id'],
        );

        List existingDos = groupedMap[uniqueKey]!['collective_dos'];
        List newDos = requestNode?['delivery_order'] ?? [];

        for (var nDo in newDos) {
          bool isAlreadyExist = existingDos.any(
            (e) => e['do_number'] == nDo['do_number'],
          );
          if (!isAlreadyExist) {
            existingDos.add(nDo);
          }
        }
      }
    }
    return groupedMap.values.toList();
  }

  Widget _buildFilterArea() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Autocomplete<Map<String, dynamic>>(
                displayStringForOption: (option) =>
                    "${option['nik']} - ${option['vendor_name']}",

                optionsBuilder: (TextEditingValue textEditingValue) async {
                  return await _getVendorSuggestions(textEditingValue.text);
                },

                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4.0,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.5,
                        constraints: const BoxConstraints(maxHeight: 300),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (BuildContext context, int index) {
                            final Map<String, dynamic> option = options
                                .elementAt(index);
                            return InkWell(
                              onTap: () => onSelected(option),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 15,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "${option['nik']} - ${option['vendor_name']}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      option['vendor_name'],
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
                fieldViewBuilder:
                    (context, controller, focusNode, onFieldSubmitted) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          hintText: "Ketik untuk mencari...",
                          prefixIcon: const Icon(Icons.search, size: 20),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                        ),
                      );
                    },

                onSelected: (Map<String, dynamic> selection) async {
                  final nik = selection['nik'] as String;
                  final detailIds = await AuthService.getVendorDetailIds(nik);
                  setState(() {
                    _selectedNik = nik;
                    _vendorDetailIds = detailIds;
                    _vendorSearchController.text = nik;
                  });
                  _fetchEvaluationData();
                },
              ),
            ),
          ),

          const SizedBox(width: 8),

          Expanded(
            flex: 2,
            child: InkWell(
              onTap: _pickDateRange,
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: _selectedDateRange != null
                      ? Colors.red.shade700
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.date_range,
                      size: 18,
                      color: _selectedDateRange != null
                          ? Colors.white
                          : Colors.black87,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _selectedDateRange == null
                            ? "Pilih Periode"
                            : "${DateFormat('dd/MM').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM').format(_selectedDateRange!.end)}",
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _selectedDateRange != null
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          Container(
            height: 55,
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: IconButton(
              onPressed: _exportToExcel,
              icon: const Icon(
                Icons.file_download,
                color: Colors.green,
                size: 26,
              ),
              tooltip: "Export Excel",
            ),
          ),
        ],
      ),
    );
  }

  double hitungKetepatanJumlahPemasukan(Map<String, dynamic> data) {
    try {
      String? status = data['status_assignment']?.toString().toLowerCase();

      if (status == 'cancel booking') {
        dynamic cancelledRaw = data['cancelled_at'];
        dynamic assignedRaw = data['assigned_at'];
        dynamic respondedRaw = data['responded_at'];

        if (cancelledRaw == null) return 5.0;

        DateTime cancelledAt = DateTime.parse(cancelledRaw.toString());

        dynamic baselineRaw = assignedRaw ?? respondedRaw;
        if (baselineRaw == null) return 5.0;

        DateTime baselineDate = DateTime.parse(baselineRaw.toString());

        DateTime cancelledDay = DateTime(
          cancelledAt.year,
          cancelledAt.month,
          cancelledAt.day,
        );
        DateTime baselineDay = DateTime(
          baselineDate.year,
          baselineDate.month,
          baselineDate.day,
        );

        if (cancelledDay.isAfter(baselineDay)) {
          return 1.0;
        } else {
          return 5.0;
        }
      }

      return 5.0;
    } catch (e) {
      debugPrint("Error Hitung Jumlah Pemasukan: $e");
      return 5.0;
    }
  }

  double hitungPengembalianPOD(Map<String, dynamic> data) {
    try {
      int? aktual = data['pod_return_aktual'] != null
          ? int.tryParse(data['pod_return_aktual'].toString())
          : null;

      var vendorTransport = data['vendor_transportasi'];
      int? standar =
          (vendorTransport != null && vendorTransport['pod_return'] != null)
          ? int.tryParse(vendorTransport['pod_return'].toString())
          : null;

      if (aktual == null || standar == null) {
        return 0.0;
      }
      int selisih = aktual - standar;

      if (selisih <= 0) {
        return 5.0;
      } else if (selisih <= 2) {
        return 3.0;
      } else {
        return 1.0;
      }
    } catch (e) {
      debugPrint("Error Hitung Doc Balik: $e");
      return 0.0;
    }
  }

  double hitungKetepatanWaktuKirim(Map<String, dynamic> data) {
    try {
      int? aktual = data['lead_time_aktual'] != null
          ? int.tryParse(data['lead_time_aktual'].toString())
          : null;

      var vendorTransport = data['vendor_transportasi'];
      int? standar =
          vendorTransport != null && vendorTransport['lead_time'] != null
          ? int.tryParse(vendorTransport['lead_time'].toString())
          : null;

      if (aktual == null || standar == null) {
        return 0.0;
      }

      if (aktual <= standar) {
        return 5.0;
      } else {
        return 1.0;
      }
    } catch (e) {
      debugPrint("Error Hitung Waktu Kirim: $e");
      return 0.0;
    }
  }

  double hitungKetepatanWaktuMasuk(Map<String, dynamic> data) {
    try {
      String? jamBookingRaw = data['jam_booking'];
      if (jamBookingRaw == null) return 0.0;

      String? stuffingDateRaw = data['shipping_request']?['stuffing_date']
          ?.toString();
      if (stuffingDateRaw == null) return 0.0;
      DateTime stuffingDate = DateTime.parse(stuffingDateRaw.split('T')[0]);

      String startTimeStr = jamBookingRaw.split(" - ")[0];
      List<String> timeParts = startTimeStr.split(":");
      int startHour = int.parse(timeParts[0]);
      int startMinute = int.parse(timeParts[1]);
      DateTime targetBookingTime = DateTime(
        stuffingDate.year,
        stuffingDate.month,
        stuffingDate.day,
        startHour,
        startMinute,
      );

      DateTime batasMandiriVendor = targetBookingTime.subtract(
        const Duration(hours: 2),
      );

      List historyReschedule = data['booking_history'] is List
          ? data['booking_history']
          : [];

      bool telatDanDiambilAlihAdmin = false;

      for (var history in historyReschedule) {
        if (history['created_at'] == null) continue;

        DateTime createdAt = DateTime.parse(history['created_at'].toString());
        String changedBy = history['changed_by'] ?? '';

        bool isChangedByAdmin = changedBy.toLowerCase() != 'vendor';

        if (isChangedByAdmin) {
          bool isSameDay =
              createdAt.year == stuffingDate.year &&
              createdAt.month == stuffingDate.month &&
              createdAt.day == stuffingDate.day;

          bool terjadiDiWaktuKritis = createdAt.isAfter(batasMandiriVendor);

          if (isSameDay && terjadiDiWaktuKritis) {
            telatDanDiambilAlihAdmin = true;
            break;
          }
        }
      }

      if (telatDanDiambilAlihAdmin) {
        return 1.0;
      } else {
        return 5.0;
      }
    } catch (e) {
      debugPrint("Error Hitung Ketepatan Waktu Masuk: $e");
      return 0.0;
    }
  }

  List<DataColumn> _buildColumns() {
    return [
      _buildLabel('Ship ID', 60),
      _buildLabel('Stuffing', 70),
      _buildLabel('No Polisi', 85),
      _buildLabel('No DO', 60),
      _buildLabel('Customer Tujuan', 190),
      _buildLabel('Ketepatan Waktu Pemasukan Harian', 70),
      _buildLabel('Ketepatan Jumlah Pemasukan Harian', 70),
      _buildLabel('Ketepatan Waktu Pengiriman', 70),
      _buildLabel('Pengembalian Dokumen Pengiriman', 80),
      _buildLabel('Kelayakan Unit', 70),
      _buildLabel('Total Nilai', 60),
      _buildLabel('Nilai LK3', 60),
    ];
  }

  DataColumn _buildLabel(String label, double width) {
    return DataColumn(
      label: SizedBox(
        width: width,
        child: Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          softWrap: true,
        ),
      ),
    );
  }

  Widget _buildTableArea() {
    final List<Map<String, dynamic>> displayData = _getGroupedDisplayData(
      _evaluationData,
    );

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.red.shade700),
            headingTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            headingRowHeight: 80,
            columnSpacing: 22,
            horizontalMargin: 12,
            columns: _buildColumns(),
            rows: const [],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DataTable(
                    headingRowHeight: 0,
                    dataRowMaxHeight: double.infinity,
                    dataRowMinHeight: 60,
                    columnSpacing: 22,
                    horizontalMargin: 12,
                    columns: _buildColumns(),
                    rows: displayData.map((data) {
                      double pWaktuMasuk = hitungKetepatanWaktuMasuk(data);
                      double pWaktuKirim = hitungKetepatanWaktuKirim(data);
                      double pJumlahPemasukan = hitungKetepatanJumlahPemasukan(
                        data,
                      );
                      double pDocBalik = hitungPengembalianPOD(data);
                      double pKelayakan = hitungKelayakanKendaraan(data);
                      double pLK3 = hitungNilaiLK3(data);
                      double pAkhir = hitungNilaiAkhir(data);

                      final List dos = data['collective_dos'] ?? [];
                      Set<String> uDOs = dos
                          .map((d) => d['do_number']?.toString() ?? "")
                          .toSet();
                      Set<String> uCusts = dos
                          .map(
                            (d) =>
                                d['customer']?['customer_name']?.toString() ??
                                "",
                          )
                          .toSet();

                      return DataRow(
                        cells: [
                          _buildValueCell(
                            (data['all_shipping_ids'] as Set).toList().join(
                              ", ",
                            ),
                            60,
                          ),
                          _buildValueCell(
                            _formatDate(
                              data['shipping_request']?['stuffing_date'],
                            ),
                            70,
                          ),
                          _buildValueCell(
                            data['no_polisi']?.toString() ?? "-",
                            85,
                          ),
                          DataCell(
                            SizedBox(
                              width: 60,
                              child: _buildNestedColumn(uDOs.toList()),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 190,
                              child: _buildNestedColumn(uCusts.toList()),
                            ),
                          ),
                          _buildScoreBadge(pWaktuMasuk, 70),
                          _buildScoreBadge(pJumlahPemasukan, 70),
                          _buildScoreBadge(pWaktuKirim, 70),
                          _buildScoreBadge(pDocBalik, 80),
                          _buildScoreBadge(pKelayakan, 70),
                          _buildScoreBadge(pAkhir, 60, isFinal: true),
                          _buildScoreBadge(pLK3, 60),
                        ],
                      );
                    }).toList(),
                  ),

                  _buildSummaryAverage(displayData),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  DataCell _buildScoreBadge(double val, double width, {bool isFinal = false}) {
    Color bg = Colors.grey.shade50;
    Color border = Colors.grey.shade300;
    Color text = Colors.grey.shade600;

    if (val > 0) {
      if (isFinal) {
        bg = Colors.blue.shade50;
        border = Colors.blue.shade200;
        text = Colors.blue.shade900;
      } else {
        if (val >= 5) {
          bg = Colors.green.shade50;
          border = Colors.green.shade200;
          text = Colors.green.shade900;
        } else if (val >= 3) {
          bg = Colors.orange.shade50;
          border = Colors.orange.shade200;
          text = Colors.orange.shade900;
        } else {
          bg = Colors.red.shade50;
          border = Colors.red.shade200;
          text = Colors.red.shade900;
        }
      }
    }

    return DataCell(
      SizedBox(
        width: width,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(width: 0.8, color: border),
            ),
            child: Text(
              val == 0
                  ? "-"
                  : (isFinal ? val.toStringAsFixed(2) : val.toStringAsFixed(0)),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: text,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryAverage(List<Map<String, dynamic>> displayData) {
    const double labelWidth = 180.0;
    const double paddingKiri = 415.0;
    double grandTotal = _calculateGrandTotal(displayData);
    double finalPercentage = grandTotal > 0 ? ((grandTotal - 1) / 4) * 100 : 0;
    if (finalPercentage < 0) finalPercentage = 0;
    if (finalPercentage > 100) finalPercentage = 100;
    String grade = _calculateGrade(finalPercentage);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 415),
              const Text(
                "RATA-RATA PERFORMA:",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 13),
              _avgBox("", _calculateColumnAvg(displayData, 'waktu_masuk')),
              const SizedBox(width: 28),
              _avgBox("", _calculateColumnAvg(displayData, 'jumlah_masuk')),
              const SizedBox(width: 25),
              _avgBox("", _calculateColumnAvg(displayData, 'waktu_kirim')),
              const SizedBox(width: 29),
              _avgBox("", _calculateColumnAvg(displayData, 'doc_balik')),
              const SizedBox(width: 30),
              _avgBox("", _calculateColumnAvg(displayData, 'kelayakan')),
              const SizedBox(width: 15),
              _avgBox(
                "",
                _calculateColumnAvg(displayData, 'akhir'),
                isFinal: true,
              ),
              const SizedBox(width: 20),
              _avgBox(
                "",
                _calculateColumnAvg(displayData, 'lk3'),
                isFinal: true,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const SizedBox(width: 330),
              const Text(
                "TEMUAN KASUS / CAR:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
              const SizedBox(width: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: DropdownButton<String>(
                  value: _selectedCarFilter,
                  underline: const SizedBox(),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                  items: ["Tidak Ada", "1 - 2 CAR", "> 2 CAR"].map((
                    String val,
                  ) {
                    return DropdownMenuItem<String>(
                      value: val,
                      child: Text(val),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCarFilter = value!;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              const SizedBox(width: paddingKiri),
              SizedBox(
                width: labelWidth,
                child: const Text(
                  "NILAI AKHIR EVALUASI:",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: Colors.blue,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: 15),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade900,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      grandTotal.toStringAsFixed(2),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "(${finalPercentage.toStringAsFixed(1)}%)",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 25),
              const Text(
                "PERINGKAT: ",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _getGradeColor(grade),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  grade,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _avgBox(String label, double val, {bool isFinal = false}) {
    double percentage = 0.0;
    if (val > 0) {
      percentage = ((val - 1) / 4) * 100;
      if (percentage < 0) percentage = 0;
      if (percentage > 100) percentage = 100;
    }

    return Container(
      margin: const EdgeInsets.only(left: 10),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isFinal ? Colors.blue.shade700 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isFinal ? Colors.blue.shade900 : Colors.grey.shade300,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label.isNotEmpty)
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isFinal ? Colors.white70 : Colors.grey.shade600,
              ),
            ),

          Text(
            val == 0 ? "-" : val.toStringAsFixed(2),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isFinal ? Colors.white : Colors.black,
            ),
          ),

          if (val > 0)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: isFinal
                    ? Colors.blue.shade900.withValues(alpha: 0.5)
                    : Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                "${percentage.toStringAsFixed(1)}%",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isFinal ? Colors.white : Colors.green.shade700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  double _calculateGrandTotal(List<Map<String, dynamic>> displayData) {
    double avgAkhir = _calculateColumnAvg(displayData, 'akhir');
    double avgLK3 = _calculateColumnAvg(displayData, 'lk3');

    double minusPoin = 0;
    if (_selectedCarFilter == "1 - 2 CAR") minusPoin = 0.8;
    if (_selectedCarFilter == "> 2 CAR") minusPoin = 1.2;

    double total = (avgAkhir * 0.85) + (avgLK3 * 0.15) - minusPoin;
    return total < 0 ? 0 : total;
  }

  DataCell _buildValueCell(String txt, double width) => DataCell(
    SizedBox(
      width: width,
      child: Text(
        txt,
        style: const TextStyle(fontSize: 12),
        textAlign: TextAlign.center,
      ),
    ),
  );
  Widget _buildNestedColumn(List<String?> items) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (item) => Text(
              item ?? "-",
              style: const TextStyle(fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
          )
          .toList(),
    );
  }

  double hitungKelayakanKendaraan(Map<String, dynamic> data) {
    if (data['sisi_kanan'] == null && data['decision_for_unit'] == null) {
      return 0.0;
    }

    List<String> daftarKondisi = [
      "Berkarat",
      "Bagian Tajam",
      "Kotor",
      "Basah",
      "Berlubang",
      "Push In/Out",
    ];

    List<dynamic> gabunganSisi = [];
    List<String> kolomSisi = [
      'sisi_kanan',
      'sisi_kiri',
      'sisi_depan',
      'sisi_pintu_belakang',
      'sisi_atap',
      'sisi_lantai',
    ];

    for (var kolom in kolomSisi) {
      var val = data[kolom];
      if (val != null && val is List) {
        gabunganSisi.addAll(val);
      }
    }

    double totalSkorFisik = 0;
    for (var kondisi in daftarKondisi) {
      int jumlahMuncul = gabunganSisi.where((item) {
        if (item == null) return false;
        return item.toString().trim().toLowerCase() == kondisi.toLowerCase();
      }).length;

      if (jumlahMuncul > 0) {
        totalSkorFisik += (jumlahMuncul * 0.1).ceilToDouble();
      }
    }

    int skorTambahan = 0;
    var kondisiLainnya = data['kondisi_tidak_standar_lainnya'];
    if (kondisiLainnya != null && kondisiLainnya is List) {
      skorTambahan = kondisiLainnya.length;
    }

    double totalTemuan = totalSkorFisik + skorTambahan;

    if (totalTemuan > 3) {
      return 1.0;
    } else if (totalTemuan > 0) {
      return 3.0;
    } else {
      return 5.0;
    }
  }

  double hitungNilaiLK3(Map<String, dynamic> data) {
    if (data['ganjal_roda'] == null && data['rem_handrem'] == null) {
      return 0.0;
    }

    int skorDokumen = 0;
    var dokumen = data['dokumen_pendukung'];
    if (dokumen != null && dokumen is List) {
      skorDokumen = dokumen.length * 5;
    }

    int skorGanjal = 0;
    String ganjal = (data['ganjal_roda']?.toString() ?? "")
        .trim()
        .toLowerCase();

    if (ganjal.contains("2 standard") || ganjal.contains("2 standar")) {
      skorGanjal = 10;
    } else if (ganjal.contains("1 standard") || ganjal.contains("1 standar")) {
      skorGanjal = 5;
    } else if (ganjal.contains("2 tidak standard") ||
        ganjal.contains("2 tidak standar")) {
      skorGanjal = 6;
    } else if (ganjal.contains("1 tidak standard") ||
        ganjal.contains("1 tidak standar")) {
      skorGanjal = 3;
    } else if (ganjal.contains("tidak ada")) {
      skorGanjal = -5;
    }

    int skorRem = 0;
    String rem = (data['rem_handrem']?.toString() ?? "").trim().toLowerCase();

    if (rem.contains("hand rem") || rem.contains("handrem")) {
      skorRem = 5;
    } else if (rem.contains("tidak ada") || rem.contains("tidak standard")) {
      skorRem = -5;
    }
    int skorAPD = 0;
    var apd = data['apd_supir'];
    if (apd != null && apd is List) {
      skorAPD = apd.length * 5;
    }

    int totalKalkulasi = skorDokumen + skorGanjal + skorRem + skorAPD;

    if (totalKalkulasi < 40) {
      return 1.0;
    } else if (totalKalkulasi < 43) {
      return 2.0;
    } else if (totalKalkulasi < 45) {
      return 3.0;
    } else if (totalKalkulasi < 50) {
      return 4.0;
    } else {
      return 5.0;
    }
  }

  double hitungNilaiAkhir(Map<String, dynamic> data) {
    double pWaktuMasuk = hitungKetepatanWaktuMasuk(data);
    double pJumlahMasuk = hitungKetepatanJumlahPemasukan(data);
    double pWaktuKirim = hitungKetepatanWaktuKirim(data);
    double pDocBalik = hitungPengembalianPOD(data);
    double pKelayakan = hitungKelayakanKendaraan(data);
    double total =
        (pWaktuMasuk * 0.20) +
        (pJumlahMasuk * 0.20) +
        (pWaktuKirim * 0.10) +
        (pDocBalik * 0.15) +
        (pKelayakan * 0.20);
    double hasilAkhir = total / 0.85;

    return hasilAkhir.clamp(0.0, 5.0);
  }

  double _calculateColumnAvg(
    List<Map<String, dynamic>> displayData,
    String type,
  ) {
    if (displayData.isEmpty) return 0.0;

    double totalPoints = 0;
    int countFilledRows = 0;

    for (var data in displayData) {
      double point = 0;

      switch (type) {
        case 'waktu_masuk':
          point = hitungKetepatanWaktuMasuk(data);
          break;
        case 'jumlah_masuk':
          point = hitungKetepatanJumlahPemasukan(data);
          break;
        case 'waktu_kirim':
          point = hitungKetepatanWaktuKirim(data);
          break;
        case 'doc_balik':
          point = hitungPengembalianPOD(data);
          break;
        case 'kelayakan':
          point = hitungKelayakanKendaraan(data);
          break;
        case 'lk3':
          point = hitungNilaiLK3(data);
          break;
        case 'akhir':
          point = hitungNilaiAkhir(data);
          break;
      }

      totalPoints += point;
      countFilledRows++;
    }

    return countFilledRows > 0 ? totalPoints / countFilledRows : 0.0;
  }

  String _calculateGrade(double percentage) {
    if (percentage >= 95) return "A";
    if (percentage >= 85) return "B";
    if (percentage >= 75) return "C";
    if (percentage >= 65) return "D";
    return "E";
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
      case "A":
        return Colors.green.shade700;
      case "B":
        return Colors.blue.shade700;
      case "C":
        return Colors.orange.shade700;
      case "D":
        return Colors.deepOrange;
      case "E":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _exportToExcel() async {
    if (_evaluationData.isEmpty) {
      _showSnackBar("Pilih data terlebih dahulu", Colors.orange);
      return;
    }
    if (_isLoading) return;
    try {
      setState(() => _isLoading = true);
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Evaluasi_Vendor'];
      excel.delete('Sheet1');

      String vendorDisplay = _selectedNik ?? "-";
      if (_evaluationData.isNotEmpty) {
        final firstRow = _evaluationData.first;
        final vendorName = firstRow['master_vendor']?['vendor_name'] ?? '';
        if (vendorName.isNotEmpty) {
          vendorDisplay = "$_selectedNik - $vendorName";
        }
      }
      String periodeText = _selectedDateRange == null
          ? "Semua Periode"
          : "${DateFormat('dd-MM-yyyy').format(_selectedDateRange!.start)} s.d ${DateFormat('dd-MM-yyyy').format(_selectedDateRange!.end)}";

      sheetObject.appendRow([
        TextCellValue('LAPORAN PENILAIAN PERFORMA VENDOR'),
      ]);
      sheetObject.appendRow([
        TextCellValue('Vendor:'),
        TextCellValue(vendorDisplay),
      ]);
      sheetObject.appendRow([
        TextCellValue('Periode:'),
        TextCellValue(periodeText),
      ]);
      sheetObject.appendRow([TextCellValue('')]);
      sheetObject.appendRow([
        TextCellValue('Ship ID'),
        TextCellValue('Stuffing'),
        TextCellValue('No Polisi'),
        TextCellValue('No DO'),
        TextCellValue('Customer'),
        TextCellValue('Ketepatan Waktu Pemasukan'),
        TextCellValue('Ketepatan Jumlah Pemasukan'),
        TextCellValue('Ketepatan Waktu Pengiriman'),
        TextCellValue('Pengembalian POD'),
        TextCellValue('Kelayakan Kendaraan'),
        TextCellValue('Total Nilai'),
        TextCellValue('Nilai LK3'),
      ]);

      final List<Map<String, dynamic>> displayData = _getGroupedDisplayData(
        _evaluationData,
      );

      for (var data in displayData) {
        final List dos = data['collective_dos'] ?? [];
        sheetObject.appendRow([
          TextCellValue((data['all_shipping_ids'] as Set).toList().join(", ")),
          TextCellValue(
            _formatDate(data['shipping_request']?['stuffing_date']),
          ),
          TextCellValue(data['no_polisi']?.toString() ?? "-"),
          TextCellValue(
            dos.map((d) => d['do_number']?.toString() ?? "").join(", "),
          ),
          TextCellValue(
            dos
                .map((d) => d['customer']?['customer_name']?.toString() ?? "")
                .join(", "),
          ),
          DoubleCellValue(hitungKetepatanWaktuMasuk(data)),

          DoubleCellValue(hitungKetepatanJumlahPemasukan(data)),
          DoubleCellValue(hitungKetepatanWaktuKirim(data)),
          DoubleCellValue(hitungPengembalianPOD(data)),
          DoubleCellValue(hitungKelayakanKendaraan(data)),
          DoubleCellValue(hitungNilaiAkhir(data)),
          DoubleCellValue(hitungNilaiLK3(data)),
        ]);
      }

      sheetObject.appendRow([TextCellValue('')]);
      double avgAkhir = _calculateColumnAvg(displayData, 'akhir');
      double avgLK3 = _calculateColumnAvg(displayData, 'lk3');
      double grandTotal = _calculateGrandTotal(displayData);
      double finalPercentage = grandTotal > 0
          ? ((grandTotal - 1) / 4) * 100
          : 0;
      String grade = _calculateGrade(finalPercentage.clamp(0, 100));
      sheetObject.appendRow([
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue('TOTAL RATA-RATA:'),
        DoubleCellValue(_calculateColumnAvg(displayData, 'waktu_masuk')),
        DoubleCellValue(_calculateColumnAvg(displayData, 'jumlah_masuk')),
        DoubleCellValue(_calculateColumnAvg(displayData, 'waktu_kirim')),
        DoubleCellValue(_calculateColumnAvg(displayData, 'doc_balik')),
        DoubleCellValue(_calculateColumnAvg(displayData, 'kelayakan')),
        DoubleCellValue(avgAkhir),
        DoubleCellValue(avgLK3),
      ]);

      sheetObject.appendRow([TextCellValue('')]);
      sheetObject.appendRow([
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
      ]);
      sheetObject.appendRow([
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue('Temuan Kasus/CAR:'),
        TextCellValue(_selectedCarFilter),
      ]);
      sheetObject.appendRow([
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue('Nilai Akhir Evaluasi:'),
        DoubleCellValue(double.parse(grandTotal.toStringAsFixed(2))),
      ]);
      sheetObject.appendRow([
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue('Persentase:'),
        TextCellValue("${finalPercentage.toStringAsFixed(1)}%"),
      ]);
      sheetObject.appendRow([
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue('Peringkat (Grade):'),
        TextCellValue(grade),
      ]);
      String safeName = vendorDisplay
          .replaceAll(RegExp(r'[^\w\s]+'), '')
          .replaceAll(' ', '_');
      String fileName =
          "Penilaian_${safeName}_${DateTime.now().millisecondsSinceEpoch}.xlsx";

      if (kIsWeb) {
        excel.save(fileName: fileName);
      } else {
        var fileBytes = excel.save();
        if (fileBytes == null) throw "Gagal merender byte data Excel";

        final directory = await getApplicationDocumentsDirectory();
        String filePath = '${directory.path}/$fileName';

        io.File file = io.File(filePath);
        if (await file.exists()) {
          await file.delete();
        }

        await file.create(recursive: true);
        await file.writeAsBytes(fileBytes);

        await OpenFile.open(filePath);
      }
      _showSnackBar("Ekspor berhasil", Colors.green);
    } catch (e) {
      debugPrint("Error Export: $e");
      _showSnackBar("Gagal ekspor: $e", Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDateRange() async {
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime(2100),
      initialDateRange: _selectedDateRange,
      locale: const Locale('id', 'ID'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.red.shade700,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
            ),
          ),

          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400, maxHeight: 550),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: child!,
              ),
            ),
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
      _fetchEvaluationData();
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "-";
    try {
      return DateFormat('dd/MM/yy').format(DateTime.parse(dateStr));
    } catch (e) {
      return "-";
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }
}
