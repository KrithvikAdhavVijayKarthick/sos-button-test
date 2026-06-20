# 🛡️ Guardian SOS — Flutter App

Shake your phone → 10-second countdown → Automatic Twilio voice call + WhatsApp message with live GPS location.
Works when screen is off. Restarts after phone reboot. No SIM needed (uses internet/WiFi).

---

## How it works

```
User shakes phone hard
       ↓
10-second countdown (shown on screen + lock screen notification)
       ↓
[if not cancelled]
       ↓
┌─────────────────────────────────────┐
│  1. GPS location fetched            │
│  2. Twilio makes voice call         │
│     → Speaks danger message + GPS  │
│  3. WhatsApp message sent           │
│     → Danger alert + Maps link     │
└─────────────────────────────────────┘
```

---

## Step 1 — Get Twilio (free, takes 5 minutes)

1. Go to **https://www.twilio.com/try-twilio** — sign up free
2. You get **$15 free credit** (enough for ~300 calls to India)
3. From the Console dashboard, copy:
   - **Account SID** → looks like `ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`
   - **Auth Token**  → looks like `xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`
4. Get a Twilio phone number:
   - Console → Phone Numbers → Manage → Buy a number
   - Pick any US/UK number (~$1/month) — it will call +91 numbers
5. Open `lib/background_service.dart` and fill in:

```dart
const String kTwilioAccountSid = 'ACxxxxxxxxxxxxxxxx'; // your SID
const String kTwilioAuthToken  = 'xxxxxxxxxxxxxxxx';   // your token
const String kTwilioFromNumber = '+1XXXXXXXXXX';       // your Twilio number
const String kEmergencyNumber  = '+919791662479';      // number to call
```

### What Twilio says when the call is answered

The app sends this voice message (in Indian English accent via Alice TTS):

> *"Emergency Alert. Emergency Alert.*
> *The owner of this phone is in danger and needs immediate police assistance.*
> *Their live location is: https://maps.google.com/?q=LAT,LNG*
> *I repeat. The owner of this phone is in danger. Please send help immediately.*
> *This is an automated SOS message from Guardian Emergency App."*

---

## Step 2 — Host the TwiML (one-time, free)

Twilio needs a URL to fetch call instructions from. Easiest free option:

### Option A — Twilio Functions (recommended, free)

1. Twilio Console → Explore Products → Functions & Assets → Services
2. Create new Service → name it `guardian`
3. Add Function → path `/emergency_twiml`
4. Paste this code:

```javascript
exports.handler = function(context, event, callback) {
  const lat = event.lat || '';
  const lng = event.lng || '';
  const locText = lat
    ? `Their live location is: https://maps.google.com/?q=${lat},${lng}`
    : 'Location could not be determined. Please trace this call immediately.';

  const twiml = `<?xml version="1.0" encoding="UTF-8"?>
<Response>
  <Say voice="alice" language="en-IN">
    Emergency Alert. Emergency Alert.
    The owner of this phone is in danger and needs immediate police assistance.
    ${locText}
    I repeat. The owner of this phone is in danger.
    Please send help immediately.
    This is an automated SOS message from Guardian Emergency App.
  </Say>
  <Pause length="2"/>
  <Say voice="alice" language="en-IN">
    Emergency Alert. The owner of this phone needs help.
  </Say>
</Response>`;

  callback(null, twiml);
};
```

5. Deploy → copy the function URL
6. In `background_service.dart`, replace `YOUR_TWIML_URL` with your function URL

### Option B — Use inline TwiML (simplest, no hosting needed)

In `background_service.dart`, the `_makeTwilioCall` function already has inline TwiML.
Just make sure the `'Twiml'` param is in the POST body (it already is).
Twilio supports inline TwiML directly — no URL needed.

---

## Step 3 — WhatsApp Setup

### Current behavior (works immediately)
When triggered, the app opens WhatsApp with a pre-filled message:

```
🚨 EMERGENCY ALERT 🚨

The owner of this phone is in DANGER and needs immediate police assistance.

