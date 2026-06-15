import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html; 
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:async';
import 'package:intl/intl.dart';

class ListDOPage extends StatefulWidget {
  const ListDOPage({super.key});

  @override
  State<ListDOPage> createState() => _ListDOPageState();
}

class _ListDOPageState extends State<ListDOPage> {
  final supabase = Supabase.instance.client;
  StreamSubscription? _realtimeSubscription;
  bool _isLoading = true;
  String _dateFilterType = "RDD";
  String? userDisplayName;

final ScrollController _horizontalController = ScrollController();
  List<Map<String, dynamic>> _allRequests = [];
  List<Map<String, dynamic>> _filteredRequests = [];
  String _searchQuery = "";
DateTimeRange? _selectedDateRange;

  final Set<int> _selectedIds = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchShippingRequests();
    _setupRealtime();
  }

void _setupRealtime() {
    _realtimeSubscription = supabase
        .from('shipping_request')
        .stream(primaryKey: ['shipping_id'])
        .listen((_) {
          _fetchShippingRequests(isRealtimeTrigger: true);
        });
  }

@override
  void dispose() {
    _horizontalController.dispose();
    _realtimeSubscription?.cancel(); 
    _searchController.dispose();
    super.dispose();
  }

Future<void> _fetchShippingRequests({bool isRealtimeTrigger = false}) async {
  try {
   
    if (_allRequests.isEmpty && !isRealtimeTrigger) {
      setState(() => _isLoading = true);
    }
    final response = await supabase
        .from('shipping_request')
        .select('''
          *,
          group_id,
          delivery_order (
            do_number,
            customer (customer_id, customer_name),
            do_details (details_id, qty, material (material_id, material_name, material_type, net_weight))
          ),
      shipping_pending_history (
      shipping_id,
        reason,
        pending_at
      )
        ''')
        // .eq('status', 'waiting approval',) 
        .inFilter('status', ['waiting approval', 'pending'])
        .order('shipping_id', ascending: false);

    List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(response);
if (mounted) {
    setState(() {
      _allRequests = data;
      _filteredRequests = _allRequests;
      _runFilter(_searchController.text);
      _isLoading = false;
      _selectedIds.clear();
    });
}
  } catch (e) {
    setState(() => _isLoading = false);
    _showSnackBar("Gagal ambil data: $e", Colors.red);
    //print("Error Detail: $e");
  }
}

Future<void> _updateQtyMaterial(int detailsId, double newQty) async {
  try {
    await supabase
        .from('do_details')
        .update({'qty': newQty})
        .eq('details_id', detailsId);
  } catch (e) {
    rethrow;
  }
}

