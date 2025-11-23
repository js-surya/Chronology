# Chronology

**Chronology** is a beautiful, modern macOS application designed to help students and faculty manage their TimeEdit schedules effortlessly. Built with SwiftUI, it lives in your menu bar and provides a clean, native interface for your academic life.

![Chronology App Icon](chronology_app_icon.svg)

## ✨ Features

### 📅 Schedule Management

* **Menu Bar Integration**: See your next class and time remaining directly in the menu bar (e.g., "In 15m", "Ends in 45m")
* **Quick Glance**: Click the menu bar icon to see your schedule for the rest of the day
* **Week & Day Views**: Switch between comprehensive week view and focused daily view
* **Customizable Calendar Hours**: Set visible hours range (e.g., 8 AM - 6 PM) to fit your schedule

### 👤 Multiple Profiles

* **Profile Management**: Create unlimited schedule profiles with custom names and descriptions
* **iCal Integration**: Direct TimeEdit iCal URL support for automatic schedule syncing
* **Custom Icons**: Choose from 80+ SF Symbols icons to represent each profile
* **Color Coding**: Assign custom colors to profiles for easy identification
* **Profile Switching**: Quickly switch between different schedules (courses, exam schedules, etc.)

### 🔔 Smart Notifications

* **Configurable Reminders**: Get notified 5, 15, 30 minutes, or 1 hour before classes
* **Test Notifications**: Send test notifications to verify your settings
* **System Integration**: Native macOS notification support with banner display

### 🎨 Beautiful Customization

* **Appearance Modes**:
  * Auto (follows system)
  * Light mode
  * Dark mode
  * **AMOLED Black** mode (pure black for OLED displays)
* **Dark Mode Preferences**: Choose between standard dark or AMOLED when using auto mode
* **Accent Colors**: Select from 7 preset colors (Blue, Purple, Pink, Red, Orange, Green, Teal) or pick any custom color
* **Time Format**: Toggle between 12-hour and 24-hour time display

### 🔐 Privacy & System

* **Privacy Focused**: All schedule data is stored locally on your device - no cloud syncing
* **Launch at Login**: Automatically start Chronology when you log in
* **Menu Bar Only Mode**: Hide dock icon and run purely from the menu bar
* **Native macOS**: Built with SwiftUI for optimal performance and battery efficiency

## 💻 Tech Stack

* **Language**: Swift 5.9+
* **UI Framework**: SwiftUI
* **Platform**: macOS 14.0+ (Sonoma and later)
* **Architecture**: MVVM (Model-View-ViewModel)
* **Dependencies**: Native macOS frameworks only (no third-party dependencies)
  * UserNotifications for notification management
  * Combine for reactive programming
  * AppKit for menu bar integration
  * EventKit-style iCal parsing

## 🤖 Built with AI

This project was built with the assistance of **AI**. From architectural decisions to SwiftUI implementation and refactoring, AI played a co-pilot role in bringing Chronology to life.

* **Development Assistants**: GitHub Copilot & Google Gemini
* **Design Philosophy**: Clean, native macOS experience with modern SwiftUI patterns
* **Code Quality**: AI-assisted code reviews and optimizations

## 🚀 Installation

1. Download the latest `Chronology.dmg` from the [Releases](https://github.com/js-surya/chronology/releases) page.
2. Open the DMG file.
3. Drag **Chronology** to your **Applications** folder.
4. Launch the app!

## 🛠️ Building from Source

**Requirements:**

* macOS 14.0 (Sonoma) or later
* Xcode 15.0 or later
* Swift 5.9+

**Build Instructions:**

```bash
# Clone the repository
git clone https://github.com/js-surya/chronology.git

# Navigate to the project folder
cd chronology

# Build the release version
swift build -c release

# Package as a macOS application
sh package_app.sh
```

The packaged app will be available in the project directory as `Chronology.dmg`.

## 📝 Usage

### Getting Started

1. **Add Your First Profile**:
   * Launch Chronology
   * Click the menu bar icon or open Settings (`Cmd+,`)
   * Navigate to the **Profiles** tab
   * Click the **+** button
   * Enter a profile name (e.g., "Winter 2024")
   * Paste your TimeEdit iCal URL
   * Choose an icon and color for easy identification
   * Click **Save**

2. **Customize Your Experience**:
   * Go to **General** settings (`Cmd+,`)
   * Select your preferred appearance (Light, Dark, or AMOLED)
   * Choose an accent color
   * Set your notification preferences
   * Configure calendar hours to match your schedule

3. **Daily Use**:
   * Check the menu bar for your next class and countdown
   * Click the menu bar icon for a quick schedule overview
   * Switch between profiles using the profile selector
   * Get notified before classes start

### Finding Your TimeEdit iCal URL

1. Go to your TimeEdit schedule page
2. Look for an "Export" or "Subscribe" option
3. Copy the iCal/ICS URL (usually ends with `.ics`)
4. Paste it into Chronology

### Tips

* Use **Week View** for planning ahead
* Use **Day View** for focusing on today's schedule
* Enable **Launch at Login** to never miss an update
* Use **Menu Bar Only Mode** for a cleaner desktop experience

## � Known Issues & Limitations

* iCal URL must be publicly accessible (no authentication support yet)
* Schedule updates are periodic - manual refresh not yet implemented
* Limited to TimeEdit iCal format (other calendar systems not tested)

## 🗺️ Roadmap

* [ ] Manual schedule refresh button
* [ ] Export schedule to other formats
* [ ] Custom event colors per course
* [ ] Event notes and reminders
* [ ] Calendar overlay with other calendars
* [ ] Keyboard shortcuts for common actions
* [ ] Multiple window support

## 🤝 Contributing

Contributions are welcome! If you have suggestions for improvements or find bugs:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

* TimeEdit for providing iCal export functionality
* Apple for SwiftUI and SF Symbols
* The Swift community for excellent documentation and resources

---

Made with ❤️ by Surya & AI
