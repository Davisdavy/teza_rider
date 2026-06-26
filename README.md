# Teza Rider

The mobile client application for Teza riders, built with Flutter. It tracks GPS location, allows riders to accept and fulfill delivery offers, and provides real-time routing and ETA calculations.

## Recently Added Features

### 1. Persistent Session & Token Auto-Refresh
To prevent riders from experiencing session timeouts (such as "Authentication required" errors) in the middle of active deliveries, we implemented token persistence and automatic background refresh:
- **Local Persistence**: Both access and refresh tokens are securely stored locally using `SharedPreferences`.
- **Automatic Auto-Login**: The app checks for stored sessions on startup and skips the login screen if valid credentials exist.
- **Background Token Refresh Interceptor**: If an API call fails with a `401 Unauthorized` status code, the API client automatically calls the refresh token endpoint, updates the local and in-memory tokens, and retries the original request seamlessly.

### 2. Real-Road GPS Routing & Map Expansion
Rider routing has been upgraded from straight lines to actual drivable road paths:
- **Road-Accurate Routing**: Leverages the Open Source Routing Machine (OSRM) API to retrieve exact road coordinates.
- **Route Segments & Progress**: Completed segments of the route are automatically greyed out as the rider moves.
- **Map Expansion & Fullscreen**: Added a control button allowing the rider to expand the map container (utilizing a smooth `AnimatedContainer` transition from 280px to 480px) or toggle full-screen map mode for better navigation visibility.

### 3. Dynamic ETA Header
Replaced the static "ACTIVE EXECUTION JOB" banner with a dynamic Estimated Time of Arrival (ETA) indicator:
- **Real-Time Speed Detection**: Measures the rider's speed using the device's GPS (`Geolocator`).
- **Dynamic Calculation**: Calculates remaining distance on the road and divides it by the rider's current speed (with sensible fallbacks for static states) to compute and display a dynamic time estimate (e.g., `Estimated Delivery Time: 18Min`).

### 4. Anti-Fraud Delivery Safeguards
To prevent fraud, a rider cannot go offline or log out while in the middle of executing a delivery:
- **Offline Duty Prevention**: If the rider attempts to toggle the online switch to offline during an active delivery, the action is blocked, and a red validation warning SnackBar is displayed.
- **Logout Prevention**: If the rider attempts to log out from the Profile screen while a delivery is active, the app blocks the sign-out action and displays a validation warning SnackBar.
- **Provider-Level Guard**: A secure check is also enforced at the `JobProvider` level to reject offline status changes during active deliveries.

---

## Technical Stack & Architecture
- **Framework**: Flutter / Dart
- **State Management**: Provider
- **Local Database**: SharedPreferences (session tokens)
- **Map & Geolocation**: Flutter Map, Geolocator, flutter_map_line_editor
- **HTTP client**: HTTP with custom retry interceptor pattern for token auto-refresh

## Getting Started

### Prerequisites
- Flutter SDK (latest stable version)
- Android SDK or Xcode (for iOS)

### Installation
1. Clone the repository and navigate to `teza_rider`:
   ```bash
   cd teza_rider
   ```
2. Install Dart dependencies:
   ```bash
   flutter pub get
   ```
3. Run the application:
   ```bash
   flutter run
   ```

### Running Tests
Run the test suite using:
   ```bash
   flutter test
   ```

---

## 🌿 Git Workflow & Branching Strategy

This repository follows a structured branch management workflow:
- **`main`**: Contains the stable production code. No direct commits or feature branch merges are allowed on `main`. It only accepts merges from the `develop` branch.
- **`develop`**: The primary integration branch for development. All feature branches must target and merge into `develop` first.
- **Feature Branches**: Created for writing new features or fixes (e.g., `feat/some-feature` or `fix/some-bug`). Developers push these branches and create Pull Requests targeting the `develop` branch.
