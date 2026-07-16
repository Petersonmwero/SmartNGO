import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/api_exception.dart';
import '../../core/theme.dart';
import '../../features/beneficiaries/beneficiary_repository.dart';

/// Cascading Kenya location picker (eCitizen-style):
/// fixed Country → County → Constituency → Ward dropdowns plus a free-text
/// Village field. Each selection loads the next level from
/// GET /api/v1/locations/kenya/ and resets everything below it.
///
/// Reports every change through [onChanged] as
/// `{country, county, constituency, ward, village}`.
class KenyaLocationPicker extends StatefulWidget {
  final ValueChanged<Map<String, String>> onChanged;

  const KenyaLocationPicker({super.key, required this.onChanged});

  @override
  State<KenyaLocationPicker> createState() => _KenyaLocationPickerState();
}

class _KenyaLocationPickerState extends State<KenyaLocationPicker> {
  List<String> _counties = const [];
  List<String> _constituencies = const [];
  List<String> _wards = const [];

  String? _county;
  String? _constituency;
  String? _ward;
  String _village = '';

  bool _loadingCounties = false;
  bool _loadingConstituencies = false;
  bool _loadingWards = false;
  bool _countiesFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCounties());
  }

  void _emit() {
    widget.onChanged({
      'country': 'Kenya',
      'county': _county ?? '',
      'constituency': _constituency ?? '',
      'ward': _ward ?? '',
      'village': _village.trim(),
    });
  }

  Future<void> _loadCounties() async {
    setState(() {
      _loadingCounties = true;
      _countiesFailed = false;
    });
    try {
      final counties =
          await context.read<BeneficiaryRepository>().kenyaCounties();
      if (!mounted) return;
      setState(() => _counties = counties);
    } on ApiException {
      if (mounted) setState(() => _countiesFailed = true);
    } finally {
      if (mounted) setState(() => _loadingCounties = false);
    }
  }

  Future<void> _loadConstituencies(String county) async {
    setState(() => _loadingConstituencies = true);
    try {
      final constituencies = await context
          .read<BeneficiaryRepository>()
          .kenyaConstituencies(county);
      if (!mounted) return;
      setState(() => _constituencies = constituencies);
    } on ApiException {
      if (mounted) setState(() => _constituencies = const []);
    } finally {
      if (mounted) setState(() => _loadingConstituencies = false);
    }
  }

  Future<void> _loadWards(String constituency) async {
    setState(() => _loadingWards = true);
    try {
      final wards =
          await context.read<BeneficiaryRepository>().kenyaWards(constituency);
      if (!mounted) return;
      setState(() => _wards = wards);
    } on ApiException {
      if (mounted) setState(() => _wards = const []);
    } finally {
      if (mounted) setState(() => _loadingWards = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _CountryField(),
        const SizedBox(height: 12),
        if (_countiesFailed)
          Row(
            children: [
              const Expanded(child: Text('Failed to load counties.')),
              TextButton(
                  onPressed: _loadCounties, child: const Text('Retry')),
            ],
          )
        else
          _LocationDropdown(
            key: const Key('county_dropdown'),
            label: 'County',
            icon: Icons.location_city_outlined,
            hint: 'Select County',
            items: _counties,
            value: _county,
            isLoading: _loadingCounties,
            enabled: true,
            onChanged: (value) {
              setState(() {
                _county = value;
                _constituency = null;
                _ward = null;
                _constituencies = const [];
                _wards = const [];
              });
              _emit();
              if (value != null) _loadConstituencies(value);
            },
          ),
        const SizedBox(height: 12),
        _LocationDropdown(
          key: const Key('constituency_dropdown'),
          label: 'Constituency',
          icon: Icons.map_outlined,
          hint: _county == null ? 'Select county first' : 'Select Constituency',
          items: _constituencies,
          value: _constituency,
          isLoading: _loadingConstituencies,
          enabled: _county != null,
          onChanged: (value) {
            setState(() {
              _constituency = value;
              _ward = null;
              _wards = const [];
            });
            _emit();
            if (value != null) _loadWards(value);
          },
        ),
        const SizedBox(height: 12),
        _LocationDropdown(
          key: const Key('ward_dropdown'),
          label: 'Ward',
          icon: Icons.place_outlined,
          hint: _constituency == null
              ? 'Select constituency first'
              : _wards.isEmpty && !_loadingWards
                  ? 'No ward data — skip'
                  : 'Select Ward',
          items: _wards,
          value: _ward,
          isLoading: _loadingWards,
          enabled: _constituency != null && _wards.isNotEmpty,
          onChanged: (value) {
            setState(() => _ward = value);
            _emit();
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const Key('village_field'),
          decoration: const InputDecoration(
            labelText: 'Village / Sub-location',
            hintText: 'e.g. Nyalenda, Kondele',
            prefixIcon: Icon(Icons.home_outlined, color: AppColors.primary),
          ),
          onChanged: (v) {
            _village = v;
            _emit();
          },
        ),
      ],
    );
  }
}

/// Read-only country row — the platform currently serves Kenya only.
class _CountryField extends StatelessWidget {
  const _CountryField();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: Row(
        children: [
          const Icon(Icons.public, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Country',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(fontSize: 11, color: AppColors.muted)),
              Text('Kenya 🇰🇪',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.charcoal, fontWeight: FontWeight.w700)),
            ],
          ),
          const Spacer(),
          const Icon(Icons.lock_outline, color: AppColors.muted, size: 16),
        ],
      ),
    );
  }
}

/// Labelled dropdown with disabled/loading treatments shared by the three
/// cascading levels.
class _LocationDropdown extends StatelessWidget {
  final String label;
  final IconData icon;
  final String hint;
  final List<String> items;
  final String? value;
  final bool isLoading;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  const _LocationDropdown({
    super.key,
    required this.label,
    required this.icon,
    required this.hint,
    required this.items,
    required this.value,
    required this.isLoading,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700, color: AppColors.charcoal),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: enabled ? Colors.white : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isLoading ? AppColors.primary : const Color(0xFFD1D5DB),
            ),
          ),
          child: isLoading
              ? const _LoadingDropdown()
              : DropdownButtonFormField<String>(
                  initialValue: value,
                  isExpanded: true,
                  hint: Row(
                    children: [
                      Icon(icon, color: AppColors.muted, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          hint,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.muted),
                        ),
                      ),
                    ],
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                  ),
                  items: [
                    for (final item in items)
                      DropdownMenuItem(
                        value: item,
                        child: Text(
                          item,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.charcoal),
                        ),
                      ),
                  ],
                  onChanged: enabled ? onChanged : null,
                  icon: const Icon(Icons.keyboard_arrow_down,
                      color: AppColors.muted),
                ),
        ),
      ],
    );
  }
}

/// Shimmer row shown inside a dropdown container while its items load.
class _LoadingDropdown extends StatelessWidget {
  const _LoadingDropdown();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              width: 120,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const Spacer(),
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