void _editShippingRequest(Map<String, dynamic> req) async {
  final bool isGroup = req['group_id'] != null;
  final List<int> idsToUpdate = isGroup 
      ? List<int>.from(req['grouped_ids']) 
      : [req['shipping_id'] as int];

Map<int, TextEditingController> soController = {};
  Map<int, TextEditingController> qtyControllers = {};

  if (isGroup) {
   
    for (int sId in idsToUpdate) {
      var originalReq = _allRequests.firstWhere((element) => element['shipping_id'] == sId);
      soController[sId] = TextEditingController(text: originalReq['so']?.toString() ?? "");
    }
  } else {
    soController[req['shipping_id']] = TextEditingController(text: req['so']?.toString() ?? "");
  }

  final List dos = req['delivery_order'] ?? [];
  for (var d in dos) {
    for (var det in d['do_details']) {
      int detId = det['details_id'];
      qtyControllers[detId] = TextEditingController(text: det['qty'].toString());
    }
  }

 DateTime? selectedRDD = req['rdd'] != null ? DateTime.tryParse(req['rdd'].toString()) : null;
  DateTime? selectedStuffing = req['stuffing_date'] != null ? DateTime.tryParse(req['stuffing_date'].toString()) : null;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) => StatefulBuilder(
      builder: (context, setModalState) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom, 
          left: 20, right: 20, top: 20
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isGroup ? "Edit Grup (ID: ${req['group_id']})" : "Edit Shipping Request", 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
            ),
            const Divider(),
            
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                   
                    const Align(alignment: Alignment.centerLeft, child: Text("Nomor SO:", style: TextStyle(fontWeight: FontWeight.bold))),
                    const SizedBox(height: 8),
                    ...soController.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TextField(
                          controller: entry.value,
                          decoration: InputDecoration(
                            labelText: isGroup ? "SO untuk Ship ID ${entry.key}" : "Nomor SO",
                            isDense: true,
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.assignment, size: 20),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        _buildDateTile("RDD", selectedRDD, (date) => setModalState(() => selectedRDD = date)),
                        const SizedBox(width: 10),
                        _buildDateTile("Stuffing", selectedStuffing, (date) => setModalState(() => selectedStuffing = date)),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Daftar Material (Edit Qty):", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    const SizedBox(height: 10),

                    ...dos.expand((d) {
                      return (d['do_details'] as List).map((det) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300)
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(det['material']?['material_name'] ?? "Unknown Material", 
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    Text("DO: ${d['do_number']}", style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 80,
                                child: TextField(
                                  controller: qtyControllers[det['details_id']],
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                  decoration: const InputDecoration(
                                    labelText: "Qty",
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      });
                    })
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50), 
                  backgroundColor: Colors.blue.shade800,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
                onPressed: () async {
                  try {
                    
                    for (var entry in soController.entries) {
                      await supabase
                          .from('shipping_request')
                          .update({
                            'so': entry.value.text,
                            'rdd': selectedRDD?.toIso8601String(),
                            'stuffing_date': selectedStuffing?.toIso8601String(),
                          })
                          .eq('shipping_id', entry.key);
                    }
                   
                    for (var entry in qtyControllers.entries) {
                      double? newQty = double.tryParse(entry.value.text);
                      if (newQty != null) {
                        await _updateQtyMaterial(entry.key, newQty);
                      }
                    }
                   if (context.mounted) Navigator.pop(context);
                    _showSnackBar("Data dan Qty Berhasil Diperbarui!", Colors.green);
                    _fetchShippingRequests();
                  } catch (e) {
                    setState(() => _isLoading = false);
                    _showSnackBar("Gagal Update: $e", Colors.red);
                  }
                },
                child: const Text("SIMPAN PERUBAHAN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildDateTile(String label, DateTime? date, Function(DateTime) onPick) {
  return Expanded(
    child: InkWell(
      onTap: () async {
        DateTime? picked = await showDatePicker(
          context: context, 
          initialDate: date ?? DateTime.now(), 
          firstDate: DateTime(2020), lastDate: DateTime(2100)
        );
        if (picked != null) onPick(picked);
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade100)
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.blue)),
            Text(date == null ? "-" : DateFormat('dd/MM/yyyy').format(date),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    ),
  );
}

Future<void> _createAndAssignGroup() async {
  if (_selectedIds.length < 2) {
    _showSnackBar("Pilih minimal 2 data untuk digrup", Colors.orange);
    return;
  }

  final alreadyGrouped = _allRequests.where((req) => 
      _selectedIds.contains(req['shipping_id']) && req['group_id'] != null
  ).toList();

  if (alreadyGrouped.isNotEmpty) {
    String problemIds = alreadyGrouped.map((e) => e['shipping_id']).join(", ");
    
    _showSnackBar(
      "Gagal! ID ($problemIds) sudah memiliki grup. Silakan Split dulu jika ingin mengganti grup.", 
      Colors.red
    );
    return; 
  }
  
  try {
final currentUser = supabase.auth.currentUser;
    String creatorName = "System"; 

    if (currentUser != null) {
      final profile = await supabase
          .from('profiles')
          .select('name')
          .eq('id', currentUser.id)
          .single();
      creatorName = profile['name'] ?? "No Name";
    }
    final groupResponse = await supabase
        .from('shipping_groups')
        .insert({
          'created_at': DateTime.now().toIso8601String(), 
          'created_by': creatorName,
        })
      
        .select()
        .single();

    final int newGroupId = groupResponse['id'];

    await supabase
        .from('shipping_request')
        .update({'group_id': newGroupId})
        .inFilter('shipping_id', _selectedIds.toList());

    _showSnackBar("Berhasil membuat Grup ID: $newGroupId", Colors.green);
    
    setState(() => _selectedIds.clear());
    await _fetchShippingRequests(); 
    
  } catch (e) {
    setState(() => _isLoading = false);
    _showSnackBar("Gagal grouping: $e", Colors.red);
  }
}

List<Map<String, dynamic>> _getGroupedDisplayData(List<Map<String, dynamic>> source) {
  Map<int, Map<String, dynamic>> groupedMap = {};
  List<Map<String, dynamic>> finalResult = [];

  for (var req in source) {
    if (req['group_id'] == null) {
      finalResult.add(Map<String, dynamic>.from(req));
    } else {
      int gId = req['group_id'];
      if (!groupedMap.containsKey(gId)) {
        groupedMap[gId] = Map<String, dynamic>.from(req);
        groupedMap[gId]!['grouped_ids'] = [req['shipping_id']];
        groupedMap[gId]!['all_rdds'] = [req['rdd']];
     
  List historyRaw = req['shipping_pending_history'] ?? [];
  List historyWithId = historyRaw.map((h) => {
    ...h, 
    'origin_ship_id': req['shipping_id'] // Suntik ID asli ke tiap baris history
  }).toList();
  
  groupedMap[gId]!['collective_history'] = historyWithId;
      } else {
        groupedMap[gId]!['grouped_ids'].add(req['shipping_id']);
        
      
  List currentHistory = List.from(groupedMap[gId]!['collective_history'] ?? []);
  List newHistoryRaw = req['shipping_pending_history'] ?? [];
  
  for (var h in newHistoryRaw) {
    currentHistory.add({
      ...h, 
      'origin_ship_id': req['shipping_id']
    });
  }
  groupedMap[gId]!['collective_history'] = currentHistory;

        List<String?> rdds = List<String?>.from(groupedMap[gId]!['all_rdds']);
        if (!rdds.contains(req['rdd'])) {
          rdds.add(req['rdd']);
        }
        groupedMap[gId]!['all_rdds'] = rdds;
        List currentDos = List.from(groupedMap[gId]!['delivery_order'] ?? []);
        List newDos = req['delivery_order'] ?? [];
        
        for (var ndo in newDos) {
          ndo['parent_so'] = req['so']; 
          currentDos.add(ndo);
        }
        
        groupedMap[gId]!['delivery_order'] = currentDos;
      }
    }
  }
  
  finalResult.addAll(groupedMap.values);
  finalResult.sort((a, b) => (b['shipping_id'] as int).compareTo(a['shipping_id'] as int));
  return finalResult;
}


Future<void> _editStuffingMassal() async {
  if (_selectedIds.isEmpty) return;
final now = DateTime.now();
  final DateTime? picked = await showDatePicker(
    context: context,
    initialDate: DateTime.now(),
    firstDate: DateTime(2025),
    lastDate: DateTime(now.year + 100),
    helpText: 'Pilih Tanggal Stuffing untuk Semuanya',
  );

  if (picked != null) {
    String formattedDate = picked.toIso8601String().split('T')[0];

    try {
     
      await supabase
          .from('shipping_request')
          .update({'stuffing_date': formattedDate})
          .inFilter('shipping_id', _selectedIds.toList());

      _showSnackBar("Berhasil update stuffing ${_selectedIds.length} data", Colors.green);
      
     
      await _fetchShippingRequests();
    } catch (e) {
      _showSnackBar("Gagal update massal: $e", Colors.red);
    } finally {
      
    }
  }
}

Future<void> _prosesKePermintaan() async {
  if (_selectedIds.isEmpty) return;
  
  try {
  
List<String> errorMessages = [];
for (var id in _selectedIds) {
      final req = _allRequests.firstWhere((element) => element['shipping_id'] == id, orElse: () => {});
      
      if (req.isNotEmpty) {
        
        String so = req['so']?.toString().trim() ?? "";
        String rdd = req['rdd']?.toString().trim() ?? "";
        String stuffing = req['stuffing_date']?.toString().trim() ?? "";

        if (so.isEmpty || rdd.isEmpty || stuffing.isEmpty) {
          errorMessages.add("Ship ID $id: SO, RDD, atau Stuffing Date masih kosong.");
          continue;
        }
        }
              }
    if (errorMessages.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Data Belum Lengkap", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: errorMessages.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text("- ${errorMessages[index]}", style: const TextStyle(fontSize: 13)),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("OKE")),
          ],
        ),
      );
      return; 
    }
    await supabase
        .from('shipping_request')
        .update({
          'status': 'waiting GBJ',
        })
        .inFilter('shipping_id', _selectedIds.toList());

    _showSnackBar("Berhasil memproses ${_selectedIds.length} Shipping ID", Colors.green);
    
    setState(() => _selectedIds.clear());
    await _fetchShippingRequests();
    
  } catch (e) {
    setState(() => _isLoading = false);
    _showSnackBar("Gagal memproses data: $e", Colors.red);
  }
}

  void _runFilter(String query) {
  setState(() {
    _searchQuery = query.toLowerCase();

    _filteredRequests = _allRequests.where((req) {
      final soNum = (req['so'] ?? "").toString().toLowerCase();
      final List dos = req['delivery_order'] ?? [];

      bool matchInSO = soNum.contains(_searchQuery);

      bool matchInDO = dos.any((doItem) {
        final doNum = (doItem['do_number'] ?? "").toString().toLowerCase();
        final custId = (doItem['customer']?['customer_id'] ?? "").toString().toLowerCase();
        final custName = (doItem['customer']?['customer_name'] ?? "").toString().toLowerCase();
        final List details = doItem['do_details'] ?? [];

        bool matchMat = details.any((det) {
          final matId = (det['material']?['material_id'] ?? "").toString().toLowerCase();
          final matName = (det['material']?['material_name'] ?? "").toString().toLowerCase();
          
          return matId.contains(_searchQuery) || matName.contains(_searchQuery);
        });

        return doNum.contains(_searchQuery) || 
               custName.contains(_searchQuery) || 
               custId.contains(_searchQuery) || 
               matchMat;
      });

      bool matchText = matchInSO || matchInDO;

      bool matchDate = true;
      if (_selectedDateRange != null) {
     
String dateColumn = _dateFilterType == "RDD" ? 'rdd' : 'stuffing_date';
  
  DateTime? targetDate = req[dateColumn] != null 
      ? DateTime.tryParse(req[dateColumn].toString()) 
      : null;
  
  if (targetDate != null) {
    final startDate = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
    final endDate = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day);
    final checkDate = DateTime(targetDate.year, targetDate.month, targetDate.day);

    matchDate = checkDate.isAtSameMomentAs(startDate) || 
                checkDate.isAtSameMomentAs(endDate) ||
                (checkDate.isAfter(startDate) && checkDate.isBefore(endDate));
  } else {
    matchDate = false; 
  }
}
      return matchText && matchDate;
    }).toList();
  });
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
     
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildTableArea(),
          ),
        ],
      ),
      bottomNavigationBar: _selectedIds.isNotEmpty ? _buildActionBottomBar() : null,
   
    );
  }

