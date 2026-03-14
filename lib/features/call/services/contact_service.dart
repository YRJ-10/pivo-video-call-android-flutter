import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/contact_model.dart';
import '../../../core/constants/app_constants.dart';

class ContactService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<ContactModel?> searchUserByEmail(String email) async {
    try {
      final query = await _firestore
          .collection(AppConstants.colUsers)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (query.docs.isEmpty) return null;
      return ContactModel.fromMap(query.docs.first.data());
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addContact(String currentUid, ContactModel contact) async {
    await _firestore
        .collection(AppConstants.colContacts)
        .doc(currentUid)
        .collection('list')
        .doc(contact.uid)
        .set(contact.toMap());
  }

  Future<void> removeContact(String currentUid, String contactUid) async {
    await _firestore
        .collection(AppConstants.colContacts)
        .doc(currentUid)
        .collection('list')
        .doc(contactUid)
        .delete();
  }

  // Ambil list uid kontak, lalu listen realtime ke setiap dokumen user
  Stream<List<ContactModel>> contactsStream(String currentUid) {
    return _firestore
        .collection(AppConstants.colContacts)
        .doc(currentUid)
        .collection('list')
        .snapshots()
        .asyncMap((snapshot) async {
      if (snapshot.docs.isEmpty) return <ContactModel>[];

      final uids = snapshot.docs
          .map((doc) => doc.data()['uid'] as String?)
          .whereType<String>()
          .toList();

      final userDocs = await Future.wait(
        uids.map((uid) => _firestore
            .collection(AppConstants.colUsers)
            .doc(uid)
            .get()),
      );

      return userDocs
          .where((doc) => doc.exists)
          .map((doc) => ContactModel.fromMap(doc.data()!))
          .toList();
    });
  }

  // Stream realtime per kontak individu
  Stream<ContactModel?> contactStatusStream(String uid) {
    return _firestore
        .collection(AppConstants.colUsers)
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? ContactModel.fromMap(doc.data()!) : null);
  }

  Future<void> updateStatus(String uid, String status) async {
    await _firestore
        .collection(AppConstants.colUsers)
        .doc(uid)
        .update({'status': status});
  }
}