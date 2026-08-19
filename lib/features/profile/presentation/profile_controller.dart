import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/entities.dart';
import '../../../providers/repository_providers.dart';

final profileProvider = FutureProvider<UserEntity>((ref) {
  return ref.watch(profileRepositoryProvider).fetchProfile();
});

class ProfileUiState {
  const ProfileUiState({this.guardianEnabled = true});

  final bool guardianEnabled;

  ProfileUiState copyWith({bool? guardianEnabled}) =>
      ProfileUiState(guardianEnabled: guardianEnabled ?? this.guardianEnabled);
}

class ProfileController extends StateNotifier<ProfileUiState> {
  ProfileController(this._ref) : super(const ProfileUiState());

  final Ref _ref;

  void setGuardianEnabled(bool value) {
    state = state.copyWith(guardianEnabled: value);
  }

  Future<void> signOut() async {
    await _ref.read(authRepositoryProvider).logout();
  }
}

final profileControllerProvider =
    StateNotifierProvider<ProfileController, ProfileUiState>(ProfileController.new);
