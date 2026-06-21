import 'package:flutter/material.dart';
import 'package:project_app/auth/auth_service.dart';
import 'package:project_app/dynamic_tab_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ScheduleSelectionPage extends StatefulWidget {
  final int assignmentId;
  final int shippingId;
  final String? oldTime;
  final String vendorNik;
  final VoidCallback onSuccess;

  const ScheduleSelectionPage({
    super.key,
    required this.assignmentId,
    required this.shippingId,
    this.oldTime,
    required this.vendorNik,
    required this.onSuccess,
  });

  @override
  State<ScheduleSelectionPage> createState() => _ScheduleSelectionPageState();
}

class _ScheduleSelectionPageState extends State<ScheduleSelectionPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _shippingData;
  String? _selectedTime;
  List<String> _timeSlots = [];
  List<int> _vendorDetailIds = [];
  final TextEditingController _otherReasonController = TextEditingController();
  String? _tempSelectedReason;
  final List<String> _rescheduleReasons = [
    'Tidak Ada Supir',
    'Tidak Ada Unit',
    'Unit Rusak',
    'Jalan Macet',
    'Dokumen Expired',
    'Other',
  ];

  Map<String, int> _bookedCounts = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    _vendorDetailIds = await AuthService.getVendorDetailIds(widget.vendorNik);
    await _loadData();
    if (_shippingData != null) {
      final warehouseId = _shippingData?['warehouse_id'];

      setState(() {
        if (warehouseId == 6) {
          _timeSlots = [
            '08:00 - 10:00',
            '10:00 - 12:00',
            '12:00 - 14:00',
            '14:00 - 16:00',
            '16:00 - 18:00',
            '18:00 - 20:00',
            '20:00 - 22:00',
            '22:00 - 24:00',
          ];
        } else {
          _timeSlots = [
            '07:00 - 09:00',
            '09:00 - 11:00',
            '11:00 - 13:00',
            '13:00 - 15:00',
            '15:00 - 17:00',
            '17:00 - 19:00',
            '19:00 - 21:00',
            '21:00 - 23:00',
          ];
        }
      });

      await _checkAvailability();
    }
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      final initialRes = await supabase
          .from('shipping_request')
          .select('group_id')
          .eq('shipping_id', widget.shippingId)
          .single();

      final int? groupId = initialRes['group_id'];

      if (_vendorDetailIds.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      PostgrestFilterBuilder query = supabase.from('shipping_request').select(
        '''
          *,
          so, 
          warehouse:warehouse(warehouse_id, warehouse_name, lokasi),
          shipping_assignments!inner(
            id_assignment,
            id_vendor_details,
            vendor_transportasi:id_vendor_details(
              qcf,
              city,
              area,
              type_unit,
              vendor_name
            )
          ),
          delivery_order(
            *,
            customer(*),
            do_details(
              qty,
              material:material_id (material_id, material_name, net_weight)
            )
          )
        ''',
      );
      query = query.inFilter(
        'shipping_assignments.id_vendor_details',
        _vendorDetailIds,
      );

      dynamic response;
      if (groupId != null) {
        response = await query.eq('group_id', groupId).order('shipping_id');
      } else {
        response = await query.eq('shipping_id', widget.shippingId);
      }

      setState(() {
        List list = response as List;
        _shippingData = Map<String, dynamic>.from(list[0]);
        _shippingData!['all_shipping_ids'] = list
            .map((e) => e['shipping_id'])
            .toList();

        List allDos = [];
        for (var item in list) {
          List currentDos = List.from(item['delivery_order'] ?? []);
          for (var doItem in currentDos) {
            doItem['parent_so'] = item['so'];
            doItem['rdd_origin'] = item['rdd'];
          }
          allDos.addAll(currentDos);
        }
        _shippingData!['delivery_order'] = allDos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Gagal memuat detail: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  int _getMaxCapacity(String timeSlot) {
    final warehouseId = _shippingData?['warehouse_id'];

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

    bool isRestTime =
        timeSlot == '11:00 - 13:00' || timeSlot == '17:00 - 19:00';

    if (warehouseId == 1) {
      return isRestTime ? 4 : 8;
    } else if (warehouseId == 2) {
      return isRestTime ? 1 : 3;
    } else if (warehouseId == 3) {
      return isRestTime ? 2 : 4;
    }

    return 14;
  }

  Future<void> _confirmAndAccept({String? rescheduleReasons}) async {
    if (_selectedTime == null) return;

    if (widget.oldTime != null && _selectedTime == widget.oldTime) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Pilih jam yang berbeda!"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final List<int> shipIds = List<int>.from(
        _shippingData!['all_shipping_ids'],
      );

      final currentUser = supabase.auth.currentUser;

      String changedBy = widget.vendorNik;

      if (currentUser != null) {
        final profileRes = await supabase
            .from('profiles')
            .select('role, name')
            .eq('id', currentUser.id)
            .maybeSingle();

        if (profileRes != null) {
          final String role = (profileRes['role'] ?? '')
              .toString()
              .toLowerCase();

          if (role.isNotEmpty) {
            changedBy = role;
          }
        }
      }

      List<int> assignmentIds = [];
      if (_shippingData?['group_id'] != null) {
        final assignmentRes = await supabase
            .from('shipping_assignments')
            .select('id_assignment')
            .inFilter('shipping_id', shipIds)
            .inFilter('id_vendor_details', _vendorDetailIds)
            .inFilter('status_assignment', ['offered', 'accepted']);
        assignmentIds = (assignmentRes as List)
            .map((e) => e['id_assignment'] as int)
            .toList();
        if (!assignmentIds.contains(widget.assignmentId)) {
          assignmentIds.add(widget.assignmentId);
        }
      } else {
        assignmentIds = [widget.assignmentId];
      }

      if (widget.oldTime != null) {
        final List<Map<String, dynamic>> historyInserts = assignmentIds.map((
          id,
        ) {
          return {
            'id_assignment': id,
            'jam_lama': widget.oldTime,
            'jam_baru': _selectedTime,
            'changed_by': changedBy,
            'reason_reschedule': rescheduleReasons,
            'created_at': DateTime.now().toIso8601String(),
          };
        }).toList();

        await supabase.from('booking_history').insert(historyInserts);
      }

      await supabase
          .from('shipping_assignments')
          .update({
            'status_assignment': 'accepted',
            'responded_at': DateTime.now().toIso8601String(),
            'jam_booking': _selectedTime,
          })
          .inFilter('id_assignment', assignmentIds);

      await supabase
          .from('shipping_request')
          .update({'status': 'on process'})
          .inFilter('shipping_id', shipIds);

      if (mounted) {
        widget.onSuccess();

        final dynamicTab = DynamicTabPage.of(context);

        if (dynamicTab != null) {
          dynamicTab.closeCurrentTab();
        } else {
          Navigator.pop(context);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Berhasil! Jadwal grup telah disimpan."),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Gagal menyimpan: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailedSummary(),
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                          child: Text(
                            "⏰ PILIH JAM KEDATANGAN",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        _buildTimePickerGrid(),
                      ],
                    ),
                  ),
                ),
                _buildBottomAction(),
              ],
            ),
    );
  }

  Widget _buildDetailedSummary() {
    final data = _shippingData ?? {};
    final bool isGroup = data['group_id'] != null;
    final List dos = data['delivery_order'] ?? [];
    final List rejectList = data['reject_list'] ?? [];

    final warehouse = data['warehouse'];
    final String warehouseDisplay = warehouse != null
        ? "${warehouse['lokasi'] ?? ''} - ${warehouse['warehouse_name'] ?? ''}"
        : "-";

    Map<String, dynamic>? vendorDetails;
    final List assignments = data['shipping_assignments'] ?? [];
    if (assignments.isNotEmpty) {
      vendorDetails = assignments[0]['vendor_transportasi'];
    }
    final String vVendorName = vendorDetails?['vendor_name'] ?? '-';
    final String vCity = vendorDetails?['city'] ?? '-';
    final String vArea = vendorDetails?['area'] ?? '-';
    final String vUnit = vendorDetails?['type_unit'] ?? '-';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(
            color: isGroup ? Colors.blue.shade700 : Colors.red.shade700,
            width: 6,
          ),
        ),
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
                    Text(
                      isGroup ? "📦 GROUP SHIPMENT" : "🚚 SINGLE SHIPMENT",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isGroup
                            ? Colors.blue.shade900
                            : Colors.red.shade900,
                        letterSpacing: 1.1,
                        fontSize: 11,
                      ),
                    ),
                    _buildBadge(
                      warehouseDisplay.toUpperCase(),
                      Colors.red.shade700,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isGroup
                      ? "ID Grup: ${data['group_id']}"
                      : "ID Shipping: ${data['shipping_id']}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "${widget.vendorNik} - $vVendorName",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Divider(height: 1, color: Color(0xFFE0E0E0)),
                ),
                Row(
                  children: [
                    _infoBox("Stuffing", _formatDate(data['stuffing_date'])),
                    _infoBox(
                      "Dedicated",
                      (data['is_dedicated'] ?? "-").toString().toUpperCase(),
                    ),
                    _infoBox("Type Unit", vUnit),
                    _infoBox("City", vCity),
                    _infoBox("Area", vArea),
                  ],
                ),
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
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 14,
                              color: Colors.orange.shade900,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "RIWAYAT REJECT VENDOR:",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ...rejectList.map((rej) {
                          String vendorName =
                              rej['master_vendor']?['vendor_name'] ??
                              "Unknown Vendor";
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              "• $vendorName",
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black87,
                              ),
                            ),
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
            child: const Text(
              "DETAIL ITEM & CUSTOMER",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
          ),

          ...dos.map((doItem) {
            final List doDetails = doItem['do_details'] ?? [];
            final String soNum =
                doItem['parent_so']?.toString() ??
                data['so']?.toString() ??
                "-";
            final String rddSpesifik = _formatDate(doItem['rdd_origin']);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB71C1C),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.description_outlined,
                        size: 16,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "DO: ${doItem['do_number']}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Text(
                        "SO: $soNum",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "👤 ${doItem['customer']?['customer_id'] ?? '-'} - ${doItem['customer']?['customer_name'] ?? '-'}",
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Table(
                      columnWidths: const {
                        0: FlexColumnWidth(1.2),
                        1: FlexColumnWidth(3),
                        2: FlexColumnWidth(0.8),
                        3: FlexColumnWidth(1.3),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                          ),
                          children: [
                            _tableCell("ID Mat", isBold: true, isHeader: true),
                            _tableCell("Name", isBold: true, isHeader: true),
                            _tableCell(
                              "Qty",
                              isBold: true,
                              align: TextAlign.right,
                              isHeader: true,
                            ),
                            _tableCell(
                              "NW (Kg)",
                              isBold: true,
                              align: TextAlign.right,
                              isHeader: true,
                            ),
                          ],
                        ),
                        ...doDetails.map((det) {
                          double qty =
                              double.tryParse(det['qty']?.toString() ?? "0") ??
                              0;
                          var matSource = det['material'];
                          Map<String, dynamic>? matData;

                          if (matSource is List && matSource.isNotEmpty) {
                            matData = matSource[0];
                          } else if (matSource is Map) {
                            matData = matSource as Map<String, dynamic>;
                          }

                          double unitWeight =
                              double.tryParse(
                                matData?['net_weight']?.toString() ?? "0",
                              ) ??
                              0;

                          return TableRow(
                            children: [
                              _tableCell(
                                matData?['material_id']?.toString() ?? "-",
                              ),
                              _tableCell(
                                matData?['material_name']?.toString() ?? "-",
                              ),
                              _tableCell(
                                qty.toInt().toString(),
                                align: TextAlign.right,
                                isBold: true,
                              ),
                              _tableCell(
                                (qty * unitWeight).toStringAsFixed(2),
                                align: TextAlign.right,
                              ),
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

  Widget _tableCell(
    String text, {
    bool isBold = false,
    TextAlign align = TextAlign.left,
    bool isHeader = false,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8),
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

  Widget _buildTimePickerGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = constraints.maxWidth > 900
            ? 4
            : (constraints.maxWidth > 600 ? 3 : 2);

        double aspectRatio = constraints.maxWidth > 600 ? 1.8 : 1.4;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: aspectRatio,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: _timeSlots.length,
            itemBuilder: (context, index) {
              final time = _timeSlots[index];
              final int booked = _bookedCounts[time] ?? 0;
              final int maxCap = _getMaxCapacity(time);
              final bool isFull = booked >= maxCap;
              final bool isSelected = _selectedTime == time;
              final bool isCurrentBooking = widget.oldTime == time;
              final int remaining = maxCap - booked;
              List<String> timeParts = time.split(" - ");

              return InkWell(
                onTap: isFull
                    ? null
                    : () => setState(() => _selectedTime = time),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.red.shade700
                        : (isCurrentBooking
                              ? Colors.yellow.shade100
                              : (isFull ? Colors.grey.shade100 : Colors.white)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? Colors.red
                          : (isFull
                                ? Colors.grey.shade300
                                : Colors.grey.shade300),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.2),
                              blurRadius: 4,
                            ),
                          ]
                        : null,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                timeParts[0],
                                style: _slotStyle(
                                  isSelected,
                                  isFull,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                " - ",
                                style: _slotStyle(
                                  isSelected,
                                  isFull,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                timeParts[1],
                                style: _slotStyle(
                                  isSelected,
                                  isFull,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isFull ? "PENUH" : "$remaining/$maxCap Tersedia",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isFull
                                ? Colors.red.shade400
                                : (isSelected
                                      ? Colors.white
                                      : Colors.green.shade700),
                          ),
                        ),
                        const Divider(height: 12, indent: 10, endIndent: 10),

                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "Check-in: ${_getCheckInTime(time)}",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                              color: isSelected
                                  ? Colors.white70
                                  : Colors.blueGrey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  TextStyle _slotStyle(bool isSelected, bool isFull, {double fontSize = 14}) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      color: isFull
          ? Colors.grey.shade400
          : (isSelected ? Colors.white : Colors.black),
    );
  }

  String _getCheckInTime(String timeSlot) {
    String startTimeStr = timeSlot.split(" - ")[0];
    String endTimeStr = timeSlot.split(" - ")[1];

    int startHour = int.parse(startTimeStr.split(":")[0]);
    int endHour = int.parse(endTimeStr.split(":")[0]);

    String checkInStart = "${(startHour - 2).toString().padLeft(2, '0')}:00";
    String checkInEnd = "${(endHour - 2).toString().padLeft(2, '0')}:00";

    return "$checkInStart - $checkInEnd";
  }

  Future<void> _checkAvailability() async {
    try {
      if (_shippingData == null) return;

      final rawDate = _shippingData!['stuffing_date'];
      final String filterDate = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime.parse(rawDate.toString()));
      final int targetWarehouseId = int.parse(
        _shippingData!['warehouse_id'].toString(),
      );

      final List<dynamic> response = await supabase.rpc(
        'get_booked_slots',
        params: {
          'target_date': filterDate,
          'target_warehouse_id': targetWarehouseId,
        },
      );

      Map<String, int> counts = {};
      for (var row in response) {
        String? slot = row['slot_time'];
        int total = int.parse(row['total_booked'].toString());
        if (slot != null) {
          counts[slot] = total;
        }
      }

      setState(() {
        _bookedCounts = counts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade700,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: _selectedTime == null || _isSaving
            ? null
            : () {
                if (widget.oldTime != null) {
                  _showReasonDialog();
                } else {
                  _confirmAndAccept();
                }
              },
        child: _isSaving
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                widget.oldTime == null
                    ? "KONFIRMASI JADWAL & TERIMA ORDER"
                    : "KONFIRMASI RESCHEDULE JADWAL",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  void _showReasonDialog() {
    _tempSelectedReason = null;
    _otherReasonController.clear();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text(
                "Pilih Alasan Reschedule",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ..._rescheduleReasons.map((reason) {
                      return RadioListTile<String>(
                        title: Text(
                          reason,
                          style: const TextStyle(fontSize: 14),
                        ),
                        value: reason,
                        groupValue: _tempSelectedReason,
                        activeColor: Colors.red.shade700,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (value) {
                          setStateDialog(() {
                            _tempSelectedReason = value;
                          });
                        },
                      );
                    }),

                    if (_tempSelectedReason == 'Other')
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: TextField(
                          controller: _otherReasonController,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: "Tulis alasan lainnya...",
                            hintStyle: const TextStyle(fontSize: 13),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          maxLines: 2,
                          onChanged: (val) {
                            setStateDialog(() {});
                          },
                        ),
                      ),
                  ],
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "BATAL",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: _tempSelectedReason == null
                      ? null
                      : () {
                          Navigator.pop(context);
                          _confirmAndAccept(
                            rescheduleReasons: _tempSelectedReason,
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: const Text(
                    "SIMPAN JADWAL BARU",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _infoBox(String label, String value) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    ),
  );
  Widget _buildBadge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color, width: 1),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
    ),
  );
  String _formatDate(String? s) => s == null || s.isEmpty
      ? "-"
      : DateFormat('dd/MM/yy').format(DateTime.parse(s));
}
