import 'dart:io';

class SimpleNetworkInfo {
  static Future<String?> getLocalIP() async {
    try {
      // Get all network interfaces
      final interfaces = await NetworkInterface.list();
      
      // Priority order: WiFi interfaces first, then Ethernet
      final priorityPatterns = [
        'wlan',    // Windows WiFi
        'wifi',    // Generic WiFi
        'en0',     // macOS WiFi
        'eth',     // Ethernet
        'en1',     // macOS Ethernet
      ];
      
      String? fallbackIP;
      
      // First pass: look for preferred interface types
      for (final pattern in priorityPatterns) {
        for (final interface in interfaces) {
          if (interface.name.toLowerCase().contains(pattern)) {
            for (final address in interface.addresses) {
              if (address.type == InternetAddressType.IPv4 && 
                  !address.isLoopback &&
                  _isPrivateIP(address.address)) {
                print('✅ Found IP on ${interface.name}: ${address.address}');
                return address.address;
              }
            }
          }
        }
      }
      
      // Second pass: any private IPv4 address
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (address.type == InternetAddressType.IPv4 && 
              !address.isLoopback &&
              _isPrivateIP(address.address)) {
            if (fallbackIP == null) {
              fallbackIP = address.address;
            }
            print('ℹ️ Available IP on ${interface.name}: ${address.address}');
          }
        }
      }
      
      if (fallbackIP != null) {
        print('✅ Using fallback IP: $fallbackIP');
        return fallbackIP;
      }
      
      print('❌ No suitable IP address found');
      return null;
    } catch (e) {
      print('❌ Failed to get local IP: $e');
      return null;
    }
  }
  
  static bool _isPrivateIP(String ip) {
    // Check if IP is in private address ranges
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    
    try {
      final first = int.parse(parts[0]);
      final second = int.parse(parts[1]);
      
      // 192.168.x.x
      if (first == 192 && second == 168) return true;
      
      // 10.x.x.x
      if (first == 10) return true;
      
      // 172.16.x.x - 172.31.x.x
      if (first == 172 && second >= 16 && second <= 31) return true;
      
      return false;
    } catch (e) {
      return false;
    }
  }
  
  static String? getBaseIP(String ip) {
    final parts = ip.split('.');
    if (parts.length == 4) {
      return '${parts[0]}.${parts[1]}.${parts[2]}';
    }
    return null;
  }
}