String formatSmart(dynamic value) {
  if (value == null) return "0";
  double n = double.tryParse(value.toString()) ?? 0.0;
  num rounded = num.parse(n.toStringAsFixed(3));
 return rounded.toString();
}

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
      children: [
        Expanded(
          flex: 3,
      child: TextField(
        controller: _searchController,
        onChanged: _runFilter,
        decoration: InputDecoration(
          hintText: "Cari SO, DO, Customer, atau Material...",
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
        ),
        const SizedBox(width: 8),
        if (_selectedIds.isNotEmpty)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade100,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 19),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _editStuffingMassal,
            icon: const Icon(Icons.edit_calendar, size: 16),
            label: const Text("Set Stuffing Massal", style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 8),

Container(
  decoration: BoxDecoration(
    color: _selectedDateRange != null ? Colors.red.shade700 : Colors.grey.shade200,
    borderRadius: BorderRadius.circular(10),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: const EdgeInsets.only(left: 10, right: 5),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: _selectedDateRange != null ? Colors.white30 : Colors.grey.shade400,
              width: 1,
            ),
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _dateFilterType,
            isDense: true,
            dropdownColor: _selectedDateRange != null ? Colors.red.shade800 : Colors.white,
            iconEnabledColor: _selectedDateRange != null ? Colors.white : Colors.black87,
            style: TextStyle(
              fontSize: 12, 
              fontWeight: FontWeight.bold,
              color: _selectedDateRange != null ? Colors.white : Colors.black87,
            ),
            items: ["RDD", "Stuffing"].map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                _dateFilterType = val!;
                _runFilter(_searchController.text);
              });
            },
          ),
        ),
      ),

      InkWell(
        onTap: _pickDateRange,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(10),
          bottomRight: Radius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.date_range, 
                size: 18, 
                color: _selectedDateRange != null ? Colors.white : Colors.black87,
              ),
              const SizedBox(width: 8),
              Text(
                _selectedDateRange == null 
                    ? "Filter Tanggal" 
                    : "${DateFormat('dd/MM').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM').format(_selectedDateRange!.end)}",
                style: TextStyle(
                  fontSize: 12,
                  color: _selectedDateRange != null ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  ),
),

