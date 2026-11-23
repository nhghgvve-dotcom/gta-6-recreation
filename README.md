# Coastline — Open-World Prototype

An original, lightweight tropical open-world driving and exploration prototype built with Godot 4.4.1.

## Controls
- WASD: move / drive
- Mouse: camera
- Shift: sprint
- Space: jump
- E: enter or exit the car
- Escape: release or capture the mouse

## Build a Windows executable
The GitHub Actions workflow in `.github/workflows/build-windows.yml` exports a Windows x86_64 build. Open the repository's **Actions** tab and select the Windows build workflow if it is not triggered automatically. Download the `Coastline-Windows` artifact. It contains `Coastline.exe` and its `.pck` data file; keep both together.

This is an early prototype, not a recreation of GTA 6 or a finished commercial game.

## Character model credits
The human character models used by Coastline are by vinish.dev, licensed under Creative Commons Attribution 4.0 (CC BY 4.0). Models included: Casual Man, Casual Woman, Business Man, Business Woman, Construction Worker, Doctor, and Runner. Source: https://vinish.dev/free-3d-models/people


## Galaxy Remote Touch Controller

The Windows build can host a touch controller page for a Galaxy phone or tablet on the same Wi-Fi network. Launch Coastline on Windows and read the **GALAXY REMOTE** address shown along the bottom of the game window. Open that address in Chrome on the Galaxy. If Windows Firewall asks, allow Coastline on your private network. The Galaxy page provides a joystick, camera-look area, and ACTION, JUMP, RUN, BRAKE, FIRE, and PAUSE buttons.

Keep both devices on the same trusted Wi-Fi network. The controller is intended for local-network use; do not expose port 8765 to the internet.
