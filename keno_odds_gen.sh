#!/bin/bash
# This is used to generate the rows of the keno odds spreadsheet data.

# Determine if this script was invoked by being executed or sourced.
( [[ -n "$ZSH_EVAL_CONTEXT" && "$ZSH_EVAL_CONTEXT" =~ :file$ ]] \
  || [[ -n "$KSH_VERSION" && $(cd "$(dirname -- "$0")" && printf '%s' "${PWD%/}/")$(basename -- "$0") != "${.sh.file}" ]] \
  || [[ -n "$BASH_VERSION" ]] && (return 0 2>/dev/null) \
) && sourced='YES' || sourced='NO'

KENO_ODDS_GEN_SCRIPT_NAME="$( basename "$0" 2> /dev/null || basename "$BASH_SOURCE" )"
DEFAULT_DRAWS=( '20' )
MIN_DRAWS=1
DEFAULT_PICKS=( $( seq '2' '10' ) )
MIN_PICKS=1
DEFAULT_CELLS=( '80' )
MIN_CELLS=2
MAX_CELLS=1000
DEFAULT_V_STATE="NO"
DEFAULT_V_STATE_OPT_VAL="YES"
DEFAULT_GEN_STATE="YES"
DEFAULT_GEN_STATE_OPT_VAL="YES"

keno_odds_gen_usage () {
    cat << EOF
$KENO_ODDS_GEN_SCRIPT_NAME - Generates data that can be copy and pasted into a spreadsheet to get keno odds.

To use this script:
    1.  Run the script with the desired parameters.
    2.  Copy the output to your clipboard.
            For large data sets, consider piping the script output to a file or pbcopy.
    3.  Select the appropriate cell in your spreadsheet, and paste the data.
            By default, the appropriate cell is A1. But this might not be the case with the --first-row, --left-column, and --no-header options.
    4.  Tell it to split the rows into cells on the semicolons.
    5.  In Google Sheets, reformat the calculation cells to get the values instead of the strings you pasted in.

Usage: ./$KENO_ODDS_GEN_SCRIPT_NAME [-d <val>|--draws <val>] [-p <val>|--picks <val>] [-c|--cells <val>]
         $( echo -e "$KENO_ODDS_GEN_SCRIPT_NAME" | sed 's/./ /g;' ) [--first-row <num>] [--left-column <col>] [--no-header]
         $( echo -e "$KENO_ODDS_GEN_SCRIPT_NAME" | sed 's/./ /g;' ) [-v <state>|--verbose [<state>]] [-g [<state>]|--generate [<state>]]

    -d or --draws defines the number of spots that are drawn by the machine. Default is '${DEFAULT_DRAWS[@]}'.
    -p or --picks defines the number of spots that you have picked. Default is '${DEFAULT_PICKS[@]}'.
    -c or --cells defines the number of cells available to pick. Default is '${DEFAULT_CELLS[@]}'.

    The <val> can be one of the following:
        a) A number, e.g. --draws 20
        b) A range, e.g. --picks 2-10
        c) A comma or space delimited list, e.g. --cells '20 35 40 45'
        d) A combination of b and c, e.g. --picks '2-3 10-15'

    Limitations:
        All draw and pick values must be less than or equal to the maximum of the cell count values.
        All draw values must be greater than or equal to $MIN_DRAWS.
        All pick values must be greater than or equal to $MIN_PICKS.
        Cell counts must be greater than or equal to $MIN_CELLS.
        Cell counts must be less than or equal to $MAX_CELLS.

    --first-row defines what the first row number will be.
        Provided value must be a number.
        The first row is row 1 (just like in all the spreadsheet programs).
        By default, this is 1.
    --left-column defines the left-most column.
        Provided value should be a letter or letters, but can also be a column number, with column A being a 1.
        By default, this is A.
    --no-header indicates that you do not want the header row included in the output.

    Notes:
        * Basically, if you are going to select a cell other than A1 to paste this information into,
          then you should define the --first-row and --left-column appropriately.

    -v or --verbose turns verbosity on or off. The <state> is optional.
        If this option is not provided, the default is '$DEFAULT_V_STATE'.
        If this option is provided without a <state>, the default <state> is '$DEFAULT_V_STATE_OPT_VAL'.
    -g or --generate turns generation on or off. The <state> is optional.
        If this option is not provided, the default is '$DEFAULT_GEN_STATE'.
        If this option is provided without a <state>, the default <state> is '$DEFAULT_GEN_STATE_OPT_VAL'.

    The <state> can be one of the following:
        ON - Turns on the feature
        OFF - Turns off the feature
        YES - Same as 'ON', turns on the feature.
        NO - Same as 'OFF', turns off the feature.

    Only valid combinations of cells, draws, picks, and hits are generated.
    An input combination is only valid if both the draws and picks are less than or equal to the cell count.
        Examples:
            ./$KENO_ODDS_GEN_SCRIPT_NAME --cells 10 80 --draws 20 --picks 10
                This configuration will not be attempted:
                    Cells: 10, Draws: 20, Picks: 10
                This configuration will be generated:
                    Cells: 80, Draws: 20, Picks: 10
            ./$KENO_ODDS_GEN_SCRIPT_NAME --cells 40 80 --draws 20 --picks 50
                This configuration will not be attempted:
                    Cells: 40, Draws: 20, Picks: 50
                This configuration will be generated:
                    Cells: 80, Draws: 20, Picks: 50
            ./$KENO_ODDS_GEN_SCRIPT_NAME --cells 40 --draws 20 55 --picks 15 50
                These configurations will not be attempted:
                    Cells: 40, Draws: 55, Picks: 15
                    Cells: 40, Draws: 55, Picks: 50
                    Cells: 40, Draws: 20, Picks: 50
                This configuration will be generated:
                    Cells: 40, Draws: 20, Picks: 15
            ./$KENO_ODDS_GEN_SCRIPT_NAME --cells 20 80 --draws 10 25 --picks 10 35
                These configurations will not be attempted:
                    Cells: 20, Draws: 10, Picks: 35
                    Cells: 20, Draws: 25, Picks: 10
                    Cells: 20, Draws: 25, Picks: 35
                These configurations will be generated:
                    Cells: 20, Draws: 10, Picks: 10
                    Cells: 80, Draws: 10, Picks: 10
                    Cells: 80, Draws: 10, Picks: 35
                    Cells: 80, Draws: 25, Picks: 10
                    Cells: 80, Draws: 25, Picks: 35