if (_selectedDateRange != null || _searchController.text.isNotEmpty)
  IconButton(
    icon: const Icon(Icons.refresh, color: Colors.red),
    onPressed: () {
      setState(() {
        _searchController.clear();
        _selectedDateRange = null;
        _dateFilterType = "RDD";
      });
      _runFilter("");
    },
  ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: _importMassalTigaTabel,
            icon: const Icon(Icons.file_upload, color: Colors.orange),
            tooltip: "Import Excel",
            style: IconButton.styleFrom(
    backgroundColor: Colors.orange.shade50,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ),
          ),
          const SizedBox(width: 6),
IconButton(
  onPressed: _exportToExcel,
  icon: const Icon(Icons.file_download, color: Colors.green),
  tooltip: "Export Excel",
  style: IconButton.styleFrom(
    backgroundColor: Colors.green.shade50,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ),
 ),
      
      ],
      
    ),
    
  );
}
  
Future<void> _pickDateRange() async {
  final now = DateTime.now();
  DateTimeRange? picked = await showDateRangePicker(
    context: context,
    firstDate: DateTime(2025),
    lastDate: DateTime(now.year + 100),
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
            constraints: const BoxConstraints(
              maxWidth: 400,  
              maxHeight: 550,
            ),
            child: child!,
          ),
        ),
      );
    },
  );

  if (picked != null) {
    setState(() => _selectedDateRange = picked);
    _runFilter(_searchController.text);
  }
}

double get _totalSelectedTNW {
  double total = 0;
  for (var id in _selectedIds) {
    final req = _allRequests.firstWhere((element) => element['shipping_id'] == id, orElse: () => {});
    if (req.isNotEmpty) {
      final List dos = req['delivery_order'] ?? [];
      for (var d in dos) {
        for (var det in d['do_details']) {
          double qty = double.tryParse(det['qty']?.toString() ?? "0") ?? 0;
          double nw = double.tryParse(det['material']?['net_weight']?.toString() ?? "0") ?? 0;
          total += (qty * nw);
        }
      }
    }
  }
  return total / 1000;
}
 
