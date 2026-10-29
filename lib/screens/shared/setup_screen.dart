import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/helpers.dart';
import '../../core/models.dart';
import '../../data/repositories.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  UserRole? _selectedRole;

  // Shared
  final _phoneController = TextEditingController();

  // Resident
  bool _isCreatingSociety = false;
  final _societyNameController = TextEditingController();
  final _joinCodeController = TextEditingController();
  final _guardCodeController = TextEditingController();
  final _residentJoinCodeController = TextEditingController();

  // Guard
  bool _isEventGuard = false;
  final _guardJoinCodeController = TextEditingController();
  String? _selectedGate;
  final _customGateController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _societyNameController.dispose();
    _joinCodeController.dispose();
    _guardCodeController.dispose();
    _residentJoinCodeController.dispose();
    _guardJoinCodeController.dispose();
    _customGateController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRole == null) {
      showSnack(context, 'Please select your role first.', isError: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final phone = _phoneController.text.trim();
      final user = authService.currentUser;
      if (user == null)
        throw const AppException('Session expired. Please sign in again.');

      switch (_selectedRole!) {
        case UserRole.resident:
        case UserRole.admin:
          if (_isCreatingSociety) {
            await authService.createSociety(
              societyName: _societyNameController.text.trim(),
              joinCode: _joinCodeController.text.trim(),
              guardCode: _guardCodeController.text.trim(),
            );
          } else {
            await authService.joinSociety(
              joinCode: _residentJoinCodeController.text.trim(),
              phone: phone,
            );
          }
          break;

        case UserRole.organizer:
          await authService.completeOrganizerSetup(phone: phone);
          break;

        case UserRole.guard:
          String gate;
          if (_isEventGuard) {
            gate = _customGateController.text.trim();
          } else {
            gate = _selectedGate ?? 'Main Gate';
          }
          await authService.joinAsGuard(
            guardCode: _guardJoinCodeController.text.trim(),
            gateName: gate,
            isEventGuard: _isEventGuard,
            phone: phone,
          );
          break;
      }

      if (mounted) {
        // Triggers RootGate to re-evaluate and route to the correct Home Screen
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Welcome to Dastak',
                      style: AppTextStyles.h1, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    'Let\'s set up your profile to get started.',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // --- Role Selection ---
                  Text('I am a...', style: AppTextStyles.label),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildRoleCard(
                          UserRole.resident, Icons.home_rounded, 'Resident'),
                      const SizedBox(width: 12),
                      _buildRoleCard(
                          UserRole.organizer, Icons.event_rounded, 'Organizer'),
                      const SizedBox(width: 12),
                      _buildRoleCard(
                          UserRole.guard, Icons.security_rounded, 'Guard'),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // --- Phone (Required for all) ---
                  TextFormField(
                    controller: _phoneController,
                    decoration: fieldDecoration(
                        label: 'Phone Number',
                        icon: Icons.phone_rounded,
                        hint: '0300 1234567'),
                    keyboardType: TextInputType.phone,
                    validator: validatePhone,
                  ),
                  const SizedBox(height: 24),

                  // --- Role Specific Forms ---
                  if (_selectedRole == UserRole.resident) _buildResidentForm(),
                  if (_selectedRole == UserRole.organizer)
                    _buildOrganizerForm(),
                  if (_selectedRole == UserRole.guard) _buildGuardForm(),

                  const SizedBox(height: 32),

                  // --- Submit ---
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Complete Setup'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // ROLE CARDS
  // ==========================================================================
  Widget _buildRoleCard(UserRole role, IconData icon, String label) {
    final isSelected = _selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRole = role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withOpacity(0.1)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.surfaceMuted,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color:
                      isSelected ? AppColors.primary : AppColors.textSecondary,
                  size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color:
                      isSelected ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // RESIDENT FORM
  // ==========================================================================
  Widget _buildResidentForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isCreatingSociety = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: !_isCreatingSociety
                          ? AppColors.surface
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: !_isCreatingSociety
                          ? [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4)
                            ]
                          : [],
                    ),
                    child: Center(
                      child: Text(
                        'Join Society',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: !_isCreatingSociety
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: !_isCreatingSociety
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isCreatingSociety = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _isCreatingSociety
                          ? AppColors.surface
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: _isCreatingSociety
                          ? [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4)
                            ]
                          : [],
                    ),
                    child: Center(
                      child: Text(
                        'Create Society',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: _isCreatingSociety
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _isCreatingSociety
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (!_isCreatingSociety)
          TextFormField(
            controller: _residentJoinCodeController,
            decoration: fieldDecoration(
                label: 'Society Join Code',
                icon: Icons.vpn_key_rounded,
                hint: 'e.g. BHR-123'),
            validator: (v) => validateRequired(v, 'Join code'),
          )
        else ...[
          TextFormField(
            controller: _societyNameController,
            decoration: fieldDecoration(
                label: 'Society Name', icon: Icons.apartment_rounded),
            validator: (v) => validateRequired(v, 'Society name'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _joinCodeController,
            decoration: fieldDecoration(
                label: 'Create Join Code (for residents)',
                icon: Icons.group_add_rounded,
                hint: 'Min 6 characters'),
            validator: (v) => validateRequired(v, 'Join code'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _guardCodeController,
            decoration: fieldDecoration(
                label: 'Create Guard Code',
                icon: Icons.security_rounded,
                hint: 'Min 6 characters'),
            validator: (v) => validateRequired(v, 'Guard code'),
          ),
        ],
      ],
    );
  }

  // ==========================================================================
  // ORGANIZER FORM
  // ==========================================================================
  Widget _buildOrganizerForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.infoLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.info, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'You can create events, import attendees, and generate passes from your dashboard once setup is complete.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.info),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // GUARD FORM
  // ==========================================================================
  Widget _buildGuardForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isEventGuard = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: !_isEventGuard
                          ? AppColors.surface
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: !_isEventGuard
                          ? [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4)
                            ]
                          : [],
                    ),
                    child: Center(
                      child: Text(
                        'Society Guard',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: !_isEventGuard
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: !_isEventGuard
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isEventGuard = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _isEventGuard
                          ? AppColors.surface
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: _isEventGuard
                          ? [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4)
                            ]
                          : [],
                    ),
                    child: Center(
                      child: Text(
                        'Event Guard',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: _isEventGuard
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _isEventGuard
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _guardJoinCodeController,
          decoration: fieldDecoration(
            label: _isEventGuard ? 'Event Guard Code' : 'Society Guard Code',
            icon: Icons.vpn_key_rounded,
            hint: 'Provided by organizer/admin',
          ),
          validator: (v) => validateRequired(v, 'Guard code'),
        ),
        const SizedBox(height: 16),
        if (_isEventGuard)
          TextFormField(
            controller: _customGateController,
            decoration: fieldDecoration(
                label: 'Assigned Gate/Zone',
                icon: Icons.door_front_door_rounded,
                hint: 'e.g. VIP Entrance'),
            validator: (v) => validateRequired(v, 'Gate name'),
          )
        else
          DropdownButtonFormField<String>(
            value: _selectedGate,
            decoration: fieldDecoration(
                label: 'Select Your Gate', icon: Icons.door_front_door_rounded),
            items: kGateNames.map((gate) {
              return DropdownMenuItem(value: gate, child: Text(gate));
            }).toList(),
            onChanged: (val) => setState(() => _selectedGate = val),
            validator: (v) => v == null ? 'Please select a gate' : null,
          ),
      ],
    );
  }
}