EOF
}

# Usage: min <values ...>
min () {
    local retval
    retval="$1"
    shift
    while [[ "$#" -gt '0' ]]; do
        if [[ "$1" -lt "$retval" ]]; then
            retval="$1"
        fi
        shift
    done
    echo -E -n "$retval"
}

# Usage: max <values ...>
max () {
    local retval
    retval="$1"
    shift
    while [[ "$#" -gt '0' ]]; do
        if [[ "$1" -gt "$retval" ]]; then
            retval="$1"
        fi
        shift
    done
    echo -E -n "$retval"
}

# Parses an input string into well-formed values.
# If there is something wrong with the input, this function will have an exit code of 1.
# Usage: parse_input_val <input> || there_was_a_problem="YES"
parse_input_val () {
    local inputs outputs
    inputs="$@"
    outputs=()
    if [[ "$inputs" =~ [[:alpha:]] ]]; then
        return 1
    fi
    for input in $( echo -E "$inputs" | sed -E 's/[^[:digit:]\-]+/ /g; s/ *- */-/g;' ); do
        if [[ "$input" =~ ^([[:digit:]]+)-([[:digit:]]+)$ ]]; then
            outputs+=( $( seq "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" ) )
        elif [[ -n "$input" ]]; then
            outputs+=( "$input" )
        fi
    done
    if [[ "${#outputs[@]}" -eq '0' ]]; then
        return 1
    fi
    echo -E -n "${outputs[@]}"
    return 0
}

# Usage: uppercase <string>
#   or   <do stuff> | uppercase
uppercase () {
    if [[ -n "$@" ]]; then
        printf '%s' "$@" | uppercase
        return 0
    fi
    tr "[:lower:]" "[:upper:]"
}

# Usage: lowercase <string>
#   or   <do stuff> | lowercase
lowercase () {
    if [[ -n "$@" ]]; then
        printf '%s' "$@" | lowercase
        return 0
    fi
    tr "[:upper:]" "[:lower:]"
}

