import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/helpers.dart';
import '../../core/models.dart';
import '../../data/repositories.dart';
import '../../widgets/shared_widgets.dart';

class CreateEventScreen extends StatefulWidget {
  final Event? event;
  const CreateEventScreen({super.key, this.event});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _venueController = TextEditingController();
  final _addressController = TextEditingController();
  final _gateController = TextEditingController();

  // State
  bool _isSaving = false;
  String _eventType = kEventTypes.first;
  DateTime _startAt = DateTime.now().add(const Duration(days: 1));
  DateTime _endAt = DateTime.now().add(const Duration(days: 1, hours: 4));

  // Gate Management
  final List<String> _gates = ['Main Entrance'];

  bool get _isEditing => widget.event != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final e = widget.event!;
      _nameController.text = e.name;
      _eventType = e.eventType;
      _venueController.text = e.venueName ?? '';
      _addressController.text = e.address ?? '';
      _startAt = e.startAt;
      _endAt = e.endAt ?? e.startAt.add(const Duration(hours: 4));
      _gates.clear();
      _gates.addAll(e.gates);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _venueController.dispose();
    _addressController.dispose();
    _gateController.dispose();
    super.dispose();
  }

  void _addGate() {
    final gate = _gateController.text.trim();
    if (gate.isEmpty) return;
    if (_gates.contains(gate)) {
      showSnack(context, 'Gate already exists.', isError: true);
      return;
    }
    setState(() {
      _gates.add(gate);
      _gateController.clear();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_gates.isEmpty) {
      showSnack(context, 'Add at least one gate/entrance.', isError: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    try {
      final user = authService.currentUser;
      if (user == null) throw const AppException('Session expired.');

      // Generate a unique guard code for new events
      final guardCode = _isEditing
          ? widget.event!.guardCode
          : 'EVC-${Random().nextInt(9999).toString().padLeft(4, '0')}';

      final event = Event(
        id: _isEditing ? widget.event!.id : '',
        organizerId: user.id,
        name: _nameController.text.trim(),
        eventType: _eventType,
        guardCode: guardCode,
        gates: _gates,
        startAt: _startAt,
        endAt: _endAt,
        venueName: _venueController.text.trim().isEmpty
            ? null
            : _venueController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        isActive: true,
      );

      if (_isEditing) {
        await eventService.updateEvent(event);
      } else {
        await eventService.createEvent(event);
      }

      if (mounted) {
        Navigator.pop(context, true);
        showSnack(context,
            _isEditing ? 'Event updated!' : 'Event created successfully!');
      }
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Event' : 'Create Event'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // --- Section 1: Event Basics ---
              const FieldLabel('Event Details', isRequired: true),
              TextFormField(
                controller: _nameController,
                decoration: fieldDecoration(
                    label: 'Event Name', icon: Icons.event_rounded),
                textCapitalization: TextCapitalization.words,
                validator: (v) => validateRequired(v, 'Event name'),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _eventType,
                decoration: fieldDecoration(
                    label: 'Event Type', icon: Icons.category_outlined),
                items: kEventTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (val) => setState(() => _eventType = val!),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _venueController,
                decoration: fieldDecoration(
                    label: 'Venue Name (Optional)',
                    icon: Icons.business_rounded),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _addressController,
                decoration: fieldDecoration(
                    label: 'Address (Optional)',
                    icon: Icons.location_on_outlined),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 32),

              // --- Section 2: Schedule ---
              const FieldLabel('Schedule', isRequired: true),
              Row(
                children: [
                  Expanded(
                    child: _buildDateTimePicker(
                      label: 'Starts',
                      date: _startAt,
                      onChanged: (d) {
                        setState(() {
                          _startAt = d;
                          // Auto-adjust end time if it's before start time
                          if (_endAt.isBefore(_startAt)) {
                            _endAt = _startAt.add(const Duration(hours: 4));
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDateTimePicker(
                      label: 'Ends',
                      date: _endAt,
                      onChanged: (d) => setState(() => _endAt = d),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // --- Section 3: Access Control (Gates) ---
              const FieldLabel('Gates & Entrances', isRequired: true),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.surfaceMuted),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Guards will select one of these gates during setup.',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _gates.map((gate) {
                        return Chip(
                          label: Text(gate),
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          labelStyle: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.primary),
                          side: BorderSide.none,
                          deleteIcon: const Icon(Icons.close,
                              size: 16, color: AppColors.primary),
                          onDeleted: () {
                            if (_gates.length > 1) {
                              setState(() => _gates.remove(gate));
                            } else {
                              showSnack(context, 'Must have at least one gate.',
                                  isError: true);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _gateController,
                            decoration: fieldDecoration(
                              label: 'Add Gate',
                              hint: 'e.g. VIP Entrance',
                              isDense: true,
                            ),
                            onSubmitted: (_) => _addGate(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _addGate,
                          icon: const Icon(Icons.add_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(14),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (_isEditing) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.infoLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.vpn_key_rounded, color: AppColors.info),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Event Guard Code',
                                style: AppTextStyles.label
                                    .copyWith(color: AppColors.info)),
                            Text(
                              widget.event!.guardCode,
                              style: AppTextStyles.h3.copyWith(
                                  color: AppColors.info, letterSpacing: 2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 48),

              // --- Submit ---
              AppButton(
                label: _isEditing ? 'Save Changes' : 'Create Event',
                icon: Icons.check_circle_rounded,
                isLoading: _isSaving,
                onPressed: _submit,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // HELPER WIDGETS
  // ==========================================================================

  Widget _buildDateTimePicker({
    required String label,
    required DateTime date,
    required Function(DateTime) onChanged,
  }) {
    return InkWell(
      onTap: () async {
        final d = await pickDateTime(context, initial: date);
        if (d != null) onChanged(d);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.label),
            const SizedBox(height: 6),
            Text(
              formatDateTime(date),
              style: AppTextStyles.bodyMedium
                  .copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
