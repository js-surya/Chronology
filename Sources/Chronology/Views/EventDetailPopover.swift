import SwiftUI
import UserNotifications

struct EventDetailPopover: View {
    let event: Event
    @EnvironmentObject var appViewModel: AppViewModel
    
    @State private var noteText = ""
    @State private var isEditingNote = false
    @State private var showingColorPicker = false
    @State private var selectedColor: Color
    @State private var customReminderTime: Int = 15
    
    private var isImportant: Bool {
        appViewModel.isEventImportant(event)
    }
    
    private var currentReminderTime: Int {
        appViewModel.getImportantEvent(event)?.reminderMinutes ?? 15
    }
    
    init(event: Event) {
        self.event = event
        _selectedColor = State(initialValue: event.color(from: event.title))
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, yyyy"
        return formatter
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Title
                Text(event.title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .fixedSize(horizontal: false, vertical: true)
                
                Divider()
                
                // Date
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "calendar")
                        .foregroundColor(appViewModel.accentColor)
                        .font(.body)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dateFormatter.string(from: event.startTime))
                            .font(.body)
                    }
                }
            
            // Time
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "clock")
                    .foregroundColor(appViewModel.accentColor)
                    .font(.body)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(timeFormatter.string(from: event.startTime)) - \(timeFormatter.string(from: event.endTime))")
                        .font(.body)
                    Text(durationText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Location
            if !event.location.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "mappin.circle")
                        .foregroundColor(appViewModel.accentColor)
                        .font(.body)
                        .frame(width: 20)
                    Text(event.location)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            // Description
            if let description = event.description, !description.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Details")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    Text(description)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            Divider()
            
            // Important Reminder Status
            if isImportant {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Important Reminder", systemImage: "star.fill")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.yellow)
                            .textCase(.uppercase)
                    }
                    
                    HStack(spacing: 8) {
                        Image(systemName: "bell.badge.fill")
                            .foregroundColor(.orange)
                            .font(.body)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("This event is marked as important")
                                .font(.body)
                            Text("You'll receive a reminder \(currentReminderTime) minutes before")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(12)
                    .background(Color.yellow.opacity(0.1))
                    .cornerRadius(8)
                    
                    Text("Tip: Click the star icon on the event card to toggle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            
            Divider()
            
            // Personal Note
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Personal Note", systemImage: "note.text")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    Spacer()
                    Button(isEditingNote ? "Done" : "Edit") {
                        if isEditingNote {
                            appViewModel.saveNote(for: event, noteText: noteText)
                        }
                        isEditingNote.toggle()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                }
                
                if isEditingNote {
                    TextEditor(text: $noteText)
                        .frame(height: 60)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(6)
                } else if !noteText.isEmpty {
                    Text(noteText)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("No notes")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            
            // Color Customization
            VStack(alignment: .leading, spacing: 8) {
                Label("Course Color", systemImage: "paintpalette")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                HStack(spacing: 10) {
                    ColorPicker("", selection: $selectedColor)
                        .labelsHidden()
                        .frame(width: 40, height: 30)
                        .onChange(of: selectedColor) { _, newColor in
                            appViewModel.setCustomColor(for: event.title, color: newColor)
                        }
                    
                    Button("Reset to Default") {
                        selectedColor = event.color(from: event.title)
                        appViewModel.setCustomColor(for: event.title, color: nil)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            }
            .padding(16)
        }
        .frame(width: 360, height: 600)
        .onAppear {
            if let existingNote = appViewModel.getNote(for: event) {
                noteText = existingNote.note
            }
            if let customColor = appViewModel.getCustomColor(for: event.title) {
                selectedColor = customColor
            }
            // Load current reminder time if event is important
            if let importantEvent = appViewModel.getImportantEvent(event) {
                customReminderTime = importantEvent.reminderMinutes
            }
        }
    }
    
    private var durationText: String {
        let duration = event.endTime.timeIntervalSince(event.startTime)
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func scheduleImportantReminder() {
        guard event.startTime > Date() else { return }
        
        // Save to persistent storage
        let importantEvent = ImportantEvent(
            eventTitle: event.title,
            eventDate: event.startTime,
            reminderMinutes: customReminderTime
        )
        
        // Remove existing if any and add new - using objectWillChange to ensure UI updates
        DispatchQueue.main.async {
            self.appViewModel.objectWillChange.send()
            // Match by title and exact start time
            self.appViewModel.importantEvents.removeAll { $0.eventTitle == self.event.title && abs($0.eventDate.timeIntervalSince(self.event.startTime)) < 60 }
            self.appViewModel.importantEvents.append(importantEvent)
            self.appViewModel.saveImportantEvents()
            
            // Trigger notification rescheduling to include this important event
            NotificationCenter.default.post(name: .rescheduleNotifications, object: nil)
            
            print("✅ Important reminder saved and scheduled for \(self.event.title) (\(self.customReminderTime) min before)")
        }
    }
    
    private func cancelImportantReminder() {
        // Remove from persistent storage - using objectWillChange to ensure UI updates
        DispatchQueue.main.async {
            self.appViewModel.objectWillChange.send()
            // Match by title and exact start time
            self.appViewModel.importantEvents.removeAll { $0.eventTitle == self.event.title && abs($0.eventDate.timeIntervalSince(self.event.startTime)) < 60 }
            self.appViewModel.saveImportantEvents()
            
            // Cancel scheduled notifications
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["important-\(self.event.id)"])
            print("✅ Cancelled important reminder for \(self.event.title)")
        }
    }
}