# Usage: join <delimiter> <strings ...>
join () {
    local d retval v
    d="$1"
    shift
    echo -n "$1"
    shift
    for v in "$@"; do
        echo -n "$d$1"
        shift
    done
}

# Converts a column number to it's letters. 1 -> A
# Usage: col_index_to_letters <number>
col_index_to_letters () {
    local idx idx_this idx_1
    idx="$1"
    idx=$(( idx - 1 ))
    if [[ "$idx" -ge '26' ]]; then
        idx_this=$(( idx % 26 ))
        col_index_to_letters $(( idx / 26 ))
    else
        idx_this="$idx"
    fi
    idx_1=$(( idx_this % 10 ))
    if [[ "$idx_this" -ge '20' ]]; then
        printf '%d' "$idx_1" | tr '012345' 'UVWXYZ'
    elif [[ "$idx_this" -ge '10' ]]; then
        printf '%d' "$idx_1" | tr '0123456789' 'KLMNOPQRST'
    else
        printf '%d' "$idx_1" | tr '0123456789' 'ABCDEFGHIJ'
    fi
}

# Converts a column letter to it's index. A -> 1
# Usage: col_letters_to_index
col_letters_to_index () {
    local col l retval
    col="$1"
    retval=0
    for l in $( echo -E "$col" | sed -E 's/(.)/\1 /g' | uppercase ); do
        retval=$(( retval * 26 ))
        if [[ "$l" =~ [ABCDEFGHIJ] ]]; then
            retval=$(( retval + $( printf '%s' "$l" | tr 'ABCDEFGHIJ' '0123456789' ) ))
        elif [[ "$l" =~ [KLMNOPQRST] ]]; then
            retval=$(( retval + $( printf '%s' "$l" | tr 'KLMNOPQRST' '0123456789' ) + 10 ))
        elif [[ "$l" =~ [UVWXYZ] ]]; then
            retval=$(( retval + $( printf '%s' "$l" | tr 'UVWXYZ' '012345' ) + 20 ))
        fi
        retval=$(( retval + 1 ))
    done
    printf '%d' "$retval"
}

# Usage: generate_keno_odds_rows <draws> <picks> <cells> <verbose> <first_row> <left_cell> <no_header>
generate_keno_odds_rows () {
    local draws picks cells verbose first_row left_cell no_header header_cells row_num left_cell_idx \
          cell_col draw_col pick_col hit_col hit_comb_col miss_comb_col pick_comb_col odds_col chance_col \
          cell draw pick hit row_cells
    draws="$1"
    picks="$2"
    cells="$3"
    verbose="$4"
    first_row="$5"
    left_cell="$6"
    no_header="$7"
    header_cells=( "cells" "draws" "picks" "hits" "hit combos" "miss combos" "pick combos" "odds (1 in ...)" "% chance" )
    if [[ -n "$first_row" ]]; then
        row_num="$first_row"
    else
        row_num='1'
    fi
    if [[ -n "$left_cell" ]]; then
        if [[ "$left_cell" =~ ^[[:digit:]]+$ ]]; then
            left_cell_idx="$( max "$left_cell" '1' )"
        else
            left_cell_idx="$( col_letters_to_index "$left_cell" )"
        fi
    else
        left_cell_idx='1'
    fi
    if [[ -z "$no_header" ]]; then
        echo -E "$( join ';' "${header_cells[@]}" )"
        row_num=$(( row_num + 1 ))
    fi
    cell_col="$( col_index_to_letters "$left_cell_idx" )"
    draw_col="$( col_index_to_letters "$(( left_cell_idx + 1 ))" )"
    pick_col="$( col_index_to_letters "$(( left_cell_idx + 2 ))" )"
    hit_col="$( col_index_to_letters "$(( left_cell_idx + 3 ))" )"
    hit_comb_col="$( col_index_to_letters "$(( left_cell_idx + 4 ))" )"
    miss_comb_col="$( col_index_to_letters "$(( left_cell_idx + 5 ))" )"
    pick_comb_col="$( col_index_to_letters "$(( left_cell_idx + 6 ))" )"
    odds_col="$( col_index_to_letters "$(( left_cell_idx + 7 ))" )"
    chance_col="$( col_index_to_letters "$(( left_cell_idx + 8 ))" )"
    for cell in $cells; do
        for draw in $draws; do
            if [[ "$cell" -ge "$draw" ]]; then
                for pick in $picks; do
                    if [[ "$cell" -ge "$pick" ]]; then
                        for hit in $( seq "$( max '0' "$(( ( cell - draw - pick ) * -1 ))" )" "$( min "$draw" "$pick" )" ); do
                            row_cells=( "$cell" "$draw" "$pick" "$hit"
                                        "=COMBIN($draw_col$row_num,$hit_col$row_num)"
                                        "=COMBIN($cell_col$row_num-$draw_col$row_num,$pick_col$row_num-$hit_col$row_num)"
                                        "=COMBIN($cell_col$row_num,$pick_col$row_num)"
                                        "=$pick_comb_col$row_num/($hit_comb_col$row_num*$miss_comb_col$row_num)"
                                        "=100/$odds_col$row_num"
                            )
                            echo -E "$( join ';' "${row_cells[@]}" )"
                            row_num=$(( row_num + 1 ))
                        done
                    fi
                done
            fi
        done
    done
}

