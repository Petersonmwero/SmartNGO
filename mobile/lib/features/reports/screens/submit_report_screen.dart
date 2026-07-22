import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/api_exception.dart';
import '../../../core/feedback.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/blur_validated_text_field.dart';
import '../../projects/models/milestone.dart';
import '../../projects/models/phase.dart';
import '../../projects/models/project.dart';
import '../../projects/project_repository.dart';
import '../draft_store.dart';
import '../models/activity_type.dart';
import '../models/report_draft.dart';
import '../report_repository.dart';

/// Maximum photos per report (mirrors the backend's MAX_IMAGES_PER_REPORT).
const int kMaxReportPhotos = 5;

/// Six-step report wizard:
/// Details → Activity → Impact → Location → Photos → Review.
///
/// Activity and Impact capture the structured donor-reporting payload —
/// what was done, what it cost, who it reached, and what it changed. Every
/// field there is optional: a narrative-only report is still valid, and the
/// figures only affect project totals once a manager approves the report.
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
  static const _stepLabels = [
    'Details',
    'Activity',
    'Impact',
    'GPS',
    'Photos',
    'Review',
  ];
  static const _activityStep = 1;

  int _step = 0;
  final _detailsFormKey = GlobalKey<FormState>();
  final _activityFormKey = GlobalKey<FormState>();
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

  // Submission runs in three server calls (create → upload photos → submit);
  // on a flaky field connection any of them can fail mid-way. These two
  // fields make a retry resume rather than restart:
  //  - the created report's id, so we never create a second report;
  //  - the paths of photos already uploaded, so we never re-post them.
  int? _createdReportId;
  final Set<String> _uploadedPhotoPaths = {};

  // ── Structured reporting state ────────────────────────────────────────
  String _activityType = '';
  int? _linkedPhaseId;
  int? _linkedMilestoneId;
  final _amountSpent = TextEditingController();
  final _expenditureNotes = TextEditingController();
  final _reached = TextEditingController();
  final _male = TextEditingController();
  final _female = TextEditingController();
  final _youth = TextEditingController();
  final _impact = TextEditingController();
  final _challenges = TextEditingController();
  final _recommendations = TextEditingController();
  final _nextSteps = TextEditingController();

  /// Phases and milestones of the selected project, for the link pickers.
  /// Null while loading; empty when the project has none.
  List<ProjectPhase>? _phases;
  List<Milestone>? _milestones;
  int? _linksLoadedFor;

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
      _activityType = draft.activityType;
      _linkedPhaseId = draft.linkedPhaseId;
      _linkedMilestoneId = draft.linkedMilestoneId;
      _amountSpent.text = draft.amountSpent;
      _expenditureNotes.text = draft.expenditureNotes;
      // Zero means "not recorded" here, so it shows as an empty field
      // rather than a 0 the officer has to clear.
      _reached.text = _countText(draft.beneficiariesReached);
      _male.text = _countText(draft.beneficiariesMale);
      _female.text = _countText(draft.beneficiariesFemale);
      _youth.text = _countText(draft.beneficiariesYouth);
      _impact.text = draft.impactDescription;
      _challenges.text = draft.challengesFaced;
      _recommendations.text = draft.recommendations;
      _nextSteps.text = draft.nextSteps;
    }
    if (!_projectPreselected) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadProjects());
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _title,
      _description,
      _amountSpent,
      _expenditureNotes,
      _reached,
      _male,
      _female,
      _youth,
      _impact,
      _challenges,
      _recommendations,
      _nextSteps,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  static String _countText(int value) => value > 0 ? '$value' : '';

  /// Parse a count field; blank means "not recorded", i.e. zero.
  static int _count(TextEditingController controller) =>
      int.tryParse(controller.text.trim()) ?? 0;

  /// Load the selected project's phases and milestones for the link
  /// pickers. Failure is silent: the links are optional, so the step
  /// degrades to "no phases recorded" rather than blocking the report.
  Future<void> _loadLinkTargets() async {
    final projectId = _projectId;
    if (projectId == null || _linksLoadedFor == projectId) return;
    _linksLoadedFor = projectId;
    setState(() {
      _phases = null;
      _milestones = null;
    });
    final repo = context.read<ProjectRepository>();
    try {
      final phases = await repo.phases(projectId);
      final milestones = await repo.milestones(projectId);
      if (!mounted) return;
      setState(() {
        _phases = phases;
        _milestones = milestones;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() {
        _phases = const [];
        _milestones = const [];
      });
    }
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
    if (_step == _activityStep) {
      if (!(_activityFormKey.currentState?.validate() ?? false)) return;
      // Mirrors the server's cross-field rule so an officer is told here
      // rather than by a 400 four steps later.
      final error = _beneficiaryError();
      if (error != null) {
        _toast(error);
        return;
      }
    }
    if (_step < _stepLabels.length - 1) {
      setState(() => _step++);
      if (_step == _activityStep) _loadLinkTargets();
    }
  }

  /// The backend rejects a gender split wider than the total reached, and a
  /// youth count above it; returns the message to show, or null when valid.
  String? _beneficiaryError() {
    final reached = _count(_reached);
    if (_count(_male) + _count(_female) > reached) {
      return 'Male plus female cannot exceed the total reached.';
    }
    if (_count(_youth) > reached) {
      return 'Youth cannot exceed the total reached.';
    }
    return null;
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
      activityType: _activityType,
      linkedPhaseId: _linkedPhaseId,
      linkedMilestoneId: _linkedMilestoneId,
      amountSpent: _amountSpent.text.trim(),
      expenditureNotes: _expenditureNotes.text.trim(),
      beneficiariesReached: _count(_reached),
      beneficiariesMale: _count(_male),
      beneficiariesFemale: _count(_female),
      beneficiariesYouth: _count(_youth),
      impactDescription: _impact.text.trim(),
      challengesFaced: _challenges.text.trim(),
      recommendations: _recommendations.text.trim(),
      nextSteps: _nextSteps.text.trim(),
    ));
    if (!mounted) return;
    showSuccessSnackBar(context, 'Draft saved on this device.');
    Navigator.of(context).pop(true);
  }

  /// Send the report to the server; on success any local draft it came
  /// from is deleted.
  ///
  /// The three server calls (create → upload photos → submit) are made
  /// idempotent so a retry after a mid-way failure resumes rather than
  /// duplicates: the report is created only once ([_createdReportId]) and
  /// each photo is uploaded only once ([_uploadedPhotoPaths]).
  Future<void> _submit() async {
    setState(() => _busy = true);
    final repo = context.read<ReportRepository>();
    final store = context.read<DraftStore>();
    try {
      // Create the report only if a previous attempt hasn't already. The
      // id is captured before the loop so a failed upload/submit leaves it
      // set for the next try. (If createReport itself throws, the field
      // stays null and a retry correctly creates the report.)
      final reportId = _createdReportId ??= await repo.createReport(
        projectId: _projectId!,
        title: _title.text.trim(),
        reportType: _reportType,
        description: _description.text.trim(),
        latitude: _lat,
        longitude: _lng,
        activityType: _activityType,
        linkedPhaseId: _linkedPhaseId,
        linkedMilestoneId: _linkedMilestoneId,
        amountSpent: _amountSpent.text.trim(),
        expenditureNotes: _expenditureNotes.text.trim(),
        beneficiariesReached: _count(_reached),
        beneficiariesMale: _count(_male),
        beneficiariesFemale: _count(_female),
        beneficiariesYouth: _count(_youth),
        impactDescription: _impact.text.trim(),
        challengesFaced: _challenges.text.trim(),
        recommendations: _recommendations.text.trim(),
        nextSteps: _nextSteps.text.trim(),
      );
      var skippedPhotos = 0;
      for (final photo in _photos) {
        // Already sent on an earlier attempt — don't post it twice.
        if (_uploadedPhotoPaths.contains(photo.path)) continue;
        final bytes = await _readPhotoBytes(photo);
        // The OS can evict a resumed draft's picked files from cache; that
        // read fails with a filesystem error, not an ApiException, so it
        // would otherwise escape the handler and abort a valid submission.
        // Skip the missing photo and carry on.
        if (bytes == null) {
          skippedPhotos++;
          continue;
        }
        await repo.uploadImage(reportId, bytes: bytes, filename: photo.name);
        _uploadedPhotoPaths.add(photo.path);
      }
      await repo.submit(reportId);
      final draftId = widget.draft?.id;
      if (draftId != null) await store.delete(draftId);
      if (!mounted) return;
      showSuccessSnackBar(
        context,
        skippedPhotos == 0
            ? 'Report submitted successfully!'
            : 'Report submitted. $skippedPhotos photo(s) were no longer '
                'available on this device and were skipped.',
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Read a picked photo's bytes, returning null if the file is no longer
  /// readable (e.g. the OS cleared the picker cache under a resumed draft).
  Future<Uint8List?> _readPhotoBytes(XFile photo) async {
    try {
      return await photo.readAsBytes();
    } catch (_) {
      return null;
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
                  1 => _buildActivity(),
                  2 => _buildImpact(),
                  3 => _buildLocation(),
                  4 => _buildPhotos(),
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
          else if (_projects == null)
            const InputDecorator(
              decoration: InputDecoration(
                labelText: 'Project',
                prefixIcon: Icon(Icons.work_outline),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text('Loading projects…'),
                ],
              ),
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

  // ── Step 2: Activity ─────────────────────────────────────────────────

  Widget _buildActivity() {
    return Form(
      key: _activityFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionLabel(
            'What was done',
            hint: 'Optional — used for donor reporting.',
          ),
          DropdownButtonFormField<String>(
            key: const Key('activity_type'),
            initialValue: _activityType.isEmpty ? null : _activityType,
            decoration: const InputDecoration(
              labelText: 'Activity type',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: [
              for (final type in ReportActivityType.all)
                DropdownMenuItem(
                  value: type.value,
                  // No Flexible/Expanded here: a dropdown measures its items
                  // under unbounded width, where a flexed child asserts.
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(type.icon, size: 18, color: AppColors.muted),
                      const SizedBox(width: 8),
                      Text(type.label),
                    ],
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _activityType = v ?? ''),
          ),
          const SizedBox(height: 16),
          _linkPicker(
            key: const Key('linked_phase'),
            label: 'Project phase',
            icon: Icons.timeline_outlined,
            emptyHint: 'No phases recorded for this project',
            value: _linkedPhaseId,
            loading: _phases == null,
            items: [
              for (final phase in _phases ?? const <ProjectPhase>[])
                DropdownMenuItem(
                  value: phase.id,
                  child: Text(phase.phaseName, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => _linkedPhaseId = v),
          ),
          const SizedBox(height: 16),
          _linkPicker(
            key: const Key('linked_milestone'),
            label: 'Milestone completed',
            icon: Icons.flag_outlined,
            emptyHint: 'No milestones recorded for this project',
            value: _linkedMilestoneId,
            loading: _milestones == null,
            items: [
              for (final milestone in _milestones ?? const <Milestone>[])
                DropdownMenuItem(
                  value: milestone.id,
                  child: Text(milestone.title, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => _linkedMilestoneId = v),
          ),
          if (_linkedMilestoneId != null)
            _NoteLine(
              'This milestone is marked complete when a manager approves '
              'the report.',
            ),
          const SizedBox(height: 24),
          _SectionLabel(
            'What it cost',
            hint: 'Counts towards the phase budget once approved.',
          ),
          BlurValidatedTextField(
            key: const Key('amount_spent'),
            controller: _amountSpent,
            // Rebuild so the "select a phase" note appears as soon as an
            // amount is typed.
            onChanged: (_) => setState(() {}),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount spent',
              prefixText: 'KES ',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
            validator: (v) {
              final text = (v ?? '').trim();
              if (text.isEmpty) return null;
              final amount = double.tryParse(text);
              if (amount == null) return 'Enter a number';
              if (amount < 0) return 'Cannot be negative';
              return null;
            },
          ),
          // Spend is aggregated per phase, so an amount with no phase
          // selected is recorded on the report but never reaches the
          // project's budget figures. Say so rather than let it vanish.
          if (_amountSpent.text.trim().isNotEmpty && _linkedPhaseId == null)
            _NoteLine(
              'Select a project phase above, or this spend will not count '
              'towards the project budget.',
            ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _expenditureNotes,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Expenditure notes',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),
          _SectionLabel(
            'Who it reached',
            hint: 'Male + female cannot exceed the total; youth is a subset.',
          ),
          BlurValidatedTextField(
            key: const Key('beneficiaries_reached'),
            controller: _reached,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'People reached',
              prefixIcon: Icon(Icons.groups_outlined),
            ),
            validator: _countValidator,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: BlurValidatedTextField(
                  key: const Key('beneficiaries_male'),
                  controller: _male,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Male'),
                  validator: _countValidator,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: BlurValidatedTextField(
                  key: const Key('beneficiaries_female'),
                  controller: _female,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Female'),
                  validator: _countValidator,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: BlurValidatedTextField(
                  key: const Key('beneficiaries_youth'),
                  controller: _youth,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Youth'),
                  validator: _countValidator,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String? _countValidator(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final count = int.tryParse(text);
    if (count == null) return 'Whole number';
    if (count < 0) return 'Cannot be negative';
    return null;
  }

  /// Dropdown that copes with the three states a link list can be in:
  /// still loading, empty for this project, or populated.
  Widget _linkPicker({
    required Key key,
    required String label,
    required IconData icon,
    required String emptyHint,
    required int? value,
    required bool loading,
    required List<DropdownMenuItem<int>> items,
    required ValueChanged<int?> onChanged,
  }) {
    if (loading) {
      return InputDecorator(
        decoration:
            InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Loading…'),
          ],
        ),
      );
    }
    if (items.isEmpty) {
      return InputDecorator(
        decoration:
            InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        child: Text(emptyHint,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.muted)),
      );
    }
    return DropdownButtonFormField<int>(
      key: key,
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        // Nothing selected is a valid answer, so offer a way back to it.
        suffixIcon: value == null
            ? null
            : IconButton(
                icon: const Icon(Icons.clear, size: 18),
                tooltip: 'Clear',
                onPressed: () => onChanged(null),
              ),
      ),
      items: items,
      onChanged: onChanged,
    );
  }

  // ── Step 3: Impact ───────────────────────────────────────────────────

  Widget _buildImpact() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(
          'The story behind the numbers',
          hint: 'These sections are quoted in donor reports.',
        ),
        _narrativeField(
          key: const Key('impact_description'),
          controller: _impact,
          label: 'Impact observed',
          hint: 'What changed for the people you worked with?',
        ),
        const SizedBox(height: 16),
        _narrativeField(
          key: const Key('challenges_faced'),
          controller: _challenges,
          label: 'Challenges faced',
          hint: 'What got in the way?',
        ),
        const SizedBox(height: 16),
        _narrativeField(
          key: const Key('recommendations'),
          controller: _recommendations,
          label: 'Recommendations',
          hint: 'What should change next time?',
        ),
        const SizedBox(height: 16),
        _narrativeField(
          key: const Key('next_steps'),
          controller: _nextSteps,
          label: 'Next steps',
          hint: 'What happens after this activity?',
        ),
      ],
    );
  }

  Widget _narrativeField({
    required Key key,
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: true,
      ),
    );
  }

  // ── Step 4: Location ─────────────────────────────────────────────────

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

  // ── Step 5: Photos ───────────────────────────────────────────────────

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

  // ── Step 6: Review ───────────────────────────────────────────────────

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
                _reviewRow('Activity', ReportActivityType.labelFor(_activityType)),
                if (_linkedPhaseId != null)
                  _reviewRow('Phase', _nameOfPhase(_linkedPhaseId!)),
                if (_linkedMilestoneId != null)
                  _reviewRow('Milestone', _nameOfMilestone(_linkedMilestoneId!)),
                if (_amountSpent.text.trim().isNotEmpty)
                  _reviewRow('Spent', 'KES ${_amountSpent.text.trim()}'),
                if (_count(_reached) > 0)
                  _reviewRow('Reached', _reachSummary()),
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

  /// "300 (140 male · 160 female · 90 youth)" — only the parts recorded.
  String _reachSummary() {
    final parts = <String>[
      if (_count(_male) > 0) '${_count(_male)} male',
      if (_count(_female) > 0) '${_count(_female)} female',
      if (_count(_youth) > 0) '${_count(_youth)} youth',
    ];
    final total = '${_count(_reached)} people';
    return parts.isEmpty ? total : '$total (${parts.join(' · ')})';
  }

  String _nameOfPhase(int id) {
    for (final phase in _phases ?? const <ProjectPhase>[]) {
      if (phase.id == id) return phase.phaseName;
    }
    return 'Phase $id';
  }

  String _nameOfMilestone(int id) {
    for (final milestone in _milestones ?? const <Milestone>[]) {
      if (milestone.id == id) return milestone.title;
    }
    return 'Milestone $id';
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

// ── Small form furniture ──────────────────────────────────────────────────

/// Heading that groups a set of related fields, with an optional hint
/// explaining what the group is for.
class _SectionLabel extends StatelessWidget {
  final String title;
  final String? hint;
  const _SectionLabel(this.title, {this.hint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.primary,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(hint!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.muted)),
          ],
        ],
      ),
    );
  }
}

/// Inline consequence note, e.g. what approving the report will do.
class _NoteLine extends StatelessWidget {
  final String text;
  const _NoteLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 14, color: AppColors.muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.muted)),
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

class _PhotoSlot extends StatefulWidget {
  final XFile file;
  final VoidCallback onRemove;
  const _PhotoSlot({required this.file, required this.onRemove});

  @override
  State<_PhotoSlot> createState() => _PhotoSlotState();
}

class _PhotoSlotState extends State<_PhotoSlot> {
  // Read the bytes once. Building the future inline in build() would make
  // the FutureBuilder re-subscribe on every rebuild — an infinite rebuild
  // loop, since each completion triggers the next rebuild.
  late final Future<Uint8List> _bytes = widget.file.readAsBytes();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        FutureBuilder(
          future: _bytes,
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
            onTap: widget.onRemove,
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
