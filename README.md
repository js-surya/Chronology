# Chronology

**Chronology** is a beautiful, modern macOS application designed to help students and faculty manage their TimeEdit schedules effortlessly. Built with SwiftUI, it lives in your menu bar and provides a clean, native interface for your academic life.

![Chronology App Icon](chronology_app_icon.svg)

## ✨ Features

* **Menu Bar Integration**: See your next class and time remaining directly in the menu bar (e.g., "In 15m", "Ends in 45m").
* **Quick Glance**: Click the menu bar icon to see your schedule for the rest of the day.
* **Smart Notifications**: Get notified before your classes start so you're never late.
* **Multiple Profiles**: Manage different schedules (e.g., Course 1, Course 2, Exam Schedule) with custom icons and colors.
* **Customizable Interface**:
  * **Themes**: Light, Dark, and a special **AMOLED Black** mode.
  * **Accent Colors**: Choose from a variety of system colors or pick your own.
  * **View Modes**: Switch between Week and Day views.
* **Privacy Focused**: Your schedule data is stored locally on your device.
* **Launch at Login**: Option to automatically start Chronology when you log in.

## 🤖 Built with AI

This project was built with the assistance of **AI**. From architectural decisions to SwiftUI implementation and refactoring, AI played a co-pilot role in bringing Chronology to life.

* **Core Logic**: Swift & Combine
* **UI/UX**: SwiftUI
* **Development**: Assisted by GitHub Copilot & Gemini Models

## 🚀 Installation

1. Download the latest `Chronology.dmg` from the [Releases](https://github.com/js-surya/chronology/releases) page.
2. Open the DMG file.
3. Drag **Chronology** to your **Applications** folder.
4. Launch the app!

## 🛠️ Building from Source

Requirements:

* macOS 14.0 or later
* Xcode 15.0 or later
* Swift 5.9

```bash
# Clone the repository
git clone https://github.com/js-surya/chronology.git

# Navigate to the project folder
cd chronology

# Build and run
swift build -c release
sh package_app.sh
```

## 📝 Usage

1. **Add a Profile**: Open Settings (`Cmd+,`) -> Profiles. Click "+" and paste your TimeEdit iCal URL.
2. **Customize**: Choose an emoji and color for your profile.
3. **Stay Updated**: The app will automatically fetch your schedule. Check the menu bar for quick updates.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---
Made with ❤️ by Surya & AI
