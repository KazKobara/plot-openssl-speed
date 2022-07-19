#!/usr/bin/env bash
# This file is part of https://github.com/KazKobara/plot_openssl_speed
#set -e

### Params ###
VER=0.0.0
GNUPLOT_VER=$(gnuplot -V)
COMMAND=$(basename "$0")
DEFAULT_OPENSSL="openssl"
DEFAULT_GRA_FILE="./graph.png"
DEFAULT_DAT_FILE="${DEFAULT_GRA_FILE%.*}.dat"
ALLOWED_DIR=$(realpath ./)

### functions ###
usage () {
    echo " Plot OpenSSL Speed $VER"
    echo
    echo " Usage:"
    echo "   Measure and plot:"
    echo
    echo "     \$ ./${COMMAND} [options] crypt-algorithm [crypt-algorithm ...]"
    echo
    echo "   Plot given data:"
    echo
    echo "     \$ ./${COMMAND} [options] [-d data_file_to_graph] [-o filename.png]"
    echo
    echo "   options:"
    echo "     [-d data_file_to_graph]"
    echo "         Available only when no crypt-algorithm is given"
    echo "         (default: ${DEFAULT_DAT_FILE})."
    echo "     [-o filename.png]"
    echo "         Output png file name (default: ${DEFAULT_GRA_FILE})."
    echo "         Its data file is overwritten to the" 
    echo "         same_filename_as_png.dat (default: ${DEFAULT_DAT_FILE})."
    echo "     [-p path_to_openssl]"
    echo "         Path to openssl command (default: ${DEFAULT_OPENSSL})"
    echo "         Ignored when plotting from given data."
    echo "     [-s seconds]"
    echo "         Seconds [1-99] to measure the speed. Set '1' to speed up"
    echo "         for debug. Ignored when plotting from given data."
    echo "         LibreSSL (at least 2.8.3) does not support this."
    echo "     [-(h|?)]"
    echo "         Show this usage."
    echo
    echo "   where:"
    echo "     'crypt-algorithms' can be found in the area" 
    echo "     '# Edit crypt-algorithms below #' of '${COMMAND%.sh}_all.sh)',"
    echo "     or by the following commands:"
    echo "       \$ ${OPENSSL} help list"
    echo "       \$ ${OPENSSL} list --digest-commands"
    echo "       \$ ${OPENSSL} list --cipher-commands"
    echo
    echo "     'data_file_to_graph':"
    echo "     - ignores the lines starting with # as comments."
    echo "     - may include single blank lines"
    echo "       but not double or more consecutive blank-lines"
    echo "       (or use gnuplot index to plot"
    echo "       double-or-more-blank-line separated datasets)"
    echo
    echo " With:"
    echo "   $GNUPLOT_VER"
}

