#!/usr/bin/env fish
set project_dir (path dirname (path resolve (status filename)))
set -lx XDG_DATA_HOME "$project_dir/.runtime/data"
set -lx XDG_CONFIG_HOME "$project_dir/.runtime/config"
set -lx XDG_CACHE_HOME "$project_dir/.runtime/cache"
set godot_executable (command -s godot)
if test -z "$godot_executable"
    set godot_executable "$HOME/.local/bin/godot"
end
if not test -x "$godot_executable"
    echo "Godot 4 is required."
    exit 1
end
"$godot_executable" --headless --editor --path "$project_dir" --import --quiet
or exit $status
exec "$godot_executable" --path "$project_dir" $argv
