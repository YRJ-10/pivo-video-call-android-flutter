import 'package:tencent_calls_uikit/debug/generate_test_user_sig.dart';
import '../constants/app_constants.dart';

class TRTCUtils {
  static String generateUserSig(String userId) {
    return GenerateTestUserSig.genTestSig(
      userId,
      AppConstants.trtcAppId,
      AppConstants.trtcSecretKey,
    );
  }
}