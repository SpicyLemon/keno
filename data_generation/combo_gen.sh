#!/bin/bash
# This is used to generate the rows of combination calcs to put into a spreadsheet.

# Determine if this script was invoked by being executed or sourced.
( [[ -n "$ZSH_EVAL_CONTEXT" && "$ZSH_EVAL_CONTEXT" =~ :file$ ]] \
  || [[ -n "$KSH_VERSION" && $(cd "$(dirname -- "$0")" && printf '%s' "${PWD%/}/")$(basename -- "$0") != "${.sh.file}" ]] \
  || [[ -n "$BASH_VERSION" ]] && (return 0 2>/dev/null) \
) && sourced='YES' || sourced='NO'

COMB_GEN_SCRIPT_NAME="$( basename "$0" 2> /dev/null || basename "$BASH_SOURCE" )"
MIN_N=1
MAX_N=1000
DEFAULT_FIRST_ROW=1
DEFAULT_LEFT_COL='A'
DEFAULT_N_VALUES=( '10' )
DEFAULT_V_STATE="NO"
DEFAULT_V_STATE_OPT_VAL="YES"
DEFAULT_GEN_STATE="YES"
DEFAULT_GEN_STATE_OPT_VAL="YES"

keno_odds_gen_usage () {
    cat << EOF
$COMB_GEN_SCRIPT_NAME - Generates data that can be copy and pasted into a spreadsheet to get combination values.

To use this script:
    1.  Run the script with the desired parameters.
    2.  Copy the output to your clipboard.
            For large data sets, consider piping the script output to a file or pbcopy.
    3.  Select the appropriate cell in your spreadsheet, and paste the data.
            By default, the appropriate cell is $DEFAULT_LEFT_COL$DEFAULT_FIRST_ROW. But this might not be the case with the --first-row, --left-column, and --no-header options.
    4.  Tell it to split the rows into cells on the semicolons.
    5.  In Google Sheets, reformat the calculation cells to get the values instead of the strings you pasted in.

Usage: ./$COMB_GEN_SCRIPT_NAME [-n <val>|--n-values <val>]
         $( echo -e "$COMB_GEN_SCRIPT_NAME" | sed 's/./ /g;' ) [--first-row <num>] [--left-column <col>] [--no-header]
         $( echo -e "$COMB_GEN_SCRIPT_NAME" | sed 's/./ /g;' ) [-v <state>|--verbose [<state>]] [-g [<state>]|--generate [<state>]]

    -n defines the n value(s) in nCk. Default is '${DEFAULT_N_VALUES[@]}'.
        All k values >= 0 and <= n are generated for each n.

    The <val> can be one of the following:
        a) A number, e.g. -n 20
        b) A range, e.g. -n 2-10
        c) A comma or space delimited list, e.g. -n '20 35 40 45'
        d) A combination of b and c, e.g. -n '2-3 10-15'

    Limitations:
        All n values must be greater than or equal to $MIN_N.
        All n values must be less than or equal to $MAX_N.

    --first-row defines what the first row number will be.
        Provided value must be a number.
        The first row is row 1 (just like in all the spreadsheet programs).
        By default, this is '$DEFAULT_FIRST_ROW'.
    --left-column defines the left-most column.
        Provided value should be a letter or letters, but can also be a column number, with column A being a 1.
        By default, this is '$DEFAULT_LEFT_COL'.
    --no-header indicates that you do not want the header row included in the output.

    Notes:
        * Basically, if you are going to select a cell other than $DEFAULT_LEFT_COL$DEFAULT_FIRST_ROW to paste this information into,
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