Widget _buildTableArea() {
  if (_filteredRequests.isEmpty) {
    return const Center(child: Text("Tidak ada data ditemukan"));
  }

  return LayoutBuilder(
    builder: (context, constraints) {
      final List<DataColumn> originalColumns = _buildColumns();

      return Scrollbar(
        controller: _horizontalController,
        thumbVisibility: true,
        trackVisibility: true,
        child: SingleChildScrollView(
          controller: _horizontalController,
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DataTable(
                  headingRowColor: WidgetStateProperty.all(Colors.red.shade700),
                  headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  columnSpacing: 10,
                  horizontalMargin: 13,
                  columns: originalColumns,
                  rows: const [], 
                ),
                
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ClipRect(
                        child: DataTable(
                          headingRowHeight: 0, 
                          dataRowMaxHeight: double.infinity,
                          dataRowMinHeight: 70,
                          columnSpacing: 9,
                          horizontalMargin: 12, 
                          columns: originalColumns.map((col) {
                            final labelWidget = col.label;
                            double targetWidth = 50.0;
                            if (labelWidget is SizedBox) {
                              targetWidth = labelWidget.width ?? 50.0;
                            }
                            return DataColumn(label: SizedBox(width: targetWidth));
                          }).toList(), 
                          rows: _getGroupedDisplayData(_filteredRequests).map((req) {
                            return _buildDataRow(req);
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
DataRow _buildDataRow(Map<String, dynamic> req) {
  final isGroupRow = req['group_id'] != null;
  final List<int> idsInRow = isGroupRow
      ? List<int>.from(req['grouped_ids'])
      : [req['shipping_id'] as int];

  final bool isSelected = idsInRow.any((id) => _selectedIds.contains(id));
  final int shippingId = req['shipping_id'];
  final List dos = req['delivery_order'] ?? [];

  List<Widget> doNumW = [],
      soW = [],
      custIdW = [],
      custW = [],
      matIdW = [],
      matW = [],
      matTypeW = [],
      qtyW = [],
      nwW = [];
  double totalNetWeight = 0;

  for (var d in dos) {
    String currentSo = d['parent_so']?.toString() ?? req['so']?.toString() ?? "-";
    String custId = d['customer']?['customer_id']?.toString() ?? "-";
    for (var det in d['do_details']) {
      double qty = double.tryParse(det['qty']?.toString() ?? "0") ?? 0;
      double nwValue = double.tryParse(det['material']?['net_weight']?.toString() ?? "0") ?? 0;
      double rowNw = qty * nwValue;
      totalNetWeight += rowNw;

      // soW.add(_buildTextItem(currentSo, width: 80));
      // doNumW.add(_buildTextItem(d['do_number'] ?? "-", isBold: true, width: 70));
      // custIdW.add(_buildTextItem(custId, width: 70));
      // custW.add(_buildTextItem(d['customer']?['customer_name'] ?? "-", width: 196));
      // matIdW.add(_buildTextItem(det['material']?['material_id']?.toString() ?? "-", width: 50));
      // matW.add(_buildTextItem(det['material']?['material_name'] ?? "-", width: 226));
      // matTypeW.add(_buildTextItem(det['material']?['material_type'] ?? "-", width: 42));
      // qtyW.add(_buildTextItem(det['qty']?.toString() ?? "0", isBold: true, width: 30));
      // nwW.add(_buildTextItem(formatSmart(rowNw), width: 52));
      soW.add(_buildTextItem(currentSo, width: 90)); 
doNumW.add(_buildTextItem(d['do_number'] ?? "-", isBold: true, width: 80));
custIdW.add(_buildTextItem(custId, width: 70)); 
custW.add(_buildTextItem(d['customer']?['customer_name'] ?? "-", width: 180));
matIdW.add(_buildTextItem(det['material']?['material_id']?.toString() ?? "-", width: 65)); 
matW.add(_buildTextItem(det['material']?['material_name'] ?? "-", width: 220)); 
matTypeW.add(_buildTextItem(det['material']?['material_type'] ?? "-", width: 45));
qtyW.add(_buildTextItem(det['qty']?.toString() ?? "0", isBold: true, width: 45)); 
nwW.add(_buildTextItem(formatSmart(rowNw), width: 55));
    }
  }

  return DataRow(
    selected: isSelected,
    color: WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.selected)) {
          return Colors.grey.shade400.withValues(alpha: 0.5);
        }
      final String currentStatus = (req['status'] ?? "").toString().toLowerCase();
      if (currentStatus == 'pending') return Colors.red.shade100;
      if (req['group_id'] != null) return Colors.blue.shade100.withValues(alpha: 0.5);
      return null;
    }),
    cells: [
      DataCell(Checkbox(
        value: isSelected,
        onChanged: (v) {
          setState(() {
            if (v == true) {
              _selectedIds.addAll(idsInRow);
            } else {
              _selectedIds.removeAll(idsInRow);
            }
          });
        },
      )),
      DataCell(Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
         
if (isGroupRow)
  Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: idsInRow.map((id) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text(
        id.toString(),
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
      ),
    )).toList(),
  )
else
  Text(
    shippingId.toString(),
    style: const TextStyle(fontWeight: FontWeight.normal, fontSize: 11),
  ),
          _buildStatusBadge(req['status'],isGroupRow ? req['collective_history'] : req['shipping_pending_history']),
          if (isGroupRow)
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: BorderRadius.circular(4)),
              child: Text("GROUP ID: ${req['group_id']}",
                  style: const TextStyle(color: Colors.white, fontSize: 9)),
            ),
        ],
      )),
      DataCell(Column(children: doNumW)),
      DataCell(Column(children: soW)),
      DataCell(Column(children: custIdW)),
      DataCell(Column(children: custW)),
      DataCell(Column(children: matIdW)),
      DataCell(Column(children: matW)),
      DataCell(Column(children: matTypeW)),
      DataCell(Column(children: qtyW)),
      DataCell(Column(children: nwW)),
      DataCell(Text(formatSmart(totalNetWeight / 1000),
          style: const TextStyle(fontWeight: FontWeight.bold))),
    
      DataCell(
        InkWell(
          onTap: () => _selectDate(context, req, 'rdd'),
          child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Builder(
        builder: (context) {
          if (req['all_rdds'] != null) {
            List<String?> rdds = List<String?>.from(req['all_rdds']);
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rdds.map((r) => Text(
                _formatDate(r), 
                style: const TextStyle(fontSize: 12, color: Colors.black)
              )).toList(),
            );
          }
          return Text(_formatDate(req['rdd']), style: const TextStyle(color: Colors.black));
        }
      ),
    ),
  ),
),

      DataCell(
        InkWell(
          onTap: () => _selectDate(context, req, 'stuffing_date'),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_formatDate(req['stuffing_date']), style: const TextStyle(color: Colors.black)),
              // const Icon(Icons.calendar_month, size: 14, color: Colors.blue),
            ],
          ),
        ),
      ),
      DataCell(Row(
        children: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
            onPressed: () => _editShippingRequest(req),
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(2),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
            onPressed: () => _deleteShippingRequest(req),
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(2),
          ),
        ],
      )),
    ],
  );
}

