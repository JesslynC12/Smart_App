import 'package:flutter/material.dart';
import 'package:project_app/admin/input%20form/loadingform_page.dart'; // Pastikan import ini benar
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
  List<dynamic> _planningList = [];
  
  // Filter Variables
  DateTime _selectedDate = DateTime.now();
  String _dateFilterType = 'stuffing_date'; 
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _fetchPlanningData();
    _setupRealtime();
  }

  void _setupRealtime() {
    _channel = supabase
        .channel('shipping_assignments_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'shipping_assignments',
          callback: (payload) => _fetchPlanningData(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  /// Membuka Tab Baru untuk Form Loading
  void _openLoadingTab(Map<String, dynamic> item) {
    final req = item['request'] ?? {};
    final String title = req['group_id'] != null 
        ? "Loading Grup #${req['group_id']}" 
        : "Loading Ship #${req['shipping_id']}";

    DynamicTabPage.of(context)?.openTab(
      title,
      LoadingFormPage(item: item), // Menggunakan LoadingFormPage sesuai konteks list
    );
  }

  Future<void> _fetchPlanningData() async {
    try {
      if (!mounted) return;
      setState(() => _isLoading = true);

      String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
      
      // Query dengan filter: status_assignment = 'check in' DAN status_request != 'loading'
      final response = await supabase
          .from('shipping_assignments')
          .select('''
            *,
            master_vendor:nik (vendor_name), 
            request:shipping_id (
              shipping_id, so, rdd, stuffing_date, group_id, storage_location, is_dedicated,
              warehouse:warehouse(warehouse_id, warehouse_name, lokasi),
              delivery_order (
                do_id, do_number,
                customer (customer_id, customer_name),
                do_details (
                  qty,
                  material:material_id (material_id, material_name)
                )
              )
            )
          ''')
          .eq('status_assignment', 'check in')
          .not('jam_booking', 'is', null)
          .eq('request.$_dateFilterType', formattedDate)
          .neq('request.status', 'loading')
          .order('jam_booking', ascending: true);

      // PROSES GROUPING MANUAL
      Map<String, dynamic> groupedData = {};

      for (var item in response) {
        final req = item['request'];
        if (req == null) continue;

        String key = req['group_id'] != null 
            ? "GROUP_${req['group_id']}" 
            : "SINGLE_${req['shipping_id']}";

        if (!groupedData.containsKey(key)) {
          groupedData[key] = Map<String, dynamic>.from(item);
          groupedData[key]['grouped_assignment_ids'] = [item['id_assignment']];
          groupedData[key]['grouped_shipping_ids'] = [req['shipping_id']];
          
          if (groupedData[key]['request']['delivery_order'] != null) {
            for (var d in groupedData[key]['request']['delivery_order']) {
              d['rdd_origin'] = req['rdd'];
            }
          }
        } else {
          groupedData[key]['grouped_assignment_ids'].add(item['id_assignment']);
          groupedData[key]['grouped_shipping_ids'].add(req['shipping_id']);

          List currentDOs = groupedData[key]['request']['delivery_order'] ?? [];
          List newDOs = req['delivery_order'] ?? [];

          for (var ndo in newDOs) {
            bool isDuplicate = currentDOs.any((existing) => existing['do_number'] == ndo['do_number']);
            if (!isDuplicate) {
              ndo['rdd_origin'] = req['rdd'];
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
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        debugPrint("Error Fetch Loading: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Column(
        children: [
          _buildTopFilterBar(),
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
    bool isToday = DateFormat('yyyy-MM-dd').format(_selectedDate) == 
                   DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: !isToday ? Colors.red.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: !isToday ? Colors.red.shade200 : Colors.transparent),
              ),
              child: Row(
                children: [
                  _buildDropdownFilter(isToday),
                  _buildDatePickerTrigger(isToday),
                ],
              ),
            ),
          ),
          if (!isToday)
            IconButton(
              icon: const Icon(Icons.history, color: Colors.red),
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

  Widget _buildDropdownFilter(bool isToday) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey.shade300)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _dateFilterType == 'stuffing_date' ? "Stuffing" : "RDD",
          isDense: true,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red.shade900),
          items: ["RDD", "Stuffing"].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
          onChanged: (val) {
            setState(() => _dateFilterType = val == "RDD" ? "rdd" : "stuffing_date");
            _fetchPlanningData();
          },
        ),
      ),
    );
  }

  Widget _buildDatePickerTrigger(bool isToday) {
    return Expanded(
      child: InkWell(
        onTap: _selectDate,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.calendar_month, size: 16, color: Colors.red.shade700),
              const SizedBox(width: 8),
              Text(
                DateFormat('dd MMM yyyy', 'id_ID').format(_selectedDate),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _fetchPlanningData();
    }
  }

  Widget _buildPlanningCard(Map<String, dynamic> item) {
    final req = item['request'] ?? {};
    final vendor = item['master_vendor'] ?? {};
    final List dos = req['delivery_order'] ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _openLoadingTab(item), // Klik kartu untuk buka form loading
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: req['group_id'] != null ? Colors.purple.shade600 : Colors.blue.shade700,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(item['jam_booking'] ?? "-", 
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text(req['group_id'] != null ? "GRUP #${req['group_id']}" : "SHIP #${req['shipping_id']}",
                    style: const TextStyle(color: Colors.white, fontSize: 11)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("${item['nik']} - ${vendor['vendor_name']}", 
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Divider(),
                  ...dos.map((d) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.article_outlined, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text("${d['do_number']} - ${d['customer']?['customer_name'] ?? ''}", 
                          style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("Tidak ada antrean yang sudah Check-in", 
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}