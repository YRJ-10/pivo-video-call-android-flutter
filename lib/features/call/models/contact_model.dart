class ContactModel {
  final String uid;
  final String displayName;
  final String email;
  final String photoURL;
  final String status;
  final DateTime? lastSeen;

  ContactModel({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoURL = '',
    this.status = 'offline',
    this.lastSeen,
  });

  factory ContactModel.fromMap(Map<String, dynamic> map) {
    return ContactModel(
      uid: map['uid'] ?? '',
      displayName: map['displayName'] ?? '',
      email: map['email'] ?? '',
      photoURL: map['photoURL'] ?? '',
      status: map['status'] ?? 'offline',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'email': email,
      'photoURL': photoURL,
      'status': status,
    };
  }
}