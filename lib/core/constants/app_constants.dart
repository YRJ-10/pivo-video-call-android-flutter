class AppConstants {
  // App
  static const String appName = 'Pivo Vidcall';

  // TRTC - ganti dengan credentials kamu
  static const int trtcAppId = xxxx; // ganti dengan SDKAppID kamu
  static const String trtcSecretKey = 'xxxx'; // ganti dengan SecretKey kamu

  // Routes
  static const String routeOnboarding = '/onboarding';
  static const String routeLogin = '/login';
  static const String routeRegister = '/register';
  static const String routeHome = '/home';
  static const String routeCall = '/call';
  static const String routeIncomingCall = '/incoming-call';

  // Shared Preferences Keys
  static const String keyOnboardingDone = 'onboarding_done';
  static const String keyUserId = 'user_id';

  // Firestore Collections
  static const String colUsers = 'users';
  static const String colCallHistory = 'call_history';
  static const String colCalls = 'calls';
  static const String colContacts = 'contacts';
}