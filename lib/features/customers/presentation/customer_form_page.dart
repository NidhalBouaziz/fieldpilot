import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/customer.dart';
import '../../../core/repositories/providers.dart';

class CustomerFormPage extends ConsumerStatefulWidget {
  const CustomerFormPage({super.key});

  @override
  ConsumerState<CustomerFormPage> createState() => _CustomerFormPageState();
}

class _CustomerFormPageState extends ConsumerState<CustomerFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _company = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _governorate = TextEditingController();
  final _speciality = TextEditingController();
  final _notes = TextEditingController();
  CustomerStatus _status = CustomerStatus.neverVisited;
  bool _favorite = false;

  @override
  void dispose() {
    for (final controller in [
      _firstName,
      _lastName,
      _company,
      _phone,
      _email,
      _address,
      _city,
      _governorate,
      _speciality,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final customer = Customer(
      id: ref.read(idGeneratorProvider)(),
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      companyName: _company.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim().isEmpty ? null : _email.text.trim(),
      address: _address.text.trim().isEmpty ? null : _address.text.trim(),
      city: _city.text.trim(),
      governorate: _governorate.text.trim(),
      speciality:
          _speciality.text.trim().isEmpty ? null : _speciality.text.trim(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      status: _status,
      favorite: _favorite,
      createdAt: now,
      updatedAt: now,
    );

    final repository = ref.read(customerRepositoryProvider);
    final duplicates = await repository.duplicatesFor(customer);
    if (duplicates.isNotEmpty && mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Possible duplicate'),
          content: Text(
            'FieldPilot found ${duplicates.length} similar customer profile. Save this customer anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Review'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    await repository.save(customer);
    ref.invalidate(customersProvider);
    ref.invalidate(dashboardSnapshotProvider);
    if (mounted) context.go('/customers/${customer.id}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New customer')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field(_firstName, 'First name'),
            _field(_lastName, 'Last name'),
            _field(_company, 'Company or clinic', required: true),
            _field(
              _phone,
              'Phone',
              keyboardType: TextInputType.phone,
              required: true,
            ),
            _field(_email, 'Email', keyboardType: TextInputType.emailAddress),
            _field(_address, 'Address'),
            _field(_city, 'City', required: true),
            _field(_governorate, 'Governorate', required: true),
            _field(_speciality, 'Speciality'),
            const SizedBox(height: 12),
            DropdownButtonFormField<CustomerStatus>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: CustomerStatus.values
                  .where((status) => status != CustomerStatus.archived)
                  .map((status) {
                return DropdownMenuItem(
                  value: status,
                  child: Text(status.label),
                );
              }).toList(),
              onChanged: (value) => setState(() => _status = value ?? _status),
            ),
            SwitchListTile(
              value: _favorite,
              onChanged: (value) => setState(() => _favorite = value),
              title: const Text('Favorite'),
            ),
            TextField(
              controller: _notes,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save customer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (value) => value == null || value.trim().isEmpty
                ? '$label is required'
                : null
            : null,
      ),
    );
  }
}