#If sourced, stop here. We've loaded all the pieces.
if [[ "$sourced" == 'YES' ]]; then
    return 0
fi

# Get user input
DRAWS=()
PICKS=()
CELLS=()
errors=()
VERBOSE="$DEFAULT_V_STATE"
DO_GEN="$DEFAULT_GEN_STATE"
while [[ "$#" -gt '0' ]]; do
    option="$( lowercase "$1" )"
    case "$option" in
    -h|--help)
        keno_odds_gen_usage
        exit 0
        ;;
    -d|--draws)
        vals=''
        while [[ "$#" -gt '1' && ! "$2" =~ ^- && ! "$2" =~ [[:alpha:]] ]]; do
            vals="$vals $2"
            shift
        done
        if [[ "$vals" =~ ^[[:space:]]*$ ]]; then
            errors+=( "No draws defined after $1 option." )
        fi
        parsed_vals="$( parse_input_val "$vals" )" || parse_problem='YES'
        if [[ "parse_problem" == 'YES' ]]; then
            errors+=( "Unable to parse draws from '$vals'" )
        fi
        DRAWS+=( $parsed_vals )
        ;;
    -p|--picks)
        vals=''
        while [[ "$#" -gt '1' && ! "$2" =~ ^- && ! "$2" =~ [[:alpha:]] ]]; do
            vals="$vals $2"
            shift
        done
        if [[ "$vals" =~ ^[[:space:]]*$ ]]; then
            errors+=( "No picks defined after $1 option." )
        fi
        parsed_vals="$( parse_input_val "$vals" )" || parse_problem='YES'
        if [[ "parse_problem" == 'YES' ]]; then
            errors+=( "Unable to parse picks from '$vals'" )
        fi
        PICKS+=( $parsed_vals )
        ;;
    -c|--cells|-n)
        vals=''
        while [[ "$#" -gt '1' && ! "$2" =~ ^- && ! "$2" =~ [[:alpha:]] ]]; do
            vals="$vals $2"
            shift
        done
        if [[ "$vals" =~ ^[[:space:]]*$ ]]; then
            errors+=( "No cells defined after $1 option." )
        fi
        parsed_vals="$( parse_input_val "$vals" )" || parse_problem='YES'
        if [[ "parse_problem" == 'YES' ]]; then
            errors+=( "Unable to parse cells from '$vals'" )
        fi
        CELLS+=( $parsed_vals )
        ;;
    --first-row|--1st-row|--top-row)
        if [[ -n "$2" && "$2" =~ ^[[:digit:]]+$ ]]; then
            FIRST_ROW="$2"
            shift
        else
            errors+=( "Invalid first row value '$2'" )
        fi
        ;;
    --left-col|--left-column)
        if [[ -n "$2" && ( "$2" =~ ^[[:alpha:]]+$ || "$2" =~ ^[[:digit:]]$ ) ]]; then
            LEFT_COLUMN="$2"
            shift
        else
            errors+=( "Invalid left column value '$2" )
        fi
        ;;
    --no-header)
        NO_HEADER='YES'
        ;;
    -v|--verbose)
        if [[ -n "$2" && ! "$2" =~ ^- ]]; then
            val="$( uppercase "$2" )"
            case "$val" in
            YES|ON) VERBOSE="YES"; shift;;
            NO|OFF) VERBOSE="NO"; shift;;
            *) errors+=( "Invalid $1 setting [$2]" );;
            esac
        else
            VERBOSE="$DEFAULT_V_STATE_OPT_VAL"
        fi
        ;;
    -g|--gen|--generate)
        if [[ -n "$2" && ! "$2" =~ ^- ]]; then
            val="$( uppercase "$2" )"
            case "$val" in
            YES|ON) DO_GEN="YES"; shift;;
            NO|OFF) DO_GEN="NO"; shift;;
            *) errors+=( "Invalid $1 setting [$2]" );;
            esac
        else
            DO_GEN="$DEFAULT_GEN_STATE_OPT_VAL"
        fi
        ;;
    *)
        errors+=( "Unknown option [$1]" )
        ;;
    esac
    shift
