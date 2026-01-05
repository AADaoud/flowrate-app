import 'package:flutter/material.dart';

import '../models/setup_profile.dart';
import '../services/flow_controller.dart';

class SetupProfileScreen extends StatefulWidget {
  const SetupProfileScreen({super.key, required this.controller});

  final FlowController controller;

  @override
  State<SetupProfileScreen> createState() => _SetupProfileScreenState();
}

class _SetupProfileScreenState extends State<SetupProfileScreen> {
  final _magnetCount = TextEditingController();
  final _magnetSize = TextEditingController();
  final _pipeDiameter = TextEditingController();
  final _notes = TextEditingController();
  ElectrodeType _electrodeType = ElectrodeType.sheet;
  CouplingMode _couplingMode = CouplingMode.direct;

  @override
  void dispose() {
    _magnetCount.dispose();
    _magnetSize.dispose();
    _pipeDiameter.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profiles = widget.controller.profiles;
    final active = widget.controller.activeProfile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup profiles'),
        backgroundColor: Colors.black,
      ),
      body: Container(
        color: const Color(0xFF0E101C),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _sectionTitle('Active profile'),
              if (profiles.isEmpty)
                _emptyCard()
              else
                ...profiles.map((p) => _profileTile(p, active)),
              const SizedBox(height: 20),
              _sectionTitle('Create profile'),
              _buildForm(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _emptyCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: const Text(
        'No profiles yet. Create one to unlock calibration.',
        style: TextStyle(color: Colors.white70),
      ),
    );
  }

  Widget _profileTile(SetupProfile profile, SetupProfile? active) {
    final isActive = active?.id == profile.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: _cardDecoration(),
      child: ListTile(
        title: Text(
          profile.label,
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Text(
          'Electrodes: ${profile.electrodeType.name} · Coupling: ${profile.couplingMode.name}'
              '${profile.notes.isNotEmpty ? "\n${profile.notes}" : ""}',
          style: const TextStyle(color: Colors.white70),
        ),
        leading: Radio<String>(
          value: profile.id,
          groupValue: active?.id,
          onChanged: (v) {
            widget.controller.selectProfile(profile.id);
            setState(() {});
          },
          fillColor: MaterialStateProperty.all(Colors.tealAccent),
        ),
        trailing: isActive
            ? const Chip(
                label: Text('Active'),
                labelStyle: TextStyle(color: Colors.white),
                backgroundColor: Colors.teal,
              )
            : null,
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _numberField(_magnetCount, 'Magnet count', 'e.g. 12'),
          const SizedBox(height: 12),
          _numberField(_magnetSize, 'Magnet size (mm edge)', 'e.g. 10'),
          const SizedBox(height: 12),
          _numberField(_pipeDiameter, 'Pipe diameter (mm)', 'e.g. 50'),
          const SizedBox(height: 12),
          _dropdown<ElectrodeType>(
            title: 'Electrode type',
            value: _electrodeType,
            onChanged: (v) => setState(() => _electrodeType = v!),
            items: ElectrodeType.values,
          ),
          const SizedBox(height: 12),
          _dropdown<CouplingMode>(
            title: 'Coupling mode',
            value: _couplingMode,
            onChanged: (v) => setState(() => _couplingMode = v!),
            items: CouplingMode.values,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('Notes (optional)'),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _saveProfile,
            icon: const Icon(Icons.save),
            label: const Text('Save and activate profile'),
          ),
        ],
      ),
    );
  }

  Widget _numberField(
      TextEditingController controller, String label, String hint) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(label).copyWith(hintText: hint),
    );
  }

  Widget _dropdown<T>({
    required String title,
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return InputDecorator(
      decoration: _inputDecoration(title),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          dropdownColor: Colors.black87,
          items: items
              .map(
                (e) => DropdownMenuItem<T>(
                  value: e,
                  child: Text(
                    e is Enum ? (e as Enum).name : e.toString().split('.').last,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.tealAccent.withOpacity(0.8)),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white.withOpacity(0.06),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withOpacity(0.08)),
    );
  }

  void _saveProfile() {
    final magnetCount = int.tryParse(_magnetCount.text);
    final magnetSize = double.tryParse(_magnetSize.text);
    final pipe = double.tryParse(_pipeDiameter.text);
    if (magnetCount == null || magnetSize == null || pipe == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter magnet count, size, and pipe.')),
      );
      return;
    }
    final profile = SetupProfile(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      magnetCount: magnetCount,
      magnetSizeMm: magnetSize,
      pipeDiameterMm: pipe,
      electrodeType: _electrodeType,
      couplingMode: _couplingMode,
      notes: _notes.text,
    );
    widget.controller.addProfile(profile);
    setState(() {
      _magnetCount.clear();
      _magnetSize.clear();
      _pipeDiameter.clear();
      _notes.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile saved and activated.')),
    );
  }
}
