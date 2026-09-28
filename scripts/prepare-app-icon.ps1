param([Parameter(Mandatory=$true)][string]$Source)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$assetDirectory = Join-Path $PSScriptRoot '../CarPlayW/Assets.xcassets/AppIcon.appiconset'
$sourceImage = [System.Drawing.Image]::FromFile((Resolve-Path -LiteralPath $Source).Path)
try {
    if ($sourceImage.Width -ne $sourceImage.Height) { throw 'App icon source must be square.' }
    foreach ($size in @(40, 60, 58, 87, 80, 120, 180, 1024)) {
        $bitmap = New-Object System.Drawing.Bitmap($size, $size, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb))
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $graphics.Clear([System.Drawing.Color]::White)
            $graphics.DrawImage($sourceImage, 0, 0, $size, $size)
            $bitmap.Save((Join-Path $assetDirectory "AppIcon-$size.png"), [System.Drawing.Imaging.ImageFormat]::Png)
        } finally {
            $graphics.Dispose()
            $bitmap.Dispose()
        }
    }
} finally { $sourceImage.Dispose() }
