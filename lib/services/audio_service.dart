import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class AudioService {
  static final YoutubeExplode _yt = YoutubeExplode();

  static Future<String> getAudioUrl(String videoId) async {
    try {
      print('Getting audio URL for video ID: $videoId');
      
      // Get video manifest
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      
      // Get audio-only streams
      final audioStreams = manifest.audioOnly;
      
      if (audioStreams.isEmpty) {
        throw Exception('No audio streams available for this video');
      }
      
      // Create a mutable copy and sort by quality (highest first)
      final sortedStreams = List.from(audioStreams);
      sortedStreams.sort((a, b) => b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond));
      
      final audioStream = sortedStreams.first;
      print('Selected audio stream: ${audioStream.bitrate}, ${audioStream.audioCodec}');
      
      return audioStream.url.toString();
    } catch (e) {
      print('Error getting audio URL: $e');
      throw Exception('Failed to get audio URL: $e');
    }
  }

  static Future<VideoDetails> getVideoDetails(String videoId) async {
    try {
      print('Getting video details for: $videoId');
      final video = await _yt.videos.get(videoId);
      
      return VideoDetails(
        id: video.id.value,
        title: video.title,
        author: video.author,
        duration: video.duration,
        thumbnailUrl: video.thumbnails.highResUrl,
      );
    } catch (e) {
      print('Error getting video details: $e');
      throw Exception('Failed to get video details: $e');
    }
  }

  static void dispose() {
    _yt.close();
  }
}

class VideoDetails {
  final String id;
  final String title;
  final String author;
  final Duration? duration;
  final String thumbnailUrl;

  VideoDetails({
    required this.id,
    required this.title,
    required this.author,
    this.duration,
    required this.thumbnailUrl,
  });
}
