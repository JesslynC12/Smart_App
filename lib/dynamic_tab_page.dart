import 'package:flutter/material.dart';
import 'package:project_app/admin/home_page.dart';
import 'package:project_app/admin/main_drawer.dart';
import 'package:project_app/vendor/homepage_vendor.dart';
import '../auth/auth_service.dart';

class DynamicTabPage extends StatefulWidget {
  final String role;

  const DynamicTabPage({super.key, required this.role});

  @override
  State<DynamicTabPage> createState() => DynamicTabPageState();

  static DynamicTabPageState? of(BuildContext context) {
    return context.findAncestorStateOfType<DynamicTabPageState>();
  }
}

class DynamicTabPageState extends State<DynamicTabPage> {
  late Future<dynamic> _userFuture;
  dynamic currentUser;
  List<_TabItem> tabs = [];
  int activeIndex = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _userFuture = AuthService.getCurrentUser();
    tabs.add(
      _TabItem(
        title: "Home",
        content: widget.role == 'admin'
            ? const HomePage(key: PageStorageKey('home-admin'))
            : const HomepageVendor(key: PageStorageKey('home-vendor')),
      ),
    );
  }

  void closeCurrentTab() {
    setState(() {
      if (activeIndex == 0) return;

      if (tabs.isNotEmpty) {
        tabs.removeAt(activeIndex);

        if (activeIndex >= tabs.length) {
          activeIndex = tabs.length - 1;
        }
      }
    });
  }

  void openTab(String title, Widget page) {
    setState(() {
      int existingIndex = tabs.indexWhere((t) => t.title == title);
      if (existingIndex != -1) {
        activeIndex = existingIndex;
      } else {
        tabs.add(_TabItem(title: title, content: page));
        activeIndex = tabs.length - 1;
      }
    });
  }

  void _closeTab(int index) {
    setState(() {
      if (index == 0) return;
      tabs.removeAt(index);
      if (activeIndex >= tabs.length) {
        activeIndex = (activeIndex - 1).clamp(0, tabs.length - 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<dynamic>(
      future: _userFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        currentUser = snapshot.data;
        return Scaffold(
          drawer: currentUser == null
              ? null
              : MainDrawer(currentUser: currentUser),
          body: SafeArea(
            child: Column(
              children: [
                _buildTabBar(),

                Container(
                  height: 56,
                  color: Colors.red.shade700,
                  child: Row(
                    children: [
                      Builder(
                        builder: (context) => IconButton(
                          icon: const Icon(Icons.menu, color: Colors.white),
                          onPressed: () {
                            if (currentUser != null) {
                              Scaffold.of(context).openDrawer();
                            }
                          },
                        ),
                      ),
                      Expanded(
                        child: Text(
                          tabs[activeIndex].title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (currentUser == null)
                        const Padding(
                          padding: EdgeInsets.only(right: 16),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                Expanded(
                  child: IndexedStack(
                    index: activeIndex,
                    children: tabs.map((t) => t.content).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 50,
      width: double.infinity,
      color: Colors.white,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        itemBuilder: (context, index) {
          final isActive = index == activeIndex;
          return GestureDetector(
            onTap: () => setState(() => activeIndex = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isActive ? Colors.red.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isActive ? Colors.red.shade700 : Colors.grey.shade300,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    tabs[index].title,
                    style: TextStyle(
                      fontSize: 13,
                      color: isActive ? Colors.red.shade900 : Colors.black87,
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  if (index != 0) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _closeTab(index),
                      child: Icon(
                        Icons.close,
                        size: 14,
                        color: isActive ? Colors.red : Colors.grey,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TabItem {
  final String title;
  final Widget content;
  _TabItem({required this.title, required this.content});
}

class KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const KeepAliveWrapper({super.key, required this.child});

  @override
  State<KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }

  @override
  bool get wantKeepAlive => true;
}
