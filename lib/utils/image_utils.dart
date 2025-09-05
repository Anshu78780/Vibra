/// Utility functions for handling image URLs and quality enhancement
class ImageUtils {
  /// Enhance Google User Content (googleusercontent.com) image URLs to higher quality
  /// 
  /// Replaces low quality parameters like =w120-h120-l90-rj with high quality =w500-h500
  /// 
  /// Example:
  /// Input:  https://lh3.googleusercontent.com/q5PWa2JVJApX31A7QU2vE4RY8i5S_ofYbfpxgDjhz5fagMAxv8ROkEpUr2OAYgYrhzYqJpv0bV94DRCb=w120-h120-l90-rj
  /// Output: https://lh3.googleusercontent.com/q5PWa2JVJApX31A7QU2vE4RY8i5S_ofYbfpxgDjhz5fagMAxv8ROkEpUr2OAYgYrhzYqJpv0bV94DRCb=w500-h500
  static String enhanceImageQuality(String imageUrl, {int size = 500}) {
    if (imageUrl.isEmpty) return imageUrl;
    
    // Check if it's a googleusercontent.com URL
    if (imageUrl.contains('googleusercontent.com')) {
      // Find the last '=' in the URL which typically starts the image parameters
      final int lastEquals = imageUrl.lastIndexOf('=');
      
      if (lastEquals != -1) {
        // Extract the base URL (everything before the last '=')
        final String baseUrl = imageUrl.substring(0, lastEquals + 1);
        
        // Replace with high quality parameters
        return '${baseUrl}w$size-h$size';
      }
    }
    
    // Return original URL if it's not a googleusercontent URL or doesn't have parameters
    return imageUrl;
  }
  
  /// Get multiple quality versions of an image URL
  static Map<String, String> getImageQualityVariants(String imageUrl) {
    return {
      'thumbnail': enhanceImageQuality(imageUrl, size: 300),
      'medium': enhanceImageQuality(imageUrl, size: 500),
      'high': enhanceImageQuality(imageUrl, size: 800),
      'original': imageUrl,
    };
  }
}
