# Reference-led scenery artwork

Generated with the built-in image_gen tool on 2026-10-18 for project nixos-cmd,
asset task nixos-cmd.3. The supplied reference was used as style/composition
guidance, not shipped as project imagery. Original generated asset:
contents/images/canyon-scenery-v1.png. Open sky is transparent so the runtime
can compose weather behind the scenery. Lead inspected the generated output.

Matching transparent cloud layer: contents/images/canyon-clouds-v1.png.
Generated and inspected with the same built-in tool and style reference.
The runtime can drift and color-grade clouds independently from the terrain.

Reference: https://t3.ftcdn.net/jpg/08/18/07/60/360_F_818076000_P60RZCJU3zhiKeqvB33Z4mpTSkkgrSOs.jpg

## Final cloud prompt

Use case: stylized-concept.
Asset type: transparent wide 16:9 cloud-layer PNG for an animated pixel-art landscape wallpaper.
Input image 1 is a STYLE/MOOD reference only. Create an ORIGINAL arrangement, do not recreate the reference.
Primary request: a richly textured atmospheric bank of pixel-art clouds as a SEPARATE sky overlay with genuinely transparent empty sky. Spread several irregular elongated cloud masses across the upper two-thirds of the canvas, including wispy layered mid-sky bands and larger dark clusters near the top edge, with generous open gaps between them. Lower third mostly transparent.
Style: premium dense hand-crafted 16-bit pixel art matching the reference. Intricate organic clusters, crisp pixel contour stepping, small wisps, painterly tonal layering and subtle dither texture. Sophisticated violet/slate cloud shadows with coral/rose/gold lit undersides. Rich and natural, not simple circles, rounded cartoon blobs, flat vector shapes or smooth photographic clouds.
Composition: very wide sky layer, balanced irregular distribution without a single central cloud. No terrain, tree, mountain, skyline, background sky color, sun, moon, stars, rain, text, logo, watermark or border. Empty gaps and the entire backdrop are actual alpha transparency, no painted checkerboard. Only the clouds are opaque/semitransparent. The layer will be drifted and tinted by weather in code; do not bake in a sun or horizon.

## Final scenery prompt

Use case: stylized-concept.
Asset type: layered scenery PNG for a wide 16:9 animated desktop wallpaper.
Input image 1 is a STYLE AND MOOD reference only, not an edit target. Create an ORIGINAL scene with different silhouettes and spatial arrangement, evoking the reference's richly detailed pixel art, dramatic depth, saturated warm/cool light and material richness.
Primary request: one breathtaking detailed pixel-art mountain/canyon vista. A graceful broad-canopied tree rooted on a grassy rocky overlook occupies the LEFT FOREGROUND, its canopy reaching the upper-left quarter and its textured trunk/branching silhouette readable. The overlook slopes off toward a deep valley. Layer many distant mountain ridges and cliff terraces receding toward the center-right horizon. A narrow winding river snakes through the valley, catching subtle light. An unobtrusive rocky/vegetated edge on far right frames the open center vista. Strong depth from deep indigo/plum foreground shadows through violet and rose mid-distance to hazy pale lavender distance.
Style/medium: premium hand-crafted 16-bit pixel-art landscape, dense intentional pixel clusters, dithered gradients and intricate stone strata/cracks, grasses, moss, flowers and foliage texture; natural organic forms and sophisticated atmospheric perspective. Not flat vector art, not minimalist polygons, not low-detail triangular mountains. Broad rich canopy of many clusters, asymmetrical natural cliff forms. Warm pink/coral rim highlights on a cool twilight-neutral terrain; no neon.
CRITICAL LAYER REQUIREMENTS: Render ONLY the tree, grassy overlook, mountain/canyon/valley/river scenery, with a genuinely TRANSPARENT SKY wherever open sky would be, including through gaps in the canopy and above every distant horizon silhouette. The terrain fills the bottom edge and both lower corners; no transparent bottom gap. The broad upper-center/right sky area is empty alpha so the application can paint its own animated sky, sun and clouds BEHIND this scenery. Do not draw sky color, sun, moon, clouds, stars, rain, fog floating above the horizon, or a checkerboard pattern. Distant terrain itself can have atmospheric haze color but sky must be real alpha.
Composition/framing: cinematic wide landscape 16:9, generous sky opening approximately upper half, tree left foreground and winding river leading toward center-right. Scene reaches all image borders, no border/vignette, no text, logo, watermark, frame, characters, houses or buildings. Preserve rich details at full resolution; pixel-art is deliberate texture rather than coarse rectangular blobs.

## Runtime integration (nixos-cmd.4)

Original PNG bytes are preserved. Both assets are 1672 × 941 and retain their
original alpha, including slightly translucent terrain/foliage interior pixels.
The downloaded reference is not included in the package.

SHA-256:

- canyon-scenery-v1.png: e2e43f1d12b6b19617de95ecfd49432a85d1c99a98a2ef5fe5c2ecdfb403db86
- canyon-clouds-v1.png: 169a26d1bfb1c0c82f1bf8593e67410ddd235d2322012b724b91e59446415e5e

ArtworkLayer.qml loads each original into Canvas's explicit image cache with a
bounded decode request. Scenery fits the source width and anchors to the bottom;
clouds form a separate cached layer, enlarged at composition time for bounded
seam-free drift. Sky, sun and rain are drawn separately. No procedural scenery
or circular cloud placeholders remain in the active rendering path.

Sunny preserves the original rich coral/violet colors. Cloudy and rainy grade
asset RGB toward cooler, less saturated tones and darker rain lighting; cloud
RGB becomes white-grey or dark grey. Grading leaves the original alpha intact.
This processing occurs only for image/source-size/weather changes, never on
animation ticks or detail changes. It does not write modified artwork to disk.

The complete layered frame receives final grid sampling. Current full-size
captures are preview-sunny.png, preview-cloudy.png, preview-rainy.png and
preview-coarse.png. The builder inspected the reference and these actual Qt
captures; the reviewer must independently judge their visual correspondence.
Historical procedural/native evidence does not establish this pipeline's native
Plasma behavior. Lead owns a fresh-ID native preview after review.
