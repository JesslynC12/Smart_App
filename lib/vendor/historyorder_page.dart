import 'package:flutter/material.dart';
import 'package:project_app/auth/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class VendorOrderHistoryPage extends StatefulWidget {
  final String vendorNik;

  const VendorOrderHistoryPage({super.key, required this.vendorNik});

  @override
  State<VendorOrderHistoryPage> createState() => _VendorOrderHistoryPageState();
}

class _VendorOrderHistoryPageState extends State<VendorOrderHistoryPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _historyData = [];
  List<int> _vendorDetailIds = [];

  @override
  void initState() {
    super.initState();
    _loadVendorDetailIds().then((_) => _fetchHistory());
  }

  Future<void> _loadVendorDetailIds() async {
    _vendorDetailIds = await AuthService.getVendorDetailIds(widget.vendorNik);
  }

  Future<void> _fetchHistory() async {
    try {
      setState(() => _isLoading = true);

      if (_vendorDetailIds.isEmpty) {
        setState(() {
          _historyData = [];
          _isLoading = false;
        });
        return;
      }

      final response = await supabase
          .from('shipping_assignments')
          .select('''
          *,
          request:shipping_id (
            shipping_id, so, rdd, group_id, stuffing_date, storage_location, is_dedicated,
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
          .inFilter('id_vendor_details', _vendorDetailIds)
          .inFilter('status_assignment', [
            'completed',
            'rejected',
            'no response',
            'cancel booking',
          ])
          .order('responded_at', ascending: false);

      List<dynamic> rawData = response as List;
      Map<String, Map<String, dynamic>> groupedMap = {};

      for (var item in rawData) {
        final req = item['request'];
        if (req == null) continue;

        String key = req['group_id'] != null
            ? "GROUP_${req['group_id']}"
            : "SINGLE_${req['shipping_id']}";

        if (!groupedMap.containsKey(key)) {
          Map<String, dynamic> mutableItem = Map<String, dynamic>.from(item);

          mutableItem['all_requests'] = [Map<String, dynamic>.from(req)];

          List dos = List.from(
            mutableItem['all_requests'][0]['delivery_order'] ?? [],
          );
          for (var d in dos) {
            d['rdd_origin'] = req['rdd'];
          }
          mutableItem['all_requests'][0]['delivery_order'] = dos;

          groupedMap[key] = mutableItem;
        } else {
          List allReqs = groupedMap[key]!['all_requests'];

          bool isShipExists = allReqs.any(
            (r) => r['shipping_id'] == req['shipping_id'],
          );

          if (!isShipExists) {
            Map<String, dynamic> newReq = Map<String, dynamic>.from(req);
            List newDos = List.from(newReq['delivery_order'] ?? []);

            for (var ndo in newDos) {
              ndo['rdd_origin'] = req['rdd'];
            }
            newReq['delivery_order'] = newDos;
            allReqs.add(newReq);
          }
        }
      }

      List<Map<String, dynamic>> finalResult = groupedMap.values.toList();
      finalResult.sort(
        (a, b) => (b['responded_at'] ?? "").compareTo(a['responded_at'] ?? ""),
      );

      setState(() {
        _historyData = finalResult;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Error History: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : _historyData.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _fetchHistory,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _historyData.length,
                itemBuilder: (context, index) =>
                    _buildHistoryCard(_historyData[index]),
              ),
            ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    final List allRequests = item['all_requests'] ?? [];
    if (allRequests.isEmpty) return const SizedBox.shrink();

    final String status =
        item['status_assignment']?.toString().toLowerCase() ?? "";
    final bool isNegativeStatus =
        status == 'rejected' ||
        status == 'no response' ||
        status == 'cancel booking';
    final Color headerColor = isNegativeStatus
        ? Colors.red.shade700
        : Colors.green.shade700;

    final request = allRequests[0];
    final bool isGroup = request['group_id'] != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isGroup ? Icons.layers : Icons.local_shipping,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isGroup
                          ? "GROUP ID: ${request['group_id']}"
                          : "SHIP ID: ${request['shipping_id']}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Text(
                  status.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
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
                  children: [
                    Icon(
                      isNegativeStatus
                          ? Icons.cancel_outlined
                          : Icons.check_circle_outline,
                      size: 14,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "${isNegativeStatus ? 'Batal' : 'Selesai'} pada: ${_formatDateTime(item['responded_at'])}",
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _infoBox("STUFFING", _formatDate(request['stuffing_date'])),
                    _infoBox(
                      "TYPE",
                      (request['is_dedicated'] ?? "-").toString().toUpperCase(),
                    ),
                    _infoBox(
                      "WAREHOUSE",
                      request['warehouse'] != null
                          ? "${request['warehouse']['lokasi']} - ${request['warehouse']['warehouse_name']}"
                                .toUpperCase()
                          : "-",
                      color: Colors.red.shade700,
                    ),
                  ],
                ),
                const Divider(height: 32),

                const Text(
                  "RINCIAN MUATAN",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 10),

                ...allRequests.map((req) {
                  final List dos = req['delivery_order'] ?? [];
                  final String soNum = req['so']?.toString() ?? "-";

                  return Column(
                    children: dos
                        .map((doItem) => _buildDoMiniCard(doItem, soNum))
                        .toList(),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoMiniCard(Map<String, dynamic> doItem, String parentSo) {
    final List details = doItem['do_details'] ?? [];
    final String rddSpesifik = _formatDate(doItem['rdd_origin']);
    final customer = doItem['customer'] ?? {};
    final String custInfo =
        "${customer['customer_id'] ?? '-'} - ${customer['customer_name'] ?? '-'}";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Row(
            children: [
              Icon(Icons.calendar_month, size: 14, color: Colors.red.shade700),
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
          margin: const EdgeInsets.only(bottom: 16),
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
                  borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "DO: ${doItem['do_number']}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      "SO: $parentSo",
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      custInfo.toUpperCase(),
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
                      _tablePadding(mat['material_id']?.toString() ?? "-"),
                      _tablePadding(mat['material_name']?.toString() ?? "-"),
                      _tablePadding(
                        det['qty']?.toString() ?? "0",
                        isBold: true,
                        align: TextAlign.right,
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
  }

  Widget _tablePadding(
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            "Belum ada riwayat pekerjaan.",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? s) =>
      s == null ? "-" : DateFormat('dd MMM yyyy').format(DateTime.parse(s));
  String _formatDateTime(String? s) =>
      s == null ? "-" : DateFormat('dd/MM/yy HH:mm').format(DateTime.parse(s));
}
