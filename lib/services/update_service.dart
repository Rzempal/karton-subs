// update_service.dart v0.001 OTA update service (adapted from APPteczka)

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ota_update/ota_update.dart';
import '../config/app_config.dart';

/// Service for checking and installing OTA updates.
/// versionCode: Major*10^9 + Minor*10^8 + Patch (yyMMDDcc)
class UpdateService extends ChangeNotifier {
  String? _currentVersion;
  String? _currentVersionName; // Full version like 0.1.26032500
  String? _latestVersion;
  int? _latestVersionCode;
  String? _apkUrl;
  String? _releaseNotes;
  List<Map<String, String>> _changelog = [];
  bool _updateAvailable = false;
  double _downloadProgress = 0.0;
  UpdateStatus _status = UpdateStatus.idle;
  String? _errorMessage;
  DateTime? _lastCheckTime;
  bool _isUpToDate = false;
  bool _showInstallerHint = false;
  Timer? _installerHintTimer;

  // Getters
  String? get currentVersion => _currentVersion;
  String? get currentVersionName => _currentVersionName;
  String? get latestVersion => _latestVersion;
  int? get latestVersionCode => _latestVersionCode;
  String? get releaseNotes => _releaseNotes;
  List<Map<String, String>> get changelog => _changelog;
  bool get updateAvailable => _updateAvailable;
  double get downloadProgress => _downloadProgress;
  UpdateStatus get status => _status;
  String? get errorMessage => _errorMessage;
  DateTime? get lastCheckTime => _lastCheckTime;
  bool get isUpToDate => _isUpToDate;
  bool get showInstallerHint => _showInstallerHint;

  /// Initialize and load current app version, then check for updates
  Future<void> init() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _currentVersion = packageInfo.buildNumber;
      _currentVersionName = packageInfo.version;
      notifyListeners();

      await checkForUpdate();
    } catch (e) {
      debugPrint('UpdateService init error: $e');
    }
  }

  /// Check for updates by fetching version.json from server
  Future<bool> checkForUpdate() async {
    _status = UpdateStatus.checking;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.get(Uri.parse(AppConfig.versionJsonUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _latestVersion = data['version'] as String?;
        _apkUrl = data['apkUrl'] as String?;
        _releaseNotes = data['releaseNotes'] as String?;

        // Parse cumulative changelog, filter entries newer than current version
        _changelog = [];
        final changelogRaw = data['changelog'] as List<dynamic>?;
        if (changelogRaw != null && _currentVersionName != null) {
          for (final entry in changelogRaw) {
            final version = entry['version'] as String? ?? '';
            final notes = entry['notes'] as String? ?? '';
            if (version == _currentVersionName) break;
            if (notes.isNotEmpty) {
              _changelog.add({'version': version, 'notes': notes});
            }
          }
        }

        _latestVersionCode = data['versionCode'] as int?;

        if (_latestVersionCode != null && _currentVersion != null) {
          final currentCode = int.tryParse(_currentVersion!) ?? 0;
          _updateAvailable = _latestVersionCode! > currentCode;
          _isUpToDate = !_updateAvailable;
        }

        _lastCheckTime = DateTime.now();
        _status = UpdateStatus.idle;
        notifyListeners();
        return _updateAvailable;
      } else {
        _errorMessage = 'Błąd serwera: ${response.statusCode}';
        _status = UpdateStatus.error;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Błąd połączenia: $e';
      _status = UpdateStatus.error;
      notifyListeners();
      return false;
    }
  }

  /// Start downloading and installing the update
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
                  _downloadProgress =
                      double.tryParse(event.value ?? '0') ?? 0;
                  _status = UpdateStatus.downloading;
                  notifyListeners();
                  break;
                case OtaStatus.INSTALLING:
                  _status = UpdateStatus.launchingInstaller;
                  _showInstallerHint = false;
                  _installerHintTimer?.cancel();
                  _installerHintTimer = Timer(const Duration(seconds: 5), () {
                    _showInstallerHint = true;
                    notifyListeners();
                  });
                  notifyListeners();
                  break;
                case OtaStatus.INSTALLATION_DONE:
                  _status = UpdateStatus.idle;
                  notifyListeners();
                  break;
                case OtaStatus.ALREADY_RUNNING_ERROR:
                  _errorMessage = 'Aktualizacja już w toku';
                  _status = UpdateStatus.error;
                  notifyListeners();
                  break;
                case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
                  _errorMessage = 'Brak uprawnień do instalacji';
                  _status = UpdateStatus.error;
                  notifyListeners();
                  break;
                case OtaStatus.INTERNAL_ERROR:
                  _errorMessage = 'Błąd wewnętrzny: ${event.value}';
                  _status = UpdateStatus.error;
                  notifyListeners();
                  break;
                case OtaStatus.DOWNLOAD_ERROR:
                  _errorMessage = 'Błąd pobierania: ${event.value}';
                  _status = UpdateStatus.error;
                  notifyListeners();
                  break;
                case OtaStatus.CHECKSUM_ERROR:
                  _errorMessage = 'Błąd sumy kontrolnej';
                  _status = UpdateStatus.error;
                  notifyListeners();
                  break;
                case OtaStatus.INSTALLATION_ERROR:
                  _errorMessage = 'Błąd instalacji: ${event.value}';
                  _status = UpdateStatus.error;
                  notifyListeners();
                  break;
                case OtaStatus.CANCELED:
                  _errorMessage = 'Pobieranie anulowane';
                  _status = UpdateStatus.error;
                  notifyListeners();
                  break;
              }
            },
            onError: (e) {
              _errorMessage = 'Błąd: $e';
              _status = UpdateStatus.error;
              notifyListeners();
            },
          );
    } catch (e) {
      _errorMessage = 'Błąd uruchomienia aktualizacji: $e';
      _status = UpdateStatus.error;
      notifyListeners();
    }
  }

  /// Reset update state
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

enum UpdateStatus { idle, checking, downloading, launchingInstaller, error }
