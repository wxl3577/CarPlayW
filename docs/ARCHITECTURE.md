# Architecture (1.0)

- The locator discovers the random application container and the exact MappedImageCache CarPlay wallpaper directory. Editing supports the three explicitly tested dynamic families; one existing appearance is sufficient.
- A single photo generates both appearances using validated current files as templates. Persistent backup creation/restoration and diagnostic reports are removed. Existing old backup files are left untouched and are not read.
- ATX uses the existing Arm ASTC software codec and Morton32 ordering. Internal format, pixel, content and read-back validation remain mandatory.
- A serial file-operation queue prevents overlapping app scans, writes and clears. Writes keep originals in memory for failure rollback only, not as a user-accessible or persistent backup.
- Clearing independently resolves one exact cache directory, rejects ambiguity and symlinked directories, and lists only direct regular files with recognized image extensions. It never recursively deletes folders or other file types. Content fingerprints are rechecked after confirmation; changed caches require a new confirmation. Rollback memory is limited by a 128 MiB clear-plan cap.
- Successful clearing cannot be undone in the app. iOS must regenerate wallpaper caches through CarPlay. Process termination and concurrent OS activity are not crash-atomic.
- Four fixed tabs separate wallpaper editing, cache viewing/clearing, instructions and app information, without vertical scrolling or draggable sheets. Cache snapshots are decoded from actual file bytes, with pixel dimensions and byte counts. Refresh and post-write scans replace snapshots, never substitute the selected source photo. Only aspect-fit with black padding is exposed; internal codec validation remains unchanged.