##
# @brief        Run `openssl speed` and save the results to ${DAT}.
# @param[in]    list of algorithms
# @param[out]   Write to ${DAT}
measure () {
    echo
    echo "----- Measuring the speed -----" 
    if  [[ "${OPENSSL_VER}" != "OpenSSL 3."* ]] && \
        [[ "${OPENSSL_VER}" != "OpenSSL 1."* ]] && \
        [[ "${OPENSSL_VER}" != "LibreSSL"* ]]; then
            echo "Warning: ${OPENSSL_VER} is not tested!"
            echo "         Edit 'measure()' in '${COMMAND}' to adjust options"
            echo "         for '${OPENSSL} speed'."
    fi
    # Store each result in the ${LOG} file.
    # save only the last execution to see the openssl speed configurations.
    # local LOG=.${COMMAND%.*}.log
    local LOG=${DAT%.*}.log
    echo "Updating '${LOG}' and '${DAT}'."
    rm -f "${LOG}" "${DAT}"

    local NO_EVP="-no-evp"
    # Final ${TABLE_TYPE} (and ${NUM_FIELD}) will be decidec by table_type().
    # ${PRE_TABLE_TYPE} is to decide ${OPENSSL} options.
    local PRE_TABLE_TYPE
    ((cou=0))
    for algo in "$@"; do
        echo
        echo "--- $algo ---"
        local CUR_TABLE_TYPE="kbytes"  # default
        local NO_EVP_NAME=""           # default
        local EVP_OPT=""               # default
        # if [[ "${OPENSSL_VER}" == "OpenSSL 1."* ]] || \
        #   [[ "${OPENSSL_VER}" == "OpenSSL 3."* ]] || \
        #   [[ "${OPENSSL_VER}" == "LibreSSL"* ]]; then
            # Process -no-evp (no -evp or low-level API for symmetric/no-key algorithms) first
            # to distinguish between, e.g. hmac-no-evp and hmac-sha512.
            if [ "${algo: -${#NO_EVP}}" == "${NO_EVP}" ]; then
                # *-no-evp, i.e. `openssl speed *`.
                # As of openssl 1.1.1, * may be sha256, sha512, and hmac (hmac(md5)).
                # OpenSSL 3.0 or newer will depreciate them.
                algo=${algo%"${NO_EVP}"}
                echo "algo: $algo"
                NO_EVP_NAME=${NO_EVP}
            elif [ "${algo: 0: 5}" == "hmac-" ]; then
                # hmac-sha512, i.e. `openssl speed -hmac sha256` and so on.
                EVP_OPT="-hmac"
                algo=${algo#hmac-}  # sha*
            elif [ "${algo: 0:4}" == "ecdh" ] || [ "${algo: 0:4}" == "ffdh" ]; then
                CUR_TABLE_TYPE="op"
            elif    [ "${algo: 0:5}" == "ecdsa" ] || [ "${algo: 0:2}" == "ed" ] || \
                    [ "${algo: 0:3}" == "rsa" ] || [ "${algo: 0:3}" == "dsa" ]; then
                CUR_TABLE_TYPE="sig_ver"
            else
                EVP_OPT="-evp"
            fi
        # fi
        # Set then check TABLE_TYPE's.
        if [ ${cou} -eq 0 ]; then
            PRE_TABLE_TYPE=${CUR_TABLE_TYPE}
        elif [ ${cou} -ge 1 ] && [ "${PRE_TABLE_TYPE}" != "${CUR_TABLE_TYPE}" ] ; then
            echo
            echo "Warning: skipped because CUR_TABLE_TYPE ($CUR_TABLE_TYPE)"
            echo "         differs from the previous one (${PRE_TABLE_TYPE})!"
            echo
            continue
        fi
        ((cou++))

        ## TODO: Add '-mr' (machine readable) option,
        #        and change the corresponding table parsers.
        echo "${OPENSSL} speed ${SPEED_OPT} ${EVP_OPT} $algo"
        # shellcheck disable=SC2086  # ${SPEED_OPT} and ${EVP_OPT} contain spaces.
        ${OPENSSL} speed ${SPEED_OPT} ${EVP_OPT} "$algo" | tee "${LOG}"
        ALGO3="${algo: 0: 3}"
        if [ "${PRE_TABLE_TYPE}" == "kbytes" ]; then
            ## Examples of input formats:
            # type             16 bytes     64 bytes    256 bytes   1024 bytes   8192 bytes  16384 bytes
            if [ "${NO_EVP_NAME}" == "" ]; then
                if [ "${EVP_OPT}" == "-hmac" ]; then
                    # OpenSSL 3 and later
                    # hmac(sha512)     23408.12k    90165.99k   249721.98k   538953.37k   756375.73k   782985.02k
                    grep -i -E "^hmac\($algo\)" "${LOG}" >> "${DAT}"
                else
                    ## -evp
                    # aes-128-cbc     845296.57k  1422663.94k  1480359.68k  1446441.98k  1389936.64k  1412481.02k
                    # sha256           80287.30k   177244.16k   335795.46k   428160.00k   458956.80k   461897.73k
                    grep -i -E "^$algo" "${LOG}" >> "${DAT}"        
                fi
            else
                ## no -evp (old low-level API)
                # aes-128 cbc     228064.46k   210600.70k   190551.55k   232110.08k   238206.98k   231325.70k
                # OpenSSL 1 and older
                # hmac(md5)     23408.12k    90165.99k   249721.98k   538953.37k   756375.73k   782985.02k
                # sha256           30840.78k    88357.72k   199311.27k   292801.60k   334301.56k   319321.27k
                # LibreSSL 2.8.3
                # hmac(md5)     23408.12k    90165.99k   249721.98k   538953.37k   756375.73k  
                # sha256           30840.78k    88357.72k   199311.27k   292801.60k   334301.56k   
                #
                # aes-128 cbc -> aes-128-cbc-no-evp
                # sha256 -> sha256-no-evp
                # grep -i -E "^${ALGO3}" "${LOG}" | awk '{if (NF == 8) {$1=$1"-"$2;$2="";print} else {print}}' | sed -E -e "s/(^${ALGO3}[^ ]*?) /\1${NO_EVP_NAME} /" >> "${DAT}"
                # grep -i -E "^${ALGO3}" "${LOG}" | awk -v NO_EVP_NAME="${NO_EVP_NAME}" '{if (NF == 8) {$1=$1"-"$2NO_EVP_NAME;$2="";print} else {$1=$1NO_EVP_NAME;print}}' >> "${DAT}"
                grep -i -E "^${ALGO3}" "${LOG}" | awk -v NO_EVP_NAME="${NO_EVP_NAME}" '{if ( $2 !~ /^[0-9]+\.[0-9]+k$/ ) {$1=$1"-"$2NO_EVP_NAME;$2="";print} else {$1=$1NO_EVP_NAME;print}}' >> "${DAT}"
            fi
        elif [ "${ALGO3}" == "rsa" ] || [ "${ALGO3}" == "dsa" ]; then
            # All the RSA or DSA
            # rsa 4096 bits 0.003922s 0.000061s    255.0  16471.0
            # dsa 2048 bits 0.000296s 0.000219s   3383.0   4557.0
            grep -i -E "^${ALGO3} [0-9]+ bits? " "${LOG}" | awk '{$1=$1$2; $2=""; $3=""; print}' >> "${DAT}"
        elif [ "${algo: 0:4}" == "ecdh" ] || [ "${algo: 0:5}" == "ecdsa" ] || [ "${algo: 0:2}" == "ed" ]; then
            #  256 bits ecdsa (nistp256)   0.0000s   0.0001s  43201.0  15221.0
            #  253 bits EdDSA (Ed25519)   0.0000s   0.0001s  24010.0   8805.0
            #  256 bits ecdh (nistp256)   0.0000s  20643.0
            #  256 bits ecdsa (brainpoolP256r1)   0.0004s   0.0004s   2448.7   2635.9
            # LibreSSL 2.8.3
            #  521 bit ecdh (nistp521)   0.0020s    507.5
            grep -i -E "^ [0-9]+ bits? (ecdh \(|ecdsa \(|EdDSA \(Ed)" "${LOG}" | awk '{$1="";$2="";$3=$3$4;$4=""; print substr($0, 3)}' >> "${DAT}"
        elif [ "${algo: 0:4}" == "ffdh" ] ; then
            # OpenSSL 3 and later
            # 4096 bits ffdh   0.0129s     77.8
            grep -i -E "^[0-9]+ bits? ffdh " "${LOG}" | awk '{$1=$3$1;$2="";$3=""; print}' >> "${DAT}"
        else
            echo
            echo "Warning: skipped. Add format type for this algorithm."
            echo
        fi
    done
    rm -f "${LOG}"
}

##
# @brief        Identify TABLE_TYPE and set it to global TABLE_TYPE and NUM_FIELD.
# @param[in]    ${DAT} [file name]
# @param[out]   ${TABLE_TYPE}
# @param[out]   ${NUM_FIELD}
table_type () {
    # Check if records exist and they are in the same format.
    # On macOS:
    #   $ wc -l  ./graph.dat 
    #   "    0 ./graph.dat"
    NUM_FIELD=$(awk '(! /#/) && (NF > 1) {print NF}' "${DAT}" | uniq)
    NUM_FIELD_VARIATION=$(echo "${NUM_FIELD}" | wc -l | awk '{print $1}' )
    # if [ "$(awk '(! /#/) && (NF > 1) {print NF}' < "${DAT}" | uniq | wc -l | awk '{print $1}' )" == "1" ]; then   
    if [ "${NUM_FIELD_VARIATION}" == "1" ]; then
          # NUM_FIELD="$(awk '(! /#/) && (NF > 1) {print NF}' "${DAT}" | uniq)"
        echo "NUM_FIELD: ${NUM_FIELD}"
        case "$NUM_FIELD" in
            # 6 for LibreSSL 2.8.3
            6|7) TABLE_TYPE="kbytes";;
            5) TABLE_TYPE="sig_ver";;
            3) TABLE_TYPE="op";;
            0|1) echo "Warning: $DAT has no appropriate table!";
               return 1;;
            *) echo "Error: unknown data format!";
               return 1;;
        esac
    else
        echo
        echo "Error: records are not in the same format!"
        echo
        return 1
    fi
    return 0
}


