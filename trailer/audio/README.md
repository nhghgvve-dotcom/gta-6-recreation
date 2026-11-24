# Coastline trailer audio

The GitHub Actions trailer workflow now renders 288 separate frames directly from the actual Coastline Godot project and generates an original electronic soundtrack automatically.

Optional custom audio:
- `music.mp3` — if present, this replaces the generated soundtrack. Use original music or audio you have permission to use.

The workflow creates a 12-second, 24 FPS, 1080p MP4 with the Coastline title card and audio. It uploads the result as the `Coastline-Cinematic-Trailer-MP4` artifact.

You do not need to upload frame images manually anymore. The renderer script is at `Coastline/trailer/render_trailer.gd`; it moves the camera through the procedural city built by the game itself.
