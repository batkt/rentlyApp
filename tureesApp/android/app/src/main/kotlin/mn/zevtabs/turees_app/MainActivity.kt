package mn.zevtabs.turees_app

import io.flutter.embedding.android.FlutterFragmentActivity

// local_auth requires a FragmentActivity host on Android — with plain
// FlutterActivity, authenticate()/canCheckBiometrics() throw and get
// swallowed by BiometricService's try/catch, silently disabling biometric
// login (button never shows, user is always forced back to password).
class MainActivity : FlutterFragmentActivity()
