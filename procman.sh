#!/bin/bash

procmanShow() {
    {
        INPUT=$@
        COMMAND="ps aux" # command to show output of

	    # convert user input to ps arg
	    declare -A sorts=( ["pid"]="pid" ["cpu"]="pcpu" ["mem"]="rss")

        # convert user input to column number
        declare -A cols=( ["pid"]=2 ["cpu"]=3 ["mem"]=4)

        # sorting #
        if [[ $INPUT =~ -s|--sort ]]; then
            SORT="$(grep -oP "(?:(?<=-s )|(?<=--sort ))\w+" <<< $INPUT)"
	    SORT="${sorts[$SORT]}"
	  
            if [[ "$SORT" != "" ]]; then
                COMMAND="ps aux --sort -$SORT"
	    else
		COMMAND="echo Invalid category for sort flag. Use either pid, mem, or cpu."
            fi
        fi

        # check for regex flag #
        REGEX=false
        if [[ $INPUT =~ -E|--regex ]]; then
            # remove flag from INPUT #
            INPUT="$(sed -e 's/-E //g' -e 's/--regex //g' <<< $INPUT)"
            REGEX=true
        fi
	
        # check for expression flag #
        EXPRESSION=false
        if [[ $INPUT =~ -x|--exp ]]; then 
            EXPRESSION=true
        fi

	# check for filter flag #
	FILFLAG=false
	if [[ $INPUT =~ -f|--filter ]]; then
	    FILFLAG=true
	fi

        # filtering #
        if $FILFLAG ; then
            FILTER="$(grep -oP '((?<=-f )|(?<=--filter ))(\w+(..?[0-9\.]+)?)' <<< $INPUT)"

            if $REGEX ; then
                COMMAND="$COMMAND | grep -E $FILTER"

            elif [[ "$FILTER" != "" ]]; then
                COMMAND="$COMMAND | grep $FILTER"

            # handle no filter #
            else
                COMMAND="echo No filter specified. Refer to ./procman.sh help for more guidance."
            fi
        fi
 
	if [[ $INPUT =~ -x|--exp ]]; then
	    if [[ "$SORT" != "" ]] || $FILFLAG ; then
                COMMAND="echo Cannot use sort or filter flag with expression flag. Refer to ./procman.sh help for more guidance."

            else
		EXP="$(grep -oP '((?<=-x )|(?<=--exp ))(\w+(..?[0-9\.]+)?)' <<< $INPUT)"
                COL="$(grep -o -E "^[a-z]+" <<< $EXP)" # column name
                TYPE="${sorts[$COL]}" # ps arg
                VALUE="$(grep -oP '[0-9\.]+$' <<< $EXP)" # value to compare
                OPERATOR="$(grep -oP '(<=|<|>=|>)' <<< $EXP)" # operator to use
                COLNUM="${cols[$COL]}" # column number
		    
		# throw error for invalid arg(s)
		if [ -z $COL ] || [ -z $TYPE ] || [ -z $VALUE ] || [ -z $OPERATOR ] || [ "$COL$OPERATOR$VALUE" != $EXP ]; then
		    COMMAND="echo 'Invalid argument(s) provided. Refer to ./procman.sh help for more guidance.'"
		else
                    let count=0	
                    if [[ $OPERATOR =~ ">" ]]; then
                        TYPE="-$TYPE"
                    fi
                    # count number of instances
                    while read line; do
			    
                        if (( $(echo $line $OPERATOR $VALUE |bc -l) )); then # compare with argument
                            count=$((count+1))
                        fi
                    done < <(ps aux --sort=$TYPE | sed '1d;$d' | awk "{print \$$COLNUM}")
                    count=$((count+1)) # increment to account for table heading
                    COMMAND="ps aux --sort=$TYPE | head -n $count"
	        fi
            fi
	fi

    # hide all output #
    } &> /dev/null

    # add table header if removed #
    if [[ "$COMMAND" =~ grep ]]; then
        ps aux | sed "1q"
    fi

    # eval $COMMAND
    eval $COMMAND | 
        while read LINE; do
            echo "$LINE"
        done
}

procmanKill() {
    # check if arg is a number #
    if [[ $1 =~ ^-?[0-9]+$ ]]; then
	    kill $1
    else
	    pkill $1
    fi
}

procmanDetails() {
    # check if arg is a number #
    if [[ $1 =~ ^-?[0-9]+$ ]]; then
	    pid=$1
    else
	    pid=$(pidof $1 | awk '{print $1}')
    fi
    cat /proc/$pid/status
    echo
    cat /proc/$pid/cmdline
    echo
}

procmanHelp() {
    man ./procman.1
}

case $1 in 
    "show")
        procmanShow "$@"
        # maybe replace with procmanShow $@
        # $2 is --sort or -s, $3 is property, $4 is --filter or -f, $5...$# is what to filter by
        ;;

    "kill")
        procmanKill "$2"
        ;;

    "details")
	procmanDetails "$2"
	;;

    "help")
        procmanHelp
        ;;

    *)
        # default case, help script here
	echo "Command not found. Enter './procman.sh help' for a list of commands"
        ;;
esac
