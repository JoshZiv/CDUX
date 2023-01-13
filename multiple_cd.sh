#! /usr/bin/bash

skips=""
layout="tiled"
pane_limit=6

function help () {
    echo \
    "
    Usage: cdx [OPTION]... [DIRECTORY]...
    When in a tmux session, multiple directories can be opened simulataneously.

    OPTIONS
    -l {horizontal|vertical|tiled}      Specify pane layout, default is tiled
    -w                                  Have each directory open in a new window
    -c                                  Pane limit before a new window is used, defaults
                                        at 6"
}

function exists_in_list () {
    echo "$2" | tr " " '\n' | grep -F -q -x -- "$1"
}

function is_int () {
    if ! [[ $1 =~ ^[0-9]+$ ]]; then
        return 1
    fi

    return 0
}

function equal_layout () {
    if [ "$layout" == "horizontal" ]; then
        tmux select-layout even-vertical
    elif [ "$layout" == "vertical" ]; then
        tmux select-layout even-horizontal
    else
        tmux select-layout tiled
    fi
}

function cdx_main () {
    sessionName=$(tmux display-message -p '#S')

    panes=1
    count=1
    window=0
    for x in "$@"; do
        if ! exists_in_list "$x" "$skips"; then
            abs_path=$(realpath "$x");

            if [ ! -e "$x" ]; then
                echo "\`$x\` does not exist" >&2 && exit 1
            fi

            if [ ! -d "$x" ]; then
                continue
            fi

            tmux new-window -t "$sessionName":"$count" -n "$abs_path" -c "$x";

            if [ "$windows" != "1" ] && [ $count -gt $window ]; then
                tmux join-pane -t "$sessionName":"$window" -s "$abs_path";

                tmux select-layout tiled
            else
                count=$((count+1))
            fi

            panes=$((panes+1))

            if [ "$panes" -eq "$pane_limit" ]; then
                panes=0
                equal_layout

                window=$count
            fi
        fi
    done

    equal_layout
}

function handle_options () {
    while getopts "c:l:w" o; do
        case "${o}" in
            c)
                if is_int "$OPTARG"; then
                    pane_limit=$OPTARG

                    skips="$skips -$o"
                    skips="$skips $OPTARG"
                else
                    echo "\`$OPTARG\` is not an integer" >&2 && exit 1
                fi
                ;;
            l)
                skips="$skips -${o}"
                skips="$skips $OPTARG"
                case "${OPTARG}" in
                    horizontal)
                        layout=$OPTARG
                        ;;
                    vertical)
                        layout=$OPTARG
                        ;;
                    *)
                        help
                        return 1
                        ;;
                esac
                ;;
            w)
                skips="$skips -$o"
                windows="1"
                ;;
            *)
                skips="$skips -$o"
                help
                return 1
                ;;
        esac
    done

    return 0
}

if [ -z "${TMUX}" ]; then
    echo "Not in tmux"
else
    if handle_options "$@"; then
        cdx_main "$@"
    fi
fi
