import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/dev_log.dart';
import '../../../domain/entities/entities.dart';
import '../../../providers/repository_providers.dart';
import '../../home/presentation/home_controller.dart';

final trustedContactsProvider =
    FutureProvider.autoDispose<List<TrustedContactEntity>>((ref) async {
  DevLog.contact('Loading trusted contacts list...');
  final repo = ref.watch(contactRepositoryProvider);
  try {
    final list = await repo.fetchContacts();
    DevLog.contact('Loaded ${list.length} trusted contacts.');
    return list;
  } catch (e) {
    DevLog.contact('Failed to fetch contacts', error: e);
    rethrow;
  }
});

class PickedContactData {
  const PickedContactData({required this.name, required this.phone});
  final String name;
  final String phone;
}

class ContactsController extends StateNotifier<AsyncValue<void>> {
  ContactsController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  /// Pick a SINGLE contact from the device address book.
  /// Never reads or uploads other contacts.
  Future<PickedContactData?> pickSingleDeviceContact() async {
    try {
      DevLog.contact('Requesting native contacts picker permission...');
      final hasPermission = await FlutterContacts.requestPermission(readonly: true);
      if (!hasPermission) {
        throw Exception('Contacts permission was denied. Please allow contact access to select a trusted contact.');
      }

      // Open native OS single contact picker
      final contact = await FlutterContacts.openExternalPick();
      if (contact == null) return null;

      // Fetch full details of ONLY the chosen contact
      final fullContact = await FlutterContacts.getContact(contact.id);
      if (fullContact == null) return null;

      final name = fullContact.displayName.isNotEmpty
          ? fullContact.displayName
          : '${fullContact.name.first} ${fullContact.name.last}'.trim();

      String phone = '';
      if (fullContact.phones.isNotEmpty) {
        phone = fullContact.phones.first.number.replaceAll(RegExp(r'\s+'), '');
      }

      DevLog.contact('Contact picked from OS address book: $name, phone: [REDACTED]');
      return PickedContactData(name: name, phone: phone);
    } catch (e, st) {
      DevLog.contact('Failed to pick native contact', error: e);
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> addContact(TrustedContactEntity contact) async {
    state = const AsyncLoading();
    try {
      DevLog.contact('Adding new contact: ${contact.name}');
      final repo = _ref.read(contactRepositoryProvider);
      await repo.createContact(contact);
      _ref.invalidate(trustedContactsProvider);
      _ref.invalidate(dashboardProvider);
      DevLog.contact('Contact created successfully: ${contact.name}');
      state = const AsyncData(null);
    } catch (e, st) {
      DevLog.contact('Failed to create contact', error: e);
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> updateContact(TrustedContactEntity contact) async {
    state = const AsyncLoading();
    try {
      DevLog.contact('Updating contact: ${contact.name} (id: ${contact.id})');
      final repo = _ref.read(contactRepositoryProvider);
      await repo.updateContact(contact);
      _ref.invalidate(trustedContactsProvider);
      _ref.invalidate(dashboardProvider);
      DevLog.contact('Contact updated successfully: ${contact.name}');
      state = const AsyncData(null);
    } catch (e, st) {
      DevLog.contact('Failed to update contact', error: e);
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> deleteContact(String contactId) async {
    state = const AsyncLoading();
    try {
      DevLog.contact('Deleting contact id: $contactId');
      final repo = _ref.read(contactRepositoryProvider);
      await repo.deleteContact(contactId);
      _ref.invalidate(trustedContactsProvider);
      _ref.invalidate(dashboardProvider);
      DevLog.contact('Contact deleted successfully: $contactId');
      state = const AsyncData(null);
    } catch (e, st) {
      DevLog.contact('Failed to delete contact', error: e);
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final contactsControllerProvider =
    StateNotifierProvider<ContactsController, AsyncValue<void>>(
  ContactsController.new,
);