##
# @brief        Set params and plot
# @param[in]    ${DAT} [file name]
# @param[in]    ${TABLE_TYPE}
# @param[in]    ${NUM_FIELD}
# @param[out]   Figure in ${GRA_FILE}
plot_data () {
    echo
    echo "--- plot ---"
    ## Graph type
    # GRA_TYPE=linespoints
    GRA_TYPE="histogram"

    ## Graph title
    if [ "${t_arg}" != "" ]; then
        GRA_TITLE="${t_arg}"
    else
        if [ "${PLOT_DATA_FILE}" == "1" ]; then
            GRA_TITLE=""
        else
            GRA_TITLE="with $(echo "${OPENSSL_VER}" | awk '{print $1,$2}')"
        fi
    fi
    GRA_OPT_COMMON="\
        set key ${GRA_KEY_POS} tmargin horizontal;\
        set title \"Depicted by ${COMMAND} (v$VER) ${GRA_TITLE}\" noenhanced;\
        "

    if [ "$GRA_TYPE" == "linespoints" ]; then
        GRA_CLM="0:"
        GRA_OPT="$GRA_OPT_COMMON;"
    elif [ "$GRA_TYPE" == "histogram" ]; then
        GRA_CLM=""
        GRA_OPT="$GRA_OPT_COMMON; \
            set style histogram clustered; \
            set style fill solid border lc rgb 'black';\
            "
    fi

    GRA_YTICS=""
    if [ "${TABLE_TYPE}" == "kbytes" ]; then
        ## Use this for 100000 < y < 1000000.
        # GRA_YTICS="set ytics ('0' 0, '100,000' 1e5, '200,000' 2e5, '300,000' 3e5, '400,000' 4e5, '500,000' 5e5, '600,000' 6e5, '700,000' 7e5, '800,000' 8e5, '900,000' 9e5);"
        ## This does not work.
        # GRA_YTICS="stats \"./$DAT\" using 1:7 nooutput; if ( (100000 < STATS_max_y) && (STATS_max_y < 1000000) ) { set ytics ('0' 0, '100,000' 1e5, '200,000' 2e5, '300,000' 3e5, '400,000' 4e5, '500,000' 5e5, '600,000' 6e5, '700,000' 7e5, '800,000' 8e5, '900,000' 9e5)};"
        XTICS_ROTATE_ANGLE="-10"
        SPEED_UNIT="k bytes/s"
        if [ "${NUM_FIELD}" -ge 7 ]; then
            GRA_CLM7="\"./${DAT}\" using ${GRA_CLM}7:xtic(1) with ${GRA_TYPE} title '16,384 bytes',"
        else
            # For LibreSSL 2.8.3
            GRA_CLM7=""
        fi
        GRA_PLOT=" \
            \"./${DAT}\" using ${GRA_CLM}2:xtic(1) with ${GRA_TYPE} title '16 bytes', \
            \"./${DAT}\" using ${GRA_CLM}3:xtic(1) with ${GRA_TYPE} title '64 bytes', \
            \"./${DAT}\" using ${GRA_CLM}4:xtic(1) with ${GRA_TYPE} title '256 bytes', \
            \"./${DAT}\" using ${GRA_CLM}5:xtic(1) with ${GRA_TYPE} title '1,024 bytes', \
            \"./${DAT}\" using ${GRA_CLM}6:xtic(1) with ${GRA_TYPE} title '8,192 bytes', \
            ${GRA_CLM7} \
            "
    elif [ "${TABLE_TYPE}" == "sig_ver" ]; then
        XTICS_ROTATE_ANGLE="-15"
        SPEED_UNIT="operations/s"
        GRA_PLOT=" \
            \"./${DAT}\" using ${GRA_CLM}5:xtic(1) with ${GRA_TYPE} title 'verify/s', \
            \"./${DAT}\" using ${GRA_CLM}4:xtic(1) with ${GRA_TYPE} title 'sign/s', \
            "
            # \"./${DAT}\" using ${GRA_CLM}8:xtic(4) with ${GRA_TYPE} title 'verify/s', \
            # \"./${DAT}\" using ${GRA_CLM}7:xtic(4) with ${GRA_TYPE} title 'sign/s', \
    elif [ "${TABLE_TYPE}" == "op" ]; then
        XTICS_ROTATE_ANGLE="-15"
        SPEED_UNIT="operations/s"
        GRA_PLOT=" \
            \"./${DAT}\" using ${GRA_CLM}3:xtic(1) with ${GRA_TYPE} title 'op/s' \
            "
    else
        echo "Unknown TABLE_TYPE: ${TABLE_TYPE}"
    fi

    # Set graph params depending on # of effective lines.
    declare -i num
    num="$(awk '(! /#/) && (NF > 1) {n+=1} END{print n}' "${DAT}" | uniq)"
    echo "# of effective lines: $num"
    if [[ $num -ge 14 ]]; then
        GRA_XTICS_ROTATE="set xtics rotate by -90;"
        GRA_KEY_POS="center"
    elif [[ $num -ge 7 ]]; then
        # GRA_XTICS_ROTATE="set xtics rotate by -60 offset first -0.3,0;"
        GRA_XTICS_ROTATE="set xtics rotate by -45 offset first -0.4,0;"
        GRA_KEY_POS="center"
    elif [[ $num -ge 3 ]]; then
        GRA_XTICS_ROTATE="set xtics rotate by ${XTICS_ROTATE_ANGLE} offset first -0.4,0;"
        GRA_KEY_POS="center"
    else
        GRA_XTICS_ROTATE=""
        GRA_KEY_POS="right"
    fi

    # cf. http://gnuplot.info/
    gnuplot -p -e "set terminal png; set output \"${GRA_FILE}\"; \
        ${GRA_XTICS_ROTATE} \
        ${GRA_YTICS} \
        set ylabel 'Speed [${SPEED_UNIT}]'; \
        set grid; \
        ${GRA_OPT} \
        plot [] [0:] \
        ${GRA_PLOT}
        "
}

