import 'package:flutter/material.dart';
import 'package:tencent_calls_uikit/tencent_calls_uikit.dart';
import '../../../core/constants/app_constants.dart';

class TRTCCallService {
  static Future<void> login({
    required String userId,
    required String userSig,
  }) async {
    await TUICallKit.instance.login(
      AppConstants.trtcAppId,
      userId,
      userSig,
    );
  }

  static Future<void> setSelfInfo({
    required String nickname,
    required String avatar,
  }) async {
    await TUICallKit.instance.setSelfInfo(nickname, avatar);
  }

  static Future<void> call({
    required String userId,
    required TUICallMediaType mediaType,
  }) async {
    await TUICallKit.instance.call(userId, mediaType);
  }

  static Future<void> logout() async {
    await TUICallKit.instance.logout();
  }
}