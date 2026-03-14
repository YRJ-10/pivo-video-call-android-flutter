import 'dart:async';
import 'package:flutter/material.dart';
import '../models/contact_model.dart';
import '../services/contact_service.dart';

class ContactProvider extends ChangeNotifier {
  final ContactService _service = ContactService();

  List<ContactModel> _contacts = [];
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription? _contactsSubscription;
  final Map<String, StreamSubscription> _statusSubscriptions = {};

  List<ContactModel> get contacts => _contacts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<ContactModel> get onlineContacts =>
      _contacts.where((c) => c.status == 'online').toList();

  void listenContacts(String uid) {
    _contactsSubscription?.cancel();
    _contactsSubscription =
        _service.contactsStream(uid).listen((contacts) {
          _contacts = contacts;
          // Listen realtime status untuk setiap kontak
          _listenContactStatuses(contacts);
          notifyListeners();
        });
  }

  void _listenContactStatuses(List<ContactModel> contacts) {
    // Cancel subscription lama yang tidak relevan
    final newUids = contacts.map((c) => c.uid).toSet();
    _statusSubscriptions.keys
        .where((uid) => !newUids.contains(uid))
        .toList()
        .forEach((uid) {
      _statusSubscriptions[uid]?.cancel();
      _statusSubscriptions.remove(uid);
    });

    // Tambah subscription baru
    for (final contact in contacts) {
      if (_statusSubscriptions.containsKey(contact.uid)) continue;
      _statusSubscriptions[contact.uid] =
          _service.contactStatusStream(contact.uid).listen((updated) {
            if (updated == null) return;
            final index = _contacts.indexWhere((c) => c.uid == updated.uid);
            if (index != -1) {
              _contacts[index] = updated;
              notifyListeners();
            }
          });
    }
  }

  Future<ContactModel?> searchUser(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await _service.searchUserByEmail(email);
      if (result == null) _errorMessage = 'User not found.';
      return result;
    } catch (e) {
      _errorMessage = 'Search failed. Try again.';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addContact(String currentUid, ContactModel contact) async {
    try {
      await _service.addContact(currentUid, contact);
    } catch (e) {
      _errorMessage = 'Failed to add contact.';
      notifyListeners();
    }
  }

  Future<void> removeContact(String currentUid, String contactUid) async {
    try {
      await _service.removeContact(currentUid, contactUid);
    } catch (e) {
      _errorMessage = 'Failed to remove contact.';
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _contactsSubscription?.cancel();
    for (final sub in _statusSubscriptions.values) {
      sub.cancel();
    }
    super.dispose();
  }
}