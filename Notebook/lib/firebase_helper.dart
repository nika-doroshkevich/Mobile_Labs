import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

class FirebaseHelper {

  static Future createItem(int id, String title, String description) async {
    final docItem = FirebaseFirestore.instance.collection('notes').doc();

    final json = {
      'id': id,
      'title': title,
      'description': description,
      'createdAt': DateTime.now().toString(),
    };

    await docItem.set(json);
  }

  static Future<void> updateItem(int id, String title, String description) async {
    var documents = await FirebaseFirestore.instance.collection('notes').where(
        "id",
        isEqualTo: id
    ).get();

    var docs = documents.docs;
    for (var queryDocumentSnapshot in docs) {
      queryDocumentSnapshot.reference.update({
        'title': title,
        'description': description
      });
    }
  }

  static Future<void> deleteItem(int id) async {
    var documents = await FirebaseFirestore.instance.collection('notes').where(
        "id",
        isEqualTo: id
    ).get();

    var docs = documents.docs;
    for (var queryDocumentSnapshot in docs) {
      queryDocumentSnapshot.reference.delete();
    }
  }

  static Future<void> deleteAllItems() async {
    var documents = await FirebaseFirestore.instance.collection('notes').get();

    var docs = documents.docs;
    for (var queryDocumentSnapshot in docs) {
      queryDocumentSnapshot.reference.delete();
    }
  }

  static Future<bool> isInternet() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.mobile) {
      // I am connected to a mobile network, make sure there is actually a net connection.
      if (await InternetConnectionChecker().hasConnection) {
        // Mobile data detected & internet connection confirmed.
        return true;
      } else {
        // Mobile data detected but no internet connection found.
        return false;
      }
    } else if (connectivityResult == ConnectivityResult.wifi) {
      // I am connected to a WIFI network, make sure there is actually a net connection.
      if (await InternetConnectionChecker().hasConnection) {
        // Wifi detected & internet connection confirmed.
        return true;
      } else {
        // Wifi detected but no internet connection found.
        return false;
      }
    } else {
      // Neither mobile data or WIFI detected, not internet connection found.
      return false;
    }
  }
}