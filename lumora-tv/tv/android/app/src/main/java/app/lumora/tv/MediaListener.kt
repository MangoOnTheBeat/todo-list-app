package app.lumora.tv

import android.service.notification.NotificationListenerService

/**
 * Exists only so Lumora can be given notification access, which Android requires before an app may read
 * what's playing (title, artist, artwork) for the Control Centre. Lumora doesn't read or store notifications.
 */
class MediaListener : NotificationListenerService()
