# 🎵 Vibra Music App

<div align="center">
  <img src="android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png" alt="Vibra Logo" width="120" height="120">
  
  **A powerful, open-source music streaming app built with Flutter**
  
  [![Flutter](https://img.shields.io/badge/Flutter-3.9.0+-02569B.svg?style=flat&logo=flutter)](https://flutter.dev)
  [![Dart](https://img.shields.io/badge/Dart-3.0.0+-0175C2.svg?style=flat&logo=dart)](https://dart.dev)
  [![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
  [![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Windows-lightgrey.svg)](https://github.com/Anshu78780/Vibra)
</div>

## 📱 About Vibra

Vibra is a cross-platform music streaming application built with Flutter. Stream millions of songs with a beautiful dark theme interface across Android, iOS, and Windows.

### ✨ Key Features

- 🎵 **Music Streaming** - High-quality audio streaming
- 📱 **Cross-Platform** - Android, iOS & Windows support  
- 💾 **Offline Downloads** - Download for offline listening
- ❤️ **Favorites & Playlists** - Save and organize music
- 🔍 **Smart Search** - Intelligent search with history
- � **Background Playback** - Continue while multitasking
- 🔄 **Auto-Updates** - Seamless app updates
- � **Modern UI** - Dark theme with smooth animations

## 🎯 Core Features

### 🎵 Music Player
- Full-featured player with queue management
- Background audio with media notifications
- Shuffle, repeat, and auto-advance modes
- Gapless playback experience

### 📱 Pages & Navigation
- **Home** - Trending music and recommendations
- **Search** - Find music with smart suggestions
- **Liked Songs** - Manage favorites and playlists
- **Downloads** - Access offline music
- **Settings** - App preferences and updates

### 💾 Offline & Storage
- Download manager with progress tracking
- Smart storage management
- Offline queue playback

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

### 🔧 Tech Stack

- **Framework**: Flutter 3.9.0+ (Cross-platform)
- **Language**: Dart 3.0.0+
- **Audio**: just_audio with audio_service
- **Storage**: shared_preferences + local file system
- **Architecture**: Provider pattern with ChangeNotifier

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.9.0+
- Dart SDK 3.0.0+
- Platform-specific requirements:
  - **Android**: Android Studio & Android SDK
  - **iOS**: Xcode (macOS only)
  - **Windows**: Visual Studio with C++ workload

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

#### Android
```bash
# Generate vibra.0.0.1.v7a.apk format
flutter build apk --split-per-abi --release

# App Bundle for Play Store
flutter build appbundle --release
```

#### iOS
```bash
flutter build ios --release
```

#### Windows
```bash
flutter build windows --release
```

## � API & Configuration

### Music API
- **Base URL**: `https://song-9bg4.onrender.com`
- **Endpoints**: `/homepage`, `/search`, `/suggestions`

### Release Signing (Android)
Place keystore at `android/vibra-release-key.jks` and configure `android/key.properties`

### Auto-Updates
Built-in GitHub release monitoring with architecture-specific APK selection

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

**Guidelines**: Follow Flutter/Dart style, test on multiple platforms, keep dependencies minimal.

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## � Support & Links

- **Issues**: [GitHub Issues](https://github.com/Anshu78780/Vibra/issues)
- **Repository**: [GitHub](https://github.com/Anshu78780/Vibra)

---

<div align="center">
  <p><strong>🎵 Vibra Music - Cross-Platform Music Streaming</strong></p>
  <p>Built with ❤️ using Flutter | Supports Android, iOS & Windows</p>
  <p>⭐ Star this repository if you find it helpful!</p>
</div>