# Usage: generate_combination_rows <n values> <verbose> <first_row> <left_column> <no_header>
generate_combination_rows () {
    local n_values verbose first_row left_col no_header d header_cells row_num left_col_idx \
          cell_n cell_k cell_comb \
          n k
    n_values="$1"
    verbose="$2"
    first_row="$3"
    left_col="$4"
    no_header="$5"
    d=';'
    header_cells=( "n" "k" "nCk" )
    if [[ -n "$first_row" ]]; then
        row_num="$first_row"
    else
        row_num='1'
    fi
    if [[ -n "$left_col" ]]; then
        if [[ "$left_col" =~ ^[[:digit:]]+$ ]]; then
            left_col_idx="$( max "$left_col" '1' )"
        else
            left_col_idx="$( col_letters_to_index "$left_col" )"
        fi
    else
        left_col_idx='1'
    fi
    if [[ -z "$no_header" ]]; then
        echo -E "$( join "$d" "${header_cells[@]}" )"
        row_num=$(( row_num + 1 ))
    fi
    cell_n="$( col_index_to_letters "$left_col_idx" )"
    cell_k="$( col_index_to_letters "$(( left_col_idx + 1 ))" )"
    cell_comb="$( col_index_to_letters "$(( left_col_idx + 2 ))" )"
    for n in $n_values; do
        for k in $( seq 0 "$n" ); do
            row_cells=( "$n" "$k" "=COMBIN($cell_n$row_num,$cell_k$row_num)" )
            echo -E "$( join "$d" "${row_cells[@]}" )"
            row_num=$(( row_num + 1 ))
        done
    done
}

#If sourced, stop here. We've loaded all the pieces.
if [[ "$sourced" == 'YES' ]]; then
    return 0
fi

# Get user input
N_VALUES=()
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
    -n|--n-values)
        vals=''
        while [[ "$#" -gt '1' && ! "$2" =~ ^- && ! "$2" =~ [[:alpha:]] ]]; do
            vals="$vals $2"
            shift
        done
        if [[ "$vals" =~ ^[[:space:]]*$ ]]; then
            errors+=( "No n values defined after $1 option." )
        else
            parsed_vals="$( parse_input_val "$vals" )" || parse_problem='YES'
            if [[ "parse_problem" == 'YES' ]]; then
                errors+=( "Unable to parse n values from '$vals'" )
            fi
            N_VALUES+=( $parsed_vals )
        fi
        ;;
    --first-row|--1st-row|--top-row)
        if [[ -n "$2" && "$2" =~ ^[[:digit:]]+$ ]]; then
            FIRST_ROW="$2"
            shift
        else
            errors+=( "Invalid first row value '$2'" )
        fi
        ;;
    --left-column|--left-col)
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
if [[ "${#N_VALUES[@]}" -eq '0' ]]; then
    N_VALUES+=( "${DEFAULT_N_VALUES[@]}" )
fi
if [[ -z "$FIRST_ROW" ]]; then
    FIRST_ROW="$DEFAULT_FIRST_ROW"
fi
if [[ -z "$LEFT_COL" ]]; then
    LEFT_COL="$DEFAULT_LEFT_COL"
fi

# Some final valiation
for n in "${N_VALUES[@]}"; do
    if [[ "$n" -lt "$MIN_N" ]]; then
        errors+=( "n value [$n] cannot be less than [$MIN_N]." )
    elif [[ "$n" -gt "$MAX_N" ]]; then
        errors+=( "n value [$n] cannot be greater than [$MAX_N]." )
    fi
done

if [[ "${#errors[@]}" -gt '0' ]]; then
    for error in "${errors[@]}"; do
        >&2 echo -E "$error"
    done
    if [[ "${#errors[@]}" -gt '1' ]]; then
        >&2 echo -E "For more info: ./$COMB_GEN_SCRIPT_NAME --help"
    fi
    exit 1
fi

# And do what you're supposed to do
CMD=( generate_combination_rows "$( echo -E "${N_VALUES[@]}" )" "$VERBOSE" "$FIRST_ROW" "$LEFT_COLUMN" "$NO_HEADER" )
if [[ "$VERBOSE" == 'YES' ]]; then
    echo "N Values: ( ${N_VALUES[@]} )"
    echo "  First row: $FIRST_ROW"
    echo "   Left col: $LEFT_COLUMN"
    echo "Show header: $( if [[ -n "$NO_HEADER" ]]; then echo -E -n 'NO'; else echo -E -n 'YES'; fi )"
    echo " Verbose: $VERBOSE"
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
