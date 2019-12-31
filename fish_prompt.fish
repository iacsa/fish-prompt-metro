# Helper Functions #
function __git_branch_name -d "Get the name of the current Git branch, tag or sha1"
    set -l branch_name (command git symbolic-ref --short HEAD 2>/dev/null)

    if test -z "$branch_name"
        set -l tag_name (command git describe --tags --exact-match HEAD 2>/dev/null)

        if test -z "$tag_name"
            command git rev-parse --short HEAD 2>/dev/null
        else
            printf "%s\n" "$tag_name"
        end
    else
        printf "%s\n" "$branch_name"
    end
end

function __git_is_staged -d "Test if there are changes staged for commit"
    not git diff --cached --no-ext-diff --quiet --exit-code 2>/dev/null
end

function __git_is_dirty -d "Test if there are changes not staged for commit"
    not git diff --no-ext-diff --quiet --exit-code 2>/dev/null
end

function __git_untracked_files -d "Get the number of untracked files in a repository"
    set -l untracked_files (git ls-files --others --exclude-standard (git rev-parse --show-toplevel))
    [ "$untracked_files" != "" ]
end

function __git_is_detached_head -d "Test if the repository is in a detached HEAD state"
    not command git symbolic-ref HEAD 2>/dev/null >/dev/null
end

function __git_is_stashed -d "Test if there are changes in the Git stash"
    command git rev-parse --verify --quiet refs/stash >/dev/null 2>/dev/null
end

function __git_ahead -a ahead behind diverged none
    command git rev-list --count --left-right "@{upstream}...HEAD" 2>/dev/null | command awk "
        /^0\t0/         { print \"$none\"       ? \"$none\"     : \"\";     exit 0 }
        /^[0-9]+\t0/    { print \"$behind\"     ? \"$behind\"   : \"- \";    exit 0 }
        /^0\t[0-9]+/    { print \"$ahead\"      ? \"$ahead\"    : \"+ \";    exit 0 }
        //              { print \"$diverged\"   ? \"$diverged\" : \"± \";    exit 0 }
    "
end


# Main Function #
function fish_prompt
    set -l status_copy $status
    set -l pwd_info (pwd_info "/")
    set -l dir
    set -l base
    set -l base_color 888 161616

    if test "$PWD" = ~
        set base "~"

    else if pwd_is_home
        set dir "~/"
    else
        if test "$PWD" != /
            set dir "/"
        end

        set base (set_color red)"/"
    end

    if test ! -z "$pwd_info[1]"
        set base "$pwd_info[1]"
    end

    if test ! -z "$pwd_info[2]"
        set dir "$dir$pwd_info[2]/"
    end

    if test ! -z "$pwd_info[3]"
        segment $base_color " $pwd_info[3] "
    end

    if set branch_name (__git_branch_name)
        set -l git_color
        set -l git_glyph ""

        if __git_is_staged
            set git_color $git_color black yellow

            if __git_is_dirty
                set git_color $git_color white red
            end

        else if __git_is_dirty
            set git_color $git_color white red

        else if __git_untracked_files
            set git_color $git_color white blue
        end

        if __git_is_detached_head
            set git_glyph "➤"

        else if __git_is_stashed
            set git_glyph "╍╍"
        end

        # If there is no special status, show a default cursor
        if not set -q git_color[1]
            set git_color black green
        end

        set -l prompt
        set -l git_ahead (__git_ahead)

        if test "$branch_name" = master
            set prompt " $git_glyph $git_ahead"
        else
            set prompt " $git_glyph $branch_name $git_ahead"
        end

        if set -q git_color[3]
            segment "$git_color[3]" "$git_color[4]" "$prompt"
            segment black black
            segment "$git_color[1]" "$git_color[2]" " $git_glyph "
        else
            segment "$git_color[1]" "$git_color[2]" "$prompt"
        end
    end

    segment $base_color " $dir"(set_color white)"$base "

    if test ! -z "$SSH_CLIENT"
        set -l color bbb 222

        if test 0 -eq (id -u "$USER")
            set color red 222
        end

        segment $color (host_info " usr@host ")

    else if test 0 -eq (id -u "$USER")
        segment red 222 " \$ "
    end

    if test "$status_copy" -ne 0
        segment red white (set_color -o)" ! "(set_color normal)

    else if last_job_id > /dev/null
        segment white 333 " %% "
    end

    if test "$fish_key_bindings" = "fish_vi_key_bindings"
      switch $fish_bind_mode
        case default
          segment white red "[N]"
        case insert
          segment black green "[I]"
        case replace-one
          segment yellow blue "[R]"
        case visual
          segment white magenta "[V]"
      end
    end

    segment_close
end
