import 'package:flutter/material.dart';
import 'package:project_app/admin/home_page.dart';

class DynamicTabPage extends StatefulWidget {
  const DynamicTabPage({super.key});

  @override
  State<DynamicTabPage> createState() => DynamicTabPageState();

  static DynamicTabPageState? of(BuildContext context) {
    return context.findAncestorStateOfType<DynamicTabPageState>();
  }
}

class DynamicTabPageState extends State<DynamicTabPage> {
  List<_TabItem> tabs = [];
  int activeIndex = 0;
  int counter = 1;
  
  // Tambahkan ScrollController untuk auto-scroll tab bar
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    tabs.add(_TabItem(
      title: "Home",
      // Gunakan Key agar state tidak tertukar saat tab dihapus
      //content: const Center(key: PageStorageKey('dashboard'), child: Text("Welcome to Dashboard")),
    content: const HomePage(),
    ));
    activeIndex = 0;
  
  }

  void openTab(String title, Widget page) {
    int existingIndex = tabs.indexWhere((t) => t.title == title);

    if (existingIndex != -1) {
      setState(() {
        activeIndex = existingIndex;
      });
    } else {
      setState(() {
        tabs.add(_TabItem(title: title, content: page));
        activeIndex = tabs.length - 1;
      });
      // Auto scroll ke tab terbaru
      _scrollToEnd();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _closeTab(int index) {
    setState(() {
      tabs.removeAt(index);

      if (tabs.isEmpty) {
        tabs.add(_TabItem(
          title: "Dashboard",
          content: const Center(key: PageStorageKey('dashboard'), child: Text("Welcome to Dashboard")),
        ));
        activeIndex = 0;
      } else {
        // Logika perbaikan index agar tidak error saat menghapus
        if (activeIndex > index) {
          activeIndex--;
        } else if (activeIndex >= tabs.length) {
          activeIndex = tabs.length - 1;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade700,
      // appBar: AppBar(
      //   title: const Text("Dynamic Tabs"),
      //   backgroundColor: Colors.red.shade700,
      // ),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: IndexedStack(
              index: activeIndex,
              // .toList() sudah benar, tapi pastikan widget di dalamnya punya Key
              children: tabs.map((t) => t.content).toList(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final currentCounter = counter++;
          openTab(
            "Tab $currentCounter", 
            Center(
              key: ValueKey('tab_$currentCounter'), // Key unik
              child: Text("Content for Tab $currentCounter")
            )
          );
        },
        backgroundColor: Colors.red.shade700,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 50,
      color: Colors.grey.shade100,
      child: ListView.builder(
        controller: _scrollController, // Pasang controller di sini
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        itemBuilder: (context, index) {
          final isActive = index == activeIndex;
          return GestureDetector(
            onTap: () => setState(() => activeIndex = index),
            child: AnimatedContainer( // Gunakan AnimatedContainer agar transisi warna halus
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isActive ? Colors.white : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isActive ? Colors.red.shade700 : Colors.grey.shade400,
                  width: isActive ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    tabs[index].title,
                    style: TextStyle(
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      color: isActive ? Colors.black : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _closeTab(index),
                    borderRadius: BorderRadius.circular(10), // Tambahkan radius klik
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: isActive ? Colors.red : Colors.grey,
                    ),
                  ),
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