import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/api_exception.dart';
import '../../../core/feedback.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/blur_validated_text_field.dart';
import '../../projects/models/project.dart';
import '../../projects/project_repository.dart';
import '../draft_store.dart';
import '../models/report_draft.dart';
import '../report_repository.dart';

/// Maximum photos per report (mirrors the backend's MAX_IMAGES_PER_REPORT).
const int kMaxReportPhotos = 5;

/// Four-step report wizard: Details → Location → Photos → Review.
///
/// Can be opened with a pre-selected project (from a project detail screen),
/// with a local [draft] to resume, or bare (dashboard quick action) — in
/// which case step 1 shows a project selector.
class SubmitReportScreen extends StatefulWidget {
  final int? projectId;
  final String? projectName;

  /// When resuming a locally saved draft, its content pre-fills the form and
  /// the draft row is updated on save (and removed on successful submit).
  final ReportDraft? draft;

  const SubmitReportScreen({
    super.key,
    this.projectId,
    this.projectName,
    this.draft,
  });

  @override
  State<SubmitReportScreen> createState() => _SubmitReportScreenState();
}

class _SubmitReportScreenState extends State<SubmitReportScreen> {
  static const _stepLabels = ['Details', 'Location', 'Photos', 'Review'];

  int _step = 0;
  final _detailsFormKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  String _reportType = 'daily';
  int? _projectId;
  String _projectName = '';
  double? _lat;
  double? _lng;
  double? _accuracy;
  final List<XFile> _photos = [];
  bool _busy = false;

  // Project selector state (only used when no project was passed in).
  List<Project>? _projects;
  bool _projectsFailed = false;

  /// A draft carries its own project, so resuming one never needs the
  /// project selector either.
  bool get _projectPreselected =>
      widget.projectId != null || widget.draft != null;