done

# Fill in defaults for anything not provided
if [[ "${#DRAWS[@]}" -eq '0' ]]; then
    DRAWS+=( "${DEFAULT_DRAWS[@]}" )
fi
if [[ "${#PICKS[@]}" -eq '0' ]]; then
    PICKS+=( "${DEFAULT_PICKS[@]}" )
fi
if [[ "${#CELLS[@]}" -eq '0' ]]; then
    CELLS+=( "${DEFAULT_CELLS[@]}" )
fi

# Some final valiation
for cell in "${CELLS[@]}"; do
    if [[ "$cell" -lt "$MIN_CELLS" ]]; then
        errors+=( "Cell count [$cell] cannot be less than [$MIN_CELLS]." )
    elif [[ "$cell" -gt "$MAX_CELLS" ]]; then
        errors+=( "Cell count [$cell] cannot be greater than [$MAX_CELLS]." )
    fi
done
cell_gen_max="$( max "${CELLS[@]}" )"
for draw in "${DRAWS[@]}"; do
    if [[ "$draw" -lt "$MIN_DRAWS" ]]; then
        errors+=( "Draw value [$draw] cannot be less than [$MIN_DRAWS]." )
    elif [[ "$draw" -gt "$cell_gen_max" ]]; then
        errors+=( "Draw value [$draw] cannot be greater than the max cell count [$cell_gen_max]." )
    fi
done
for pick in "${PICKS[@]}"; do
    if [[ "$pick" -lt "$MIN_PICKS" ]]; then
        errors+=( "Pick value [$pick] cannot be less than [$MIN_PICKS]." )
    elif [[ "$pick" -gt "$cell_gen_max" ]]; then
        errors+=( "Pick value [$pick] cannot be greater than the max cell count [$cell_gen_max]." )
    fi
done

if [[ "${#errors[@]}" -gt '0' ]]; then
    for error in "${errors[@]}"; do
        >&2 echo -E "$error"
    done
    if [[ "${#errors[@]}" -gt '1' ]]; then
        >&2 echo -E "For more info: ./$KENO_ODDS_GEN_SCRIPT_NAME --help"
    fi
    exit 1
fi

# And do what you're supposed to do
CMD=( generate_keno_odds_rows "$( echo -E "${DRAWS[@]}" )" "$( echo -E "${PICKS[@]}" )" "$( echo -E "${CELLS[@]}" )" "$VERBOSE" "$FIRST_ROW" "$LEFT_COLUMN" "$NO_HEADER" )
if [[ "$VERBOSE" == 'YES' ]]; then
    echo "Draws: ( ${DRAWS[@]} )"
    echo "Picks: ( ${PICKS[@]} )"
    echo "Cells: ( ${CELLS[@]} )"
    echo "Verbose: $VERBOSE"
    echo "Generate: $DO_GEN"
    echo -e -n "\033[1;37m"
    echo -E -n "${CMD[0]}"
    for p in "${CMD[@]:1}"; do
        echo -E -n " \"$p\""
    done
    echo -e "\033[0m"
fi
if [[ "$DO_GEN" == 'YES' ]]; then
    "${CMD[@]}"
fi
