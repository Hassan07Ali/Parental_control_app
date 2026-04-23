
# 🛡️ SafeScreen - Flutter Parental Control App
## Iteration 1 Frontend - Complete Source Code

---

## 📁 Project Structure

```
lib/
├── main.dart                    ← App entry point
├── theme/
│   └── app_theme.dart           ← Colors, gradients, TextTheme
├── models/
│   └── app_models.dart          ← Data models + sample data
├── widgets/
│   └── common_widgets.dart      ← Reusable UI components
└── screens/
    ├── splash_screen.dart       ← Animated splash
    ├── onboarding_screen.dart   ← 3-page onboarding swipe
    ├── setup_screen.dart        ← 4-step parent setup wizard
    ├── main_shell.dart          ← Bottom nav shell
    ├── home_screen.dart         ← Dashboard (main screen)
    ├── controls_screen.dart     ← App limits & controls
    ├── activity_screen.dart     ← Weekly usage report
    ├── location_screen.dart     ← Location tracking view
    └── settings_screen.dart     ← App settings (inside location.dart)
```

---

## 🚀 Setup Instructions

### Step 1: Create Flutter project
```bash
flutter create safescreen
cd safescreen
```

### Step 2: Replace files
Copy all the provided `.dart` files into your project's `lib/` folder,
maintaining the folder structure above.

Replace the existing `pubspec.yaml` with the provided one.

### Step 3: Add Poppins font (optional but recommended)
1. Go to https://fonts.google.com/specimen/Poppins
2. Download: Regular, Medium, SemiBold, Bold, ExtraBold weights
3. Create folder: `assets/fonts/`
4. Place font files there
5. Uncomment the fonts section in `pubspec.yaml`

### Step 4: Run
```bash
flutter pub get
flutter run
```

---

## 🎨 Design System

### Color Palette
| Variable         | Hex       | Usage                    |
|------------------|-----------|--------------------------|
| `background`     | #0A0E1A   | App background           |
| `surfaceDark`    | #111827   | Bottom nav, cards        |
| `surfaceMid`     | #1A2236   | Input fields             |
| `surfaceCard`    | #1E2D45   | Cards                    |
| `accentCyan`     | #00D4FF   | Primary accent, CTAs     |
| `accentGreen`    | #00E5A0   | Success, education apps  |
| `accentPurple`   | #7C6FFF   | Gaming, secondary        |
| `accentOrange`   | #FF8C42   | Warnings, entertainment  |
| `accentPink`     | #FF6B9D   | Social media, danger     |

### Reusable Widgets
- **`GlassCard`** — Dark glassmorphism card with border
- **`GlowButton`** — Gradient button with glow shadow
- **`SectionHeader`** — Title + optional "AI Suggestion" badge
- **`CircularProgressRing`** — Circular progress indicator
- **`StatMiniCard`** — Icon + value + label stat card
- **`AppSearchBar`** — Styled dark search input
- **`AppBottomNav`** — 5-tab bottom navigation bar

---

## 📱 Screens Overview

| Screen           | Description                                        |
|------------------|----------------------------------------------------|
| Splash           | Logo + animated loading dots                      |
| Onboarding       | 3 swipeable feature intro pages                   |
| Setup (Step 1)   | Parent name input                                  |
| Setup (Step 2)   | Add child + avatar picker                         |
| Setup (Step 3)   | Daily screen time limit with sliders              |
| Setup (Step 4)   | 4-digit security PIN with numpad                  |
| Home             | Dashboard: screen time, map, recent app usage     |
| Controls         | App limits with toggles, blocked stats            |
| Activity         | Weekly bar chart (Last 7 days)                    |
| Location         | Live location map + children list                 |
| Settings         | Profile, notifications, app settings              |

---

## 🔄 Iteration 2 & 3 Plan (Next Steps)

**Iteration 2 additions:**
- `screens/analytics_screen.dart` — Weekly bar chart (use `fl_chart` package)
- App categorization logic in `models/`
- Productivity score calculation
- Website restriction list screen

**Iteration 3 additions:**
- `screens/pet_screen.dart` — Virtual pet with animation
- Bonus screen time reward modal
- Reminder notification setup (use `flutter_local_notifications`)

---

## 📦 Recommended Packages (Future Iterations)

```yaml
dependencies:
  fl_chart: ^0.70.0              # Charts for analytics
  shared_preferences: ^2.2.0    # Local data persistence  
  flutter_local_notifications: ^17.0.0  # Notifications
  provider: ^6.1.0              # State management
  permission_handler: ^11.0.0   # Android permissions
  geolocator: ^13.0.0           # Location services
  installed_apps: ^2.0.0        # App enumeration (Android)
```


