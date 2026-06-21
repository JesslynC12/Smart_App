import 'package:flutter/material.dart';
import 'package:project_app/auth/auth_service.dart';
import 'package:project_app/vendor/booking_antrian.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:project_app/dynamic_tab_page.dart';

class VendorOnProcessPage extends StatefulWidget {
  final String vendorNik;
  const VendorOnProcessPage({super.key, required this.vendorNik});

  @override
  State<VendorOnProcessPage> createState() => _VendorOnProcessPageState();
}

class _VendorOnProcessPageState extends State<VendorOnProcessPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = false;
  List<Map<String, dynamic>> _dataList = [];
  List<Map<String, dynamic>> _filteredPlanningList = [];
  List<int> _vendorDetailIds = [];

  final TextEditingController _searchController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _dateFilterType = 'stuffing_date';
  RealtimeChannel? _onProcessChannel;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterDataBySearch);
    _loadVendorDetailIds().then((_) {
      _fetchOngoingOrders();
      _initRealtimeStreams();
    });
  }

  Future<void> _loadVendorDetailIds() async {
    _vendorDetailIds = await AuthService.getVendorDetailIds(widget.vendorNik);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _onProcessChannel?.unsubscribe();
    supabase.removeChannel(_onProcessChannel!);
    super.dispose();
  }

  void _initRealtimeStreams() {
    if (_vendorDetailIds.isEmpty) return;

    _onProcessChannel = supabase
        .channel('vendor_on_process_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'shipping_assignments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.inFilter,
            column: 'id_vendor_details',
            value: _vendorDetailIds,
          ),
          callback: (payload) {
            debugPrint("Realtime Update pada VendorOnProcessPage Terdeteksi!");

            _fetchOngoingOrders();
          },
        )
        .subscribe();
  }

  void _filterDataBySearch() {
    String query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _filteredPlanningList = List<Map<String, dynamic>>.from(_dataList);
      });
      return;
    }

    setState(() {
      _filteredPlanningList = _dataList.where((item) {
        final request = item['shipping_request'] ?? {};
        final List dos = request['delivery_order'] as List? ?? [];

        return dos.any((doItem) {
          final String doNumber = (doItem['do_number'] ?? '')
              .toString()
              .toLowerCase();
          return doNumber.contains(query);
        });
      }).toList();
    });
  }

  Future<void> _fetchOngoingOrders() async {
    try {
      setState(() => _isLoading = true);

      if (_vendorDetailIds.isEmpty) {
        setState(() {
          _dataList = [];
          _filteredPlanningList = [];
          _isLoading = false;
        });
        return;
      }

      String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);

      final response = await supabase
          .from('shipping_assignments')
          .select('''
          *,
           vendor_transportasi:id_vendor_details (
        qcf,
        city,
        area,
        type_unit
      ),
          shipping_request:shipping_id!inner (
            *,
            warehouse:warehouse(warehouse_id, warehouse_name, lokasi),
            delivery_order(
              do_number,
              customer(customer_id, customer_name),
              do_details(
                qty, 
                material:material_id (material_id, material_name)
              )
            )
          )
        ''')
          .inFilter('id_vendor_details', _vendorDetailIds)
          .inFilter('status_assignment', [
            'accepted',
            'check in',
            'loading',
            'kelayakan unit',
            'weighbridge',
            'keluar',
            'completed',
          ])
          .not('jam_booking', 'is', null)
          .eq('shipping_request.$_dateFilterType', formattedDate)
          .order('jam_booking', ascending: true);

      Map<String, Map<String, dynamic>> groupedMap = {};

      for (var item in response) {
        final req = item['shipping_request'];
        if (req == null) continue;

        String key = req['group_id'] != null
            ? "GROUP_${req['group_id']}"
            : "SINGLE_${req['shipping_id']}";
        if (!groupedMap.containsKey(key)) {
          Map<String, dynamic> mutableItem = Map<String, dynamic>.from(item);

          mutableItem['grouped_assignment_ids'] = [item['id_assignment']];
          mutableItem['grouped_shipping_ids'] = [item['shipping_id']];

          List dos = List.from(
            mutableItem['shipping_request']['delivery_order'] ?? [],
          );
          for (var d in dos) {
            d['rdd_origin'] = req['rdd'];
            d['parent_so'] = req['so'];
          }
          mutableItem['shipping_request']['delivery_order'] = dos;
          groupedMap[key] = mutableItem;
        } else {
          if (!groupedMap[key]!['grouped_assignment_ids'].contains(
            item['id_assignment'],
          )) {
            groupedMap[key]!['grouped_assignment_ids'].add(
              item['id_assignment'],
            );
          }
          if (!groupedMap[key]!['grouped_shipping_ids'].contains(
            item['shipping_id'],
          )) {
            groupedMap[key]!['grouped_shipping_ids'].add(item['shipping_id']);
          }
          List existingDos = List.from(
            groupedMap[key]!['shipping_request']['delivery_order'] ?? [],
          );
          List newDos = List.from(req['delivery_order'] ?? []);

          for (var ndo in newDos) {
            bool isDuplicate = existingDos.any(
              (existing) => existing['do_number'] == ndo['do_number'],
            );

            if (!isDuplicate) {
              ndo['rdd_origin'] = req['rdd'];
              ndo['parent_so'] = req['so'];
              existingDos.add(ndo);
            }
          }
          groupedMap[key]!['shipping_request']['delivery_order'] = existingDos;
        }
      }

      setState(() {
        _dataList = groupedMap.values.toList();
        _filteredPlanningList = List<Map<String, dynamic>>.from(_dataList);
        _isLoading = false;
      });
      _filterDataBySearch();
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Error: $e", Colors.red);
    }
  }

  Future<void> _cancelOrder(Map<String, dynamic> item, String reason) async {
    try {
      setState(() => _isLoading = true);

      final List<int> assignmentIds = List<int>.from(
        item['grouped_assignment_ids'] ?? [],
      );
      final List<int> shipIds = List<int>.from(
        item['grouped_shipping_ids'] ?? [],
      );

      if (assignmentIds.isEmpty || shipIds.isEmpty) {
        throw "Data ID tidak ditemukan untuk proses pembatalan.";
      }

      await supabase
          .from('shipping_assignments')
          .update({
            'status_assignment': 'cancel booking',
            'cancelled_reason': reason,
            'cancelled_at': DateTime.now().toIso8601String(),
            'jam_booking': null,
            'cancelled_by': 'vendor',
          })
          .inFilter('id_assignment', assignmentIds);

      await supabase
          .from('shipping_request')
          .update({'status': 'waiting assign vendor delivery'})
          .inFilter('shipping_id', shipIds);

      _showSnackBar("Grup Order berhasil dibatalkan", Colors.orange);

      _fetchOngoingOrders();
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Gagal membatalkan grup: $e", Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          _buildTopFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.red),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchOngoingOrders,
                    child: _filteredPlanningList.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _filteredPlanningList.length,
                            itemBuilder: (context, index) =>
                                _buildDetailedOngoingCard(
                                  _filteredPlanningList[index],
                                ),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopFilterBar() {
    bool isToday =
        DateFormat('yyyy-MM-dd').format(_selectedDate) ==
        DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 600) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: !isToday
                        ? Colors.red.shade700
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: InkWell(
                    onTap: _selectSingleDate,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: !isToday ? Colors.white : Colors.black87,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                "STUFFING: ${DateFormat('dd MMMM yyyy', 'id_ID').format(_selectedDate)}",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: !isToday
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          Icon(
                            Icons.arrow_drop_down,
                            color: !isToday ? Colors.white : Colors.black87,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 44,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: "Cari nomor DO...",
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 18,
                        color: Colors.grey,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? InkWell(
                              onTap: () => _searchController.clear(),
                              child: const Icon(
                                Icons.clear,
                                size: 16,
                                color: Colors.grey,
                              ),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                flex: 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: !isToday
                        ? Colors.red.shade700
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: InkWell(
                    onTap: _selectSingleDate,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: !isToday ? Colors.white : Colors.black87,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "STUFFING: ${DateFormat('dd MMMM yyyy', 'id_ID').format(_selectedDate)}",
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: !isToday ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_drop_down,
                            color: !isToday ? Colors.white : Colors.black87,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 5,
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: "Cari nomor DO...",
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 18,
                        color: Colors.grey,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? InkWell(
                              onTap: () => _searchController.clear(),
                              child: const Icon(
                                Icons.clear,
                                size: 16,
                                color: Colors.grey,
                              ),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              if (!isToday)
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _selectedDate = DateTime.now();
                    });
                    _fetchOngoingOrders();
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _selectSingleDate() async {
    final now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(now.year + 100),
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
      setState(() {
        _selectedDate = picked;
      });
      _fetchOngoingOrders(); // Fetch ulang data menggunakan tanggal baru
    }
  }

  String _getCheckInTime(String? timeSlot) {
    if (timeSlot == null ||
        timeSlot.isEmpty ||
        timeSlot == "-" ||
        !timeSlot.contains(" - ")) {
      return "00:00 - 00:00";
    }

    try {
      List<String> parts = timeSlot.split(" - ");
      if (parts.length < 2) return "00:00 - 00:00";

      String startTimeStr = parts[0];
      String endTimeStr = parts[1];

      List<String> startSplit = startTimeStr.split(":");
      List<String> endSplit = endTimeStr.split(":");

      if (startSplit.isEmpty || endSplit.isEmpty) return "00:00 - 00:00";

      int startHour = int.parse(startSplit[0]);
      int endHour = int.parse(endSplit[0]);

      int newStart = (startHour - 2) < 0
          ? (24 + (startHour - 2))
          : (startHour - 2);
      int newEnd = (endHour - 2) < 0 ? (24 + (endHour - 2)) : (endHour - 2);

      String checkInStart = "${newStart.toString().padLeft(2, '0')}:00";
      String checkInEnd = "${newEnd.toString().padLeft(2, '0')}:00";

      return "$checkInStart - $checkInEnd";
    } catch (e) {
      debugPrint("Error kalkulasi jam check-in: $e");
      return "00:00 - 00:00";
    }
  }

  Widget _buildDetailedOngoingCard(Map<String, dynamic> item) {
    final request = item['shipping_request'] ?? {};
    if (request.isEmpty) return const SizedBox.shrink();

    final bool isGroup = request['group_id'] != null;
    final List dos = request['delivery_order'] ?? [];
    final warehouse = request['warehouse'];
    final String status = item['status_assignment'] ?? '';
    final bool hasArrived = [
      'check in',
      'loading',
      'kelayakan unit',
      'weighbridge',
      'keluar',
    ].contains(status);

    String warehouseDisplay = warehouse != null
        ? "${warehouse['lokasi'] ?? ''} - ${warehouse['warehouse_name'] ?? ''}"
        : "-";

    bool isAllowed = _canReschedule(
      item['jam_booking'],
      request['stuffing_date'],
    );
    final vt = item['vendor_transportasi'];

    final String city = vt != null ? (vt['city'] ?? '-') : '-';
    final String area = vt != null ? (vt['area'] ?? '-') : '-';
    final String typeUnit = vt != null ? (vt['type_unit'] ?? '-') : '-';
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isGroup ? Colors.purple.shade700 : Colors.blue.shade800,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.access_time_filled,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        "CHECK-IN: ${_getCheckInTime(item['jam_booking'])} | LOADING: ${item['jam_booking'] ?? "-"}",
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white, width: 0.5),
                  ),
                  child: Text(
                    isGroup
                        ? "GROUP SHIP ${request['group_id']}"
                        : "SHIP ID ${request['shipping_id']}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _infoBox("STUFFING", _formatDate(request['stuffing_date'])),
                    _infoBox("TIPE UNIT", typeUnit.toUpperCase()),
                    _infoBox("RUTE PENGIRIMAN", "$city → $area"),
                    _infoBox(
                      "STATUS",
                      (request['is_dedicated'] ?? "-").toString().toUpperCase(),
                    ),
                    _infoBox(
                      "WAREHOUSE",
                      warehouseDisplay.toUpperCase(),
                      color: Colors.red.shade700,
                    ),
                  ],
                ),

                const Divider(height: 32),
                ...dos.map((doItem) {
                  final List details = doItem['do_details'] ?? [];
                  final String rddSpesifik = _formatDate(doItem['rdd_origin']);
                  final String custInfo =
                      "${doItem['customer']?['customer_id'] ?? '-'} - ${doItem['customer']?['customer_name'] ?? '-'}";

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_month,
                              size: 14,
                              color: Colors.red.shade700,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "RDD: $rddSpesifik",
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFB71C1C),
                              ),
                            ),
                          ],
                        ),
                      ),

                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFCE4EC),
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(8),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "DO: ${doItem['do_number']}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                  Text(
                                    "SO: ${doItem['parent_so'] ?? '-'}",
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    custInfo,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Table(
                              columnWidths: const {
                                0: FlexColumnWidth(1.2),
                                1: FlexColumnWidth(4),
                                2: FlexColumnWidth(1),
                              },
                              children: details.map((det) {
                                final mat = det['material'] ?? {};
                                return TableRow(
                                  children: [
                                    _tableCell(
                                      mat['material_id']?.toString() ?? "-",
                                    ),
                                    _tableCell(mat['material_name'] ?? "-"),
                                    _tableCell(
                                      det['qty']?.toString() ?? "0",
                                      align: TextAlign.right,
                                      isBold: true,
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),

                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: hasArrived
                            ? null
                            : () => _showCancelDialog(item),
                        icon: Icon(
                          Icons.cancel,
                          size: 16,
                          color: hasArrived ? Colors.grey : Colors.red,
                        ),
                        label: Text(
                          hasArrived ? "ARRIVED" : "CANCEL",
                          style: TextStyle(
                            fontSize: 11,
                            color: hasArrived ? Colors.grey : Colors.red,
                            fontWeight: hasArrived
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: BorderSide(
                            color: hasArrived ? Colors.grey : Colors.red,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: (isAllowed && !hasArrived)
                            ? () {
                                final int? groupId = request['group_id'];
                                final int shipId = request['shipping_id'];
                                String tabTitle;

                                if (groupId != null) {
                                  tabTitle = "Reschedule Grup #$groupId";
                                } else {
                                  tabTitle = "Reschedule Shipping #$shipId";
                                }
                                DynamicTabPage.of(context)?.openTab(
                                  tabTitle,
                                  ScheduleSelectionPage(
                                    assignmentId: item['id_assignment'],
                                    shippingId: item['shipping_id'],
                                    oldTime: item['jam_booking'],
                                    vendorNik: widget.vendorNik,
                                    onSuccess: () => _fetchOngoingOrders(),
                                  ),
                                );
                              }
                            : null,
                        icon: Icon(
                          isAllowed ? Icons.edit_calendar : Icons.lock_clock,
                          size: 16,
                          color: Colors.white,
                        ),
                        label: Text(
                          isAllowed ? "RESCHEDULE" : "TERKUNCI",
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isAllowed
                              ? Colors.red.shade700
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
                if (!isAllowed)
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text(
                      "* Batas reschedule berakhir (Maks 2 jam sebelum jam booking).",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.red,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                if (hasArrived)
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text(
                      "* Truk sudah Check-in.",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableCell(
    String text, {
    bool isBold = false,
    TextAlign align = TextAlign.left,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 10,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  void _showCancelDialog(Map<String, dynamic> item) {
    final List<String> cancelReasons = [
      "Tidak Ada Supir",
      "Tidak Ada Unit",
      "Unit Rusak",
      "Jalan Macet",
      "Dokumen Expired",
      "Other",
    ];

    String? selectedReason;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text(
              "Pilih Alasan Pembatalan",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: cancelReasons
                  .map(
                    (reason) => RadioListTile<String>(
                      title: Text(reason, style: const TextStyle(fontSize: 13)),
                      value: reason,
                      groupValue: selectedReason,
                      activeColor: Colors.red,
                      onChanged: (val) {
                        setDialogState(() => selectedReason = val);
                      },
                    ),
                  )
                  .toList(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("KEMBALI"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: selectedReason == null
                    ? null // Button mati jika alasan belum dipilih
                    : () {
                        Navigator.pop(context);
                        _cancelOrder(item, selectedReason!);
                      },
                child: const Text(
                  "SUBMIT CANCEL",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _canReschedule(String? jamBooking, String? stuffingDate) {
    if (jamBooking == null || stuffingDate == null) return false;

    try {
      String startTimeStr = jamBooking.split(" - ")[0];
      DateTime stuffingDay = DateTime.parse(stuffingDate);
      List<String> timeParts = startTimeStr.split(":");

      DateTime bookingDateTime = DateTime(
        stuffingDay.year,
        stuffingDay.month,
        stuffingDay.day,
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
      );
      DateTime limitTime = bookingDateTime.subtract(const Duration(hours: 2));
      return DateTime.now().isBefore(limitTime);
    } catch (e) {
      return false;
    }
  }

  Widget _infoBox(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  String _formatDate(String? s) =>
      s == null ? "-" : DateFormat('dd MMM yyyy').format(DateTime.parse(s));
  void _showSnackBar(String msg, Color color) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  Widget _buildEmptyState() => const Center(
    child: Text(
      "Tidak ada pengiriman aktif pada tanggal ini.",
      style: TextStyle(color: Colors.grey),
    ),
  );
}
