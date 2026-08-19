import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/utils/dev_log.dart';
import '../../../data/dto/api_dto.dart';
import '../../../providers/repository_providers.dart';

// Web Application OAuth client ID — required as `serverClientId` by GoogleSignIn
// on Android to generate a backend-verifiable OpenID Connect ID token for FastAPI.
// Can be supplied via `--dart-define=GOOGLE_WEB_CLIENT_ID=...` or configured below.
const _kGoogleWebClientId = String.fromEnvironment(
  'GOOGLE_WEB_CLIENT_ID',
  defaultValue: '638591615239-q9ggn1oo47015msgb982egplt3mhigcf.apps.googleusercontent.com',
);

/// Singleton GoogleSignIn instance scoped to the authentication flow.
/// serverClientId tells the SDK to request an ID token audience for the backend.
final _googleSignIn = GoogleSignIn(
  serverClientId: _kGoogleWebClientId,
  scopes: ['email', 'profile'],
);

class AuthFormState {
  const AuthFormState({
    this.isLoading = false,
    this.error,
    this.obscurePassword = true,
    this.obscureConfirm = true,
    this.rememberMe = false,
    this.agreedToTerms = false,
  });

  final bool isLoading;
  final String? error;
  final bool obscurePassword;
  final bool obscureConfirm;
  final bool rememberMe;
  final bool agreedToTerms;

  AuthFormState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? obscurePassword,
    bool? obscureConfirm,
    bool? rememberMe,
    bool? agreedToTerms,
  }) {
    return AuthFormState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      obscurePassword: obscurePassword ?? this.obscurePassword,
      obscureConfirm: obscureConfirm ?? this.obscureConfirm,
      rememberMe: rememberMe ?? this.rememberMe,
      agreedToTerms: agreedToTerms ?? this.agreedToTerms,
    );
  }
}

class AuthController extends StateNotifier<AuthFormState> {
  AuthController(this._ref) : super(const AuthFormState());

  final Ref _ref;

  void toggleObscurePassword() =>
      state = state.copyWith(obscurePassword: !state.obscurePassword);

  void toggleObscureConfirm() =>
      state = state.copyWith(obscureConfirm: !state.obscureConfirm);

  void setRememberMe(bool value) => state = state.copyWith(rememberMe: value);

  void setAgreedToTerms(bool value) => state = state.copyWith(agreedToTerms: value);

  Future<bool> login({required String email, required String password}) async {
    DevLog.auth('Attempting email login: $email');
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _ref.read(authRepositoryProvider).login(
            LoginRequest(
              email: email.trim(),
              password: password,
              rememberMe: state.rememberMe,
            ),
          );
      DevLog.auth('Email login successful for $email');
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      DevLog.auth('Email login failed for $email', error: e);
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String confirmPassword,
  }) async {
    if (!state.agreedToTerms) {
      DevLog.auth('Registration blocked: User did not accept terms.');
      state = state.copyWith(error: 'Please accept Privacy Policy and Terms.');
      return false;
    }
    if (password != confirmPassword) {
      DevLog.auth('Registration blocked: Passwords do not match.');
      state = state.copyWith(error: 'Passwords do not match.');
      return false;
    }
    DevLog.auth('Attempting user registration: $email');
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _ref.read(authRepositoryProvider).register(
            RegisterRequest(
              fullName: fullName.trim(),
              email: email.trim(),
              phone: phone.trim(),
              password: password,
            ),
          );
      DevLog.auth('User registration successful: $email');
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      DevLog.auth('User registration failed: $email', error: e);
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Sign in with real Google account picker.
  Future<bool> signInWithGoogle({String? customIdToken}) async {
    DevLog.log('GOOGLE_AUTH', 'button pressed');
    DevLog.log('GOOGLE_AUTH', 'Google Sign-In initialization started');
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      String idToken;

      if (customIdToken != null) {
        idToken = customIdToken;
        DevLog.log('GOOGLE_AUTH', 'ID token received = true (custom)');
      } else {
        DevLog.log('GOOGLE_AUTH', 'Google account selection started');
        final account = await _googleSignIn.signIn();
        final selected = account != null;
        DevLog.log('GOOGLE_AUTH', 'Google account selected = $selected');

        if (account == null) {
          DevLog.log('GOOGLE_AUTH', 'ERROR CODE = GOOGLE_SIGN_IN_CANCELLED');
          DevLog.log('GOOGLE_AUTH', 'ERROR MESSAGE = User cancelled Google account selection.');
          state = state.copyWith(isLoading: false, clearError: true);
          return false;
        }

        final auth = await account.authentication;
        final serverIdToken = auth.idToken;
        final tokenReceived = serverIdToken != null && serverIdToken.isNotEmpty;
        DevLog.log('GOOGLE_AUTH', 'Google credential received = $tokenReceived');
        DevLog.log('GOOGLE_AUTH', 'ID token received = $tokenReceived');
        DevLog.log('GOOGLE_AUTH', 'access token received = ${auth.accessToken != null}');

        if (!tokenReceived) {
          DevLog.log('GOOGLE_AUTH', 'ERROR CODE = GOOGLE_TOKEN_MISSING');
          DevLog.log('GOOGLE_AUTH', 'ERROR MESSAGE = Google SDK did not return an ID token. Check SHA-1 registration.');
          state = state.copyWith(
            isLoading: false,
            error: '[GOOGLE_TOKEN_MISSING] Google did not return a valid server ID token. '
                'Verify the debug SHA-1 (E7:87:1A:B1:7B:C7:9C:16:14:AA:07:F7:30:41:94:0F:27:83:36:DF) is registered in Google Cloud Console.',
          );
          return false;
        }
        idToken = serverIdToken;
      }

      await _ref.read(authRepositoryProvider).loginWithGoogle(idToken);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      final errString = e.toString();
      String errorCode = 'GOOGLE_DEVELOPER_ERROR';
      String safeMessage = 'Google Sign-In failed.';

      if (errString.contains('10') || errString.contains('DEVELOPER_ERROR')) {
        errorCode = 'GOOGLE_DEVELOPER_ERROR';
        safeMessage = 'Google Play Services configuration error (ApiException 10). '
            'Debug SHA-1 fingerprint must be registered in Google Cloud / Firebase Console.';
      } else if (errString.contains('12500')) {
        errorCode = 'GOOGLE_CONFIGURATION_ERROR';
        safeMessage = 'Google Sign-In configuration error (ApiException 12500).';
      } else if (errString.contains('401') || errString.contains('Unauthorized')) {
        errorCode = 'GOOGLE_BACKEND_401';
        safeMessage = 'Backend rejected Google identity token verification.';
      } else if (errString.contains('SocketException') || errString.contains('TimeoutException')) {
        errorCode = 'NETWORK_ERROR';
        safeMessage = 'Network unreachable while communicating with authentication service.';
      }

      DevLog.log('GOOGLE_AUTH', 'ERROR CODE = $errorCode');
      DevLog.log('GOOGLE_AUTH', 'ERROR MESSAGE = $safeMessage', error: e);

      state = state.copyWith(
        isLoading: false,
        error: '[$errorCode] $safeMessage',
      );
      return false;
    }
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthFormState>(AuthController.new);
