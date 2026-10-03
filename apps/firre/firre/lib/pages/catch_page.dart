import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../api/api_client.dart';
import '../api/lure.dart';
import '../api/weather.dart';
import '../auth/auth_service.dart';
import '../util/format.dart';
import '../util/location.dart';
import '../widgets/login_prompt.dart';
import 'location_picker_page.dart';

// Photos are scaled down before upload — phone camera originals are often
// 5-10 MB each, which is slow on mobile data and far more than the app and
// web need to show them.
const _maxPhotoSide = 2560.0;
const _photoQuality = 85;

enum _WeatherStatus { idle, loading, filled }

/// Logs a new catch: the same fields as the web app's CatchForm, sent the
/// same way. The location defaults to the phone's position, with a map to
/// adjust it, since there's no map click to start from.
class CatchPage extends StatefulWidget {
  const CatchPage({
    super.key,
    required this.auth,
    required this.api,
    required this.active,
    required this.onSaved,
  });

  final AuthService auth;
  final ApiClient api;

  /// Whether the tab is showing. The GPS lookup waits for it, so the
  /// permission prompt doesn't appear at app start.
  final bool active;

  /// Called after a catch is saved.
  final VoidCallback onSaved;

  @override
  State<CatchPage> createState() => _CatchPageState();
}

class _CatchPageState extends State<CatchPage> {
  final _formKey = GlobalKey<FormState>();
  final _species = TextEditingController();
  final _weight = TextEditingController();
  final _length = TextEditingController();
  final _bait = TextEditingController();
  final _technique = TextEditingController();
  final _waterType = TextEditingController();
  final _airTemp = TextEditingController();
  final _waterTemp = TextEditingController();
  final _windSpeed = TextEditingController();
  final _windDirection = TextEditingController();
  final _pressure = TextEditingController();
  final _notes = TextEditingController();
  late final _allFields = [
    _species, _weight, _length, _bait, _technique, _waterType, //
    _airTemp, _waterTemp, _windSpeed, _windDirection, _pressure, _notes,
  ];

  final _picker = ImagePicker();
  List<XFile> _photos = [];

  // Null means "now", resolved when saving — the tab can stay open for a
  // long time, so a time captured when the form was built would go stale.
  DateTime? _caughtAt;
  String? _cloudCover;
  String? _lureId;
  List<Lure> _lures = [];
  bool _luresLoaded = false;

  LatLng? _location;
  bool _locating = false;
  bool _triedAutoLocate = false;
  String? _locationError;

  _WeatherStatus _weatherStatus = _WeatherStatus.idle;
  // What SMHI last filled in, so a later fetch (after moving the location)
  // can replace those values without touching anything the user typed.
  final _autoFilled = <TextEditingController, String>{};
  String? _autoCloudCover;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  @override
  void didUpdateWidget(CatchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _maybeAutoLocate();
  }

  @override
  void dispose() {
    widget.auth.removeListener(_onAuthChanged);
    for (final c in _allFields) {
      c.dispose();
    }
    super.dispose();
  }

  void _onAuthChanged() {
    if (!widget.auth.isLoggedIn) {
      _luresLoaded = false;
      return;
    }
    if (!_luresLoaded) {
      _luresLoaded = true;
      _loadLures();
    }
    _maybeAutoLocate();
  }

  Future<void> _loadLures() async {
    try {
      final lures = await widget.api.listMyLures();
      if (mounted) setState(() => _lures = lures);
    } catch (e) {
      // Non-critical, as on the web — free-text bait still works.
      debugPrint('catch: loading lures failed: $e');
    }
  }

  void _maybeAutoLocate() {
    if (!widget.active || !widget.auth.isLoggedIn) return;
    if (_location != null || _triedAutoLocate) return;
    _triedAutoLocate = true;
    _useMyLocation();
  }

