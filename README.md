# 🎵 Vibra Music App

<div align="center">
  <img src="android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png" alt="Vibra Logo" width="120" height="120">
  
  **A powerful, open-source music streaming app built with Flutter**
  
  [![Flutter](https://img.shields.io/badge/Flutter-3.9.0+-02569B.svg?style=flat&logo=flutter)](https://flutter.dev)
  [![Dart](https://img.shields.io/badge/Dart-3.0.0+-0175C2.svg?style=flat&logo=dart)](https://dart.dev)
  [![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
  [![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-lightgrey.svg)](https://github.com/Anshu78780/Vibra)
</div>

## 📱 About Vibra

Vibra is a feature-rich music streaming application that provides seamless music discovery, playback, and management. Built with Flutter, it offers a native experience across platforms with a beautiful dark theme interface.

### ✨ Key Features

- 🎵 **Music Streaming**: Stream millions of songs with high-quality audio
- 📱 **Cross-Platform**: Native Android and iOS support
- 🔄 **Queue Management**: Advanced playlist and queue system
- 💾 **Offline Downloads**: Download songs for offline listening
- ❤️ **Favorites**: Like and save your favorite tracks
- 🔍 **Smart Search**: Intelligent search with history and suggestions
- 🎨 **Beautiful UI**: Modern dark theme with smooth animations
- 🔄 **Auto-Updates**: Built-in update manager for seamless updates
- 🎧 **Background Playback**: Continue listening while using other apps
- 📊 **Mini Player**: Persistent mini player for easy controls

## 🎯 Core Functionality

### 🎵 Music Player
- **Full-featured player** with play, pause, skip, and seek controls
- **Queue management** with shuffle and repeat modes
- **Background audio** support with media notifications
- **Auto-advance** to next track with smart recommendations
- **Gapless playback** for uninterrupted listening experience

### 📱 User Interface
- **Home Feed**: Trending music and personalized recommendations
- **Search Page**: Find music with intelligent suggestions and search history
- **Liked Songs**: Manage your favorite tracks and custom playlists
- **Downloads**: Access offline music with queue playback
- **Settings**: App preferences and update management

### 🔍 Discovery & Search
- **Trending Music**: Discover popular tracks and new releases
- **Search History**: Quick access to recent searches
- **Suggestions**: Real-time search suggestions as you type
- **Categories**: Browse music by genres and moods

### 💾 Offline Features
- **Download Manager**: Download songs for offline playback
- **Storage Management**: Monitor download progress and storage usage
- **Offline Queue**: Play downloaded songs with queue functionality
- **Auto-cleanup**: Smart storage management

## 🏗️ Architecture Overview

### 📁 Project Structure

```
lib/
├── components/          # UI Components
│   ├── home_page.dart          # Main navigation & app entry
│   ├── search_page.dart        # Music search & discovery
│   ├── liked_songs_page.dart   # Favorites & playlists
│   ├── downloads_page.dart     # Offline music management
│   ├── settings_page.dart      # App settings & updates
│   ├── full_music_player.dart  # Full-screen music player
│   ├── mini_music_player.dart  # Persistent mini player
│   ├── music_queue_page.dart   # Home feed & trending
│   ├── update_dialog.dart      # App update interface
│   └── universal_loader.dart   # Loading animations
│
├── controllers/         # Business Logic
│   └── music_player_controller.dart  # Core playback controller
│
├── models/             # Data Models
│   └── music_model.dart         # Music track & API models
│
├── services/           # Service Layer
│   ├── audio_service.dart       # Audio streaming service
│   ├── download_service.dart    # Download management
│   ├── music_service.dart       # API communication
│   ├── liked_songs_service.dart # Favorites management
│   ├── search_history_service.dart # Search caching
│   ├── update_manager.dart      # App update system
│   ├── background_audio_handler.dart # Background audio
│   ├── preloading_service.dart  # Audio preloading
│   ├── recommendation_service.dart # Music recommendations
│   └── playlist_service.dart    # Playlist management
│
└── utils/              # Utilities
    └── [Utility classes and helpers]
```

### 🔧 Technical Stack

- **Framework**: Flutter 3.9.0+
- **Language**: Dart 3.0.0+
- **State Management**: Provider pattern with ChangeNotifier
- **Audio Playback**: just_audio package with audio_service
- **HTTP Requests**: http package for API communication
- **Local Storage**: shared_preferences for data persistence
- **Notifications**: flutter_local_notifications
- **Background Audio**: audio_service with MediaSession
- **Downloads**: Custom download service with progress tracking

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.9.0 or higher
- Dart SDK 3.0.0 or higher
- Android Studio / VS Code
- Android SDK for Android development
- Xcode for iOS development (macOS only)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/Anshu78780/Vibra.git
   cd Vibra
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

### 📱 Building for Release

#### Android APK
```bash
# Standard APK
flutter build apk --release

# Split APKs (smaller file sizes)
flutter build apk --split-per-abi --release

# App Bundle for Google Play Store
flutter build appbundle --release
```

#### iOS
```bash
flutter build ios --release
```

## 🛠️ Configuration

### 🔐 Release Signing (Android)

The app is configured for release builds with a keystore:

1. Place your keystore file at `android/vibra-release-key.jks`
2. Configure `android/key.properties`:
   ```properties
   storePassword=your_store_password
   keyPassword=your_key_password
   keyAlias=your_key_alias
   storeFile=vibra-release-key.jks
   ```

### 🔄 Update Configuration

The app includes an automatic update system that checks for new releases from GitHub:

- **Update Check**: Automated daily checks
- **Manual Updates**: Available in settings
- **Smart Notifications**: Non-intrusive update prompts
- **Architecture Detection**: Automatic APK selection based on device

## 📖 API Integration

### Music API Endpoints

The app integrates with a custom music API:

- **Base URL**: `https://song-9bg4.onrender.com`
- **Trending**: `/homepage?limit=200`
- **Search**: `/search?q={query}&limit=20`
- **Suggestions**: `/suggestions?q={query}`

### Response Models

```dart
// Music Track Model
class MusicTrack {
  final String id;
  final String title;
  final String artist;
  final String audioUrl;
  final String thumbnail;
  final String webpageUrl;
  final String duration;
  // ... additional properties
}

// API Response Models
class MusicApiResponse {
  final List<MusicTrack> trendingMusic;
  final int totalResults;
  // ... additional properties
}
```

## 💾 Data Persistence

### Local Storage

- **Liked Songs**: Cached using SharedPreferences
- **Search History**: Persistent search cache (20 items max)
- **Downloads**: Local file system with metadata
- **Playlists**: User-created playlists with track references
- **App Settings**: User preferences and update settings

### Download System

- **Format**: MP3 audio files
- **Location**: App-specific directory
- **Metadata**: Track information stored separately
- **Progress**: Real-time download progress tracking
- **Validation**: File integrity checks on app startup

## 🔧 Services Overview

### 🎵 MusicPlayerController
Central controller managing all audio playback functionality:
- Track queue management
- Playback state synchronization
- Auto-advance and repeat modes
- Background audio coordination

### 📥 DownloadService
Handles offline music functionality:
- Audio file downloading with progress tracking
- Download queue management
- Storage optimization
- Metadata preservation

### 🔍 SearchHistoryService
Manages search experience:
- Query caching and suggestions
- History management (20 item limit)
- Duplicate prevention
- Persistent storage

### 🔄 UpdateManager
Automated app update system:
- GitHub release monitoring
- Version comparison
- Architecture-specific APK selection
- User-friendly update prompts

## 🎨 UI/UX Design

### Design Principles
- **Dark Theme**: Easy on the eyes for extended use
- **Minimal Interface**: Focus on music, not clutter
- **Smooth Animations**: Fluid transitions and interactions
- **Responsive Design**: Adapts to different screen sizes
- **Accessibility**: Screen reader support and high contrast

### Color Scheme
- **Primary**: `#B91C1C` (Red accent)
- **Background**: `#000000` (Pure black)
- **Surface**: `#1A1A1A` (Dark gray)
- **Text Primary**: `#FFFFFF` (White)
- **Text Secondary**: `#999999` (Light gray)

## 🤝 Contributing

We welcome contributions! Please read our contributing guidelines:

1. **Fork the repository**
2. **Create a feature branch** (`git checkout -b feature/amazing-feature`)
3. **Commit changes** (`git commit -m 'Add amazing feature'`)
4. **Push to branch** (`git push origin feature/amazing-feature`)
5. **Open a Pull Request**

### Development Guidelines

- Follow Flutter/Dart style guidelines
- Write meaningful commit messages
- Update documentation for new features
- Test on multiple devices before submitting
- Keep dependencies minimal and updated

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Flutter Team** for the amazing framework
- **just_audio** for excellent audio playback capabilities
- **audio_service** for background audio support
- **Contributors** who help improve the app

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/Anshu78780/Vibra/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Anshu78780/Vibra/discussions)
- **Email**: [Contact Developer](mailto:your-email@example.com)

## 🔮 Future Plans

- [ ] **Podcast Support**: Add podcast streaming capabilities
- [ ] **Social Features**: Share music and playlists
- [ ] **Lyrics Integration**: Real-time lyrics display
- [ ] **Cloud Sync**: Cross-device synchronization
- [ ] **Equalizer**: Custom audio enhancement
- [ ] **Sleep Timer**: Auto-stop functionality
- [ ] **Car Integration**: Android Auto & CarPlay support

---

<div align="center">
  <p><strong>Made with ❤️ using Flutter</strong></p>
  <p>⭐ Star this repository if you find it helpful!</p>
</div>
