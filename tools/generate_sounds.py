#!/usr/bin/env python3
"""Generate the village's sound files with the ElevenLabs sound-effects API.

Reads assets/audio/manifest.json, asks ElevenLabs for each missing variation, then trims
silence, normalises and writes 16-bit WAV (one-shots) or OGG (loops) into assets/audio as
<id>_NN so scripts/audio_kit.gd picks them up by name.

    ELEVENLABS_API_KEY=... python3 tools/generate_sounds.py            # everything missing
    python3 tools/generate_sounds.py step_grass_walk duck_quack         # only these ids
    python3 tools/generate_sounds.py --force step_grass_walk            # regenerate
    python3 tools/generate_sounds.py --list                             # show the plan
    python3 tools/generate_sounds.py --priority 2                       # priority 1 and 2
    python3 tools/generate_sounds.py --all                              # every entry

ffmpeg is required for the conversion. Existing files are never overwritten without --force.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AUDIO = os.path.join(ROOT, "assets", "audio")
MANIFEST = os.path.join(AUDIO, "manifest.json")
ENDPOINT = "https://api.elevenlabs.io/v1/sound-generation"


def request(key: str, text: str, seconds: float, influence: float, loop: bool) -> bytes:
    body = {"text": text, "prompt_influence": influence}
    if seconds:
        body["duration_seconds"] = max(0.5, min(30.0, seconds))
    if loop:
        body["loop"] = True
    data = json.dumps(body).encode()
    req = urllib.request.Request(
        ENDPOINT + "?output_format=mp3_44100_128",
        data=data,
        headers={"xi-api-key": key, "Content-Type": "application/json", "Accept": "audio/mpeg"},
    )
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=120) as response:
                return response.read()
        except urllib.error.HTTPError as error:
            detail = error.read().decode(errors="replace")[:300]
            if error.code in (429, 500, 502, 503) and attempt < 3:
                time.sleep(3 * (attempt + 1))
                continue
            raise SystemExit(f"ElevenLabs refused ({error.code}): {detail}")
    raise SystemExit("ElevenLabs did not answer")


def convert(source: str, target: str, loop: bool, gain_db: float) -> None:
    if loop:
        # Loops keep their full length; only level is matched.
        filters = f"volume={gain_db}dB,alimiter=limit=0.89"
        codec = ["-c:a", "libvorbis", "-q:a", "5"]
    else:
        # Trim leading and trailing silence so the transient lands on the trigger.
        filters = (
            "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.02,"
            "areverse,silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.08,areverse,"
            f"volume={gain_db}dB,alimiter=limit=0.89,afade=t=in:d=0.004"
        )
        codec = ["-c:a", "pcm_s16le"]
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", source, "-ac", "1", "-ar", "44100",
         "-af", filters] + codec + [target],
        check=True,
    )


def measured_gain(path: str, target_db: float) -> float:
    """Peak-normalise toward target_db (dBFS) using ffmpeg's volumedetect."""
    result = subprocess.run(
        ["ffmpeg", "-i", path, "-af", "volumedetect", "-f", "null", "-"],
        capture_output=True, text=True,
    )
    peak = 0.0
    for line in result.stderr.splitlines():
        if "max_volume" in line:
            peak = float(line.split(":")[1].strip().split(" ")[0])
    return target_db - peak


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    force = "--force" in sys.argv
    listing = "--list" in sys.argv
    limit = 1
    if "--all" in sys.argv:
        limit = 9
    for index, flag in enumerate(sys.argv):
        if flag == "--priority" and index + 1 < len(sys.argv):
            limit = int(sys.argv[index + 1])
            args = [a for a in args if a != sys.argv[index + 1]]
    with open(MANIFEST) as handle:
        manifest = json.load(handle)
    entries = manifest["sounds"]
    if args:
        entries = [e for e in entries if e["id"] in args]
        missing = set(args) - {e["id"] for e in entries}
        if missing:
            raise SystemExit("Unknown ids: " + ", ".join(sorted(missing)))
    plan = []
    for entry in entries:
        if not args and int(entry.get("priority", 1)) > limit:
            continue
        loop = bool(entry.get("loop", False))
        ext = "ogg" if loop else "wav"
        for n in range(1, int(entry.get("variations", 1)) + 1):
            target = os.path.join(AUDIO, f"{entry['id']}_{n:02d}.{ext}")
            stem = os.path.join(AUDIO, f"{entry['id']}_{n:02d}")
            if not force and any(os.path.exists(stem + "." + e) for e in ("wav", "ogg", "mp3")):
                continue
            plan.append((entry, n, target, loop))
    if listing or not plan:
        print(f"{len(plan)} file(s) to generate")
        for entry, n, target, loop in plan:
            print(f"  {os.path.basename(target):36s} {entry.get('seconds', '-'):>4}s  {entry['prompt'][:70]}")
        return
    key = os.environ.get("ELEVENLABS_API_KEY", "")
    if not key:
        raise SystemExit("Set ELEVENLABS_API_KEY in the environment.")
    if shutil.which("ffmpeg") is None:
        raise SystemExit("ffmpeg is required.")
    print(f"Generating {len(plan)} file(s)")
    with tempfile.TemporaryDirectory() as temp:
        for index, (entry, n, target, loop) in enumerate(plan, 1):
            raw = os.path.join(temp, f"{entry['id']}_{n:02d}.mp3")
            prompt = entry["prompt"]
            if entry.get("variations", 1) > 1:
                # A different take each time, without changing what is asked for.
                prompt = f"{prompt} (take {n})"
            print(f"[{index}/{len(plan)}] {os.path.basename(target)}")
            audio = request(key, prompt, float(entry.get("seconds", 0)), float(entry.get("influence", 0.4)), loop)
            with open(raw, "wb") as handle:
                handle.write(audio)
            gain = measured_gain(raw, float(entry.get("peak_db", -3.0)))
            convert(raw, target, loop, gain)
    print("Done. Godot re-imports new files on the next launch (play.fish imports first).")


if __name__ == "__main__":
    main()
