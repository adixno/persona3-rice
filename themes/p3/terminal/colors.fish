# Persona 3 terminal colours: fish syntax highlighting + fzf, navy / cyan / ice with a red highlight.
status is-interactive; or return

set -gx FZF_DEFAULT_OPTS "--height=40% --layout=reverse --border=sharp \
--color=bg+:#1238d6,bg:-1,spinner:#ff1f3a,hl:#3fd8ff,fg:#c9e6ff,header:#aaf2ff,\
info:#8fb3d9,pointer:#ff1f3a,marker:#ff1f3a,fg+:#ffffff,prompt:#3fd8ff,hl+:#aaf2ff,border:#3fd8ff"

set -g fish_color_command 3fd8ff --bold --italics
set -g fish_color_keyword 3fd8ff --bold
set -g fish_color_param e6f6ff
set -g fish_color_option aaf2ff
set -g fish_color_quote ffe27a
set -g fish_color_redirection ff5fae
set -g fish_color_operator ff5fae
set -g fish_color_end ff5fae
set -g fish_color_escape ff9ccf
set -g fish_color_error ff1f3a --underline
set -g fish_color_comment 56739f --italics
set -g fish_color_autosuggestion 3f5a85
set -g fish_color_valid_path --underline
set -g fish_color_cancel ff1f3a
set -g fish_color_selection --background=1238d6
set -g fish_color_search_match --background=1238d6
set -g fish_pager_color_prefix 3fd8ff --bold
set -g fish_pager_color_completion e6f6ff
set -g fish_pager_color_description 8fb3d9
set -g fish_pager_color_progress 030a26 --background=3fd8ff
set -g fish_pager_color_selected_background --background=1238d6