##
# @brief        Path check
# @param[in]    ${ALLOWED_DIR}
# @param[in]    path
# @param[out]   exit 2 if given path is not allowed
check_path (){
    REAL_PATH=$(realpath "$2")
    if [[ ${REAL_PATH} != $1* ]]; then
        echo
        echo "Error: '$2' is not under the allowed dir!"
        echo
        exit 2
    fi     
}

##
# @brief        Add dynamic-link lib path for built openssl.
# @param[in]    ${OPENSSL}
# @param[out]   ${DYLD_LIBRARY_PATH} or ${LD_LIBRARY_PATH}
add_ld_lib_path (){
    if [ "${OPENSSL}" != "openssl" ] && \
    [ "${OPENSSL}" == "${OPENSSL%.exe}" ]; then
        # macOS
        # Add the path to lib{ssl,crypto}.3.dylib in ./tmp/openssl-*.*.*/ .
        echo "OPENSSL: ${OPENSSL}"
        echo "PWD: ${PWD}"
        OPENSSL_LIB_PATH="${OPENSSL%apps/openssl}"
        # echo "OPENSSL_LIB_PATH: ${OPENSSL_LIB_PATH}"
        if [ "${OPENSSL}" != "${OPENSSL_LIB_PATH}" ]; then
            # If ${OPENSSL} ends with 'apps/openssl' remove it.
            # If ${OPENSSL} is the same as 'apps/openssl',
            #    ${OPENSSL_LIB_PATH}="" and set "./"
            PATH_TO_ADD="${OPENSSL_LIB_PATH:=./}"
        else
            # If OPENSSL=./openssl , it is from ./tmp/openssl-*.*.*/apps/ , so
            PATH_TO_ADD="../"
        fi
        if [[ "$(uname -s)" == "Darwin"* ]]; then
            # per process
            if [ "${DYLD_LIBRARY_PATH}" != "${PATH_TO_ADD}" ] && \
            [ "${DYLD_LIBRARY_PATH}" == "${DYLD_LIBRARY_PATH//${PATH_TO_ADD}://}" ]; then
                export DYLD_LIBRARY_PATH="${PATH_TO_ADD}${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"
                echo "DYLD_LIBRARY_PATH: ${DYLD_LIBRARY_PATH}"
            fi
        else
            # per environment
            if [ "${LD_LIBRARY_PATH}" != "${PATH_TO_ADD}" ] && \
            [ "${LD_LIBRARY_PATH}" == "${LD_LIBRARY_PATH//${PATH_TO_ADD}://}" ]; then
                export LD_LIBRARY_PATH="${PATH_TO_ADD}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
                echo "LD_LIBRARY_PATH: ${LD_LIBRARY_PATH}"
            fi
        fi
    fi
}

