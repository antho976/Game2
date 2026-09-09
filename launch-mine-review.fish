#!/usr/bin/env fish
# Separate art walkthrough; never shares the live hub's save directory.
set review_root (path resolve (path dirname (status filename)))
set -lx XDG_DATA_HOME "$review_root/.runtime/mine-review/data"
set -lx XDG_CONFIG_HOME "$review_root/.runtime/mine-review/config"
set godot_bin (command -s godot)
if test -z "$godot_bin"
    set godot_bin /home/anthony/.local/bin/godot
end
if not test -x "$godot_bin"
    echo 'Godot is required to open the mine walkthrough.' >&2
    exit 1
end
cd "$review_root"
exec "$godot_bin" --path "$review_root" res://scenes/first_portal_walkthrough.tscn $argv
