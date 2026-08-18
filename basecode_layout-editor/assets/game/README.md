# Game asset pack

The renderer automatically looks for local WebP files using these paths:

- `buildings/{building-id}/level-{level}.webp`
- `walls/level-{level}.webp`
- `scenery/{scenery-id}.{source-extension}`

Example:

```text
assets/game/buildings/1000001/level-10.webp
assets/game/buildings/1000008/level-13.webp
assets/game/walls/level-10.webp
assets/game/scenery/classic.jpg
```

Building sprites should have a transparent background, be centered, and use a consistent isometric camera. A square canvas such as 256x256 or 512x512 works well. Missing files safely fall back to the built-in procedural building renderer.

Only add assets that you are permitted to use. When using Supercell assets, follow the Supercell Fan Content Policy and keep the unofficial fan-content notice visible in the application.

## Included scenery catalog

The `scenery` folder contains 69 Home Village sceneries represented by 71
original source images downloaded from the Clash of Clans Wiki without resizing
or recompression. Full and close-up versions are both retained when available,
while editor rendering uses the close-up variant for a clearer playable grid.

`tools/download-home-village-sceneries.ps1` discovers and downloads the current
Home Village gallery automatically, validates the actual file formats, writes a
source manifest, and updates the scenery catalog without discarding calibrated
grid coordinates.

`tools/calibrate_scenery.py` regenerates `assets/js/scenery-catalog.js`. Each
catalog entry contains four normalized playable-field corners (`top`, `right`,
`bottom`, and `left`) used by the canvas renderer to transform grid coordinates
without stretching the source artwork.
