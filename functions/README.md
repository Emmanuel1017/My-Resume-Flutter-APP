# portfolio-admin Cloud Functions

Single function: `notifyAdminsOnNewContact`.

## What it does

Trigger: Firestore `onDocumentCreated('contacts/{id}')` — fires on every new
contact form submission from either Angular or the Flutter guest screen.

Action: reads `/admin_tokens` (populated by Flutter's `FcmService` when an
admin signs in), then sends a multicast FCM with title/body + a data payload.
Stale tokens that FCM rejects are pruned in the same invocation.

## Deploy

```bash
# One-time, from repo root
npm install --prefix functions

# Make sure you've selected the right Firebase project at least once
firebase use --add

# Deploy just this function
firebase deploy --only functions:notifyAdminsOnNewContact
```

Requires the [Firebase CLI](https://firebase.google.com/docs/cli) and the
Blaze (pay-as-you-go) plan — Cloud Functions are not on the free tier.

## Test locally

```bash
firebase emulators:start --only functions,firestore
```

Then trigger a write to `contacts/_test` via the emulator UI; the function
log should show `FCM sent: 1 ok, 0 failed` if one admin device is registered.