### getopts ###

OPENSSL=${DEFAULT_OPENSSL}
GRA_FILE=${DEFAULT_GRA_FILE}

s_arg=""; d_arg=""; t_arg=""
SPEED_OPT=""  # default: 3s for symmetric, 10s for asymmetric
flagh=0; flago=0; flagp=0;
while getopts 'd:o:p:s:t:h?' OPTION
do
    case $OPTION in
        d) d_arg="$OPTARG";;                # override
        o) flago=1;GRA_FILE="$OPTARG";
           DEFAULT_DAT_FILE="${GRA_FILE%.*}.dat";;   # override
        p) flagp=1;OPENSSL="$OPTARG";;      # override
        s) s_arg=${OPTARG};;  # openssl speed -seconds
        t) t_arg=${OPTARG};;
        h|?|*) flagh=1;;
    esac
done
shift $((OPTIND - 1))

add_ld_lib_path

### opt check ###

# usage() must be here since it depends on options
[ "${flagh}" == "1" ] && { usage; exit 2;}
# arg check for -o
[ "${flago}" == "1" ] && check_path "${ALLOWED_DIR}" "${GRA_FILE}"
if [ "${d_arg}" != "" ]; then
    DAT="${d_arg}"
    check_path "${ALLOWED_DIR}" "${DAT}"
    # If the data filename to read differs from the filename that replaced
    # graph name's .png with .dat, duplicate it.
    DAT_FILENAME_FROM_GRAPH="${GRA_FILE%.*}.dat"
    if [ "${DAT}" != "${DAT_FILENAME_FROM_GRAPH}" ]; then
        cp -fp "${DAT}" "${DAT_FILENAME_FROM_GRAPH}"
    fi
