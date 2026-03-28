import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ota_update/ota_update.dart';
import '../config/app_config.dart';
import 'app_logger.dart';

enum UpdateStatus { idle, checking, downloading, launchingInstaller, error }

/// OTA update service — port z APPteczka, zaadaptowany dla karton-subs.
class UpdateService extends ChangeNotifier {
  static final _log = AppLogger.get('UpdateService');

  String? _currentVersion;
  String? _currentVersionName;
  String? _latestVersion;
  int? _latestVersionCode;
  String? _apkUrl;
  List<Map<String, String>> _changelog = [];
  bool _updateAvailable = false;
  double _downloadProgress = 0.0;
  UpdateStatus _status = UpdateStatus.idle;
  String? _errorMessage;
  DateTime? _lastCheckTime;
  bool _isUpToDate = false;
  bool _showInstallerHint = false;
  Timer? _installerHintTimer;

  String? get currentVersionName => _currentVersionName;
  String? get latestVersion => _latestVersion;
  List<Map<String, String>> get changelog => _changelog;
  bool get updateAvailable => _updateAvailable;
  double get downloadProgress => _downloadProgress;
  UpdateStatus get status => _status;
  String? get errorMessage => _errorMessage;
  DateTime? get lastCheckTime => _lastCheckTime;
  bool get isUpToDate => _isUpToDate;
  bool get showInstallerHint => _showInstallerHint;

  Future<void> init() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _currentVersion = info.buildNumber;
      _currentVersionName = info.version;
      notifyListeners();
      await checkForUpdate();
    } catch (e) {
      _log.warning('UpdateService init error: $e');
    }
  }

  Future<bool> checkForUpdate() async {
    _status = UpdateStatus.checking;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http
          .get(Uri.parse(AppConfig.versionJsonUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        _latestVersion = data['version'] as String?;
        _apkUrl = data['apkUrl'] as String?;
        _latestVersionCode = data['versionCode'] as int?;

        _changelog = [];
        final changelogRaw = data['changelog'] as List<dynamic>?;
        if (changelogRaw != null && _currentVersionName != null) {
          for (final entry in changelogRaw) {
            final version = entry['version'] as String? ?? '';
            final notes = entry['notes'] as String? ?? '';
            if (version == _currentVersionName) break;
            if (notes.isNotEmpty) _changelog.add({'version': version, 'notes': notes});
          }
        }

        if (_latestVersionCode != null && _currentVersion != null) {
          final currentCode = int.tryParse(_currentVersion!) ?? 0;
          _updateAvailable = _latestVersionCode! > currentCode;
          _isUpToDate = !_updateAvailable;
        }

        _lastCheckTime = DateTime.now();
        _status = UpdateStatus.idle;
        notifyListeners();
        _log.info('Update check: available=$_updateAvailable, latest=$_latestVersion');
        return _updateAvailable;
      } else {
        _errorMessage = 'Błąd serwera: ${response.statusCode}';
        _status = UpdateStatus.error;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Błąd połączenia';
      _status = UpdateStatus.error;
      notifyListeners();
      _log.warning('Update check error: $e');
      return false;
    }
  }

  Future<void> startUpdate() async {
    if (_apkUrl == null) {
      _errorMessage = 'Brak URL do pobrania';
      _status = UpdateStatus.error;
      notifyListeners();
      return;
    }

    _status = UpdateStatus.downloading;
    _downloadProgress = 0.0;
    _showInstallerHint = false;
    _installerHintTimer?.cancel();
    notifyListeners();

    try {
      OtaUpdate()
          .execute(_apkUrl!, destinationFilename: 'karton_subs_update.apk')
          .listen(
        (OtaEvent event) {
          switch (event.status) {
            case OtaStatus.DOWNLOADING:
              _downloadProgress = double.tryParse(event.value ?? '0') ?? 0;
              _status = UpdateStatus.downloading;
            case OtaStatus.INSTALLING:
              _status = UpdateStatus.launchingInstaller;
              _installerHintTimer?.cancel();
              _installerHintTimer = Timer(const Duration(seconds: 5), () {
                _showInstallerHint = true;
                notifyListeners();
              });
            case OtaStatus.INSTALLATION_DONE:
              _status = UpdateStatus.idle;
            case OtaStatus.ALREADY_RUNNING_ERROR:
              _errorMessage = 'Aktualizacja już w toku';
              _status = UpdateStatus.error;
            case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
              _errorMessage = 'Brak uprawnień do instalacji';
              _status = UpdateStatus.error;
            case OtaStatus.INTERNAL_ERROR:
              _errorMessage = 'Błąd wewnętrzny: ${event.value}';
              _status = UpdateStatus.error;
            case OtaStatus.DOWNLOAD_ERROR:
              _errorMessage = 'Błąd pobierania: ${event.value}';
              _status = UpdateStatus.error;
            case OtaStatus.CHECKSUM_ERROR:
              _errorMessage = 'Błąd sumy kontrolnej';
              _status = UpdateStatus.error;
            case OtaStatus.INSTALLATION_ERROR:
              _errorMessage = 'Błąd instalacji: ${event.value}';
              _status = UpdateStatus.error;
            case OtaStatus.CANCELED:
              _errorMessage = 'Pobieranie anulowane';
              _status = UpdateStatus.error;
          }
          notifyListeners();
        },
        onError: (e) {
          _errorMessage = 'Błąd: $e';
          _status = UpdateStatus.error;
          notifyListeners();
        },
      );
    } catch (e) {
      _errorMessage = 'Błąd uruchomienia: $e';
      _status = UpdateStatus.error;
      notifyListeners();
    }
  }

  void reset() {
    _updateAvailable = false;
    _downloadProgress = 0.0;
    _status = UpdateStatus.idle;
    _errorMessage = null;
    _showInstallerHint = false;
    _installerHintTimer?.cancel();
    notifyListeners();
  }
}
