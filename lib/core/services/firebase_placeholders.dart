/// Firebase Auth placeholder — wire real SDK when credentials are ready.
abstract class FirebaseAuthService {
  Future<String?> signInWithEmail(String email, String password);
  Future<String?> signUpWithEmail(String email, String password);
  Future<void> signOut();
  Future<String?> getCurrentUserId();
  Stream<String?> authStateChanges();
}

class FirebaseAuthServicePlaceholder implements FirebaseAuthService {
  String? _userId;

  @override
  Future<String?> signInWithEmail(String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _userId = 'firebase_mock_$email';
    return _userId;
  }

  @override
  Future<String?> signUpWithEmail(String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _userId = 'firebase_mock_$email';
    return _userId;
  }

  @override
  Future<void> signOut() async {
    _userId = null;
  }

  @override
  Future<String?> getCurrentUserId() async => _userId;

  @override
  Stream<String?> authStateChanges() async* {
    yield _userId;
  }
}

/// Firebase Messaging placeholder.
abstract class FirebaseMessagingService {
  Future<String?> getToken();
  Future<void> requestPermission();
  Stream<Map<String, dynamic>> onMessage();
}

class FirebaseMessagingServicePlaceholder implements FirebaseMessagingService {
  @override
  Future<String?> getToken() async => 'mock_fcm_token';

  @override
  Future<void> requestPermission() async {}

  @override
  Stream<Map<String, dynamic>> onMessage() => const Stream.empty();
}
