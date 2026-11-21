"""1-minute trailer (demo video for the contest): build/jodal_rookie_trailer.mp4, 1920x1080, 30 fps.

    python tools/make_trailer.py               # record + edit
    python tools/make_trailer.py --edit-only   # edit the last recording again

1. Records tests/trailer_rec.gd with Godot's Movie Maker (MJPEG AVI + sound effects,
   music muted) into build/trailer/raw.avi. A temporary override.cfg in the project
   root sets the 1920x1080 window, 30 fps and the JPEG quality; it is removed afterwards.
2. Cuts the segments listed in build/trailer/markers.txt ("SEG name first last",
   frames) and joins them, fades in and out, lays the game's own music under it
   (bgm_town, bgm_drive during the drive segment) and encodes H.264 + AAC.

Needs ffmpeg: FFMPEG env var, ffmpeg on PATH, or `pip install imageio-ffmpeg`.
Godot: GODOT env var, or the path below.
"""
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / "build" / "trailer"
OUT = ROOT / "build" / "jodal_rookie_trailer.mp4"
GODOT_DEFAULT = Path.home() / "Documents" / "black knight godot" / ".tools" / "godot" / "Godot_v4.5.2-stable_win64_console.exe"
FPS = 30
MUSIC_GAIN = 0.75
SFX_GAIN = 1.35
FADE_IN = 0.4
FADE_OUT = 1.2
OVERRIDE = """[display]

window/size/window_width_override=1920
window/size/window_height_override=1080

[editor]

movie_writer/mjpeg_quality=0.95
movie_writer/fps=30
"""


def ffmpeg_exe() -> str:
    if os.environ.get("FFMPEG"):
        return os.environ["FFMPEG"]
    if shutil.which("ffmpeg"):
        return "ffmpeg"
    import imageio_ffmpeg  # pip install imageio-ffmpeg
    return imageio_ffmpeg.get_ffmpeg_exe()


def record() -> None:
    godot = os.environ.get("GODOT", str(GODOT_DEFAULT))
    WORK.mkdir(parents=True, exist_ok=True)
    override = ROOT / "override.cfg"
    override.write_text(OVERRIDE, encoding="utf-8")
    try:
        subprocess.run([godot, "--path", str(ROOT), "--fixed-fps", str(FPS),
                        "--write-movie", str(WORK / "raw.avi"),
                        "--script", "res://tests/trailer_rec.gd", "--",
                        f"--markers={WORK / 'markers.txt'}"], check=True)
    finally:
        override.unlink(missing_ok=True)


def segments() -> list[tuple[str, float, float]]:
    out = []
    for line in (WORK / "markers.txt").read_text(encoding="utf-8").split("\n"):
        parts = line.split()
        if len(parts) == 4 and parts[0] == "SEG" and int(parts[3]) > int(parts[2]):
            out.append((parts[1], int(parts[2]) / FPS, int(parts[3]) / FPS))
    return out


def edit() -> None:
    segs = segments()
    total = sum(b - a for _, a, b in segs)
    print("segments:", ", ".join(f"{n} {b - a:.1f}s" for n, a, b in segs), f"= {total:.1f}s")
    parts, labels = [], ""
    for i, (_, a, b) in enumerate(segs):
        parts.append(f"[0:v]trim={a:.3f}:{b:.3f},setpts=PTS-STARTPTS[v{i}];"
                     f"[0:a]atrim={a:.3f}:{b:.3f},asetpts=PTS-STARTPTS[a{i}];")
        labels += f"[v{i}][a{i}]"
    # where the drive segment lands in the edited timeline
    t, drive = 0.0, None
    for n, a, b in segs:
        if n == "drive":
            drive = (t, t + b - a)
        t += b - a
    d0, d1 = drive if drive else (total, total)
    music = (
        f"[1:a]atrim=0:{d0 + 0.6:.3f},afade=t=out:st={max(0.0, d0 - 0.3):.3f}:d=0.9,asetpts=PTS-STARTPTS[m1];"
        f"[2:a]atrim=0:{d1 - d0 + 0.6:.3f},afade=t=in:d=0.5,afade=t=out:st={max(0.0, d1 - d0 - 0.3):.3f}:d=0.9,"
        f"asetpts=PTS-STARTPTS,adelay={int(d0 * 1000)}:all=1[m2];"
        f"[3:a]atrim={d0:.3f}:{d0 + total - d1 + 0.5:.3f},asetpts=PTS-STARTPTS,afade=t=in:d=0.8,"
        f"adelay={int(d1 * 1000)}:all=1[m3];"
        f"[m1][m2][m3]amix=inputs=3:normalize=0:duration=longest,volume={MUSIC_GAIN}[mus];"
    )
    graph = (
        "".join(parts)
        + f"{labels}concat=n={len(segs)}:v=1:a=1[cv][ca];"
        + music
        + f"[ca]volume={SFX_GAIN}[sfx];"
        + f"[sfx][mus]amix=inputs=2:normalize=0:duration=first,"
          f"afade=t=in:d={FADE_IN},afade=t=out:st={total - FADE_OUT:.3f}:d={FADE_OUT},alimiter=limit=0.95[aout];"
        + f"[cv]fade=t=in:d={FADE_IN},fade=t=out:st={total - FADE_OUT:.3f}:d={FADE_OUT},"
          f"scale=1920:1080:flags=lanczos,format=yuv420p[vout]"
    )
    audio = ROOT / "assets" / "audio"
    cmd = [ffmpeg_exe(), "-hide_banner", "-loglevel", "error", "-y",
           "-i", str(WORK / "raw.avi"),
           "-stream_loop", "-1", "-i", str(audio / "bgm_town.wav"),
           "-stream_loop", "-1", "-i", str(audio / "bgm_drive.wav"),
           "-stream_loop", "-1", "-i", str(audio / "bgm_town.wav"),
           "-filter_complex", graph, "-map", "[vout]", "-map", "[aout]",
           "-c:v", "libx264", "-preset", "slow", "-crf", "17", "-r", str(FPS),
           "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", str(OUT)]
    subprocess.run(cmd, check=True)
    print(f"wrote {OUT.relative_to(ROOT)} ({OUT.stat().st_size / 1e6:.1f} MB, {total:.1f}s)")


if __name__ == "__main__":
    if "--edit-only" not in sys.argv:
        record()
    edit()
