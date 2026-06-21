# Voxora Icon Composer artwork

The four full-size 1024 × 1024 SVG source layers share one coordinate system:

1. `VoxoraIcon-Background.svg`
2. `VoxoraIcon-Microphone.svg`
3. `VoxoraIcon-Waveform.svg`
4. `VoxoraIcon-Sparkle.svg`

`VoxoraIcon-Preview.svg` is a visual reference only. Icon Composer supplies the platform enclosure mask and Liquid Glass rendering.

The Icon Composer document should enable iOS and watchOS. Keep the central microphone group inside the shared safe area so it survives the iOS rounded-square and watchOS circular masks.

`VoxoraComplicationMark.svg` is separate monochrome artwork for WidgetKit complications. Complications do not use the app icon; import this mark into the widget asset catalog or render it as a template image.