  Future<void> _useMyLocation() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      final position = await currentPosition();
      _setLocation(LatLng(position.latitude, position.longitude));
    } on LocationException catch (e) {
      if (mounted) setState(() => _locationError = e.message);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _pickOnMap() async {
    final picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(builder: (_) => LocationPickerPage(initial: _location)),
    );
    if (picked != null) _setLocation(picked);
  }

  void _setLocation(LatLng location) {
    if (!mounted) return;
    setState(() {
      _location = location;
      _locationError = null;
    });
    _fillWeather(location);
  }

  Future<void> _fillWeather(LatLng location) async {
    setState(() => _weatherStatus = _WeatherStatus.loading);
    try {
      final w = await widget.api.fetchWeather(
        location.latitude,
        location.longitude,
      );
      if (!mounted || location != _location) return;
      setState(() {
        _autoFill(_airTemp, w.tempC);
        _autoFill(_waterTemp, w.waterTempC);
        _autoFill(_windSpeed, w.windSpeedMs);
        _autoFill(_pressure, w.pressureHpa);
        _autoFillText(_windDirection, w.windDirection);
        if (w.cloudCover != null &&
            (_cloudCover == null || _cloudCover == _autoCloudCover)) {
          _cloudCover = w.cloudCover;
          _autoCloudCover = w.cloudCover;
        }
        _weatherStatus = _WeatherStatus.filled;
      });
    } catch (e) {
      // Non-critical, as on the web — the fields stay editable either way.
      debugPrint('catch: loading weather failed: $e');
      if (mounted) setState(() => _weatherStatus = _WeatherStatus.idle);
    }
  }

  void _autoFill(TextEditingController field, double? value) =>
      _autoFillText(field, value == null ? null : formatNumber(value));

  // Only fills a field the user hasn't typed in — it's empty, or still holds
  // what the previous fetch put there.
  void _autoFillText(TextEditingController field, String? value) {
    if (value == null) return;
    if (field.text.isNotEmpty && field.text != _autoFilled[field]) return;
    field.text = value;
    _autoFilled[field] = value;
  }

  Future<void> _pickCaughtAt() async {
    final now = DateTime.now();
    final current = _caughtAt ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) return;
    setState(() {
      _caughtAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _takePhoto() => _addPhotos(() async {
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: _maxPhotoSide,
      maxHeight: _maxPhotoSide,
      imageQuality: _photoQuality,
    );
    return [?photo];
  }, 'Kunde inte öppna kameran.');

  Future<void> _choosePhotos() => _addPhotos(
    () => _picker.pickMultiImage(
      maxWidth: _maxPhotoSide,
      maxHeight: _maxPhotoSide,
      imageQuality: _photoQuality,
    ),
    'Kunde inte öppna bilderna.',
  );

  Future<void> _addPhotos(
    Future<List<XFile>> Function() pick,
    String errorMessage,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final photos = await pick();
      if (photos.isNotEmpty && mounted) {
        setState(() => _photos = [..._photos, ...photos]);
      }
    } catch (e) {
      debugPrint('catch: picking photos failed: $e');
      messenger.showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    final location = _location;
    if (location == null) {
      setState(() => _error = 'Välj var fångsten gjordes.');
      return;
    }

    // The same multipart fields as handleSubmit in CatchForm.svelte. Numbers
    // go with a decimal point: the backend parses them with Go's ParseFloat
    // and silently drops anything it can't read.
    final fields = <String, String>{
      'species': _species.text.trim(),
      'latitude': location.latitude.toString(),
      'longitude': location.longitude.toString(),
      'caught_at': (_caughtAt ?? DateTime.now()).toUtc().toIso8601String(),
    };
    void put(String key, Object? value) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) fields[key] = text;
    }

    put('weight_grams', _parseInt(_weight.text));
    put('length_cm', _parseDecimal(_length.text));
    put('bait_lure', _bait.text);
    put('lure_id', _lureId);
    put('technique', _technique.text);
    put('water_type', _waterType.text);
    put('notes', _notes.text);
    put('weather_temp_c', _parseDecimal(_airTemp.text));
    put('weather_wind_speed_ms', _parseDecimal(_windSpeed.text));
    put('weather_wind_direction', _windDirection.text);
    put('weather_pressure_hpa', _parseDecimal(_pressure.text));
    put('weather_cloud_cover', _cloudCover);
    put('water_temp_c', _parseDecimal(_waterTemp.text));

    setState(() => _saving = true);
    try {
      await widget.api.createCatch(fields, [for (final p in _photos) p.path]);
      if (!mounted) return;
      _reset();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Fångsten är sparad.')));
      widget.onSaved();
    } on ApiException catch (e) {
      debugPrint('catch: saving failed: $e');
      if (mounted) {
        setState(() {
          _error = e.statusCode == 401
              ? 'Du behöver logga in igen för att spara.'
              : 'Kunde inte spara fångsten.';
        });
      }
    } catch (e) {
      debugPrint('catch: saving failed: $e');
      if (mounted) setState(() => _error = 'Kunde inte spara fångsten.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _reset() {
    for (final c in _allFields) {
      c.clear();
    }
    _formKey.currentState?.reset();
    setState(() {
      _photos = [];
      _caughtAt = null;
      _cloudCover = null;
      _lureId = null;
      _autoFilled.clear();
      _autoCloudCover = null;
      _weatherStatus = _WeatherStatus.idle;
      // Look the position up again for the next catch.
      _location = null;
      _triedAutoLocate = false;
    });
  }

  static double? _parseDecimal(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  static int? _parseInt(String text) => int.tryParse(text.trim());

  static String? Function(String?) _numberValidator({
    bool integer = false,
    bool nonNegative = false,
  }) {
    return (text) {
      if (text == null || text.trim().isEmpty) return null;
      final num? value = integer ? _parseInt(text) : _parseDecimal(text);
      if (value == null) return integer ? 'Ange ett heltal' : 'Ange ett tal';
      if (nonNegative && value < 0) return 'Kan inte vara negativt';
      return null;
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.auth,
      builder: (context, _) {
        if (!widget.auth.isLoggedIn) {
          return LoginPrompt(
            auth: widget.auth,
            message: 'Logga in för att logga en fångst.',
            icon: Icons.phishing,
          );
        }
        return _buildForm(context);
      },
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    const gap = SizedBox(height: 12);
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _buildLocation(context),
          const SizedBox(height: 16),
          TextFormField(
            controller: _species,
            decoration: const InputDecoration(labelText: 'Art *'),
            textCapitalization: TextCapitalization.sentences,
            validator: (text) =>
                text == null || text.trim().isEmpty ? 'Ange art' : null,
          ),
          gap,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _numberField(
                  _weight,
                  'Vikt (g)',
                  integer: true,
                  nonNegative: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _numberField(_length, 'Längd (cm)', nonNegative: true),
              ),
            ],
          ),
          gap,
          InkWell(
            onTap: _pickCaughtAt,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Fångad',
                suffixIcon: Icon(Icons.edit_calendar),
              ),
              child: Text(
                _caughtAt == null ? 'Nu' : formatDateTime(_caughtAt!),
              ),
            ),
          ),
          gap,
          TextFormField(
            controller: _bait,
            decoration: const InputDecoration(labelText: 'Bete / drag'),
          ),
          if (_lures.isNotEmpty) ...[
            gap,
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Från din betesask'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _lureId,
                  isDense: true,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Eget (skriv ovan)'),
                    ),
                    for (final lure in _lures)
                      DropdownMenuItem(value: lure.id, child: Text(lure.title)),
                  ],
                  onChanged: (id) => setState(() {
                    _lureId = id;
                    final lure = _lures.where((l) => l.id == id).firstOrNull;
                    if (lure != null) _bait.text = lure.title;
                  }),
                ),
              ),
            ),
          ],
          gap,
          TextFormField(
            controller: _technique,
            decoration: const InputDecoration(
              labelText: 'Teknik',
              hintText: 'spinn, fluga, trolling…',
            ),
          ),
          gap,
          TextFormField(
            controller: _waterType,
            decoration: const InputDecoration(
              labelText: 'Vattentyp',
              hintText: 'sjö, hav, älv…',
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text('Väder & vatten', style: theme.textTheme.titleMedium),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  switch (_weatherStatus) {
                    _WeatherStatus.loading => 'hämtar från SMHI…',
                    _WeatherStatus.filled => 'ifyllt från SMHI',
                    _WeatherStatus.idle => '',
                  },
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          gap,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _numberField(_airTemp, 'Lufttemp. (°C)')),
              const SizedBox(width: 12),
              Expanded(child: _numberField(_waterTemp, 'Vattentemp. (°C)')),
            ],
          ),
          gap,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _numberField(
                  _windSpeed,
                  'Vind (m/s)',
                  nonNegative: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _windDirection,
                  decoration: const InputDecoration(
                    labelText: 'Vindriktning',
                    hintText: 'NW',
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
              ),
            ],
          ),
          gap,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _numberField(_pressure, 'Lufttryck (hPa)')),
              const SizedBox(width: 12),
              Expanded(
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Molnighet'),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _cloudCover,
                      isDense: true,
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('–')),
                        for (final MapEntry(:key, :value)
                            in cloudCoverLabels.entries)
                          DropdownMenuItem(value: key, child: Text(value)),
                      ],
                      onChanged: (value) => setState(() => _cloudCover = value),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _notes,
            decoration: const InputDecoration(
              labelText: 'Anteckningar',
              alignLabelWithHint: true,
            ),
            textCapitalization: TextCapitalization.sentences,
            minLines: 3,
            maxLines: 6,
          ),
          const SizedBox(height: 24),
          _buildPhotos(context),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(_saving ? 'Sparar…' : 'Spara fångst'),
          ),
        ],
      ),
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label, {
    bool integer = false,
    bool nonNegative = false,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: TextInputType.numberWithOptions(
        decimal: !integer,
        signed: !nonNegative,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          RegExp(integer ? r'[0-9]' : r'[0-9.,\-]'),
        ),
      ],
      validator: _numberValidator(integer: integer, nonNegative: nonNegative),
    );
  }

  Widget _buildLocation(BuildContext context) {
    final theme = Theme.of(context);
    final location = _location;
    final Widget status;
    if (_locating) {
      status = const Row(
        children: [
          SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text('Hämtar din plats…'),
        ],
      );
    } else if (location != null) {
      // Five decimals, like the web form's coordinates line.
      status = Text(
        '${location.latitude.toStringAsFixed(5)}, '
        '${location.longitude.toStringAsFixed(5)}',
        style: theme.textTheme.bodyLarge,
      );
    } else {
      status = Text(
        _locationError ?? 'Ingen plats vald.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: _locationError == null ? null : theme.colorScheme.error,
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Plats *', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            status,
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _locating ? null : _useMyLocation,
                  icon: const Icon(Icons.my_location),
                  label: const Text('Min plats'),
                ),
                OutlinedButton.icon(
                  onPressed: _pickOnMap,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Välj på kartan'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotos(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Bilder', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (_photos.isNotEmpty) ...[
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_photos[i].path),
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: IconButton.filledTonal(
                      visualDensity: VisualDensity.compact,
                      iconSize: 16,
                      tooltip: 'Ta bort',
                      onPressed: () =>
                          setState(() => _photos = [..._photos]..removeAt(i)),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _takePhoto,
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Ta foto'),
            ),
            OutlinedButton.icon(
              onPressed: _choosePhotos,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Välj bilder'),
            ),
          ],
        ),
      ],
    );
  }
}