  @override
  void initState() {
    super.initState();
    _projectId = widget.projectId ?? widget.draft?.projectId;
    _projectName = widget.projectName ?? widget.draft?.projectName ?? '';
    final draft = widget.draft;
    if (draft != null) {
      _title.text = draft.title;
      _description.text = draft.description;
      _reportType = draft.reportType;
      _lat = draft.latitude;
      _lng = draft.longitude;
      // Best-effort: the OS may have cleared the picker cache since the
      // draft was saved, in which case a thumbnail simply fails to load.
      _photos.addAll(draft.photoPaths.map(XFile.new));
    }
    if (!_projectPreselected) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadProjects());
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    setState(() => _projectsFailed = false);
    try {
      final page = await context.read<ProjectRepository>().list();
      if (!mounted) return;
      setState(() => _projects = page.results);
    } on ApiException {
      if (mounted) setState(() => _projectsFailed = true);
    }
  }

  Future<void> _captureGps() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _toast('Location permission denied.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      setState(() {
        // Round to 7 decimal places — the API stores DECIMAL(10,7) and
        // rejects the extra float precision devices report.
        _lat = double.parse(pos.latitude.toStringAsFixed(7));
        _lng = double.parse(pos.longitude.toStringAsFixed(7));
        _accuracy = pos.accuracy;
      });
    } catch (e) {
      _toast('Could not get location: $e');
    }
  }

  Future<void> _pickPhotos() async {
    final picked = await ImagePicker().pickMultiImage();
    if (picked.isEmpty) return;
    final room = kMaxReportPhotos - _photos.length;
    setState(() => _photos.addAll(picked.take(room)));
    if (picked.length > room) {
      _toast('A report can have at most $kMaxReportPhotos photos.');
    }
  }

  void _next() {
    if (_step == 0 && !(_detailsFormKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_step < _stepLabels.length - 1) setState(() => _step++);
  }

  /// Save the form as a local draft — no network involved, so it works
  /// offline. Resumable from the Reports list under the Drafts filter.
  Future<void> _saveDraft() async {
    setState(() => _busy = true);
    final store = context.read<DraftStore>();
    await store.save(ReportDraft(
      id: widget.draft?.id,
      projectId: _projectId!,
      projectName: _projectName,
      title: _title.text.trim(),
      description: _description.text.trim(),
      reportType: _reportType,
      latitude: _lat,
      longitude: _lng,
      photoPaths: _photos.map((p) => p.path).toList(),
      updatedAt: DateTime.now(),
    ));
    if (!mounted) return;
    showSuccessSnackBar(context, 'Draft saved on this device.');
    Navigator.of(context).pop(true);
  }

  /// Send the report to the server; on success any local draft it came
  /// from is deleted.
  Future<void> _submit() async {
    setState(() => _busy = true);
    final repo = context.read<ReportRepository>();
    final store = context.read<DraftStore>();
    try {
      final reportId = await repo.createReport(
        projectId: _projectId!,
        title: _title.text.trim(),
        reportType: _reportType,
        description: _description.text.trim(),
        latitude: _lat,
        longitude: _lng,
      );
      for (final photo in _photos) {
        final bytes = await photo.readAsBytes();
        await repo.uploadImage(reportId, bytes: bytes, filename: photo.name);
      }
      await repo.submit(reportId);
      final draftId = widget.draft?.id;
      if (draftId != null) await store.delete(draftId);
      if (!mounted) return;
      showSuccessSnackBar(context, 'Report submitted successfully!');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// All `_toast` call sites report failures, so use the error style.
  void _toast(String message) {
    if (!mounted) return;
    showErrorSnackBar(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Submit Report'),
            Text(
              'Step ${_step + 1} of ${_stepLabels.length}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
            ),
          ],
        ),
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: Column(
          children: [
            _StepIndicator(current: _step, labels: _stepLabels),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: switch (_step) {
                  0 => _buildDetails(),
                  1 => _buildLocation(),
                  2 => _buildPhotos(),
                  _ => _buildReview(),
                },
              ),
            ),
            _buildNavButtons(),
          ],
        ),
      ),
    );
  }

  // ── Step 1: Details ──────────────────────────────────────────────────

  Widget _buildDetails() {
    return Form(
      key: _detailsFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_projectPreselected)
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Project',
                prefixIcon: Icon(Icons.work_outline),
              ),
              child: Text(_projectName,
                  style: Theme.of(context).textTheme.bodyLarge),
            )
          else if (_projectsFailed)
            Row(
              children: [
                const Expanded(child: Text('Failed to load projects.')),
                TextButton(
                    onPressed: _loadProjects, child: const Text('Retry')),
              ],
            )
          else
            DropdownButtonFormField<int>(
              key: const Key('project_selector'),
              initialValue: _projectId,
              decoration: const InputDecoration(
                labelText: 'Project',
                prefixIcon: Icon(Icons.work_outline),
              ),
              items: [
                for (final p in _projects ?? const <Project>[])
                  DropdownMenuItem(value: p.id, child: Text(p.projectName)),
              ],
              onChanged: (v) => setState(() {
                _projectId = v;
                _projectName = (_projects ?? [])
                    .firstWhere((p) => p.id == v)
                    .projectName;
              }),
              validator: (v) => v == null ? 'Select a project' : null,
            ),
          const SizedBox(height: 16),
          Text('Report type', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            key: const Key('report_type'),
            segments: const [
              ButtonSegment(value: 'daily', label: Text('Daily')),
              ButtonSegment(value: 'weekly', label: Text('Weekly')),
              ButtonSegment(value: 'monthly', label: Text('Monthly')),
            ],
            selected: {_reportType},
            onSelectionChanged: (s) => setState(() => _reportType = s.first),
          ),
          const SizedBox(height: 16),
          BlurValidatedTextField(
            key: const Key('report_title'),
            controller: _title,
            decoration: const InputDecoration(labelText: 'Activity title'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _description,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Description',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 2: Location ─────────────────────────────────────────────────

  Widget _buildLocation() {
    final hasFix = _lat != null && _lng != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                hasFix ? Icons.location_on : Icons.location_searching,
                size: 48,
                color: AppColors.primary,
              ),
              const SizedBox(height: 12),
              Text(
                hasFix
                    ? '📍 ${_lat!.toStringAsFixed(5)}°, ${_lng!.toStringAsFixed(5)}°'
                    : 'No location captured yet',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (hasFix && _accuracy != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Accuracy: ±${_accuracy!.toStringAsFixed(0)} m',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: AppColors.muted),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _captureGps,
          icon: const Icon(Icons.my_location),
          label: Text(hasFix ? 'Update Location' : 'Capture Location'),
        ),
        const SizedBox(height: 8),
        Text(
          'GPS coordinates prove the report was filed from the field. '
          'This step is optional.',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.muted),
        ),
      ],
    );
  }

  // ── Step 3: Photos ───────────────────────────────────────────────────

  Widget _buildPhotos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_photos.length} of $kMaxReportPhotos photos added',
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            for (int i = 0; i < _photos.length; i++)
              _PhotoSlot(
                file: _photos[i],
                onRemove: () => setState(() => _photos.removeAt(i)),
              ),
            if (_photos.length < kMaxReportPhotos)
              InkWell(
                onTap: _pickPhotos,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border, width: 1.5),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined,
                          color: AppColors.muted),
                      SizedBox(height: 6),
                      Text('Add photos',
                          style:
                              TextStyle(fontSize: 11, color: AppColors.muted)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ── Step 4: Review ───────────────────────────────────────────────────

  Widget _buildReview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _reviewRow('Project', _projectName),
                _reviewRow('Type',
                    _reportType[0].toUpperCase() + _reportType.substring(1)),
                _reviewRow('Title', _title.text.trim()),
                _reviewRow(
                    'Description',
                    _description.text.trim().isEmpty
                        ? '—'
                        : _description.text.trim()),
                _reviewRow(
                    'Location',
                    (_lat != null && _lng != null)
                        ? '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}'
                        : 'Not captured'),
                _reviewRow('Photos', '${_photos.length}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('save_draft_button'),
                onPressed: _busy ? null : _saveDraft,
                child: const Text('Save as Draft'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                key: const Key('submit_button'),
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Submit Report'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: AppColors.muted)),
          ),
          Expanded(
            child: Text(value,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Wizard navigation ────────────────────────────────────────────────

  Widget _buildNavButtons() {
    if (_step == _stepLabels.length - 1) {
      // Review step renders its own Save/Submit actions; only offer Back.
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: OutlinedButton(
          onPressed: _busy ? null : () => setState(() => _step--),
          child: const Text('Back'),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          if (_step > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _step--),
                child: const Text('Back'),
              ),
            ),
          if (_step > 0) const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              key: const Key('next_button'),
              onPressed: _next,
              child: const Text('Next'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step indicator ────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int current;
  final List<String> labels;
  const _StepIndicator({required this.current, required this.labels});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          for (int i = 0; i < labels.length; i++) ...[
            _dot(context, i),
            if (i < labels.length - 1)
              Expanded(
                child: Container(
                  height: 2,
                  color: current > i ? AppColors.primary : AppColors.border,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _dot(BuildContext context, int i) {
    final done = current > i;
    final active = current == i;
    final color = (done || active) ? AppColors.primary : AppColors.border;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Center(
            child: done
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text('${i + 1}',
                    style: TextStyle(
                        color: active ? Colors.white : AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 4),
        Text(labels[i],
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: active ? AppColors.primary : AppColors.muted)),
      ],
    );
  }
}

// ── Photo grid slot ───────────────────────────────────────────────────────

class _PhotoSlot extends StatelessWidget {
  final XFile file;
  final VoidCallback onRemove;
  const _PhotoSlot({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        FutureBuilder(
          future: file.readAsBytes(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(10),
                ),
              );
            }
            return ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(snapshot.data!, fit: BoxFit.cover),
            );
          },
        ),
        Positioned(
          right: 4,
          top: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: const CircleAvatar(
              radius: 12,
              backgroundColor: Colors.black54,
              child: Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
