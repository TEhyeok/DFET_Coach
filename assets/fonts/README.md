# Bundled fonts

## Initial research assets (inactive)

The following two files are retained to reproduce the typography comparison. They are not registered in the current `pubspec.yaml` and are not used by the app theme.

### SUIT Variable

- Source: <https://github.com/sun-typeface/SUIT>
- Version: `v2.0.5`
- Commit: `55118d981336d8fce005eb62888c12c0568ef7b0`
- Research use: Korean UI, headings, body, labels
- License: `licenses/SUIT-OFL.txt`

### Wanted Sans Std Variable

- Source: <https://github.com/wanteddev/wanted-sans>
- Commit: `02c9b822349c188ada95f9e2d90c2ed18f853235`
- Research use: Latin-only scores, changes, biomarker codes and units
- License: `licenses/WantedSans-OFL.txt`

Both research fonts are pinned so the original comparison can be reproduced.

## Human Signal B typography

- Source: <https://github.com/google/fonts>
- Commit: `2d85e20401920891efb7cd6272d6339685df2820`
- `IBM Plex Sans KR`: Korean UI, body, labels (`400`, `500`, `600`, `700`)
- `Gowun Batang`: Today Signal display headlines (`700`)
- `IBM Plex Mono`: scores, changes, biomarker codes and units (`600`, `700`)
- Licenses: `licenses/IBMPlexSansKR-OFL.txt`, `licenses/GowunBatang-OFL.txt`, `licenses/IBMPlexMono-OFL.txt`

These files implement the selected `B · 휴먼 신호` direction and are bundled for identical offline rendering on iOS and Android.
