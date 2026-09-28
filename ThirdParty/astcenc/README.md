# Arm astcenc (vendored)

Unmodified core `.cpp` / `.h` files from Arm astcenc 5.3.0:
https://github.com/ARM-software/astc-encoder/tree/30aabb3f42406df45a910d8496f9bee17eeba9bb/Source

Copyright Arm Limited and contributors; Apache-2.0. The full license is bundled
in `CarPlayW/Resources/ASTC-LICENSE.txt`. No CLI or image-loader code is used.
The app bridge restricts input to bounded, single-image LDR ASTC 4x4 data.

The macro-tile ordering is implemented separately in Swift and verified against
the supplied iOS 15.6 wallpaper samples; the codec itself only sees linear ASTC.
