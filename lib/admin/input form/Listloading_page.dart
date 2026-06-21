import 'package:flutter/material.dart';
import 'package:project_app/admin/input%20form/loadingform_page.dart';
import 'package:project_app/dynamic_tab_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ListLoadingState extends StatefulWidget {
  const ListLoadingState({super.key});

  @override
  State<ListLoadingState> createState() => _ListLoadingState();
}

class _ListLoadingState extends State<ListLoadingState> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isFetching = false;
  List<dynamic> _planningList = [];
  List<dynamic> _filteredPlanningList = [];
  DateTime _selectedDate = DateTime.now();
  RealtimeChannel? _channel;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterDataBySearch);
    _fetchPlanningData();

    _channel = supabase
        .channel('shipping_assignments_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'shipping_assignments',
          callback: (payload) async {
            await _fetchPlanningData();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    if (_channel != null) supabase.removeChannel(_channel!);
    _searchController.dispose();
    super.dispose();
  }

  void _filterDataBySearch() {
    String query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _filteredPlanningList = List.from(_planningList);
      });
      return;
    }

    setState(() {
      _filteredPlanningList = _planningList.where((item) {
        final vendor = item['vendor_transportasi'] ?? {};
        final String vendorName = (vendor['vendor_name'] ?? '')
            .toString()
            .toLowerCase();
        final String nikVendor = (vendor['nik'] ?? '').toString().toLowerCase();
        final request = item['request'] ?? {};
        final List dos = request['delivery_order'] as List? ?? [];

        bool matchDO = dos.any((doItem) {
          final String doNumber = (doItem['do_number'] ?? '')
              .toString()
              .toLowerCase();
          return doNumber.contains(query);
        });

        return matchDO ||
            vendorName.contains(query) ||
            nikVendor.contains(query);
      }).toList();
    });
  }

  void _handleGoToLoading(Map<String, dynamic> item) {
    final groupId = item['request']['group_id'];
    final shipId = item['request']['shipping_id'];

    String tabTitle = groupId != null
        ? "Loading Grup #$groupId"
        : "Loading Ship #$shipId";

    DynamicTabPage.of(context)?.openTab(tabTitle, LoadingFormPage(item: item));
  }

  Future<void> _fetchPlanningData() async {
    if (_isFetching) return;
    try {
      setState(() => _isLoading = true);

      String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);

      final response = await supabase
          .from('shipping_assignments')
          .select('''
          *,
          vendor_transportasi:id_vendor_details (
            nik,
            vendor_name,
            qcf,
            city,
            area,
            type_unit
          ), 
          loading:loading (
            id_loading,
            loading_at,
            loading_by,
            checker_id,
            verifikasi_rekomendasi_logistic,
            ganjal_ban,
            no_segel_smart
          ),
          request:shipping_id (
            shipping_id, so, rdd, stuffing_date, group_id, storage_location, is_dedicated,
            warehouse:warehouse(warehouse_id, warehouse_name, lokasi),
            delivery_order (
              do_id,
              do_number,
              customer (customer_id, customer_name),
              do_details (
                qty,
                material:material_id (material_id, material_name)
              )
            )
          )
        ''')
          .eq('status_assignment', 'kelayakan unit')
          .not('jam_booking', 'is', null)
          .order('jam_booking', ascending: true);

      Map<String, dynamic> groupedData = {};

      for (var item in response) {
        final req = item['request'];
        if (req == null) continue;
        if (req['stuffing_date'] != formattedDate) continue;
        if (req['status'] == 'loading') continue;

        String key = req['group_id'] != null
            ? "GROUP_${req['group_id']}"
            : "SINGLE_${req['shipping_id']}";

        if (!groupedData.containsKey(key)) {
          groupedData[key] = Map<String, dynamic>.from(item);

          groupedData[key]['grouped_assignment_ids'] = [item['id_assignment']];

          groupedData[key]['grouped_shipping_ids'] = [req['shipping_id']];
          final loadingList = item['loading'] as List?;
          groupedData[key]['loading_info'] =
              (loadingList != null && loadingList.isNotEmpty)
              ? loadingList[0]
              : null;

          List currentDOs = List.from(
            groupedData[key]['request']['delivery_order'] ?? [],
          );

          for (var d in currentDOs) {
            d['rdd_origin'] = req['rdd'];
            d['parent_so'] = req['so'];
            d['parent_shipping_id'] = req['shipping_id'];
          }

          groupedData[key]['request']['delivery_order'] = currentDOs;
        } else {
          if (!groupedData[key]['grouped_assignment_ids'].contains(
            item['id_assignment'],
          )) {
            groupedData[key]['grouped_assignment_ids'].add(
              item['id_assignment'],
            );
          }
          if (!groupedData[key]['grouped_shipping_ids'].contains(
            req['shipping_id'],
          )) {
            groupedData[key]['grouped_shipping_ids'].add(req['shipping_id']);
          }

          List currentDOs = groupedData[key]['request']['delivery_order'] ?? [];

          List newDOs = req['delivery_order'] ?? [];

          for (var ndo in newDOs) {
            ndo['rdd_origin'] = req['rdd'];
            ndo['parent_so'] = req['so'];
            ndo['parent_shipping_id'] = req['shipping_id'];

            bool isDuplicate = currentDOs.any(
              (existing) =>
                  existing['do_number'] == ndo['do_number'] &&
                  existing['parent_shipping_id'] == req['shipping_id'],
            );

            if (!isDuplicate) {
              currentDOs.add(ndo);
            }
          }

          groupedData[key]['request']['delivery_order'] = currentDOs;
        }
      }
      if (mounted) {
        setState(() {
          _planningList = groupedData.values.toList();
          _isLoading = false;
        });
        _filterDataBySearch();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Error Fetch Planning: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildTopFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetchPlanningData,
                    child: _filteredPlanningList.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _filteredPlanningList.length,
                            itemBuilder: (context, index) => _buildPlanningCard(
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
                      hintText: "Cari DO, Vendor, NIK...",
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
                      hintText: "Cari DO, Vendor, NIK...",
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
                    _fetchPlanningData();
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
      firstDate: DateTime(2023),
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
      setState(() => _selectedDate = picked);
      _fetchPlanningData();
    }
  }

  Widget _buildPlanningCard(Map<String, dynamic> item) {
    final Map<String, dynamic> request = item['request'] ?? {};
    final vendor = item['vendor_transportasi'] ?? {};
    if (request.isEmpty) return const SizedBox.shrink();

    final List dos = request['delivery_order'] as List? ?? [];
    final bool isGroup = request['group_id'] != null;
    final warehouse = request['warehouse'];

    String warehouseDisplay = warehouse != null
        ? "${warehouse['lokasi'] ?? ''} - ${warehouse['warehouse_name'] ?? ''}"
        : "-";

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

                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: Text(
                    isGroup
                        ? "GROUP SHIP ${request['group_id']}"
                        : "SINGLE SHIP ${request['shipping_id']}",
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
                    Text(
                      "Assigned: ${_formatDateTime(item['assigned_at'])}",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    Text(
                      "Responded: ${_formatDateTime(item['responded_at'])}",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _infoBox(
                      "STUFFING DATE",
                      _formatDate(request['stuffing_date']),
                    ),
                    _infoBox("WAREHOUSE", warehouseDisplay.toUpperCase()),
                    _infoBox(
                      "TYPE",
                      (request['is_dedicated'] ?? "-").toString().toUpperCase(),
                    ),
                  ],
                ),
                const Divider(height: 24),

                Row(
                  children: [
                    const Icon(Icons.store, size: 18, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${vendor['nik'] ?? '-'} - ${vendor['vendor_name'] ?? 'Unknown Vendor'}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          if (item['vendor_transportasi'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 2,
                                children: [
                                  _miniVendorDetail(
                                    "City: ${item['vendor_transportasi']['city'] ?? '-'}",
                                  ),
                                  _miniVendorDetail(
                                    "Area: ${item['vendor_transportasi']['area'] ?? '-'}",
                                  ),
                                  _miniVendorDetail(
                                    "Unit: ${item['vendor_transportasi']['type_unit'] ?? '-'}",
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 14,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "Check-in At: ${_formatDateTime(item['checkIn_at'])}",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade900,
                            ),
                          ),
                          if (item['latecheckIn_reason'] != null) ...[
                            const SizedBox(width: 12),
                            const Text(
                              "|",
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Terlambat: ${item['latecheckIn_reason']}",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.red.shade900,
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                ...dos.map((doItem) {
                  final List details = doItem['do_details'] ?? [];
                  final String rddSpesifik = _formatDate(doItem['rdd_origin']);

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
                                    "${doItem['customer']?['customer_id'] ?? '-'} - ${doItem['customer']?['customer_name'] ?? '-'}",
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
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _handleGoToLoading(item),
                    icon: const Icon(Icons.play_arrow, color: Colors.white),
                    label: const Text(
                      "Loading",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
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

  Widget _tableCell(
    String text, {
    bool isBold = false,
    TextAlign align = TextAlign.left,
    bool isHeader = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: isHeader ? Colors.black : Colors.black87,
        ),
      ),
    );
  }

  Widget _miniVendorDetail(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300, width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: Colors.blueGrey.shade700,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "-";

    try {
      DateTime time = DateTime.parse(dateStr);

      return DateFormat('dd/MM/yy HH:mm').format(time);
    } catch (e) {
      debugPrint("Error parsing datetime: $e");
      return "-";
    }
  }

  Widget _infoBox(String label, String value) {
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
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "-";
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(dateStr));
    } catch (e) {
      return "-";
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_note, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            "Tidak ada antrian loading saat ini",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
