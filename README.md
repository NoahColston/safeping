# SafePing

SafePing is a mobile application that provides structured, customizable safety check-ins with automatic escalation. Users schedule recurring check-ins, and if a check-in is missed within a configured grace window, designated contacts are automatically notified.

## Features

- Scheduled safety check-ins with flexible recurrence options  
- Custom check in messages per schedule  
- Grace period based failure detection  
- Automatic escalation notifications to designated contacts  
- Pairing system for check in monitoring  
- Location-aware check ins  
- History tracking and calendar view of past check ins  

## Tech Stack

- Swift / SwiftUI  
- iOS location services  
- Notification system
- Core data models for users, pairings, and check-ins  

## Setup Instructions

### Prerequisites
- Xcode 15 or later  
- iOS 16+ deployment target recommended  

### Installation

1. Clone the repository:
   git clone https://github.com/NoahColston/safeping.git

2. Open the project in Xcode:
   open SafePing.xcodeproj

3. Build and run the app:
   - Select a simulator or physical device in Xcode  
   - Press Run  

### Permissions
For full functionality, enable the following when prompted:
- Location access  
- Notification permissions  

## Limitations

- Notification scheduling may require an app restart to fully refresh pending triggers.  
- WatchConnectivity messages are not always reliable and may fail when the session is inactive.  
- UI updates may briefly appear delayed due to asynchronous data loading.  
- Location features depend on user permission and device availability.  
- Each new feature impacted other parts of the system that were previously assumed stable.  
- The current escalation system relies on the check in user’s device, meaning alerts may fail if the device is off or the app is terminated.  
