import 'package:flutter/material.dart';
import 'package:project_app/admin/display/listppic_page.dart';
import 'package:project_app/admin/display/listPlanningBookAntrian_page.dart';
import 'package:project_app/admin/input%20form/Formppic.dart';
import 'package:project_app/dynamic_tab_page.dart';
import 'package:project_app/vendor/ListPengirimanOnProses.dart';
import 'package:project_app/vendor/historyorder_page.dart';
import 'package:project_app/vendor/listOrderVendor_page.dart';
import '../auth/auth_service.dart';
import '../login.dart';

// IMPORT SEMUA PAGE
import 'package:project_app/admin/display/listDO_page.dart';
import 'package:project_app/admin/display/listDOdetailsGBJ_page.dart';
import 'package:project_app/admin/display/listPermintaanPengiriman_page.dart';
import 'package:project_app/admin/input form/formComplain_page.dart';
import 'package:project_app/admin/input form/formOccupancy_page.dart';
import 'package:project_app/admin/input form/formDO_page.dart';
import 'package:project_app/admin/input form/formKelayakanunit_page.dart';
import 'package:project_app/admin/master data/checker_master.dart';
import 'package:project_app/admin/master data/customer_master.dart';
import 'package:project_app/admin/master data/manage_user_vendor.dart';
import 'package:project_app/admin/master data/material_master.dart';
import 'package:project_app/admin/master data/vendor_transportasi_master.dart';
import 'package:project_app/admin/master data/enrollment_vendor_page.dart';
import 'package:project_app/admin/master data/warehouse_master.dart';
import 'package:project_app/admin/master data/manage_user.dart';

class MainDrawer extends StatelessWidget {
  final User? currentUser;

  const MainDrawer({super.key, required this.currentUser});

