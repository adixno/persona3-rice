# Persona greeting: animated mask + starburst next to fastfetch (~/.config/fastfetch/persona.py).
# The art keeps animating at the first prompt and freezes once anything could scroll the screen.
set -g __greet_pidfile (string join / (set -q XDG_RUNTIME_DIR; and echo $XDG_RUNTIME_DIR; or echo /tmp) greeting-anim.$fish_pid)

function fish_greeting
    set -g __greet_first_prompt 1
    python3 ~/.config/fastfetch/persona.py $__greet_pidfile
end

# prints the animator's pid if it is still running (pids get recycled, so check the cmdline)
function __greet_anim_pid
    test -e $__greet_pidfile; or return 1
    set -l pid (cat $__greet_pidfile)
    string match -q -- '*/fastfetch/*.py*' (string split0 < /proc/$pid/cmdline 2>/dev/null); or return 1
    echo $pid
end

function __greet_anim_stop
    set -l pid (__greet_anim_pid); and kill $pid 2>/dev/null; and kill -CONT $pid 2>/dev/null
    rm -f $__greet_pidfile
end

function __greet_anim_on_prompt --on-event fish_prompt
    # the prompt drawn right under the greeting is fine; any later one has moved the screen
    if set -q __greet_first_prompt
        set -e __greet_first_prompt
        return
    end
    __greet_anim_stop
end
function __greet_anim_on_exec --on-event fish_preexec
    __greet_anim_stop
end

# pause while the kitty window isn't focused (saves battery)
function __greet_anim_pause --on-event fish_focus_out
    set -l pid (__greet_anim_pid); and kill -STOP $pid 2>/dev/null
end
function __greet_anim_resume --on-event fish_focus_in
    set -l pid (__greet_anim_pid); and kill -CONT $pid 2>/dev/null
end
function __greet_anim_exit --on-event fish_exit
    __greet_anim_stop
end

if status is-interactive
    bind ctrl-l '__greet_anim_stop; commandline -f clear-screen'
end
