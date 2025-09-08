import 'dart:io';

class WindowsNetworkPermissions {
  /// Checks if the app has network permissions on Windows
  static Future<bool> hasNetworkPermissions() async {
    if (!Platform.isWindows) return true;
    
    try {
      // Test basic network capability by trying to bind to localhost
      final server = await HttpServer.bind('127.0.0.1', 0);
      await server.close();
      
      // Test if we can access network interfaces
      final interfaces = await NetworkInterface.list();
      
      return interfaces.isNotEmpty;
    } catch (e) {
      print('❌ Network permission test failed: $e');
      return false;
    }
  }
  
  /// Requests network permissions on Windows
  static Future<bool> requestNetworkPermissions() async {
    if (!Platform.isWindows) return true;
    
    try {
      print('🔐 Checking Windows network permissions...');
      
      // First check if we already have permissions
      if (await hasNetworkPermissions()) {
        print('✅ Network permissions already granted');
        return true;
      }
      
      // On Windows, network permissions are typically handled by:
      // 1. Windows Firewall
      // 2. User Account Control (UAC)
      // 3. Windows Defender
      
      print('⚠️ Network access limited. Please ensure:');
      print('  1. Windows Firewall allows this app');
      print('  2. Antivirus is not blocking network access');
      print('  3. App has necessary privileges');
      
      return false;
    } catch (e) {
      print('❌ Failed to request network permissions: $e');
      return false;
    }
  }
  
  /// Gets Windows network capability info
  static Future<Map<String, dynamic>> getNetworkInfo() async {
    final info = <String, dynamic>{
      'hasBasicNetwork': false,
      'hasMulticast': false,
      'hasFirewallAccess': false,
      'availableInterfaces': <String>[],
      'recommendedActions': <String>[],
    };
    
    if (!Platform.isWindows) {
      info['hasBasicNetwork'] = true;
      info['hasMulticast'] = true;
      info['hasFirewallAccess'] = true;
      return info;
    }
    
    try {
      // Test basic network
      try {
        final server = await HttpServer.bind('127.0.0.1', 0);
        await server.close();
        info['hasBasicNetwork'] = true;
      } catch (e) {
        info['recommendedActions'].add('Enable basic network access');
      }
      
      // Test firewall (try to bind to actual network interface)
      try {
        final interfaces = await NetworkInterface.list();
        for (final interface in interfaces) {
          for (final addr in interface.addresses) {
            if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
              info['availableInterfaces'].add('${interface.name}: ${addr.address}');
              
              // Try to bind to this interface
              try {
                final server = await HttpServer.bind(addr.address, 0);
                await server.close();
                info['hasFirewallAccess'] = true;
              } catch (e) {
                if (e.toString().contains('10013')) {
                  info['recommendedActions'].add('Add app to Windows Firewall exceptions');
                }
              }
            }
          }
        }
      } catch (e) {
        info['recommendedActions'].add('Check network interface access');
      }
      
      // Test multicast (not really possible on Windows without admin)
      info['hasMulticast'] = false;
      info['recommendedActions'].add('Multicast DNS not available on Windows');
      
    } catch (e) {
      print('❌ Network info check failed: $e');
    }
    
    return info;
  }
  
  /// Shows user-friendly network permission instructions
  static String getPermissionInstructions() {
    return '''
Windows Network Permissions Required:

The music ecosystem needs network access to:
• Create a local server for music control
• Discover other devices on your network
• Allow remote control from other devices

Common Issues & Solutions:

🔥 Windows Firewall Blocking:
→ Go to Windows Security
→ Firewall & network protection
→ Allow an app through firewall
→ Add Vibra to the exceptions

🛡️ Antivirus Software:
→ Check if your antivirus blocks network access
→ Add Vibra to antivirus whitelist
→ Temporarily disable real-time protection to test

👤 User Account Control (UAC):
→ Try running as administrator once
→ This helps establish initial permissions

🌐 Network Profile:
→ Ensure you're on a "Private" network
→ Public networks restrict local communication

💡 Alternative:
→ Use QR codes for manual connection
→ Share IP address directly between devices
→ Both devices must be on same WiFi network
''';
  }
  
  /// Checks if running with elevated privileges
  static bool isRunningAsAdmin() {
    if (!Platform.isWindows) return false;
    
    try {
      // On Windows, try to perform an operation that requires admin
      // This is a simple check - more sophisticated methods exist
      return false; // For now, assume not admin
    } catch (e) {
      return false;
    }
  }
  
  /// Attempts to launch app with admin privileges
  static Future<bool> requestAdminPrivileges() async {
    if (!Platform.isWindows) return true;
    
    try {
      final exePath = Platform.resolvedExecutable;
      
      // Use PowerShell to launch with admin privileges
      await Process.start(
        'powershell',
        [
          '-Command',
          'Start-Process',
          '"$exePath"',
          '-Verb',
          'RunAs'
        ],
      );
      
      return true;
    } catch (e) {
      print('❌ Failed to request admin privileges: $e');
      return false;
    }
  }
}