  bool _hasAccess(String privilegeName) {
    return currentUser?.privileges.contains(privilegeName) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: Colors.red.shade700),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 40, color: Colors.red),
            ),
            accountName: Text(currentUser?.nik ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold),),
            accountEmail: Text(currentUser?.role?.toUpperCase() ?? '-', style: const TextStyle(fontWeight: FontWeight.bold),),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // ================= MENU ADMIN =================
                if (currentUser?.role == 'admin') ...[
                  _buildAdminMenu(context),
                ],

                // ================= MENU VENDOR =================
                if (currentUser?.role == 'vendor') ...[
                  _buildVendorMenu(context),
                ],
              ],
            ),
          ),
          const Divider(),
          _menuItem(context, Icons.logout, "Keluar", Colors.red, onTap: () => _logout(context)),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildAdminMenu(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            "SISTEM OPERASIONAL",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
        ),

        // --- SECTION 1: ENTRY & OPERASIONAL ---
        ExpansionTile(
          leading: const Icon(Icons.dvr_rounded),
          title: const Text("Entry & Operasional", style: TextStyle(fontWeight: FontWeight.w600)),
          children: [
            // if (_hasAccess('CheckIn'))
            //   _menuItem(context, Icons.how_to_reg_rounded, "Check-In", Colors.blue, onTap: () {
            //     Navigator.pop(context);
            //     _showSnackBar(context, "Membuka Presensi...", Colors.blue);
            //   }),
            // if (_hasAccess('Loading'))
            //   _menuItem(context, Icons.unarchive_rounded, "Loading Barang", Colors.orange),
              if (_hasAccess('PPICForm'))
              _menuItem(context, Icons.format_align_justify, "PPIC Form", Colors.orange, onTap: () {
                Navigator.pop(context);
                DynamicTabPage.of(context)?.openTab("PPIC Form", PPICFormPage());
              }),
            if (_hasAccess('OccupancyForm'))
              _menuItem(context, Icons.fact_check_rounded, "Occupancy Form", Colors.orange, onTap: () {
                Navigator.pop(context);
                DynamicTabPage.of(context)?.openTab("Occupancy Form", WarehouseOccupancyForm());
              }),
            if (_hasAccess('KelayakanUnit'))
              _menuItem(context, Icons.commute_rounded, "Check in & Kelayakan Unit", Colors.teal, onTap: () {
                Navigator.pop(context);
                DynamicTabPage.of(context)?.openTab("Check in & Kelayakan Unit", VehicleControlFormState()); // Pass empty vehicleData for now
              }),
            if (_hasAccess('InputDO'))
              _menuItem(context, Icons.local_shipping_rounded, "Input DO", Colors.purple, onTap: () {
                Navigator.pop(context);
                DynamicTabPage.of(context)?.openTab("Input DO", const ShippingRequestPage());
              }),
            if (_hasAccess('Complain'))
              _menuItem(context, Icons.report_problem_rounded, "Complain", Colors.redAccent, onTap: () {
                Navigator.pop(context);
                DynamicTabPage.of(context)?.openTab("Complain", const ComplainPage());
              }),
          ],
        ),

        // --- SECTION 2: DISPLAY & MONITORING ---
        ExpansionTile(
          leading: const Icon(Icons.analytics_rounded),
          title: const Text("Display", style: TextStyle(fontWeight: FontWeight.w600)),
          children: [
            if (_hasAccess('ListDO'))
              _menuItem(context, Icons.list_alt, "List DO", Colors.redAccent, onTap: () {
                Navigator.pop(context);
                DynamicTabPage.of(context)?.openTab("List DO", const ListDOPage());
              }),
            if (_hasAccess('DOdetailsGBJ'))
              _menuItem(context, Icons.list_rounded, "Do Details GBJ", Colors.redAccent, onTap: () {
                Navigator.pop(context);
                DynamicTabPage.of(context)?.openTab("Do Details GBJ", const DetailsDOGbjPage());
              }),
            if (_hasAccess('VendorRequest'))
              _menuItem(context, Icons.request_quote_rounded, "Permintaan Pengiriman", Colors.redAccent, onTap: () {
                Navigator.pop(context);
                DynamicTabPage.of(context)?.openTab("Permintaan Pengiriman ", const VendorRequestPage());
              }),
           // _menuItem(context, Icons.list_alt_rounded, "List Planning", Colors.indigo),
           // _menuItem(context, Icons.confirmation_number_rounded, "List Planning Booking Antrian", Colors.amber.shade800),
             if (_hasAccess('planningAntrian'))
               _menuItem(context, Icons.confirmation_number_rounded, "List Planning Booking Antrian", Colors.amber.shade800, onTap: () {
                Navigator.pop(context);
                DynamicTabPage.of(context)?.openTab("List Planning Booking Antrian", BookingPlanningListPage());
              }),
              // _menuItem(context, Icons.feedback_rounded, "List Complain", Colors.redAccent, onTap: () {
              //   Navigator.pop(context);
              //   DynamicTabPage.of(context)?.openTab("List Complain", const ComplainPage());
              // }),
            _menuItem(context, Icons.dashboard_customize_rounded, "Dashboard Logistik", Colors.blueGrey),
            
             if (_hasAccess('ListPPIC'))
              _menuItem(context, Icons.padding_outlined, "List PPIC", Colors.orange, onTap: () {
                Navigator.pop(context);
                DynamicTabPage.of(context)?.openTab("List PPIC", const PPICListPage());
              }),

            if (_hasAccess('ListComplain'))
              _menuItem(context, Icons.feedback_rounded, "List Complain", Colors.redAccent, onTap: () {
                Navigator.pop(context);
                DynamicTabPage.of(context)?.openTab("List Complain", const ComplainPage());
              }),
          ],
        ),

        // --- SECTION 3: MASTER DATA ---
        ExpansionTile(
          leading: const Icon(Icons.storage_rounded),
          title: const Text("Master Data", style: TextStyle(fontWeight: FontWeight.w600)),
          children: [
            if (_hasAccess('Master')) ...[
              _menuItem(context, Icons.person_add, "Manajemen User", Colors.indigo, onTap: () {
                Navigator.pop(context);
                DynamicTabPage.of(context)?.openTab("Manajemen User", const UserManagementPage());
              }),
              _menuItem(context, Icons.people_alt_rounded, "Manajemen Vendor Transport", Colors.indigo, onTap: () {
                Navigator.pop(context);
                DynamicTabPage.of(context)?.openTab("Manajemen Vendor Transport", const VendorManagementPage());
              }),
              _menuItem(context, Icons.storefront_rounded, "Manajemen Customer", Colors.blue, onTap: () {
                Navigator.pop(context);
                DynamicTabPage.of(context)?.openTab("Manajemen Customer", const CustomerPaginatedPage());
              }),
              _menuItem(context, Icons.category_rounded, "Manajemen Material", Colors.brown, onTap: () {
                Navigator.pop(context);
                DynamicTabPage.of(context)?.openTab("Manajemen Material", const MaterialPaginatedPage());
              }),
              _menuItem(context, Icons.warehouse_rounded, "Manajemen Warehouse", Colors.blueGrey, onTap: () {
                Navigator.pop(context);
                DynamicTabPage.of(context)?.openTab("Manajemen Warehouse", const WarehousePaginatedPage());
              }),
              _menuItem(context, Icons.assignment_turned_in_rounded, "Manajemen Checker", Colors.teal, onTap: () {
                Navigator.pop(context);
                DynamicTabPage.of(context)?.openTab("Manajemen Checker", const CheckerPaginatedPage());
              }),
              _menuItem(context, Icons.business_rounded, "Manajemen Vendor", Colors.deepPurple, onTap: () {
                Navigator.pop(context);
                DynamicTabPage.of(context)?.openTab("Manajemen Vendor", const VendorPaginatedPage());
              }),
              _menuItem(context, Icons.vibration_rounded, "Enrollment Akun Vendor", Colors.blueAccent, onTap: () {
                Navigator.pop(context);
                DynamicTabPage.of(context)?.openTab("Enrollment Akun Vendor", const VendorEnrollmentPage());
              }),
            ]
          ],
        ),
      ],
    );
  }

  // Widget _buildVendorMenu(BuildContext context) {
  //   return ExpansionTile(
  //     title: const Text("Fitur Vendor"),
  //     leading: const Icon(Icons.store),
  //     children: [
  //       _menuItem(context, Icons.list_alt_rounded, "List Order Saya", Colors.redAccent, onTap: () {
  //         Navigator.pop(context);
  //         DynamicTabPage.of(context)?.openTab("List Order Saya", const ListDOPage());
  //       }),
  //       _menuItem(context, Icons.list_alt_rounded, "Riwayat Order", Colors.redAccent, onTap: () {
  //         Navigator.pop(context);
  //         DynamicTabPage.of(context)?.openTab("Riwayat Order", const ListDOPage());
  //       }),
  //     ],
  //   );
  // }
  Widget _buildVendorMenu(BuildContext context) {
    final String registCode = currentUser?.nik ?? '';
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          "Fitur Vendor",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
      ),

      // _menuItem(
      //   context,
      //   Icons.list_alt_rounded,
      //   "List Order Saya",
      //   Colors.redAccent,
      //   onTap: () {
      //     Navigator.pop(context);
      //     DynamicTabPage.of(context)?.openTab(
      //       "List Order Saya",
      //       VendorOrderListPage(vendorNik :currentUser?.nikVendor ?? ''),
      //     );
      //   },
      // ),
       _menuItem(
        context,
        Icons.list_alt_rounded,
        "Pengiriman On Proses",
        Colors.redAccent,
        onTap: () {
          Navigator.pop(context);
          DynamicTabPage.of(context)?.openTab(
            "Pengiriman On Proses",
            VendorOnProcessPage(vendorNik :currentUser?.nikVendor ?? ''),
          );
        },
      ),

      _menuItem(
        context,
        Icons.history,
        "Riwayat Order",
        Colors.redAccent,
        onTap: () {
          Navigator.pop(context);
          DynamicTabPage.of(context)?.openTab(
            "Riwayat Order",
            VendorOrderHistoryPage(vendorNik: currentUser?.nikVendor ?? ''),
          );
        },
      ),
    ],
  );
}

  Widget _menuItem(BuildContext context, IconData icon, String title, Color color, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      onTap: onTap ?? () => _showSnackBar(context, 'Fitur $title belum tersedia', Colors.grey),
    );
  }

  void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    await AuthService.logout();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }
}