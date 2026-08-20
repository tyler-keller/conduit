import 'package:checks/checks.dart';
import 'package:conduit/features/hermes/models/hermes_capabilities.dart';
import 'package:flutter_test/flutter_test.dart';

/// `audioTranscription` gates server-side dictation against Hermes, and is
/// fail-closed so a server predating the endpoint keeps voice input on device.
void main() {
  group('HermesCapabilities.audioTranscription', () {
    test('defaults to false when discovery says nothing', () {
      check(HermesCapabilities.fromJson(const {}).audioTranscription).isFalse();
      check(HermesCapabilities.enabledByDefault.audioTranscription).isFalse();
    });

    test('is enabled by the audio_api feature flag', () {
      final capabilities = HermesCapabilities.fromJson(const {
        'features': {'audio_api': true},
      });
      check(capabilities.audioTranscription).isTrue();
    });

    test('is enabled by a top-level audio_api flag', () {
      final capabilities = HermesCapabilities.fromJson(const {
        'audio_api': true,
      });
      check(capabilities.audioTranscription).isTrue();
    });

    test('is enabled by an advertised transcription endpoint', () {
      final capabilities = HermesCapabilities.fromJson(const {
        'endpoints': {
          'audio_transcriptions': {
            'method': 'POST',
            'path': '/v1/audio/transcriptions',
          },
        },
      });
      check(capabilities.audioTranscription).isTrue();
    });

    test('treats an explicit false as authoritative over a stale endpoint', () {
      final capabilities = HermesCapabilities.fromJson(const {
        'features': {'audio_api': false},
        'endpoints': {
          'audio_transcriptions': {'path': '/v1/audio/transcriptions'},
        },
      });
      check(capabilities.audioTranscription).isFalse();
    });

    test('ignores a malformed endpoint entry', () {
      final capabilities = HermesCapabilities.fromJson(const {
        'endpoints': {'audio_transcriptions': 42},
      });
      check(capabilities.audioTranscription).isFalse();
    });

    test('does not disturb the optimistic management defaults', () {
      final capabilities = HermesCapabilities.fromJson(const {
        'features': {'audio_api': true},
      });
      check(capabilities.sessions).isTrue();
      check(capabilities.skills).isTrue();
      check(capabilities.inputImages).isFalse();
    });
  });
}
