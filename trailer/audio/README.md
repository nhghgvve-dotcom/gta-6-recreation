# Coastline trailer audio

Place audio assets in this folder before running the **Build Coastline Cinematic Trailer** workflow:

- `music.mp3` — required background soundtrack. Use original music or audio you have permission to use.
- `effects.wav` — optional sound-effects bed (engine ambience, ocean/wind, transitions, etc.). It is mixed under the soundtrack.

The workflow loops the audio to cover the video, mixes optional effects, fades the audio near the end, and exports AAC audio inside `Coastline-Trailer.mp4`.

Video frames belong in `trailer/frames/` as `frame_0001.png`, `frame_0002.png`, and so on. The workflow does not create the images, music, or effects; those assets must be added first.
