import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/api_exception.dart';
import '../../../shared/widgets/blur_validated_text_field.dart';
import '../report_repository.dart';

class SubmitReportScreen extends StatefulWidget {
  final int projectId;
  final String projectName;

  const SubmitReportScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<SubmitReportScreen> createState() => _SubmitReportScreenState();
}

class _SubmitReportScreenState extends State<SubmitReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  String _reportType = 'daily';
  double? _lat;
  double? _lng;
  final List<XFile> _photos = [];
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
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
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
    } catch (e) {
      _toast('Could not get location: $e');
    }
  }

  Future<void> _pickPhotos() async {
    final picked = await ImagePicker().pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() => _photos.addAll(picked));
    }
  }

  Future<void> _save({required bool submit}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final repo = context.read<ReportRepository>();
    try {
      final reportId = await repo.createReport(
        projectId: widget.projectId,
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
      if (submit) {
        await repo.submit(reportId);
      }
      if (!mounted) return;
      _toast(submit ? 'Report submitted.' : 'Draft saved.');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submit Report')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(widget.projectName,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              BlurValidatedTextField(
                key: const Key('report_title'),
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: const Key('report_type'),
                initialValue: _reportType,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'daily', child: Text('Daily')),
                  DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                ],
                onChanged: (v) => setState(() => _reportType = v ?? 'daily'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _description,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 16),
              // GPS capture
              Card(
                child: ListTile(
                  leading: const Icon(Icons.my_location),
                  title: Text(_lat == null
                      ? 'Capture GPS location'
                      : 'Lat: ${_lat!.toStringAsFixed(5)}, '
                          'Lng: ${_lng!.toStringAsFixed(5)}'),
                  trailing: TextButton(
                    onPressed: _captureGps,
                    child: Text(_lat == null ? 'Capture' : 'Update'),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Photos
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickPhotos,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: const Text('Add photos'),
                  ),
                  const SizedBox(width: 12),
                  Text('${_photos.length} selected'),
                ],
              ),
              if (_photos.isNotEmpty)
                SizedBox(
                  height: 88,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _photos.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) => _Thumb(
                      file: _photos[i],
                      onRemove: () => setState(() => _photos.removeAt(i)),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => _save(submit: false),
                      child: const Text('Save draft'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const Key('submit_button'),
                      onPressed: _busy ? null : () => _save(submit: true),
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Submit'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final XFile file;
  final VoidCallback onRemove;
  const _Thumb({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FutureBuilder(
          future: file.readAsBytes(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                  width: 88, height: 88, child: ColoredBox(color: Colors.black12));
            }
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(snapshot.data!,
                  width: 88, height: 88, fit: BoxFit.cover),
            );
          },
        ),
        Positioned(
          right: 0,
          top: 0,
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
