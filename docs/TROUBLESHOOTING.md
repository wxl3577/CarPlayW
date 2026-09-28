# Troubleshooting (1.0)

Install over the existing TrollStore app. Park before use.

If no cache is found, connect CarPlay and open Settings → Wallpaper on the car screen, select a system wallpaper, disconnect, and refresh in this app. Refresh reads existing phone files; the app neither detects connection state nor downloads caches from the car.

Before writing, choose a supported family with existing cache files. Use the Cache tab to view readable light/dark originals and their pixel dimensions and file sizes. Invalid existing files stop writing. There is no persistent backup or diagnostic-sharing interface in this version.

After writing, inspect the refreshed cache and restart the phone as recommended, then reconnect CarPlay. iOS may regenerate caches during a restart or wallpaper change; refresh and inspect again if the effect disappears.

To rebuild caches, disconnect CarPlay and use the confirmed clear action. It removes all direct image files in the single detected wallpaper-cache directory, not just the selected family. This cannot be undone and does not guarantee restoration of a particular original wallpaper. Reconnect and choose a system wallpaper to regenerate caches.

Multiple containers or a cache that changes after confirmation stop clearing. Other files, nested folders and symlinks are not cleared. Old application backups are neither removed nor used.

Only iPhone 12 (MGGM3CH/A), iOS 15.6 (19G71), is listed as the user's tested device. Other configurations are not guaranteed.
