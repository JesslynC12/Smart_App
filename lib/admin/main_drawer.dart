import 'package:flutter/material.dart';
import 'package:project_app/admin/display/daily_occupancy.dart';
import 'package:project_app/admin/display/dashboard_logistik.dart';
import 'package:project_app/admin/display/external_dashboard.dart';
import 'package:project_app/admin/display/historycomplain_page.dart';
import 'package:project_app/admin/display/indashboard.dart';
import 'package:project_app/admin/display/listppic_page.dart';
import 'package:project_app/admin/display/listPlanningBookAntrian_page.dart';
import 'package:project_app/admin/display/penilaianVendor_page.dart';
import 'package:project_app/admin/display/slotantrian_page.dart';
import 'package:project_app/admin/input%20form/Formppic.dart';
import 'package:project_app/admin/input%20form/Listloading_page.dart';
import 'package:project_app/admin/input%20form/pod_page.dart';
import 'package:project_app/admin/input%20form/posKeluar_page.dart';
import 'package:project_app/admin/input%20form/weighbridge_page.dart';
import 'package:project_app/admin/master%20data/master_user_vendor.dart';
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
import 'package:project_app/admin/input%20form/listCheckIn_page.dart';
import 'package:project_app/admin/master data/checker_master.dart';
import 'package:project_app/admin/master data/customer_master.dart';
import 'package:project_app/admin/master data/material_master.dart';
import 'package:project_app/admin/master data/vendor_transportasi_master.dart';
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
    print("DEBUG: Role User = ${currentUser?.role}");
  print("DEBUG: Privileges User = ${currentUser?.privileges}");
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
                if (currentUser?.role != 'vendor') ...[
                  _buildAdminMenu(context),
                ],
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
        ExpansionTile(
          leading: const Icon(Icons.dvr_rounded),
          title: const Text("Entry & Operasional", style: TextStyle(fontWeight: FontWeight.w600)),
          children: [
             if (_hasAccess('InputDO'))
              _menuItem(context, Icons.local_shipping_rounded, "Input DO", Colors.purple, onTap: () {
                Navigator.pop(context);
                DynamicTabPage.of(context)?.openTab("Input DO", const ShippingRequestPage());
              }),
               if (_hasAccess('KelayakanUnit'))
              _menuItem(context, Icons.commute_rounded, "Check in & Kelayakan Unit", Colors.teal, onTap: () {
                Navigator.pop(context);
                DynamicTabPage.of(context)?.openTab("Check in & Kelayakan Unit", VehicleControlFormState());
              }),
          
            // if (_hasAccess('Loading'))
            //   _menuItem(context, Icons.unarchive_rounded, "Loading Barang", Colors.orange),
              if (_hasAccess('Loading'))
              _menuItem(context, Icons.unarchive_rounded, "Loading Form", Colors.orange, onTap: () {
                Navigator.pop(context);
                DynamicTabPage.of(context)?.openTab("Loading Form", ListLoadingState());
              }),
               if (_hasAccess('Weighbridge'))
              _menuItem(context, Icons.how_to_reg_rounded, "Weighbridge", Colors.blue, onTap: () {
                Navigator.pop(context);
               DynamicTabPage.of(context)?.openTab(
        "Weighbridge",
        WeighbridgeState(
          item: {},
        ),
      );
    },
  ),
   if (_hasAccess('PosKeluar'))
              _menuItem(context, Icons.security_rounded, "Security Pos Keluar", Colors.blue, onTap: () {
                Navigator.pop(context);
               DynamicTabPage.of(context)?.openTab(
        "Security Pos Keluar",
        SecurityPosKeluarPage(
          item: {},
        ),
      );
    },
  ),
              if (_hasAccess('PPICForm'))
              _menuItem(context, Icons.format_align_justify, "PPIC Form", Colors.pink, onTap: () {
                Navigator.pop(context);
                DynamicTabPage.of(context)?.openTab("PPIC Form", PPICFormPage());
              }),
            if (_hasAccess('OccupancyForm'))
              _menuItem(context, Icons.fact_check_rounded, "Occupancy Form", Colors.orange, onTap: () {
                Navigator.pop(context);
                DynamicTabPage.of(context)?.openTab("Occupancy Form", WarehouseOccupancyForm());
              }),
           if (_hasAccess('PODForm'))
              _menuItem(context, Icons.request_quote_rounded, "POD Form", Colors.green, onTap: () {
                Navigator.pop(context);
                DynamicTabPage.of(context)?.openTab("POD Form", PODReturnPage());
              }),
            if (_hasAccess('Complain'))
              _menuItem(context, Icons.report_problem_rounded, "Complain", Colors.redAccent, onTap: () {
                Navigator.pop(context);
                DynamicTabPage.of(context)?.openTab("Complain", const ComplainPage());
              }),
          ],
        ),

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
              _menuItem(context, Icons.list_rounded, "Do Details GBJ", Colors.deepPurple, onTap: () {
                Navigator.pop(context);
                DynamicTabPage.of(context)?.openTab("Do Details GBJ", const DetailsDOGbjPage());
              }),
            if (_hasAccess('VendorRequest'))
              _menuItem(context, Icons.request_quote_rounded, "Permintaan Pengiriman", Colors.green, onTap: () {
                Navigator.pop(context);
                DynamicTabPage.of(context)?.openTab("Permintaan Pengiriman ", const VendorRequestPage());
              }),
              if (_hasAccess('planningAntrian'))
               _menuItem(context, Icons.confirmation_number_rounded, "List Planning Booking Antrian", Colors.amber.shade800, onTap: () {
                Navigator.pop(context);
                DynamicTabPage.of(context)?.openTab("List Planning Booking Antrian", BookingPlanningListPage());
              }),
              if (_hasAccess('slotAntrian'))
               _menuItem(context, Icons.schedule_rounded, "Slot Antrian", Colors.redAccent, onTap: () {
                Navigator.pop(context);
                DynamicTabPage.of(context)?.openTab("Slot Antrian", QueueSlotPage());
              }),
              // _menuItem(context, Icons.feedback_rounded, "List Complain", Colors.redAccent, onTap: () {
              //   Navigator.pop(context);
              //   DynamicTabPage.of(context)?.openTab("List Complain", const ComplainPage());
              // }),
            //_menuItem(context, Icons.dashboard_customize_rounded, "Dashboard Logistik", Colors.blueGrey),
            if (_hasAccess('penilaianVendor'))
               _menuItem(context, Icons.star_rate_rounded, "Penilaian Vendor", Colors.amber.shade800, onTap: () {
                Navigator.pop(context);
                DynamicTabPage.of(context)?.openTab("Penilaian Vendor", VendorEvaluationPage());
              }),
             if (_hasAccess('ListPPIC'))
              _menuItem(context, Icons.padding_outlined, "List PPIC", Colors.blue, onTap: () {
                Navigator.pop(context);
                DynamicTabPage.of(context)?.openTab("List PPIC", const PPICListPage());
              }),
              if (_hasAccess('DailyOccupancy'))
               _menuItem(context, Icons.calendar_today, "Daily Occupancy", Colors.red, onTap: () {
                Navigator.pop(context);
                DynamicTabPage.of(context)?.openTab("Daily Occupancy", MasterReviewDailyPage());
              }),
              if (_hasAccess('InDashboard'))
               _menuItem(context, Icons.dashboard_customize_rounded, "In Dashboard", Colors.green, onTap: () {
                Navigator.pop(context);
                DynamicTabPage.of(context)?.openTab("In Dashboard", DashboardCombinedPage());
              }),
              if (_hasAccess('ExDashboard'))
               _menuItem(context, Icons.dashboard_customize_rounded, "Ex Dashboard", Colors.green, onTap: () {
                Navigator.pop(context);
                DynamicTabPage.of(context)?.openTab("Ex Dashboard", OutboundDashboardPage());
              }),
               if (_hasAccess('DashboardLogistik'))
               _menuItem(context, Icons.dashboard, "Dashboard Logistik", Colors.blue, onTap: () {
                Navigator.pop(context);
                DynamicTabPage.of(context)?.openTab("Dashboard Logistik", LogisticDashboardPage());
              }),

            if (_hasAccess('ListComplain'))
              _menuItem(context, Icons.feedback_rounded, "List Complain", Colors.redAccent, onTap: () {
                Navigator.pop(context);
                DynamicTabPage.of(context)?.openTab("List Complain", const ComplainConfirmPage(),);
              }),
          ],
        ),

        if (_hasAccess('Master'))

        ExpansionTile(
          leading: const Icon(Icons.storage_rounded),
          title: const Text("Master Data", style: TextStyle(fontWeight: FontWeight.w600)),
          children: [
            if (_hasAccess('Master')) ...[
              _menuItem(context, Icons.person_add, "Manajemen User", Colors.indigo, onTap: () {
                Navigator.pop(context);
                DynamicTabPage.of(context)?.openTab("Manajemen User", const UserManagementPage());
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
              _menuItem(context, Icons.business_center_outlined, "Manajemen User Vendor", Colors.yellow, onTap: () {
                Navigator.pop(context);
                DynamicTabPage.of(context)?.openTab("Manajemen User Vendor", const VendorAccountsPage());
              }),
              _menuItem(context, Icons.business_rounded, "Manajemen Vendor Details", Colors.deepPurple, onTap: () {
                Navigator.pop(context);
                DynamicTabPage.of(context)?.openTab("Manajemen Vendor Details", const VendorPaginatedPage());
              }),
            ]
          ],
        ),
      ],
    );
  }

  Widget _buildVendorMenu(BuildContext context) {
    //final String registCode = currentUser?.nik ?? '';
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