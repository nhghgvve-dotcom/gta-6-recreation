# Coastline trailer audio

The GitHub Actions workflow renders 432 frames directly from the Coastline Godot project and assembles an 18-second, 1080p cinematic MP4.

The final two camera passes introduce two animated police helicopters using the game's actual `assets/vehicles/police-helicopter.glb` model. Their rotor nodes spin during the reveal. The original generated score adds a rotor-style rhythmic layer during the helicopter sequence.

Optional custom audio:
- `music.mp3` — if present, this replaces the generated soundtrack. Use original music or audio you have permission to use.

The workflow uploads the finished video as the `Coastline-Cinematic-Trailer-MP4` artifact. The renderer is at `Coastline/trailer/render_trailer.gd`.
