import 'package:flutter/material.dart';
import 'package:tencent_calls_uikit/tencent_calls_uikit.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/trtc_utils.dart';
import 'call_signaling_service.dart';

class TRTCService {
  static bool _isLoggedIn = false;
  static DateTime? _callStartTime;
  static String? _currentCallId;
  static String? _remoteUserId;
  static final CallSignalingService _signalingService = CallSignalingService();

  static Future<void> login(String userId) async {
    if (_isLoggedIn) return;
    final userSig = TRTCUtils.generateUserSig(userId);
    debugPrint('=== TRTC LOGIN userId=$userId');
    await TUICallKit.instance.login(
      AppConstants.trtcAppId,
      userId,
      userSig,
    );
    debugPrint('=== TRTC LOGIN DONE');
    _isLoggedIn = true;
    TUICallKit.instance.enableFloatWindow(true);
    TUICallKit.instance.enableIncomingBanner(true);
    _registerObserver();
  }

  static void _registerObserver() {
    TUICallEngine.instance.addObserver(TUICallObserver(
      onCallBegin: (roomId, callMediaType, callRole) {
        _callStartTime = DateTime.now();
        _currentCallId = DateTime.now().millisecondsSinceEpoch.toString();
        debugPrint('=== TRTC CALL BEGIN');
      },
      onCallEnd: (roomId, callMediaType, callRole, totalTime, floatTime, extraInfo) {
        debugPrint('=== TRTC CALL END duration=${totalTime}s');
        _saveCallHistory(status: 'completed', duration: int.tryParse(totalTime) ?? 0);
      },
      onUserReject: (userId) {
        debugPrint('=== TRTC CALL REJECTED by $userId');
        _remoteUserId ??= userId;
        _saveCallHistory(status: 'rejected', duration: 0);
      },
      onUserNoResponse: (userId) {
        debugPrint('=== TRTC CALL NO RESPONSE from $userId');
        _remoteUserId ??= userId;
        _saveCallHistory(status: 'missed', duration: 0);
      },
      onUserLineBusy: (userId) {
        debugPrint('=== TRTC USER BUSY: $userId');
        _remoteUserId ??= userId;
        _saveCallHistory(status: 'missed', duration: 0);
      },
      onKickedOffline: () {
        _isLoggedIn = false;
      },
    ));
  }

  static Future<void> _saveCallHistory({
    required String status,
    int duration = 0,
  }) async {
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid == null || _remoteUserId == null) return;

      final currentUserDoc = await FirebaseFirestore.instance
          .collection(AppConstants.colUsers)
          .doc(currentUid)
          .get();
      final remoteUserDoc = await FirebaseFirestore.instance
          .collection(AppConstants.colUsers)
          .doc(_remoteUserId)
          .get();

      final callerName = currentUserDoc.data()?['displayName'] ?? '';
      final receiverName = remoteUserDoc.data()?['displayName'] ?? '';
      final now = DateTime.now();
      final startTime = _callStartTime ?? now;

      await _signalingService.saveCallHistory(
        callId: _currentCallId ?? now.millisecondsSinceEpoch.toString(),
        callerId: currentUid,
        receiverId: _remoteUserId!,
        callerName: callerName,
        receiverName: receiverName,
        startTime: startTime,
        endTime: now,
        status: status,
      );

      _currentCallId = null;
      _callStartTime = null;
      _remoteUserId = null;
    } catch (e) {
      debugPrint('=== SAVE HISTORY ERROR: $e');
    }
  }

  static Future<void> call(String userId) async {
    _remoteUserId = userId;
    _currentCallId = DateTime.now().millisecondsSinceEpoch.toString();
    _callStartTime = DateTime.now();
    debugPrint('=== TRTC CALL to=$userId, isLoggedIn=$_isLoggedIn');
    await TUICallKit.instance.call(userId, TUICallMediaType.video);
  }

  static Future<void> groupCall(List<String> userIds) async {
    _currentCallId = DateTime.now().millisecondsSinceEpoch.toString();
    _callStartTime = DateTime.now();
    debugPrint('=== TRTC GROUP CALL to=$userIds');
    final params = TUICallParams();
    TUICallKit.instance.calls(userIds, TUICallMediaType.video, params);
  }

  static Future<void> joinCall(String callId) async {
    debugPrint('=== TRTC JOIN CALL callId=$callId');
    TUICallKit.instance.join(callId);
  }

  static Future<void> logout() async {
    try {
      await TUICallKit.instance.logout();
    } catch (e) {
      debugPrint('=== TRTC LOGOUT ERROR: $e');
    }
    _isLoggedIn = false;
  }

  static Future<void> setSelfInfo(String nickname, String avatar) async {
    await TUICallKit.instance.setSelfInfo(nickname, avatar);
  }
}