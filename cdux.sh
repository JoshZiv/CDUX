#! /usr/bin/env bash

# skips - stores arguments to be skipped
skips=""

# define variables with default values
# layout - stores the pane layout
layout="tiled"
# pane_limit - stores the maximum number of panes per window
pane_limit=6

function help () {
    echo \
    "
    Usage: cdux [OPTION]... [DIRECTORY]...
    When in a tmux session, multiple directories can be opened simulataneously.

    OPTIONS
    -l {horizontal|vertical|tiled}      Specify pane layout, default is tiled
    -w                                  Have each directory open in a new window
    -c                                  Pane limit before a new window is used, defaults
                                        at 6"
}

function exists_in_list () {
    # if argument 2 is in the passed in list (argument 1)
    # the return value of grep is used for the function, so return is not explicitly needed
    echo "$2" | tr " " '\n' | grep -F -q -x -- "$1"
}

function is_int () {
    # if arg is not only numbers
    if ! [[ $1 =~ ^[0-9]+$ ]]; then
        # return `false`
        return 1
    fi
    # return `true`
    return 0
}

function equal_layout () {
    # update tmux pane layout, depending on the layout value
    if [ "$layout" == "horizontal" ]; then
        tmux select-layout even-vertical
    elif [ "$layout" == "vertical" ]; then
        tmux select-layout even-horizontal
    else
        tmux select-layout tiled
    fi
}

function cdux_main () {
    # get the name of the current tmux session
    sessionName=$(tmux display-message -p '#S')

    # defualt values
    # panes - tracks number of panes in a window
    panes=$(tmux display-message -p '#{window_panes}')

    # window_offset - user defined offset for window start index
    tmux_base_index=()
    IFS=' ' read -a tmux_base_index <<< "$(tmux show-options -g base-index)"
    window_offset="${tmux_base_index[1]}"

    # window_counter - counts number of windows in session
    window_count=$(( $(tmux display-message -p '#{session_windows}') + window_offset))
    # window - identifies the current window index we want to add a pane to
    if [ "$panes" -eq "$pane_limit" ]; then
        window=$window_count
    else
        window=$(tmux display-message -p '#I')
    fi
    # for each argument passed in
    for x in "$@"; do
        # if this argument is not in the `skips` list
        if ! exists_in_list "$x" "$skips"; then
            # get the absolute path of the passed in path
            abs_path=$(realpath "$x");

            # if the path does not exist
            if [ ! -e "$x" ]; then
                echo "\`$x\` does not exist" >&2 && exit 1
            fi
            # if the path is not a directory, skip it. (we can't open files)
            if [ ! -d "$x" ]; then
                continue
            fi

            # create a new window in the current tmux session
            #                   cur session,   window index,      pane name,     location to open
            tmux new-window -t "$sessionName":"$window_count" -n "$abs_path" -c "$abs_path";

            # if we are not separating into windows, and we are not creating a new window to use
            if [ "$windows" != "1" ] && [ "$window_count" -gt "$window" ]; then
                # join the pane to the current session, at the current window, with the pane name of the path
                tmux join-pane -t "$sessionName":"$window" -s "$abs_path";
                # change the layout, this helps stop tmux refusing to create a new pane because it's too small
                # panes half in size for each new one created
                tmux select-layout tiled
            else
                # increase our current window index
                window_count=$((window_count+1))
            fi

            # increase our pane count, even if we're not joining a pane, when creating a window there is
            # one pane in it to begin with
            panes=$((panes+1))

            # if we have hit the pane limit
            if [ "$panes" -eq "$pane_limit" ]; then
                # reset pane count
                panes=0
                # apply the chosen layout to the window since we can't do this when we move away from this window
                equal_layout
                # make our current window the same as the newest window, this prevents us from trying to join
                # the new window, that SHOULD be a new window, to the previous window.
                # if we have a new window, make it the same as our new window count, this then prevents the
                # above condition from being true, which then stops the pane from being added, after which the
                # window_count is increased since we now have our new window and we don't want to overwrite it
                # with any new windows
                window=$window_count
            fi
        fi
    done

    # finalise the layout
    equal_layout
}

function handle_options () {
    # loop over each argument
    while getopts "c:l:w" o; do
        case "${o}" in
            c)
                # c - count - set pane_limit
                # if the supplied value is an int
                if is_int "$OPTARG"; then
                    # set pane_limit to the supplied value
                    pane_limit=$OPTARG
                    # add the -c to the list of arguments to skip later on
                    skips="$skips -$o"
                    # do the same with the value
                    skips="$skips $OPTARG"
                else
                    # fail with error since the value was not an int
                    echo "\`$OPTARG\` is not an integer" >&2 && exit 1
                fi
                ;;
            l)
                # l - layout - sets the pane layout
                # add the argument and value to our skip list
                skips="$skips -${o}"
                skips="$skips $OPTARG"
                # check the value to see if we can accept it
                case "${OPTARG}" in
                    # long names
                    horizontal)
                        layout=$OPTARG
                        ;;
                    vertical)
                        layout=$OPTARG
                        ;;
                    tiled)
                        layout=$OPTARG
                        ;;
                    # short names
                    h)
                        layout="horizontal"
                        ;;
                    v)
                        layout="vertical"
                        ;;
                    t)
                        layout="tiled"
                        ;;
                    *)
                        # if the value was not recognised, fail but supply the user with the help page for reference
                        help
                        return 1
                        ;;
                esac
                ;;
            w)
                # w - windowed - sets the windows value to true if the user wants each path to be opened in a
                # new window, instead of joined panes
                skips="$skips -$o"
                windows="1"
                ;;
            *)
                # if the argument was not recognised, fail but supply the user with the help page for refrernce
                help
                return 1
                ;;
        esac
    done

    return 0
}

# check if we're in tmux
if [ -z "${TMUX}" ]; then
    echo "Not in tmux"
else
    # if the options were processed succesfully
    if handle_options "$@"; then
        # begin processing paths
        cdux_main "$@"
    fi
fi