📍 Live Location:
https://maps.google.com/?q=LAT,LNG

Please send help immediately.
```

This requires WhatsApp to be installed on the phone.

### For fully silent background WhatsApp (no app needed on device)
Use **WhatsApp Business API via Meta** or a provider like **Twilio WhatsApp**:

1. Twilio Console → Messaging → Try it Out → Send a WhatsApp Message
2. Use Twilio's WhatsApp sandbox for testing
3. In `background_service.dart`, replace `_sendWhatsAppMessage` with:

```dart
Future<void> _sendWhatsAppMessage(String? mapURL) async {
  final locLine = mapURL != null
      ? '📍 Live Location:\n$mapURL'
      : '📍 Location unavailable.';
  final msg = '🚨 EMERGENCY ALERT 🚨\n\nThe owner of this phone is in DANGER.\n\n$locLine\n\nPlease send help immediately.';

  await http.post(
    Uri.parse('https://api.twilio.com/2010-04-01/Accounts/$kTwilioAccountSid/Messages.json'),
    headers: {
      'Authorization': 'Basic ${base64Encode('$kTwilioAccountSid:$kTwilioAuthToken')}',
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: {
      'From': 'whatsapp:$kTwilioFromNumber',
      'To':   'whatsapp:$kEmergencyNumber',
      'Body': msg,
    },
  );
}
```

---

## Step 4 — Build & Install

### Android (easiest)

```bash
cd guardian_sos
flutter pub get
flutter build apk --release
# Install on phone:
flutter install
```

Or transfer `build/app/outputs/flutter-apk/app-release.apk` to your phone and install directly.

**Android settings to enable:**
- Settings → Apps → Guardian → Battery → Unrestricted (prevents OS killing background service)
- Settings → Apps → Guardian → Notifications → Allow
- On some phones (Xiaomi/Realme/Samsung): Settings → Battery → App launch → Guardian → set Manual → enable all three toggles

### iOS

```bash
flutter build ios --release
# Open in Xcode, connect iPhone, Product → Run
```

Requires Apple Developer account ($99/year) to install on a real device.

---

## Step 5 — Test

1. Open app → see "Shake Detection Active"
2. Shake phone hard (like you're trying to shake water off it)
3. See 10-second countdown on screen
4. Let it count down — Twilio calls +919791662479 automatically
5. Answer the call — hear the automated voice message
6. Check WhatsApp — see the emergency message with your location

To test without shaking: In `background_service.dart`, temporarily lower threshold:
```dart
const double kShakeThreshold = 5.0; // very sensitive for testing
```

---

## Files

```
lib/
  main.dart               — App entry, initialises background service
  background_service.dart — Shake detection, Twilio call, WhatsApp message
  home_screen.dart        — UI (armed / countdown / triggered screens)

android/app/src/main/
  AndroidManifest.xml     — All Android permissions + boot receiver

ios/Runner/
  Info.plist              — iOS permissions + background modes
```

---

## Costs

| Service | Cost |
|---|---|
| Twilio trial | Free ($15 credit) |
| Twilio call to India | ~$0.04–0.06/minute |
| Twilio WhatsApp message | ~$0.005/message |
| Twilio phone number | ~$1/month |
| Flutter app | Free |

---

## Troubleshooting

**Shake not detected in background (Android)**
→ Go to Settings → Battery → find Guardian → set to "Unrestricted" or "No restrictions"
→ On Xiaomi: Settings → Battery & Performance → App Battery Saver → Guardian → No restrictions

**Location not sharing**
→ Settings → Apps → Guardian → Permissions → Location → Allow all the time

**WhatsApp not opening**
→ Make sure WhatsApp is installed. For background sending, use Twilio WhatsApp API (Step 3)

**Call goes to voicemail**
→ Twilio still leaves the voice message on voicemail — the recipient will hear it

**iOS background limitations**
→ iOS limits background processing. The app works best when added to Home Screen and kept in recent apps. For true always-on iOS, a dedicated Apple Watch companion app is the right approach (connects to your SOS Watch system).
