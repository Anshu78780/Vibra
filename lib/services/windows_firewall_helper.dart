import 'dart:io';

class WindowsFirewallHelper {
  /// Checks if the app likely has firewall permissions
  static Future<bool> checkFirewallStatus() async {
    if (!Platform.isWindows) return true;
    
    try {
      // Try to create a simple server to test firewall
      final server = await HttpServer.bind('0.0.0.0', 8080);
      await server.close();
      return true;
    } catch (e) {
      if (e.toString().contains('10013')) {
        // Access denied - likely firewall issue
        return false;
      }
      return true; // Other errors might not be firewall related
    }
  }
  
  /// Shows instructions for adding app to Windows Firewall
  static String getFirewallInstructions() {
    return '''
To allow Vibra through Windows Firewall:

1. Press Windows key + R
2. Type "wf.msc" and press Enter
3. Click "Inbound Rules" in the left panel
4. Click "New Rule..." in the right panel
5. Select "Program" and click Next
6. Select "This program path" and browse to Vibra.exe
7. Select "Allow the connection" and click Next
8. Keep all profiles checked and click Next
9. Name it "Vibra Music" and click Finish

Alternative method:
1. Go to Windows Security
2. Click "Firewall & network protection"
3. Click "Allow an app through firewall"
4. Click "Change settings" (requires admin)
5. Click "Allow another app..."
6. Browse and select Vibra.exe
7. Make sure both Private and Public are checked
8. Click OK
''';
  }
  
  /// Gets the current executable path for firewall rules
  static String? getExecutablePath() {
    try {
      return Platform.resolvedExecutable;
    } catch (e) {
      return null;
    }
  }
  
  /// Attempts to automatically add firewall rule (requires admin)
  static Future<bool> addFirewallRule() async {
    if (!Platform.isWindows) return true;
    
    try {
      final exePath = getExecutablePath();
      if (exePath == null) return false;
      
      // Try to add inbound rule using netsh (requires admin privileges)
      final result = await Process.run('netsh', [
        'advfirewall',
        'firewall',
        'add',
        'rule',
        'name=Vibra Music Server',
        'dir=in',
        'action=allow',
        'program=$exePath',
        'enable=yes'
      ]);
      
      if (result.exitCode == 0) {
        print('✅ Firewall rule added successfully');
        return true;
      } else {
        print('❌ Failed to add firewall rule: ${result.stderr}');
        return false;
      }
    } catch (e) {
      print('❌ Error adding firewall rule: $e');
      return false;
    }
  }
  
  /// Removes the firewall rule
  static Future<bool> removeFirewallRule() async {
    if (!Platform.isWindows) return true;
    
    try {
      final result = await Process.run('netsh', [
        'advfirewall',
        'firewall',
        'delete',
        'rule',
        'name=Vibra Music Server'
      ]);
      
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }
}
