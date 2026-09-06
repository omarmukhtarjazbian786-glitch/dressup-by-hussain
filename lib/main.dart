import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await openDatabase(
    join(await getDatabasesPath(), 'business.db'),
    onCreate: (db, version) {
      db.execute(
        'CREATE TABLE roznamcha(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, amount REAL, type TEXT, date TEXT)',
      );
      db.execute(
        'CREATE TABLE inventory(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, cost REAL, sale REAL, stock INTEGER)',
      );
      return db.execute(
        'CREATE TABLE khaata(id INTEGER PRIMARY KEY AUTOINCREMENT, party TEXT, amount REAL, type TEXT, date TEXT)',
      );
    },
    version: 1,
  );
  runApp(MaterialApp(
    home: HomeScreen(db: database),
    theme: ThemeData(primarySwatch: Colors.teal),
    debugShowCheckedModeBanner: false,
  ));
}

class HomeScreen extends StatefulWidget {
  final Database db;
  HomeScreen({required this.db});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  List<Map<String, dynamic>> roznamcha = [];
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> khaata = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  void _loadAllData() async {
    final r = await widget.db.query('roznamcha', orderBy: 'id DESC');
    final p = await widget.db.query('inventory', orderBy: 'id DESC');
    final k = await widget.db.query('khaata', orderBy: 'id DESC');
    setState(() {
      roznamcha = r;
      products = p;
      khaata = k;
    });
  }

  void _addEntry(String table, Map<String, dynamic> data) async {
    await widget.db.insert(table, data);
    _loadAllData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(['Roznamcha (Cash Book)', 'Inventory (Stock)', 'Khaata (Udhaar)'][_tab]),
      ),
      body: _buildCurrentTab(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Roznamcha'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'Inventory'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Khaata'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () => _openAddDialog(),
      ),
    );
  }

  Widget _buildCurrentTab() {
    if (_tab == 0) {
      double cashIn = roznamcha.where((e) => e['type'] == 'IN').fold(0.0, (s, e) => s + e['amount']);
      double cashOut = roznamcha.where((e) => e['type'] == 'OUT').fold(0.0, (s, e) => s + e['amount']);
      return Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.teal.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text('Cash In: Rs. $cashIn', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                Text('Cash Out: Rs. $cashOut', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: roznamcha.length,
              itemBuilder: (c, i) => ListTile(
                title: Text(roznamcha[i]['title']),
                subtitle: Text(roznamcha[i]['date']),
                trailing: Text(
                  'Rs. ${roznamcha[i]['amount']}',
                  style: TextStyle(
                    color: roznamcha[i]['type'] == 'IN' ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    } else if (_tab == 1) {
      return ListView.builder(
        itemCount: products.length,
        itemBuilder: (c, i) => ListTile(
          title: Text(products[i]['name']),
          subtitle: Text('Cost: Rs. ${products[i]['cost']} | Sale: Rs. ${products[i]['sale']}'),
          trailing: Text('Qty: ${products[i]['stock']}', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      );
    } else {
      return ListView.builder(
        itemCount: khaata.length,
        itemBuilder: (c, i) => ListTile(
          title: Text(khaata[i]['party']),
          subtitle: Text(khaata[i]['date']),
          trailing: Text(
            'Rs. ${khaata[i]['amount']} (${khaata[i]['type']})',
            style: TextStyle(
              color: khaata[i]['type'] == 'Diye' ? Colors.red : Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }
  }

  void _openAddDialog() {
    final t1 = TextEditingController();
    final t2 = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('New Entry'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: t1, decoration: InputDecoration(hintText: 'Name / Detail')),
            TextField(controller: t2, decoration: InputDecoration(hintText: 'Amount / Price'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            child: Text('Save'),
            onPressed: () {
              final text = t1.text;
              final val = double.tryParse(t2.text) ?? 0.0;
              final now = DateFormat('yyyy-MM-dd').format(DateTime.now());

              if (_tab == 0) {
                _addEntry('roznamcha', {'title': text, 'amount': val, 'type': 'IN', 'date': now});
              } else if (_tab == 1) {
                _addEntry('inventory', {'name': text, 'cost': val, 'sale': val * 1.2, 'stock': 1});
              } else {
                _addEntry('khaata', {'party': text, 'amount': val, 'type': 'Liye', 'date': now});
              }
              Navigator.pop(ctx);
            },
          )
        ],
      ),
    );
  }
}
