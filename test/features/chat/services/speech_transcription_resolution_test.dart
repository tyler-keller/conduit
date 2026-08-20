import 'dart:async';

import 'package:checks/checks.dart';
import 'package:conduit/core/providers/app_providers.dart';
import 'package:conduit/core/services/speech_transcription_service.dart';
import 'package:conduit/features/chat/services/voice_input_service.dart';
import 'package:conduit/features/hermes/models/hermes_capabilities.dart';
import 'package:conduit/features/hermes/models/hermes_config.dart';
import 'package:conduit/features/hermes/providers/hermes_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression coverage for Hermes-only installs having no server STT:
/// `hasServerStt` was tied to the Open WebUI `ApiService`, so `serverOnly`
/// disabled both branches of `startListening` and left only voice-call mode.
class _FakeHermesConfigController extends HermesConfigController {
  _FakeHermesConfigController(this._config);

  final HermesConfig _config;

  @override
  HermesConfig build() => _config;
}

const _usableHermes = HermesConfig(
  enabled: true,
  baseUrl: 'http://hermes.local:8642/v1',
  apiKey: 'secret',
);

ProviderContainer _container({
  required HermesConfig hermesConfig,
  required AsyncValue<HermesCapabilities> capabilities,
}) {
  final container = ProviderContainer(
    overrides: [
      reviewerModeProvider.overrideWithValue(false),
      activeServerProvider.overrideWith((ref) async => null),
      hermesConfigProvider.overrideWith(
        () => _FakeHermesConfigController(hermesConfig),
      ),
      hermesCapabilitiesProvider.overrideWith(
        (ref) => switch (capabilities) {
          AsyncData(:final value) => Future<HermesCapabilities>.value(value),
          _ => Completer<HermesCapabilities>().future,
        },
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<SpeechTranscriptionService?> _resolve(ProviderContainer container) async {
  await container.read(activeServerProvider.future);
  try {
    await container
        .read(hermesCapabilitiesProvider.future)
        .timeout(const Duration(milliseconds: 100));
  } on TimeoutException {
    // The loading case never completes; that is the state under test.
  }
  return container.read(speechTranscriptionServiceProvider);
}

void main() {
  const audioCapable = HermesCapabilities(audioTranscription: true);
  const audioIncapable = HermesCapabilities();

  test('resolves Hermes for server STT when the server advertises audio', () async {
    final container = _container(
      hermesConfig: _usableHermes,
      capabilities: const AsyncData(audioCapable),
    );

    check(await _resolve(container)).isNotNull();
  });

  test('voice input reports server STT available on a Hermes-only install', () async {
    final container = _container(
      hermesConfig: _usableHermes,
      capabilities: const AsyncData(audioCapable),
    );
    await _resolve(container);

    final service = container.read(voiceInputServiceProvider);
    check(service.hasServerStt).isTrue();
  });

  test('declines when the server does not advertise the audio API', () async {
    final container = _container(
      hermesConfig: _usableHermes,
      capabilities: const AsyncData(audioIncapable),
    );

    check(await _resolve(container)).isNull();
  });

  test('declines while capability discovery is still in flight', () async {
    final container = _container(
      hermesConfig: _usableHermes,
      capabilities: const AsyncLoading(),
    );

    check(await _resolve(container)).isNull();
  });

  test('declines when Hermes is configured but unusable', () async {
    final container = _container(
      hermesConfig: const HermesConfig(
        enabled: true,
        baseUrl: 'http://hermes.local:8642/v1',
      ),
      capabilities: const AsyncData(audioCapable),
    );

    check(await _resolve(container)).isNull();
  });
}