List<DataColumn> _buildColumns() {
  final visibleRows = _getGroupedDisplayData(_filteredRequests);
  final List<int> visibleIds = [];
  for (var row in visibleRows) {
    if (row['group_id'] != null) {
      visibleIds.addAll(List<int>.from(row['grouped_ids']));
    } else {
      visibleIds.add(row['shipping_id'] as int);
    }
  }

  final bool isAllSelected = visibleIds.isNotEmpty && 
      visibleIds.every((id) => _selectedIds.contains(id));

  return [
    DataColumn(
      label: SizedBox(
        width: 35, 
        child: Theme(
          data: Theme.of(context).copyWith(unselectedWidgetColor: Colors.white),
          child: Checkbox(
            value: isAllSelected,
            activeColor: Colors.white,
            checkColor: Colors.red.shade700,
            side: const BorderSide(color: Colors.white, width: 2),
            onChanged: (bool? checked) {
              setState(() {
                if (checked == true) {
                  _selectedIds.addAll(visibleIds);
                } else {
                  _selectedIds.removeAll(visibleIds);
                }
              });
            },
          ),
        ),
      ),
    ),
    const DataColumn(label: SizedBox(width: 75, child: Text('Ship ID'))),
    const DataColumn(label: SizedBox(width: 80, child: Text('No DO'))),
    const DataColumn(label: SizedBox(width: 90, child: Text('SO Number'))),
    const DataColumn(label: SizedBox(width: 70, child: Text('No Cust'))),
    const DataColumn(label: SizedBox(width: 180, child: Text('Customer Tujuan'))),
    const DataColumn(label: SizedBox(width: 65, child: Text('No Mat'))),
    const DataColumn(label: SizedBox(width: 220, child: Text('Nama Material'))),
    const DataColumn(label: SizedBox(width: 45, child: Text('Type'))),
    const DataColumn(label: SizedBox(width: 45, child: Text('Qty'))),
    const DataColumn(label: SizedBox(width: 55, child: Text('NW'))),
    const DataColumn(label: SizedBox(width: 60, child: Text('TNW'))),
    const DataColumn(label: SizedBox(width: 75, child: Text('RDD'))),
    const DataColumn(label: SizedBox(width: 75, child: Text('Stuffing'))),
    const DataColumn(label: SizedBox(width: 60, child: Text('Aksi'))),
  ];
}
Future<void> _selectDate(BuildContext context, Map<String, dynamic> req, String fieldName) async {
  DateTime initialDate = DateTime.tryParse(req[fieldName]?.toString() ?? "") ?? DateTime.now();
  
  final DateTime? picked = await showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: DateTime(2024),
    lastDate: DateTime(2030), 
    helpText: 'Pilih Tanggal ${fieldName.toUpperCase()}',
  );

  if (picked != null) {
    String formattedDate = picked.toIso8601String().split('T')[0];

    try {
      
      if (req['group_id'] != null) {
        await Supabase.instance.client
            .from('shipping_request')
            .update({fieldName: formattedDate})
            .eq('group_id', req['group_id']);
            
        _showSnackBar("Update Group berhasil", Colors.green);
      } else {
        await Supabase.instance.client
            .from('shipping_request')
            .update({fieldName: formattedDate})
            .eq('shipping_id', req['shipping_id']);

        _showSnackBar("Update Tanggal berhasil", Colors.green);
      }

      // _fetchShippingRequests(); 
      
    } catch (e) {
      _showSnackBar("Gagal mengupdate: $e", Colors.red);
    }
  }
}


Future<void> _deleteShippingRequest(Map<String, dynamic> req) async {
  final int shippingId = req['shipping_id'];
  final int? groupId = req['group_id'];
  final bool isGroup = groupId != null;

  String title = isGroup ? "Hapus Grup Data" : "Hapus Data";
  String content = isGroup 
      ? "Data ini bagian dari Grup ID: $groupId. Menghapus akan menghapus SEMUA Ship ID di grup ini. Lanjutkan?"
      : "Apakah Anda yakin ingin menghapus Shipping ID: $shippingId?";

  bool confirm = await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
        TextButton(
          onPressed: () => Navigator.pop(context, true), 
          child: const Text("Hapus", style: TextStyle(color: Colors.red))
        ),
      ],
    ),
  ) ?? false;

  if (confirm) {
    try {
      setState(() => _isLoading = true);

      if (isGroup) {
       
        await supabase
            .from('shipping_request')
            .delete()
            .eq('group_id', groupId);

        await supabase
            .from('shipping_groups')
            .delete()
            .eq('id', groupId);
            
      } else {
        await supabase
            .from('shipping_request')
            .delete()
            .eq('shipping_id', shippingId);
      }

      _showSnackBar("Data berhasil dihapus", Colors.green);
      _fetchShippingRequests(); 
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Gagal menghapus: $e", Colors.red);
    }
  }
}

  Widget _buildTextItem(String text, {bool isBold = false, double? width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
      ),
    );
  }

void _showReasonDialog(List history) {
  final sortedHistory = List.from(history);
  //sortedHistory.sort((a, b) => b['pending_at'].compareTo(a['pending_at']));
  sortedHistory.sort((a, b) {
    DateTime dtA = DateTime.tryParse(a['pending_at']?.toString() ?? "") ?? DateTime(2000);
    DateTime dtB = DateTime.tryParse(b['pending_at']?.toString() ?? "") ?? DateTime(2000);
    return dtB.compareTo(dtA);
  });
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: Row(
        children: [
          Icon(Icons.cancel, color: Colors.red.shade700),
          const SizedBox(width: 10),
          const Text("Alasan Pending", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: sortedHistory.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final item = sortedHistory[index];
         

DateTime date = DateTime.tryParse(item['pending_at']?.toString() ?? "") ?? DateTime.now();
            String originId = (item['origin_ship_id'] ?? item['shipping_id'] ?? item['id'] ?? "-").toString();
            
            return ListTile(
      
      contentPadding: EdgeInsets.zero,
              title: Text(item['reason'] ?? "-", style: const TextStyle(fontSize: 14)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Ship ID: $originId", 
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)),
                  Text(DateFormat('dd MMM yyyy, HH:mm').format(date.toLocal()),
                    style: const TextStyle(fontSize: 11)),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Tutup")),
      ],
    ),
  );
}

