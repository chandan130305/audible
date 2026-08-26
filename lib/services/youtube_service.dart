import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YouTubeService {
  final _yt = YoutubeExplode();

  /// Fetches video details and direct audio stream URL for playback
  Future<Map<String, String>> getAudioStream(String videoId) async {
    try {
      final video = await _yt.videos.get(videoId);
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      final streamInfo = manifest.audioOnly.withHighestBitrate();

      return {
        'id': videoId,
        'title': video.title,
        'artist': video.author,
        'thumbnail': video.thumbnails.highResUrl,
        'streamUrl': streamInfo.url.toString(),
      };
    } catch (e) {
      throw Exception('Failed to load audio stream: $e');
    }
  }

  void dispose() {
    _yt.close();
  }
}