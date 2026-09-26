# App Store screenshots

Upload the six PNG files in `zh-Hans/` and `en/` to the corresponding App Store Connect localizations. Each file is 1320 x 2868 pixels (6.9-inch iPhone portrait). The `source/` directory contains the full-resolution simulator captures used to compose them.

`preview.png` shows both language sets together for review; upload the individual PNG files, not this overview.

The first image shows tone selection, the second model configuration, and the third setup. No API keys or private chat content appear in the captures. These are screenshots, not App Preview videos.

To regenerate after changing copy in `generate.mjs`, run `npm install` and `npm run generate` from this directory. The script uses the local Google Chrome installation on macOS and does not require the screenshot editor project.