Widget _buildStatusBadge(String? status, dynamic historyData) {
  if (status == null || status.toLowerCase() != 'pending') {
    return const SizedBox.shrink();
  }

  if (historyData == null || historyData is! List || historyData.isEmpty) {
    return const SizedBox.shrink();
  }

List history = List.from(historyData);
  
  history.sort((a, b) => (a['pending_at'] ?? "").compareTo(b['pending_at'] ?? ""));
  Color color = Colors.red.shade800;
  String label = "PENDING";

  return InkWell(
    onTap: () => _showReasonDialog(history),
    child: Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color, 
              fontSize: 9, 
              fontWeight: FontWeight.bold
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.info_outline, size: 10, color: color),
        ],
      ),
    ),
  );
}

Widget _buildActionBottomBar() {
  double totalBerat = _totalSelectedTNW;
  int jumlahEntitas = _countSelectedEntities;

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -2))],
    ),
    child: SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "$jumlahEntitas Terpilih",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    "Total Estimasi Berat:",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  "${formatSmart(totalBerat)} Ton",
                  style: TextStyle(
                    color: Colors.blue.shade900,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _splitGroup,
                  icon: const Icon(Icons.link_off, size: 18),
                  label: const Text("Split", style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue.shade700,
                    side: BorderSide(color: Colors.blue.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _selectedIds.length < 2 ? null : _createAndAssignGroup,
                  icon: const Icon(Icons.link, size: 18),
                  label: const Text("Group", style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _prosesKePermintaan,
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: Text(
                    "Proses ($jumlahEntitas)", // Menampilkan jumlah truk/entitas
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

int get _countSelectedEntities {
  final Set<String> entities = {};

  for (var id in _selectedIds) {
    final req = _allRequests.firstWhere(
      (element) => element['shipping_id'] == id, 
      orElse: () => {}
    );

    if (req.isNotEmpty) {
      if (req['group_id'] != null) {
        entities.add("GROUP_${req['group_id']}");
      } else {
        entities.add("SINGLE_$id");
      }
    }
  }
  return entities.length;
}

Future<void> _splitGroup() async {
  if (_selectedIds.isEmpty) {
    _showSnackBar("Pilih data yang ingin dipisahkan dari grup", Colors.orange);
    return;
  }

  try {
    
    final selectedGroups = _allRequests
        .where((req) => _selectedIds.contains(req['shipping_id']) && req['group_id'] != null)
        .map((req) => req['group_id'] as int)
        .toSet()
        .toList();

    if (selectedGroups.isEmpty) {
      setState(() => _isLoading = false);
      _showSnackBar("Data yang dipilih memang tidak masuk dalam grup mana pun", Colors.blueGrey);
      return;
    }

    
    await supabase
        .from('shipping_request')
        .update({'group_id': null})
        .inFilter('group_id', selectedGroups);

    await supabase
        .from('shipping_groups')
        .delete()
        .inFilter('id', selectedGroups);

    _showSnackBar("Grup berhasil dibubarkan dan dihapus", Colors.blueGrey);
    
    setState(() => _selectedIds.clear());
    await _fetchShippingRequests(); 
    
  } catch (e) {
    setState(() => _isLoading = false);
    _showSnackBar("Gagal split & delete group: $e", Colors.red);
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

  void _showSnackBar(String msg, Color color, {Duration duration = const Duration(seconds: 4)}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar(); 
  
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: color,
      duration: duration, 
      action: duration.inSeconds > 10 
          ? SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            )
          : null, 
    ),
  );
}

static bool _globalExportLock = false;

Future<void> _exportToExcel() async {
  if (_globalExportLock || _filteredRequests.isEmpty) return;

  try {
    _globalExportLock = true;

    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Data_Shipping_Detail'];
    excel.delete('Sheet1'); 
    List<CellValue> headers = [
      TextCellValue('Group ID'),      
      TextCellValue('Ship ID'),       
      TextCellValue('No DO'),         
      TextCellValue('SO Number'),     
      TextCellValue('Customer'),      
      TextCellValue('Material'),      
      TextCellValue('Type'),          
      TextCellValue('Qty'),           
      TextCellValue('NW (Unit)'),     
      TextCellValue('TNW (Kg)'),      
      TextCellValue('RDD'),           
      TextCellValue('Stuffing'),      
      TextCellValue('Status'),        
      TextCellValue('Pending Reason'),
    ];
    sheetObject.appendRow(headers);

    for (var req in _filteredRequests) {
      final List dos = req['delivery_order'] ?? [];
      final String status = (req['status'] ?? "-").toString().toUpperCase();
      
      final List history = List.from(req['shipping_pending_history'] ?? []);
      String latestReason = "-";
      
      if (history.isNotEmpty) {
        history.sort((a, b) => (a['pending_at'] ?? "").compareTo(b['pending_at'] ?? ""));
        latestReason = history.last['reason'] ?? "-";
      }

      final String groupId = req['group_id']?.toString() ?? "-";

      for (var d in dos) {
        final List details = d['do_details'] ?? [];
        for (var det in details) {
          double qty = double.tryParse(det['qty']?.toString() ?? "0") ?? 0;
          double nwUnit = double.tryParse(det['material']?['net_weight']?.toString() ?? "0") ?? 0;
        
          double totalNwRow = (qty * nwUnit) / 1000;

          sheetObject.appendRow([
            TextCellValue(groupId),                                     
            TextCellValue(req['shipping_id'].toString()),               
            TextCellValue(d['do_number'] ?? "-"),                       
            TextCellValue(req['so']?.toString() ?? "-"),                
            TextCellValue(d['customer']?['customer_name'] ?? "-"),      
            TextCellValue(det['material']?['material_name'] ?? "-"),    
            TextCellValue(det['material']?['material_type'] ?? "-"),    
            DoubleCellValue(qty),                                       
            DoubleCellValue(nwUnit),                                    
            DoubleCellValue(totalNwRow),                                
            TextCellValue(_formatDate(req['rdd'])),                     
            TextCellValue(_formatDate(req['stuffing_date'])),           
            TextCellValue(status),                                      
            TextCellValue(latestReason),                                
          ]);
        }
      }
    }

    final fileBytes = excel.encode(); 
    if (fileBytes == null) return;

    String fileName = "Shipping_Report_${DateFormat('yyyyMMdd_HHmm')}.xlsx";

    if (kIsWeb) {
      final content = html.Blob([fileBytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(content);
      
      html.AnchorElement(href: url)..setAttribute("download", fileName)..click();
      html.Url.revokeObjectUrl(url);
      _showSnackBar("Excel diunduh!", Colors.green);
    } else {
      final directory = await getApplicationDocumentsDirectory();
      String filePath = '${directory.path}/$fileName';
      final file = io.File(filePath);
      await file.create(recursive: true);
      await file.writeAsBytes(fileBytes);
      await OpenFile.open(filePath);
    }

  } catch (e) {
    debugPrint("Export Error: $e");
    _showSnackBar("Gagal: $e", Colors.red);
  } finally {
    await Future.delayed(const Duration(seconds: 3));
    _globalExportLock = false;
  }
}
Future<void> _importMassalTigaTabel() async {
  try {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    setState(() => _isLoading = true);
    final bytes = result.files.first.bytes;
    var excel = Excel.decodeBytes(bytes!);
    var sheet = excel.tables.values.first;

    Map<String, List<Map<String, dynamic>>> groupedByDO = {};
    
    for (int i = 1; i < sheet.maxRows; i++) {
      var row = sheet.rows[i];
      
      if (row.isEmpty || row[0]?.value == null) continue;

      String doNum = row[0]!.value.toString().trim();
      if (!groupedByDO.containsKey(doNum)) groupedByDO[doNum] = [];

      groupedByDO[doNum]!.add({
        "so": row[1]?.value?.toString().trim() ?? "",
        "cust_id": int.tryParse(row[2]?.value?.toString() ?? ""),
        "mat_id": int.tryParse(row[3]?.value?.toString() ?? ""),
        "qty": int.tryParse(row[4]?.value?.toString() ?? "0"),
        "rdd": row[5]?.value?.toString(),
        "stuffing": row[6]?.value?.toString(), 
      });
    }

    List<String> duplicateDOs = [];
    List<String> materialNotFoundDOs = []; 
    int successCount = 0;
   
    for (var entry in groupedByDO.entries) {
      String doNumber = entry.key;
      var items = entry.value;
      var firstItem = items.first;

  final existingDO = await supabase
      .from('delivery_order')
      .select('do_id, shipping_id')
      .eq('do_number', doNumber)
      .maybeSingle();

  if (existingDO != null) {
   
    duplicateDOs.add(doNumber);
    continue;
  }
  
      bool allMaterialsValid = true;
      List<int> invalidMaterialIds = [];

      for (var item in items) {
        final int? matId = item['mat_id'];
        if (matId == null) {
          allMaterialsValid = false;
          break;
        }

        final checkMat = await supabase
            .from('material') 
            .select('material_id')
            .eq('material_id', matId)
            .maybeSingle();

        if (checkMat == null) {
          allMaterialsValid = false;
          invalidMaterialIds.add(matId);
        }
      }

      if (!allMaterialsValid) {
        materialNotFoundDOs.add("$doNumber (Mat: $invalidMaterialIds)");
        continue; 
      }
  
      String rddRaw = firstItem['rdd']?.toString() ?? '';
      String stuffing = firstItem['stuffing']?.toString() ?? '';
      if (rddRaw.contains(" ")) rddRaw = rddRaw.split(" ")[0];

      final shipRes = await supabase.from('shipping_request').insert({
        'so': firstItem['so'],
        'status': 'waiting approval',
        'rdd': DateTime.tryParse(rddRaw)?.toIso8601String(),
        'stuffing_date': stuffing,
        'createdDO_by': userDisplayName ?? 'System Import',
      }).select().single();

      final int newShipId = shipRes['shipping_id'];

      final doRes = await supabase.from('delivery_order').insert({
        'shipping_id': newShipId,
        'do_number': doNumber,
        'customer_id': firstItem['cust_id'],
      }).select().single();

      final int newDoId = doRes['do_id'];

      List<Map<String, dynamic>> detailsToInsert = items.map((item) => {
        'do_id': newDoId,
        'material_id': item['mat_id'],
        'qty': item['qty'],
      }).toList();

      await supabase.from('do_details').insert(detailsToInsert);
      successCount++;
    }

    _fetchShippingRequests();
   
    if (duplicateDOs.isNotEmpty || materialNotFoundDOs.isNotEmpty) {
      String feedbackMessage = "Berhasil import $successCount data. \n";
      
      if (duplicateDOs.isNotEmpty) {
        feedbackMessage += "⚠️ DO Duplikat (Dilewati): ${duplicateDOs.join(', ')}\n";
      }
      if (materialNotFoundDOs.isNotEmpty) {
        feedbackMessage += "❌ Material Tidak Ditemukan (Dilewati): ${materialNotFoundDOs.join(', ')}";
      }

      _showSnackBar(feedbackMessage.trim(), Colors.orange.shade900);
    } else {
      _showSnackBar("Berhasil import massal semua data tanpa kendala!", Colors.green);
    }
  } catch (e) {
    debugPrint("Error: $e");
    _showSnackBar("Gagal: $e", Colors.red);
  } finally {
    setState(() => _isLoading = false);
  }
}

}