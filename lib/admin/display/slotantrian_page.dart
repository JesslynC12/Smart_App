import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QueueSlotPage extends StatefulWidget {
  const QueueSlotPage({super.key});

  @override
  State<QueueSlotPage> createState() => _QueueSlotPageState();
}

class _QueueSlotPageState extends State<QueueSlotPage> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  RealtimeChannel? _assignmentsChannel;
  RealtimeChannel? _requestsChannel;

  final List<Map<String, dynamic>> _zones = [
    {
      'zone_key': 'rungkut',
      'zone_name': 'RUNGKUT',
    },
    {
      'zone_key': 'tambak_langon',
      'zone_name': 'LINK - TAMBAK LANGON',
    },
  ];

  String _selectedZoneKey = 'rungkut';

  final List<Map<String, dynamic>> _allWarehouses = [
    {'warehouse_id': 1, 'warehouse_name': 'GBJ CO CHIYODA', 'zone': 'rungkut'},
    {'warehouse_id': 2, 'warehouse_name': 'GBJ KUNCIMAS', 'zone': 'rungkut'},
    {'warehouse_id': 3, 'warehouse_name': 'GBJ MARSHO VNA', 'zone': 'rungkut'},
    {'warehouse_id': 6, 'warehouse_name': 'TAMBAK LANGON', 'zone': 'tambak_langon'}, 
  ];

  final List<String> _rungkutTimeSlots = [
    '07:00 - 09:00',
    '09:00 - 11:00',
    '11:00 - 13:00',
    '13:00 - 15:00',
    '15:00 - 17:00',
    '17:00 - 19:00',
    '19:00 - 21:00',
    '21:00 - 23:00',
  ];

  final List<String> _tambakLangonTimeSlots = [
    '08:00 - 10:00',
    '10:00 - 12:00',
    '12:00 - 14:00',
    '14:00 - 16:00',
    '16:00 - 18:00',
    '18:00 - 20:00',
    '20:00 - 22:00',
    '22:00 - 24:00',
  ];

  List<Map<String, dynamic>> get _currentWarehouses {
    return _allWarehouses.where((w) => w['zone'] == _selectedZoneKey).toList();
  }
  List<String> get _currentTimeSlots {
    if (_selectedZoneKey == 'tambak_langon') {
      return _tambakLangonTimeSlots;
    }
    return _rungkutTimeSlots;
  }

  Map<String, dynamic> _slotData = {};

  @override
  void initState() {
    super.initState();
    _loadSlotData(showGlobalLoading: true);
    _initRealtimeStreams();
  }

  @override
  void dispose() {
    _assignmentsChannel?.unsubscribe();
    _requestsChannel?.unsubscribe();
    if (_assignmentsChannel != null) supabase.removeChannel(_assignmentsChannel!);
    if (_requestsChannel != null) supabase.removeChannel(_requestsChannel!);
    super.dispose();
  }

  void _initRealtimeStreams() {
    _assignmentsChannel = supabase
        .channel('queue_slot_assignments_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'shipping_assignments',
          callback: (payload) async {
            debugPrint("Realtime Update: Perubahan slot terdeteksi");
            await _loadSlotData(showGlobalLoading: false);
          },
        )
        .subscribe();

    _requestsChannel = supabase
        .channel('queue_slot_requests_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'shipping_request',
          callback: (payload) async {
            await _loadSlotData(showGlobalLoading: false);
          },
        )
        .subscribe();
  }

  // Aturan Kapasitas Maksimum per Gudang Tunggal & Jam Muat
  int _getMaxCapacity(int warehouseId, String timeSlot) {
    if (warehouseId == 6) {
      if (timeSlot == '08:00 - 10:00') return 6;
      if (timeSlot == '10:00 - 12:00') return 4;
      if (timeSlot == '12:00 - 14:00') return 4;
      if (timeSlot == '14:00 - 16:00') return 6;
      if (timeSlot == '16:00 - 18:00') return 6;
      if (timeSlot == '18:00 - 20:00') return 3;
      if (timeSlot == '20:00 - 22:00') return 5;
      if (timeSlot == '22:00 - 24:00') return 6;
      return 0;
    }

    bool isRestTime = timeSlot == '11:00 - 13:00' || timeSlot == '17:00 - 19:00';

    if (warehouseId == 1) return isRestTime ? 4 : 8;
    if (warehouseId == 2) return isRestTime ? 1 : 3;
    if (warehouseId == 3) return isRestTime ? 2 : 4;

    return 0;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(now.year + 100),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      _loadSlotData(showGlobalLoading: true);
    }
  }

  Future<void> _loadSlotData({bool showGlobalLoading = false}) async {
    try {
      if (showGlobalLoading) {
        setState(() => _isLoading = true);
      }
      String filterDate = DateFormat('yyyy-MM-dd').format(_selectedDate);

      final response = await supabase
          .from('shipping_assignments')
          .select('''
            jam_booking,
            nik,
            status_assignment,
            no_polisi,
            vendor_transportasi(type_unit),
            master_vendor(vendor_name),
            request:shipping_id(
              shipping_id,
              group_id,
              warehouse_id,
              stuffing_date,
              delivery_order(
                do_number,
                customer(customer_name)
              )
            )
          ''')
          .inFilter('status_assignment', ['accepted', 'check in', 'loading', 'kelayakan unit', 'weighbridge', 'keluar'])
          .eq('request.stuffing_date', filterDate)
          .not('jam_booking', 'is', null);

      Map<String, dynamic> tempData = {};
      Map<String, Set<String>> uniqueVehicles = {};
      Map<String, List<Map<String, dynamic>>> bookingDetails = {};

      for (var row in response) {
        final request = row['request'];
        if (request == null) continue;

        final int warehouseId = request['warehouse_id'];
        final String? timeSlot = row['jam_booking'];
        if (timeSlot == null) continue;

        String key = '${warehouseId}_$timeSlot';
        String vehicleKey = request['group_id'] != null
            ? 'GRP_${request['group_id']}'
            : 'SHIP_${request['shipping_id']}';

        if (!uniqueVehicles.containsKey(key)) uniqueVehicles[key] = {};

        if (!uniqueVehicles[key]!.contains(vehicleKey)) {
          uniqueVehicles[key]!.add(vehicleKey);

          String vendorName = row['master_vendor']?['vendor_name'] ?? '-';
          List doList = request['delivery_order'] ?? [];
          String doNumbers = doList.map((e) => e['do_number']).join(", ");
          String customers = doList.map((e) => e['customer']?['customer_name'] ?? '-').toSet().join(", ");

          String noPolisi = row['no_polisi'] ?? '-';
          String typeUnit = row['vendor_transportasi']?['type_unit'] ?? '-';

          if (!bookingDetails.containsKey(key)) bookingDetails[key] = [];
          bookingDetails[key]!.add({
            'vendor': vendorName,
            'customer': customers,
            'id': vehicleKey,
            'dos': doNumbers,
            'status': row['status_assignment'],
            'no_polisi': noPolisi,
            'type_unit': typeUnit,
          });
        }
      }

      for (var warehouse in _allWarehouses) {
        int whId = warehouse['warehouse_id'];
        List<String> currentSlots = warehouse['zone'] == 'tambak_langon' ? _tambakLangonTimeSlots : _rungkutTimeSlots;

        for (String slot in currentSlots) {
          String key = '${whId}_$slot';
          tempData[key] = {
            'booked': uniqueVehicles[key]?.length ?? 0,
            'max': _getMaxCapacity(whId, slot),
            'details': bookingDetails[key] ?? [],
          };
        }
      }

      setState(() {
        _slotData = tempData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Table(
                          border: TableBorder.all(color: Colors.grey.shade400),
                          columnWidths: {
                            0: const FixedColumnWidth(240),
                            for (int i = 1; i <= _currentWarehouses.length; i++) i: const FixedColumnWidth(350),
                          },
                          children: [
                            _buildHeaderRow(),
                            ..._currentTimeSlots.map((slot) => _buildTimeRow(slot)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          DropdownButtonHideUnderline(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButton<String>(
                value: _selectedZoneKey,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.red),
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14),
                items: _zones.map((zone) {
                  return DropdownMenuItem<String>(
                    value: zone['zone_key'],
                    child: Text(zone['zone_name']),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedZoneKey = value;
                    });
                    _loadSlotData(showGlobalLoading: true);
                  }
                },
              ),
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _pickDate,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black87, side: BorderSide(color: Colors.grey.shade300)),
            icon: const Icon(Icons.calendar_month, size: 18, color: Colors.red),
            label: Text(DateFormat('dd MMM yyyy').format(_selectedDate), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: () => _loadSlotData(showGlobalLoading: true),
            icon: const Icon(Icons.refresh, color: Colors.red),
          ),
        ],
      ),
    );
  }

  TableRow _buildHeaderRow() {
    return TableRow(
      decoration: BoxDecoration(color: Colors.red.shade700),
      children: [
        _headerCell("Jam"),
        ..._currentWarehouses.map((e) => _headerCell(e['warehouse_name'])),
      ],
    );
  }

  Widget _headerCell(String text) {
    return Container(
      height: 60,
      alignment: Alignment.center,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }
  TableRow _buildTimeRow(String slot) {
    return TableRow(
      children: [
        Container(
          height: 180,
          alignment: Alignment.center,
          color: Colors.grey.shade200,
          child: Text(
            slot,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),

        ..._currentWarehouses.map((warehouse) {
          int warehouseId = warehouse['warehouse_id'];
          String key = '${warehouseId}_$slot';

          final data = _slotData[key] ?? {
            'booked': 0,
            'max': _getMaxCapacity(warehouseId, slot),
            'details': [],
          };

          int booked = data['booked'];
          int max = data['max'];
          int remaining = max - booked;
          List<Map<String, dynamic>> details = List<Map<String, dynamic>>.from(data['details']);
          bool isFull = booked >= max;

          return GestureDetector(
            onTap: () => _showDetailDialog(warehouse['warehouse_name'], slot, details, remaining, booked, max),
            child: Container(
              height: 180,
              padding: const EdgeInsets.all(12),
              color: isFull ? Colors.red.withValues(alpha: 0.05) : Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(isFull ? Icons.block : Icons.check_circle, size: 16, color: isFull ? Colors.red : Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isFull ? "FULL" : "Sisa Slot: $remaining",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isFull ? Colors.red.shade900 : Colors.green.shade900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text("Terisi $booked/$max", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  const Divider(height: 16),
                  Expanded(
                    child: details.isEmpty
                        ? const Text("-", style: TextStyle(fontSize: 10, color: Colors.grey))
                        : ListView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: details.length > 2 ? 2 : details.length,
                            itemBuilder: (context, i) {
                              final String rawStatus = details[i]['status'] ?? '';
                              Color statusColor = rawStatus == 'accepted' ? Colors.grey : Colors.blue.shade700;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            "• ${details[i]['vendor']}",
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: statusColor, width: 0.5),
                                          ),
                                          child: Text(
                                            rawStatus.toUpperCase(),
                                            style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: statusColor),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      "  Tujuan: ${details[i]['customer']}",
                                      style: const TextStyle(fontSize: 10, color: Colors.black54),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  void _showDetailDialog(String warehouse, String slot, List<Map<String, dynamic>> details, int remaining, int booked, int max) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            "$warehouse\n$slot",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Terisi: $booked/$max", style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  "Sisa Slot: $remaining",
                  style: TextStyle(fontWeight: FontWeight.bold, color: remaining <= 0 ? Colors.red : Colors.green),
                ),
                const Divider(height: 24),
                const Text("Daftar Booking Gudang Ini:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                const SizedBox(height: 10),
                if (details.isEmpty)
                  const Text("- Belum ada booking")
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: details.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, i) {
                        final d = details[i];
                        final String status = d['status'] ?? '-';
                        Color statusColor = status == 'accepted' ? Colors.grey : Colors.blue.shade700;
                        bool sudahCheckIn = status.toLowerCase() == 'kelayakan unit';
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    "${d['vendor']}",
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: statusColor, width: 0.5),
                                  ),
                                  child: Text(
                                    status == 'accepted' ? "BELUM TIBA" : status.toUpperCase(),
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text("ID: ${d['id']}", style: const TextStyle(fontSize: 11)),
                            Text("Tujuan: ${d['customer']}", style: const TextStyle(fontSize: 11)),
                             Text("DO: ${d['dos']}", style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey)),
                            if (sudahCheckIn) ...[
                              Text("Kendaraan: ${d['type_unit']} (${d['no_polisi']})", 
                                style: const TextStyle(fontSize: 11, color: Colors.black87)),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Tutup", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}