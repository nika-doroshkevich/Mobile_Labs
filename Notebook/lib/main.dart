import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:notebook/sql_helper.dart';
import 'package:notebook/firebase_helper.dart';

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notebook',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Notebook'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  List<Map<String, dynamic>> _notes = [];
  List<Map<String, dynamic>> _foundNotes = [];
  int mainId = 0;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _editingController = TextEditingController();

  void _refreshJournals() async {
    final data = await SQLHelper.getItems();
    setState(() {
      _notes = data;
      _foundNotes = _notes;
    });
  }

  @override
  void initState() {
    super.initState();
    _refreshJournals();
    _foundNotes = _notes;
  }

  Future createItemFB() async {
      FirebaseHelper.createItem(
          mainId, _titleController.text, _descriptionController.text);
      _refreshJournals();
  }

  Future<void> updateItemFB(int id, String title, String description) async {
    await FirebaseHelper.updateItem(id, title, description);
    _refreshJournals();
  }

  Future<void> deleteItemFB(int id) async {
    await FirebaseHelper.deleteItem(id);
    _refreshJournals();
  }

  //----------Work with synchronization----------//
  Future<bool> checkSynchronize() async {
    var fbHashSum = '';
    var sqlHashSum = '';

    var documents = await FirebaseFirestore.instance.collection('synchronize').where(
        "id",
        isEqualTo: 1
    ).get();

    var docs = documents.docs;
    for (var queryDocumentSnapshot in docs) {
      Map<String, dynamic> data = queryDocumentSnapshot.data();
      fbHashSum = data['hashSum'];
    }

    List<Map<String, dynamic>> hashSums = await SQLHelper.getHashSum(1);
    for (var hs in hashSums) {
      sqlHashSum = hs['hashSum'];
    }

    return fbHashSum == sqlHashSum;
  }

  Future<void> synchronizeSQLiteToFB() async {
    print("Move data from sql to FB");
    await FirebaseHelper.deleteAllItems();
    print("All items was deleted from FB");
    List<Map<String, dynamic>> dataFromSQLite = await SQLHelper.getItems();
    for (var sqlItem in dataFromSQLite) {
      var id = sqlItem['id'];
      var title = sqlItem['title'];
      var description = sqlItem['description'];

      await FirebaseHelper.createItem(id, title, description);
    }
    print("Move data from sql to FB - SUCCESS");
  }

  Future<void> changeSynchronizeTableInSQLite() async{
    print("Is change Synchronize Table In SQLite");
    String changedHashSum = 'changed';
    SQLHelper.updateHashSum(1, changedHashSum);
  }

  Future<void> cleanSynchronizeTableInSQLite() async{
    print("Is cleaned Synchronize Table In SQLite");
    String changedHashSum = '';
    SQLHelper.updateHashSum(1, changedHashSum);
  }
  //----------End----------//

  Future<void> _addItem() async {
    mainId = DateTime.now().millisecondsSinceEpoch;
    await SQLHelper.createItem(mainId,
        _titleController.text, _descriptionController.text);
    _refreshJournals();
  }

  Future<void> _updateItem(int id) async {
    await SQLHelper.updateItem(
        id, _titleController.text, _descriptionController.text);
    _refreshJournals();
  }

  void _deleteItem(int id) async {
    await SQLHelper.deleteItem(id);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Successfully deleted a note!'),
    ));
    _refreshJournals();
  }

  void _mainDelete(int id) async {
    bool isInternet = await FirebaseHelper.isInternet();
    if (isInternet) {
      print("Internet YES");
      bool isSynchronize = await checkSynchronize();
      if (isSynchronize) {
        print("Synchronize YES");
        _deleteItem(id);
        await deleteItemFB(id);
      } else {
        print("Synchronize NO");
        await synchronizeSQLiteToFB();
        await cleanSynchronizeTableInSQLite();
        _deleteItem(id);
        await deleteItemFB(id);
      }
    } else {
      print("Internet NO");
      _deleteItem(id);
      await changeSynchronizeTableInSQLite();
    }
  }

  void filterSearchResults(String query) {
      List<Map<String, dynamic>>? results = [];
      if (query.isEmpty) {
        results = _notes;
      } else {
        results = _notes.where((element) =>
        element['title'].toLowerCase().contains(query.toLowerCase())).toList();
      }

      setState(() {
        _foundNotes = results!;
      });
  }

  void _showForm(int? id) async {
    if (id != null) {
      final existingJournal =
      _notes.firstWhere((element) => element['id'] == id);

      _titleController.text = existingJournal['title'];
      _descriptionController.text = existingJournal['description'];
    }

    showModalBottomSheet(
        context: context,
        elevation: 5,
        isScrollControlled: true,
        builder: (_) => Container(
          padding: EdgeInsets.only(
            top: 15,
            left: 15,
            right: 15,
            bottom: MediaQuery.of(context).viewInsets.bottom + 120,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(hintText: 'Title'),
              ),
              const SizedBox(
                height: 10,
              ),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(hintText: 'Description'),
              ),
              const SizedBox(
                height: 20,
              ),
              ElevatedButton(
                  onPressed: () async {
                    if (id == null) {
                      bool isInternet = await FirebaseHelper.isInternet();
                      if (isInternet) {
                        print("Internet YES");
                        bool isSynchronize = await checkSynchronize();
                        if (isSynchronize) {
                          print("Synchronize YES");
                          await _addItem();
                          await createItemFB();
                        } else {
                          print("Synchronize NO");
                          await synchronizeSQLiteToFB();
                          await cleanSynchronizeTableInSQLite();
                          await _addItem();
                          await createItemFB();
                        }
                      } else {
                        print("Internet NO");
                        await _addItem();
                        await changeSynchronizeTableInSQLite();
                      }
                    }

                    if (id != null) {
                      bool isInternet = await FirebaseHelper.isInternet();
                      if (isInternet) {
                        print("Internet YES");
                        bool isSynchronize = await checkSynchronize();
                        if (isSynchronize) {
                          print("Synchronize YES");
                          await _updateItem(id);
                          await updateItemFB(id,
                              _titleController.text,
                              _descriptionController.text);
                        } else {
                          print("Synchronize NO");
                          await synchronizeSQLiteToFB();
                          await cleanSynchronizeTableInSQLite();
                          await _updateItem(id);
                          await updateItemFB(id,
                              _titleController.text,
                              _descriptionController.text);
                        }
                      } else {
                        print("Internet NO");
                        await _updateItem(id);
                        await changeSynchronizeTableInSQLite();
                      }
                    }

                    _titleController.text = '';
                    _descriptionController.text = '';

                    Navigator.of(context).pop();
                  },
                  child: Text(id == null ? 'Create new' : 'Update'),
              )
            ],
          ),
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),

      body: Container(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                onChanged: (value) =>
                  filterSearchResults(value),
                controller: _editingController,
                decoration: const InputDecoration(
                    labelText: "Search",
                    hintText: "Search",
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10.0)))),
              ),
            ),

            Expanded(
              child: ListView.builder(
                itemCount: _foundNotes.length,
                itemBuilder: (context, index) => Card(
                  color: Colors.orange[200],
                  margin: const EdgeInsets.all(15),
                  child: ListTile(
                    title: Text(_foundNotes[index]['title']),
                    subtitle: Text(_foundNotes[index]['description']),
                    trailing: SizedBox(
                      width: 100,
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => {
                              _editingController.clear(),
                              _showForm(_foundNotes[index]['id']),
                              _refreshJournals()
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => {
                              _editingController.clear(),
                              _mainDelete(_foundNotes[index]['id']),
                              _refreshJournals()
                            }
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            ),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showForm(null),
      ),
    );
  }
}
