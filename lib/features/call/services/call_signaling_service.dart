import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/app_utils.dart';

class CallSignalingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> createCall({
    required String callerId,
    required String receiverId,
    required String callerName,
    required String receiverName,
  }) async {
    final callId = generateId();
    final roomId = DateTime.now().millisecondsSinceEpoch % 1000000;

    await _firestore.collection(AppConstants.colCalls).doc(callId).set({
      'callId': callId,
      'callerId': callerId,
      'receiverId': receiverId,
      'callerName': callerName,
      'receiverName': receiverName,
      'roomId': roomId,
      'status': 'ringing',
      'createdAt': Timestamp.now(),
    });

    return callId;
  }

  Future<void> updateCallStatus(String callId, String status) async {
    await _firestore
        .collection(AppConstants.colCalls)
        .doc(callId)
        .update({'status': status});
  }

  Future<Map<String, dynamic>?> getCall(String callId) async {
    final doc = await _firestore
        .collection(AppConstants.colCalls)
        .doc(callId)
        .get();
    return doc.exists ? doc.data() : null;
  }

  Stream<DocumentSnapshot> callStream(String callId) {
    return _firestore
        .collection(AppConstants.colCalls)
        .doc(callId)
        .snapshots();
  }

  Stream<QuerySnapshot> incomingCallStream(String userId) {
    return _firestore
        .collection(AppConstants.colCalls)
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: 'ringing')
        .snapshots();
  }

  Future<void> saveCallHistory({
    required String callId,
    required String callerId,
    required String receiverId,
    required String callerName,
    required String receiverName,
    required DateTime startTime,
    required DateTime endTime,
    required String status,
  }) async {
    final duration = endTime.difference(startTime).inSeconds;
    await _firestore
        .collection(AppConstants.colCallHistory)
        .doc(callId)
        .set({
      'callId': callId,
      'callerId': callerId,
      'receiverId': receiverId,
      'callerName': callerName,
      'receiverName': receiverName,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'duration': duration,
      'status': status,
      'type': 'video',
    });
  }

  String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}