else
    DAT=${DEFAULT_DAT_FILE}
fi

##### main and opt check #####

[ $# -eq 0 ] && PLOT_DATA_FILE=1
if [ "$PLOT_DATA_FILE" != "1" ]; then
    # arg check for -p
    [ "$flagp" == "1" ] && check_path "${ALLOWED_DIR}" "${OPENSSL}"
    OPENSSL_VER=$(${OPENSSL} version)
    # arg check for -s
    if [ "$s_arg" != "" ]; then
        if [[ "$s_arg" =~ ^[1-9][0-9]?$ ]]; then
            SPEED_OPT="-seconds ${s_arg}"
        else
            echo
            echo "Error: invalid '${s_arg}' for -s option!"
            echo
            usage; exit 2
        fi
        if [[ "${OPENSSL_VER}" == "LibreSSL"* ]]; then
            echo
            echo "Warning: -s option for \"${SPEED_OPT}\" is ignored on LibreSSL."
            echo "  Change '${COMMAND}' after LibreSSL supports '-second' option."
            SPEED_OPT=""
        fi
    fi
    measure "$@"
else
    # opt check
    if [ "${flagp}" == "1" ]; then
        echo
        echo "Warning: -p option is ignored."
    fi
    if [ "${SPEED_OPT}" != "" ]; then
        echo
        echo "Warning: -s option for \"${SPEED_OPT}\" is ignored."
    fi
    if [ "$#" == "0" ] && [ ! -e "${DAT}" ]; then
        echo
        echo "Error: '${DAT}' does not exist!"
        echo
        exit 2
    fi
fi

# Set TABLE_TYPE and NUM_FIELD
table_type "${DAT}" || exit 1
plot_data

echo
echo "Graph is in ${GRA_FILE}"