import 'package:just_audio/just_audio.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class PlayerService {
  final AudioPlayer _player = AudioPlayer();
  final Dio _dio = Dio();

  AudioPlayer get player => _player;

  /// Play direct audio stream online
  Future<void> playOnlineStream(String streamUrl) async {
    await _player.setUrl(streamUrl);
    _player.play();
  }

  /// Download stream to device local storage for offline playback
  Future<String> downloadTrackForOffline(String streamUrl, String trackId) async {
    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/$trackId.m4a';

    await _dio.download(streamUrl, filePath);
    return filePath;
  }

  /// Play locally downloaded track
  Future<void> playOfflineFile(String filePath) async {
    await _player.setFilePath(filePath);
    _player.play();
  }

  void dispose() {
    _player.dispose();
  }
}