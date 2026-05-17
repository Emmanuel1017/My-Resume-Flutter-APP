/**
 * Cloud Functions for portfolio-admin.
 *
 * Trigger: a new contact submission is written to /contacts/{id} (from either
 * the Angular site or the Flutter guest form).
 *
 * Action: fan-out an FCM push to every device registered in /admin_tokens.
 *  - Tokens are written by Flutter's FcmService when an admin signs in.
 *  - Stale tokens (FCM returns `messaging/registration-token-not-registered`)
 *    are pruned in the same invocation so the collection stays clean.
 */

const {onDocumentCreated} = require('firebase-functions/v2/firestore');
const {initializeApp}     = require('firebase-admin/app');
const {getFirestore}      = require('firebase-admin/firestore');
const {getMessaging}      = require('firebase-admin/messaging');
const logger              = require('firebase-functions/logger');

initializeApp();

exports.notifyAdminsOnNewContact = onDocumentCreated(
  {
    document: 'contacts/{contactId}',
    region:   'us-central1', // match the Firestore default region
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const contact = snap.data() || {};
    const name    = (contact.name    || 'Someone').toString().slice(0, 80);
    const email   = (contact.email   || '').toString().slice(0, 120);
    const message = (contact.message || '').toString().slice(0, 240);

    // Load admin device tokens.
    const tokensSnap = await getFirestore().collection('admin_tokens').get();
    if (tokensSnap.empty) {
      logger.log('No admin tokens registered — skipping FCM.');
      return;
    }
    const tokens = tokensSnap.docs.map((d) => d.id);

    // Build payload. Title/body are rendered by Android/iOS system tray; the
    // `data` block is also delivered to the foreground handler in Flutter so
    // we can show a custom themed notification with avatar + colors.
    const payload = {
      notification: {
        title: `New message from ${name}`,
        body:  message || email || 'Tap to open your inbox.',
      },
      data: {
        contactId: event.params.contactId,
        name,
        email,
        source: (contact.source || 'web').toString(),
        // click_action drives onMessageOpenedApp routing in Flutter.
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      android: {
        priority: 'high',
        notification: {
          channelId:    'portfolio_contacts',
          color:        '#A8E87A',  // app accent
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
      apns: {
        payload: {
          aps: {sound: 'default', badge: 1},
        },
      },
    };

    // Multicast via sendEachForMulticast — returns per-token success/failure
    // so we can prune dead tokens in one batch write.
    const res = await getMessaging().sendEachForMulticast({
      ...payload,
      tokens,
    });

    logger.log(`FCM sent: ${res.successCount} ok, ${res.failureCount} failed`);

    // Prune unregistered tokens.
    const deletes = [];
    res.responses.forEach((r, i) => {
      if (!r.success) {
        const code = r.error && r.error.code;
        if (
          code === 'messaging/registration-token-not-registered' ||
          code === 'messaging/invalid-registration-token'
        ) {
          deletes.push(
            getFirestore().collection('admin_tokens').doc(tokens[i]).delete(),
          );
        }
      }
    });
    if (deletes.length) {
      await Promise.allSettled(deletes);
      logger.log(`Pruned ${deletes.length} stale admin tokens.`);
    }
  },
);
