# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Auto Repair Shop** is a Flutter mobile application for an auto repair shop management system. It implements client-facing features (CU01, CU02, CU03, CU06) with authentication, vehicle management, and user profiles. The app communicates with a REST API backend and uses local storage for offline auth state.

## Development Commands

```bash
# Install dependencies
flutter pub get

# Run the app (requires running backend API at http://127.0.0.1:8000)
flutter run

# Analyze code for linting issues
flutter analyze

# Format Dart code
dart format lib

# Run tests
flutter test
```

## Architecture & Project Structure

The project follows a **feature-based clean architecture**:

```
lib/
├── core/               # Shared app infrastructure
│   ├── config/         # AppConfig (API endpoints), DioClient (HTTP setup)
│   ├── models/         # Data models (User, Vehicle, Role, ApiResponse)
│   ├── services/       # API services (AuthService, VehicleService, ClientService, UserService)
│   ├── storage/        # LocalStorage (SharedPreferences wrapper)
│   └── theme/          # AppTheme, ThemeNotifier (dark/light mode via Provider)
├── features/           # Feature modules (each has screens + optional widgets)
│   ├── auth/           # LoginScreen
│   ├── register/       # RegisterScreen
│   ├── splash/         # SplashScreen (token validation, route redirect)
│   ├── home/           # HomeScreen (main dashboard)
│   ├── vehicles/       # VehiclesScreen + vehicle widgets
│   └── profile/        # ProfileScreen + profile widgets
└── shared/
    └── widgets/        # Reusable UI components (AppButton, AppCard, AppTextField, etc.)
```

### Key Architectural Patterns

**API Communication:**
- `DioClient`: Singleton HTTP client with automatic JWT injection via interceptor
- Token stored in `LocalStorage` (SharedPreferences) → automatically added to all requests with `Authorization: Bearer <token>`
- Base URL configured in `.env` file (loaded by `flutter_dotenv`)

**State Management:**
- Currently minimal Provider usage: only `ThemeNotifier` for dark/light mode
- No global state container; services are instantiated directly in screens (can refactor to use Provider at scale)
- `LocalStorage` acts as persistent session cache

**Authentication Flow:**
- Login → `AuthService.login()` → saves token + user in LocalStorage
- Subsequent requests → DioClient interceptor auto-injects token
- Logout → `AuthService.logout()` → clears LocalStorage and removes token from headers
- On app start → `SplashScreen` validates stored token via `AuthService.validateToken()`, navigates to `/login` or `/home`

**Role-Based Routing:**
- After login, app checks if user has 'client' role
- Only clients can access `/home` and vehicle features
- Non-clients are logged out and redirected to `/register`

## Configuration

### Environment Variables (.env)
```
API_URL=http://127.0.0.1:8000
```

Fallback for Android emulator: `http://10.0.2.2:8000`

### AppConfig Endpoints
All API endpoints are centralized in `lib/core/config/env.dart`:
- `POST /auth/login` — authenticate
- `GET /auth/me` — current user
- `GET /clients/me` — current client
- `POST /clients` — create client profile
- `GET /users` — list users
- `POST /users` — create user
- `GET /vehicles` — list vehicles
- `POST /vehicles` — create vehicle

## Common Development Tasks

**Add a new feature:**
1. Create `lib/features/my_feature/` directory
2. Create `my_feature_screen.dart` (StatelessWidget or StatefulWidget)
3. Add route in `lib/app.dart` routes map
4. Create shared widgets in `lib/features/my_feature/widgets/` if needed

**Modify API calls:**
1. Update service method in `lib/core/services/` (e.g., `VehicleService`)
2. Endpoint URL is defined in `AppConfig` (`lib/core/config/env.dart`)
3. DioClient automatically injects auth token; no manual header setup needed

**Add UI components:**
- Keep reusable widgets in `lib/shared/widgets/` (AppButton, AppCard, etc.)
- Feature-specific widgets go in `lib/features/<feature>/widgets/`

**Update data models:**
- Model files in `lib/core/models/` use JSON serialization
- Update `fromJson()` and `toJson()` methods when schema changes

## Testing Notes

- `flutter test` runs unit/widget tests in `test/` directory (currently minimal)
- Screens use real API calls (no mocking) → ensure `.env` API_URL is reachable
- LocalStorage is SharedPreferences backed; runs on real device/emulator

## Important Implementation Details

- **No explicit state management at the route level**: Navigation uses named routes with `Navigator.pushNamed()` / `pushReplacementNamed()`. For features that need cross-screen state, consider introducing a Provider-based state notifier.
- **Error handling in services**: Services catch DioExceptions and return structured results (`(success, message, data)`) rather than throwing. Screens check the `success` flag.
- **LocalStorage keys are prefixed with `ars_`** (auto repair shop) to avoid conflicts if the app shares prefs with other apps in the future.
- **Theme mode is global state** via `ThemeNotifier` + `ChangeNotifierProvider` in `main.dart`. Other global app state should follow the same pattern.
- **Logging**: DioClient includes a LogInterceptor that prints HTTP requests/responses to console. Disable `responseBody: true` in production.

## Notes for Exam/Assessment

This is an exam project implementing specific use cases (CU01, CU02, CU03, CU06). Focus areas:
- Auth flow (login, role-based access, logout)
- Vehicle CRUD operations
- Client profile management
- Persistent session via local storage
- Clean architecture separation (core/features/shared)
