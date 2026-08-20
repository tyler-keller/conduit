import 'dart:typed_data';

/// Uploads recorded audio to a server for speech-to-text.
///
/// Naming the transport lets voice input depend on "something that
/// transcribes" rather than on the Open WebUI session specifically, so a
/// Hermes-only install still has a server path.
abstract interface class SpeechTranscriptionService {
  Future<Map<String, dynamic>> transcribeSpeech({
    required Uint8List audioBytes,
    String? fileName,
    String? mimeType,
    String? language,
  });
}
