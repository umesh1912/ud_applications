import 'dart:async';
import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:phone_state/phone_state.dart';
import 'package:record/record.dart';
import 'package:ud_core/ud_core.dart' show udStampName;

import 'store.dart';

/// Keys shared between the app and the call service (FlutterForegroundTask data).
class K {
  static const dir = 'dir';
  static const speaker = 'speaker';
  static const source = 'source';
  static const manual = 'manual';
  static const tReady = 't_ready';
  static const tRecording = 't_recording';
  static const tIn = 't_in';
  static const tOut = 't_out';
}

/// Microphone sources offered in settings. Phones differ in which one
/// still hears the call, so the user can switch if recordings are silent.
const sources = {
  'mic': AndroidAudioSource.mic,
  'recognition': AndroidAudioSource.voiceRecognition,
  'camcorder': AndroidAudioSource.camcorder,
};

RecordConfig recordConfig({String source = 'mic', bool speaker = false}) => RecordConfig(
      encoder: AudioEncoder.aacLc,
      bitRate: 64000,
      sampleRate: 44100,
      numChannels: 1,
      androidConfig: AndroidRecordConfig(
        audioSource: sources[source] ?? AndroidAudioSource.mic,
        manageBluetooth: false,
        speakerphone: speaker,
      ),
    );

/// Starts and stops the "watch for calls" foreground service from the app.
class CallService {
  static void init() => FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'call_watch',
          channelName: 'Call recording',
          channelImportance: NotificationChannelImportance.LOW,
          priority: NotificationPriority.LOW,
        ),
        iosNotificationOptions: const IOSNotificationOptions(),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.nothing(),
          // Android does not let a microphone service start at boot.
          autoRunOnBoot: false,
          allowWakeLock: true,
        ),
      );

  static Future<bool> get running => FlutterForegroundTask.isRunningService;

  static Future<bool> start({required String title, required String text, required String stop}) async {
    final r = await FlutterForegroundTask.startService(
      serviceId: 7101,
      serviceTypes: [ForegroundServiceTypes.microphone],
      notificationTitle: title,
      notificationText: text,
      notificationButtons: [NotificationButton(id: 'stop', text: stop)],
      callback: startCallService,
    );
    return r is ServiceRequestSuccess;
  }

  static Future<void> stop() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }
}

@pragma('vm:entry-point')
void startCallService() => FlutterForegroundTask.setTaskHandler(CallWatchHandler());

/// Runs in the service: listens to the phone state and records each call
/// from the moment it connects until it ends.
class CallWatchHandler extends TaskHandler {
  StreamSubscription<PhoneState>? _sub;
  final _rec = AudioRecorder();
  final _clock = Stopwatch();

  String? _id;
  DateTime? _started;
  bool _incoming = false;
  String? _number;

  Future<T?> _get<T>(String key) => FlutterForegroundTask.getData<T>(key: key);

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _sub = PhoneState.stream.listen(_onPhone);
  }

  Future<void> _onPhone(PhoneState s) async {
    switch (s.status) {
      case PhoneStateStatus.CALL_INCOMING:
        if (_id == null) {
          _incoming = true;
          _number = s.number ?? _number;
        }
      case PhoneStateStatus.CALL_OUTGOING:
        if (_id == null) _incoming = false;
      case PhoneStateStatus.CALL_STARTED:
        if (_id == null) await _begin(s.number);
      case PhoneStateStatus.CALL_ENDED:
        await _finish();
        _incoming = false;
        _number = null;
      case PhoneStateStatus.NOTHING:
        break;
    }
  }

  Future<void> _begin(String? number) async {
    // Claim the slot first: the phone state can repeat while we start.
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    _id = id;
    _number = number ?? _number;
    final dir = await _get<String>(K.dir);
    final manual = await _get<bool>(K.manual) ?? false;
    if (dir == null || manual) {
      // Nowhere to save, or the user is already recording by hand.
      _id = manual ? 'skip' : null;
      return;
    }
    try {
      await _rec.start(
        recordConfig(
          source: await _get<String>(K.source) ?? 'mic',
          speaker: await _get<bool>(K.speaker) ?? false,
        ),
        path: audioPath(dir, id),
      );
      _started = DateTime.now();
      _clock
        ..reset()
        ..start();
      FlutterForegroundTask.updateService(
        notificationText: await _get<String>(K.tRecording) ?? 'Recording call…',
      );
    } catch (_) {
      _id = null;
    }
  }

  Future<void> _finish() async {
    final id = _id;
    _id = null;
    if (id == null || id == 'skip') return;
    _clock.stop();
    final dir = await _get<String>(K.dir);
    String? path;
    try {
      path = await _rec.stop();
    } catch (_) {}
    FlutterForegroundTask.updateService(
      notificationText: await _get<String>(K.tReady) ?? 'Ready to record calls',
    );
    if (dir == null) return;
    final file = File(path ?? audioPath(dir, id));
    if (!await file.exists()) return;
    if (_clock.elapsed < const Duration(seconds: 1)) {
      await file.delete();
      return;
    }
    final prefix = await _get<String>(_incoming ? K.tIn : K.tOut) ?? (_incoming ? 'Incoming call' : 'Outgoing call');
    await writeMeta(
      dir,
      Recording(
        id: id,
        name: udStampName(prefix),
        kind: _incoming ? RecKind.incoming : RecKind.outgoing,
        started: _started ?? DateTime.now(),
        duration: _clock.elapsed,
        number: _number,
      ),
    );
    FlutterForegroundTask.sendDataToMain('changed');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'stop') FlutterForegroundTask.stopService();
  }

  @override
  void onNotificationPressed() => FlutterForegroundTask.launchApp();

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _finish();
    await _sub?.cancel();
    await _rec.dispose();
  }
}
