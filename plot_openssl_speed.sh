#!/usr/bin/env bash
# This file is part of https://github.com/KazKobara/plot_openssl_speed
# Copyright (C) 2024 National Institute of Advanced Industrial Science and Technology (AIST). All Rights Reserved.
set -e
# set -x

### Params ###
GNUPLOT_VER=$(gnuplot -V)
COMMAND=$(basename "$0")
DEFAULT_OPENSSL="openssl"
DEFAULT_GRA_FILE="./graph.png"
DEFAULT_DAT_FILE="${DEFAULT_GRA_FILE%.*}.dat"
ALLOWED_DIR=$(realpath ./)
UTILS=utils/common.sh

### functions ###
if [ -s "./${UTILS}" ]; then
    # shellcheck source=./utils/common.sh
    . ./${UTILS}
elif [ -s "../../${UTILS}" ]; then
    # if called by plot_openssl_speed_all.sh
    # shellcheck source=./utils/common.sh
    . ../../${UTILS}
else
    echo "Error: failed to source ${UTILS}!"
    exit 3
fi

usage () {
    echo " Plot OpenSSL Speed ${VER}"
    echo
    echo " Usage:"
    echo "   Measure and plot (measure-plot mode):"
    echo
    echo "     \$ ./${COMMAND} [options] crypt-algorithm [crypt-algorithm ...]"
    echo
    echo "   Plot given data (data-plot mode):"
    echo
    echo "     \$ ./${COMMAND} [options] [-l TABLE_TYPE] [-d data_file_to_graph] [-o filename.png]"
    echo
    echo "   options:"
    echo "     [-d data_file_to_graph]"
    echo "         Available only when no crypt-algorithm is given"
    echo "         (default: '${DEFAULT_DAT_FILE}' or '<filename>.dat' if "
    echo "         '-o <filename>.png' is given)."
    echo "         For the current options: '${DAT}'."
    echo "         NOTE: 'measure and plot' overwrites the data file!"
    echo "     [-l TABLE_TYPE]"
    echo "         TABLE_TYPE used in plot_data() for data-plot, or used as"
    echo "         a default in measure() for measure-plot."
    echo "     [-o filename.png]"
    echo "         Output png file (default: '${DEFAULT_GRA_FILE}' or "
    echo "         '<filename>.png' if -d <filename>.dat' is given)."
    echo "         NOTE: 'measure and plot' overwrites the data file!"
    echo "         For the current options: '${GRA_FILE}'."
    echo "     [-p path_to_openssl]"
    echo "         Path to openssl command (default: ${DEFAULT_OPENSSL})"
    echo "         Ignored when plotting from given data."
    echo "     [-s seconds]"
    echo "         Seconds [1-99] to measure the speed. Set '1' to speed up"
    echo "         for debug. Ignored when plotting from given data."
    echo "         LibreSSL (at least 3.9.2 and older) does not support this."
    echo "     [-t 'string']"
    echo "         String to append to the graph title, especially to supplement"
    echo "         execution environment info when plotting given data."
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
    echo "     For open quantum safe provider for OpenSSL 3.2 and greater:"
    echo "       \$ ${OPENSSL} list -signature-algorithms -provider oqsprovider"
    echo "       \$ ${OPENSSL} list -kem-algorithms -provider oqsprovider"
    echo
    echo "     'data_file_to_graph':"
    echo "     - ignores the lines starting with # as comments."
    echo "     - may include single blank lines"
    echo "       but not double or more consecutive blank-lines"
    echo "       (or use gnuplot index to plot"
    echo "       double-or-more-blank-line separated datasets)"
    echo "     - For more details, cf. https://github.com/KazKobara/plot-openssl-speed?tab=readme-ov-file#data-file-format-for-plot_openssl_speedsh ."
    echo
    echo " With:"
    echo "   ${GNUPLOT_VER}"
}

##
# @brief        Extract RSA's "dec_enc_keygen_dh" data from ${LOG}.
# @param[in]    $1 (${LOG}, RSA speed's log-file-name with the path)
# @param[in]    $2 (data-file-name with the path)
# @param[in]    $3 (rsa_num_field)
# @param[in]    $4 (rsa_num_field_enc)
# @param[in]    $5 (rsa_num_field_sig)
# @param[out]   formatted-data to $2
# @param[out]   global TO_NOTICE
extract_rsa_enc (){
    local ALGO3="rsa"
    local rsa_num_field="$3"
    local rsa_num_field_enc="$4"
    local rsa_num_field_sig="$5"
    TO_NOTICE="no"  # or "yes"
    # "0" padding is needed to identify TABLE_TYPE in data-plot mode.
    if [ "${rsa_num_field_enc}" == "6" ]; then
        # enc w/ keygen
        # awk '(($1=="keygen")&&($2=="encaps")&&($3=="decaps")),(($1=="keygen")&&($2=="signs")&&($3=="verify")) {if ($1 ~ "rsa") {printf "%-25s %10s %10s %10s %10s\n",$1,$7,$6,$5,"0"}}' "$1" >> "$2"
        awk '(($2=="encaps")&&($3=="decaps")),(($2=="signs")&&($3=="verify")) {if ($1 ~ "rsa") {printf "%-25s %10s %10s %10s %10s\n",$1,$7,$6,$5,"0"}}' "$1" >> "$2"
    elif [ "${rsa_num_field}" == "11" ]; then
        # enc w/o keygen
        awk -v REGEXP="^${ALGO3}[1-9][0-9]+bit" '$1$2$3 ~ REGEXP {printf "%-25s %10s %10s %10s %10s\n",$1$2,$11,$10,"0","0"}' "$1" >> "$2"
    elif [ "${rsa_num_field_sig}" == "6" ]; then
        # sig w/ keygen
        awk '(($1=="keygen")&&($2=="signs")&&($3=="verify")),/^s+$/ {if ($1 ~ "rsa") {printf "%-25s %10s %10s %10s %10s\n",$1,$6,$7,$5,"0"}}' "$1" >> "$2"
        TO_NOTICE="yes"
    elif [ "${rsa_num_field}" == "7" ]; then
        # sig w/o keygen
        awk -v REGEXP="^${ALGO3}[1-9][0-9]+bit" '$1$2$3 ~ REGEXP {printf "%-25s %10s %10s %10s %10s\n",$1$2,$6,$7,"0","0"}' "$1" >> "$2"
        TO_NOTICE="yes"
    fi
}


##
# @brief        Extract RSA's "sig_ver_keygen" data from ${LOG}.
# @param[in]    $1 (${LOG}, RSA speed's log-file-name with the path)
# @param[in]    $2 (data-file-name with the path)
# @param[in]    $3 (rsa_num_field)
# @param[in]    $4 (rsa_num_field_enc)
# @param[in]    $5 (rsa_num_field_sig)
# @param[out]   formatted-data to $2
# @param[out]   global TO_NOTICE
extract_rsa_sig (){
    local ALGO3="rsa"
    local rsa_num_field="$3"
    local rsa_num_field_enc="$4"
    local rsa_num_field_sig="$5"
    TO_NOTICE="no"  # or "yes"
    # "0" padding is needed to identify TABLE_TYPE in data-plot mode.
    if [ "${rsa_num_field_sig}" == "6" ]; then
        # sig w keygen
        awk '(($1=="keygen")&&($2=="signs")&&($3=="verify")),/^s+$/ {if ($1 ~ "rsa") {printf "%-25s %10s %10s %10s %10s\n",$1,$6,$7,$5,"0"}}' "$1" >> "$2"
    elif [ "${rsa_num_field}" == "11" ]; then
        # sig w/o keygen
        awk -v REGEXP="^${ALGO3}[1-9][0-9]+bit" '$1$2$3 ~ REGEXP {printf "%-25s %10s %10s %10s\n",$1$2,$8,$9,"0"}' "$1" >> "$2"
    elif [ "${rsa_num_field}" == "7" ]; then
        # sig w/o keygen
        awk -v REGEXP="^${ALGO3}[1-9][0-9]+bit" '$1$2$3 ~ REGEXP {printf "%-25s %10s %10s %10s\n",$1$2,$6,$7,"0"}' "$1" >> "$2"
    elif [ "${rsa_num_field_enc}" == "6" ]; then
        # enc w keygen
        awk '(($1=="keygen")&&($2=="encaps")&&($3=="decaps")),(($1=="keygen")&&($2=="signs")&&($3=="verify")) {if ($1 ~ "rsa") {printf "%-25s %1
0s %10s %10s\n",$1,$7,$6,$5}}' "$1" >> "$2"
        TO_NOTICE="yes"
    fi
}


##
# @brief        Run `openssl speed` and save the results to ${DAT}.
# @param[in]    list of algorithms
# @param[out]   Write to ${DAT}
# @param[out]   ${TABLE_TYPE}
#               global INC_OQS_ALGO ("no"/"yes")
measure () {
    echo
    echo "----- Measuring the speed -----"
    # if  [[ "${OPENSSL_VER}" != "OpenSSL 3."* ]] && \
    #     [[ "${OPENSSL_VER}" != "OpenSSL 1."* ]] && \
    if  [[ "${OPENSSL_VER}" == "OpenSSL 0."* ]] || \
        [[ "${OPENSSL_VER}" != "OpenSSL"* ]] && \
        [[ "${OPENSSL_VER}" != "LibreSSL"* ]]; then
            echo "Warning: ${OPENSSL_VER} is not tested!"
            echo "         Edit 'measure()' in '${COMMAND}' to adjust options"
            echo "         for '${OPENSSL} speed'."
    fi
    # Store each result in the ${LOG} file.
    # save only the last execution to see the openssl speed configurations.
    # local LOG=.${COMMAND%.*}.log
    # local LOG=${DAT%.*}.log
    # echo "Updating '${LOG}' and '${DAT}'."
    echo "Updating '${DAT}'."
    rm -f "${DAT}"
    if  [[ "${DAT}" == *"rsa.dat" ]]; then
        DAT_RSA_ENC="${DAT%rsa.dat}rsa_enc.dat"
        echo "Updating '${DAT_RSA_ENC}' as well."
        rm -f "${DAT_RSA_ENC}"
    fi
    # same dir as ${DAT}, e.g.
    #   "./graphs/test.dat" -> "./graphs/"
    #   "test.dat" -> ""
    LOG_DIR="${DAT%"${DAT##*/}"}"

    local NO_EVP="-no-evp"
    # Final ${TABLE_TYPE} (and ${NUM_FIELD}) will be decided by table_type().
    # ${PRE_TABLE_TYPE} is to decide ${OPENSSL} options.
    local PRE_TABLE_TYPE
    local SIG_ENC_MIX="no"  # default

    cou=$((0))
    # OQS
    # if not defined (in plot_graph_asymmetric() of ${COMMAND}_all.sh etc.)
    if [ -z ${ARR_OQS_SIG+X} ]; then
        get_arr_oqs signature
    fi
    if [ -z ${ARR_OQS_KEM+X} ]; then
        get_arr_oqs kem
    fi
    INC_OQS_ALGO="no"  # default
    for algo in "$@"; do
        echo
        echo "--- $algo ---"
        local LOG=${LOG_DIR}${algo}.log
        local ALGO3="${algo: 0: 3}"
        local NO_EVP_NAME=""  # default
        local arr_evp_opt=()  # default and shall be an array to make "${arr_evp_opt[@]}" null

        # determine arr_evp_opt
        # Process -no-evp (low-level API for symmetric/no-key algorithms) first
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
            arr_evp_opt=("-hmac")
            algo=${algo#hmac-}  # sha*
        elif [[ ! "${algo}" =~ ^(ec|ed|ff|dsa|rsa|ML-|SLH-DSA).* ]] && \
            [[ "${ARR_OQS_SIG[*]}" != *"${algo}"* ]] && \
            [[ "${ARR_OQS_KEM[*]}" != *"${algo}"* ]]; then
            # not asymmetric algo, which are in the default and oqs providers.
            arr_evp_opt=("-evp")
        fi

        ## NOTE: For '-mr' (machine readable) option,
        #        change the table parsers.
        # shellcheck disable=SC2145  # intentional array[@] copying the next command
        echo "${OPENSSL} speed ${ARR_SPEED_OPT[@]} ${arr_evp_opt[@]} $algo"
        ${OPENSSL} speed "${ARR_SPEED_OPT[@]}" "${arr_evp_opt[@]}" "${algo}" > >(tee "${LOG}") 2>&1 || { echo "Warning: skipped '${algo}'"; continue; }
        # NOTE: Remove "\r" since POSIX awk regards "\r" as a character.
        #       Comment out the following three lines to edit "${LOG}" and
        #       "${DAT}" with Win tools and commands.
        if [ "${OPENSSL: -4}" == ".exe" ]; then
            # shellcheck disable=SC2094  # intentional same read/write file
            tr -d "\r" < "${LOG}" 1<> "${LOG}"
        fi

        # set CUR_TABLE_TYPE and extract speed data
        local CUR_TABLE_TYPE
        # local CUR_TABLE_TYPE="kbytes"  # default
        # override CUR_TABLE_TYPE="kbytes"
        if [ "${algo: 0:5}" == "ecdsa" ] || [ "${algo: 0:2}" == "ed" ] || \
             [ "${ALGO3}" == "dsa" ] || \
             [[ "${ARR_OQS_SIG[*]}" == *"${algo}"* ]]; then
            # CUR_TABLE_TYPE="sig_ver"
            CUR_TABLE_TYPE="sig_ver_keygen"
            if [ "${CUR_TABLE_TYPE}" != "${PRE_TABLE_TYPE}" ]; then
                echo -e "#\n# asymmetric_algorithm        sign/s   verify/s   keygen/s" >> "${DAT}"
            fi
            if [ "${algo: 0:5}" == "ecdsa" ] || [ "${algo: 0:2}" == "ed" ]; then
                # ecdsa and eddsa
                #                           sign    verify    sign/s verify/s
                # 253 bits EdDSA (Ed25519)   0.0000s   0.0001s  22473.0   8228.0
                # 456 bits EdDSA (Ed448)   0.0004s   0.0006s   2742.0   1609.0
                #
                # "0" padding is needed to identify TABLE_TYPE in data-plot mode.
                awk '$1$2$3$4 ~ /^[1-9][0-9]+bits?(ecdsa|eddsa|EdDSA)\(/ {printf "%-25s %10s %10s %10s\n", $3$4,$7,$8,"0"}' "${LOG}" >> "${DAT}"
            elif [ "${ALGO3}" == "dsa" ]; then
                # All the DSA's
                #                  sign    verify    sign/s verify/s
                # dsa 2048 bits 0.000296s 0.000219s   3383.0   4557.0
                #
                # "0" padding is needed to identify TABLE_TYPE in data-plot mode.
                awk -v REGEXP="^${ALGO3}[1-9][0-9]+bit" '$1$2$3 ~ REGEXP {printf "%-25s %10s %10s %10s\n", $1$2,$6,$7,"0"}' "${LOG}" >> "${DAT}"
            elif [[ "${ARR_OQS_SIG[*]}" == *"${algo}"* ]]; then
                INC_OQS_ALGO="yes"
                #             keygen     signs    verify keygens/s    sign/s  verify/s
                #  mldsa87 0.000096s 0.000177s 0.000082s   10448.0    5646.0   12261.0
                awk -v REGEXP="^${algo}" '$1 ~ REGEXP {printf "%-25s %10s %10s %10s\n", $1,$6,$7,$5}' "${LOG}" >> "${DAT}"
            fi
        elif [ "${ALGO3}" == "rsa" ]; then
            # --- rsa_num_field==7 (w/o keygen) ---
            # OpenSSL 1 etc.
            #                   sign    verify    sign/s verify/s
            # rsa  512 bits 0.000040s 0.000003s  25224.3 393957.1  # rsa_num_field
            #
            # --- rsa_num_field==11 (w/o keygen) ---
            # OpenSSL 3 etc.
            #                    sign    verify    encrypt   decrypt   sign/s verify/s  encr./s  decr./s
            # rsa   512 bits 0.000041s 0.000002s 0.000003s 0.000049s  24660.6 425189.4 338336.9  20222.1
            #
            # --- rsa_num_field_enc==6 && rsa_num_field_sig==6 (w/ keygen) ---
            # OpenSSL 3.5 fips-provider rsa<bits>
            #               keygen    encaps    decaps keygens/s  encaps/s  decaps/s  # rsa_num_field_enc
            #    rsa7680 11.820000s 0.000361s 0.050000s       0.1    2770.0      20.0
            #               keygen     signs    verify keygens/s    sign/s  verify/s  # rsa_num_field_sig
            #    rsa7680 17.970000s 0.052632s 0.000294s       0.1      19.0    3403.0
            #
            # --- rsa_num_field==11 && rsa_num_field_enc==6 && rsa_num_field_sig==6 ---
            # OpenSSL 3.5 default-provider
            #                   sign    verify    encrypt   decrypt   sign/s verify/s  encr./s  decr./s
            # rsa  1024 bits 0.000127s 0.000008s 0.000009s 0.000144s   7875.8 117815.0 114327.8   6936.4
            # rsa  3072 bits 0.002865s 0.000052s 0.000050s 0.002469s    349.0  19078.0  20088.9    405.0
            #                   keygen    encaps    decaps keygens/s  encaps/s  decaps/s
            #        rsa1024 0.012658s 0.000011s 0.000131s      79.0   92873.5    7652.0
            #        rsa3072 0.238000s 0.000056s 0.002457s       4.2   17705.0     407.0
            #                   keygen     signs    verify keygens/s    sign/s  verify/s
            #        rsa1024 0.012346s 0.000115s 0.000008s      81.0    8692.0  126870.0
            #        rsa3072 0.248000s 0.002469s 0.000054s       4.0     405.0   18644.0
            #
            local rsa_num_field rsa_num_field_enc rsa_num_field_sig
            rsa_num_field=$(awk -v REGEXP="^${ALGO3}[1-9][0-9]+bit" '$1$2$3 ~ REGEXP { print NF}' "${LOG}" | uniq)
            rsa_num_field_enc=$(awk '{if (($1=="keygen")&&($2=="encaps")&&($3=="decaps")) { print NF }}' "${LOG}" | uniq)
            rsa_num_field_sig=$(awk '{if (($1=="keygen")&&($2=="signs")&&($3=="verify")) { print NF }}' "${LOG}" | uniq)
            # echo "rsa_num_field = $rsa_num_field"
            if { [ "${rsa_num_field}" == "" ] || [ "${rsa_num_field}" == "0" ];} && \
                    { [ "${rsa_num_field_enc}" == "" ] || [ "${rsa_num_field_enc}" == "0" ];} && \
                    { [ "${rsa_num_field_sig}" == "" ] || [ "${rsa_num_field_sig}" == "0" ];}; then
                echo
                echo "Notice: no rsa data in '${LOG}'."
                # echo
                continue
            fi
            if [ "${rsa_num_field}" != "7" ] && [ "${rsa_num_field}" != "11" ] && \
                    [ "${rsa_num_field_enc}" != "6" ] && [ "${rsa_num_field_sig}" != "6" ]; then
                echo "Error: unknown data format for ${algo}!"
                echo "       Add it as a new one."
                exit 3
            fi
            if [ ${cou} -ge 1 ] && [ "${PRE_TABLE_TYPE}" == "dec_enc_keygen_dh" ]; then
                # follow the previous table type
                CUR_TABLE_TYPE="dec_enc_keygen_dh"
                extract_rsa_enc "${LOG}" "${DAT}" "${rsa_num_field}" "${rsa_num_field_enc}" "${rsa_num_field_sig}"
                if [ "${TO_NOTICE}" == "yes" ]; then
                    echo
                    echo "Notice: in '${DAT}', 'dec' and 'enc' of '${algo}' are 'sign' and 'verify' of it."
                fi
            else
                # default
                CUR_TABLE_TYPE="sig_ver_keygen"
                if [ ${cou} -ge 1 ] && [ "${CUR_TABLE_TYPE}" != "${PRE_TABLE_TYPE}" ]; then
                    # add header
                    echo -e "#\n# asymmetric_algorithm        sign/s   verify/s   keygen/s" >> "${DAT}"
                    if [ -n "${DAT_RSA_ENC}" ]; then
                        echo -e "#\n# asymmetric_algorithm         dec/s      enc/s   keygen/s" >> "${DAT_RSA_ENC}"
                    fi
                fi
                # "sig_ver_keygen" to ${DAT}
                extract_rsa_sig "${LOG}" "${DAT}" "${rsa_num_field}" "${rsa_num_field_enc}" "${rsa_num_field_sig}"
                if [ "${TO_NOTICE}" == "yes" ]; then
                    echo
                    echo "Notice: in '${DAT}', 'sign' and 'verify' of '${algo}' are 'dec' and 'enc' of it."
                fi
                echo "DAT_RSA_ENC: ${DAT_RSA_ENC}"
                if [ -n "${DAT_RSA_ENC}" ]; then
                    # "dec_enc_keygen_dh" to ${DAT_RSA_ENC}
                    extract_rsa_enc "${LOG}" "${DAT_RSA_ENC}" "${rsa_num_field}" "${rsa_num_field_enc}" "${rsa_num_field_sig}"
                    if [ "${TO_NOTICE}" == "yes" ]; then
                        echo
                        echo "Notice: in '${DAT_RSA_ENC}', 'dec' and 'enc' of '${algo}' are 'sign' and 'verify' of it."
                    fi
                fi
            fi
            if [ ${cou} -eq 0 ] && {\
                    [ "${rsa_num_field}" == "11" ] || {\
                        [ "${rsa_num_field_enc}" == "6" ] && \
                        [ "${rsa_num_field_sig}" == "6" ]\
                    ;}\
                ;}; then
                echo "Warning: 'TABLE_TYPE' of '${algo}' in '${DATA}'"
                echo "         is assumed to be '${CUR_TABLE_TYPE}'."
                echo "         Place '${algo}' after another 'algo'"
                echo "         to use the same 'TABLE_TYPE' as the previous 'algo'."
            fi
        elif [ "${algo: 0:4}" == "ecdh" ] || [ "${algo: 0:4}" == "ffdh" ] || \
             [[ "${ARR_OQS_KEM[*]}" == *"${algo}"* ]] || \
             [ "${algo: 0:6}" == "ML-KEM" ]; then
            ## common among dh and enc/dec w/ or w/o keygen
            CUR_TABLE_TYPE="dec_enc_keygen_dh"
            if [ "${CUR_TABLE_TYPE}" != "${PRE_TABLE_TYPE}" ]; then
                echo -e "#\n# asymmetric_algorithm         dec/s      enc/s   keygen/s       dh/s" >> "${DAT}"
            fi
            if [ "${algo: 0:4}" == "ecdh" ]; then
                ##  256 bits ecdh (nistp256)   0.0000s  20643.0
                ## LibreSSL 2.8.3
                ##  521 bit ecdh (nistp521)   0.0020s    507.5
                awk '$1$2$3$4 ~ /^[1-9][0-9]+bits?ecdh\(/ {printf "%-25s %10s %10s %10s %10s\n", $3$4,"0","0","0",$6}' "${LOG}" >> "${DAT}"
            elif [ "${algo: 0:4}" == "ffdh" ]; then
                ## ffdh is available OpenSSL 3 and later
                ##  4096 bits ffdh   0.0129s     77.8
                ## for *.log
                # CUR_TABLE_TYPE="dh"
                # awk '$1$2$3 ~ /^[1-9][0-9]+bits?ffdh/ {$1=$3$1;$2="";$3=""; print}' "${LOG}" >> "${DAT}"
                awk '$1$2$3 ~ /^[1-9][0-9]+bits?ffdh/ {printf "%-25s %10s %10s %10s %10s\n", $3$1,"0","0","0",$5}' "${LOG}" >> "${DAT}"
            elif [[ "${ARR_OQS_KEM[*]}" == *"${algo}"* ]]; then
                INC_OQS_ALGO="yes"
                #               keygen    encaps    decaps keygens/s  encaps/s  decaps/s
                #   mlkem512 0.000015s 0.000010s 0.000009s   65849.0  100755.0  105835.9
                awk -v ALGO="${algo}" '$1 == ALGO {printf "%-25s %10s %10s %10s %10s\n", $1,$7,$6,$5,"0"}' "${LOG}" >> "${DAT}"
            elif [ "${algo: 0:6}" == "ML-KEM" ]; then
                awk -v ALGO="${algo}" '$1 == ALGO {printf "%-25s %10s %10s %10s %10s\n", $1,$7,$6,$5,"0"}' "${LOG}" >> "${DAT}"
            fi
        else
            CUR_TABLE_TYPE="kbytes"
            ## Examples of input formats:
            # type             16 bytes     64 bytes    256 bytes   1024 bytes   8192 bytes  16384 bytes
            awk '$1 == "type {print "#\n#"$0}' "${LOG}" >> "${DAT}"
            if [ -z "${NO_EVP_NAME}" ]; then
                if [ "${arr_evp_opt[*]}" == "-hmac" ]; then
                    # OpenSSL 3 and later
                    # hmac(sha512)     23408.12k    90165.99k   249721.98k   538953.37k   756375.73k   782985.02k
                    grep -i -E "^[ \t]*hmac\($algo\)" "${LOG}" >> "${DAT}"
                else
                    ## -evp
                    # aes-128-cbc     845296.57k  1422663.94k  1480359.68k  1446441.98k  1389936.64k  1412481.02k
                    # sha256           80287.30k   177244.16k   335795.46k   428160.00k   458956.80k   461897.73k
                    grep -i -E "^[ \t]*${algo}" "${LOG}" >> "${DAT}"
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
                # grep -i -E "^[ \t]*${ALGO3}" "${LOG}" | \
                #    awk -v NO_EVP_NAME="${NO_EVP_NAME}" '{if ( $2 !~ /^[0-9]+\.[0-9]+k$/ ) {$1=$1"-"$2NO_EVP_NAME;$2="";print} else {$1=$1NO_EVP_NAME;print}}' >> "${DAT}"
                awk -v NO_EVP_NAME="${NO_EVP_NAME}" -v REGEXP="^${ALGO3}" '$1 ~ REGEXP {if ( $2 !~ /^[0-9]+\.[0-9]+k$/ ) {$1=$1"-"$2NO_EVP_NAME;$2="";print} else {$1=$1NO_EVP_NAME;print}}' "${LOG}" >> "${DAT}"
            fi
        fi

        # Set then check TABLE_TYPE's.
        if [ ${cou} -ge 1 ] && [ "${PRE_TABLE_TYPE}" != "${CUR_TABLE_TYPE}" ] ; then
            # exception
            if [[ "${PRE_TABLE_TYPE}" == "sig_ver_keygen" && \
                  "${CUR_TABLE_TYPE}" == "dec_enc_keygen_dh" ]] || \
               [[ "${CUR_TABLE_TYPE}" == "sig_ver_keygen"  && \
                  "${PRE_TABLE_TYPE}" == "dec_enc_keygen_dh" ]]; then
                SIG_ENC_MIX="yes"
            else
                echo
                echo "Warning: skipped because CUR_TABLE_TYPE ($CUR_TABLE_TYPE)"
                echo "         differs from the previous one (${PRE_TABLE_TYPE})!"
                echo
                continue
                # echo "Error: CUR_TABLE_TYPE (${CUR_TABLE_TYPE}) differs from"
                # echo "       the previous one (${PRE_TABLE_TYPE})!"
                # echo
                # exit 2
            fi
        fi
        PRE_TABLE_TYPE=${CUR_TABLE_TYPE}
        cou=$((cou+1))
    done
    if [ "${SIG_ENC_MIX}" == "yes" ]; then
        TABLE_TYPE="sig_enc_mix"
    else
        TABLE_TYPE=${PRE_TABLE_TYPE}
    fi
    # rm -f "${LOG}"
}

##
# @brief        Check the table format in ${DAT} and set global NUM_FIELD and
#               TABLE_TYPE if not yet.
# @param[in]    ${DAT} [file name]
#               global ${TABLE_TYPE}
# @param[out]   ${TABLE_TYPE} if not set yet, i.e. when plotting given data
#               without measure ().
# @param[out]   ${NUM_FIELD}
table_type () {
    NUM_FIELD="${NUM_FIELD% }"  # remove the last space
    local GUESSED_TABLE_TYPE
    local NUM_FIELD_VARIATION
    NUM_FIELD_VARIATION=$(echo "${NUM_FIELD}" | wc -l | awk '{print $1}' )
    # example of a table of "NUM_FIELD_VARIATION == 3"
    # enc/s keygen/s dh/s
    #  xxx      0
    #  xxx    yyy
    #  xxx    yyy    zzz
    # if [ "${NUM_FIELD_VARIATION}" == "1" ]; then
    if [ "${NUM_FIELD_VARIATION}" -ge 1  ] && [ "${NUM_FIELD_VARIATION}" -le 2  ]; then
        if [ -z "${TABLE_TYPE}" ]; then
            echo "NUM_FIELD: ${NUM_FIELD}"
            case "${NUM_FIELD}" in
                # 6 for LibreSSL 2.8.3
                6|7|"6 7") GUESSED_TABLE_TYPE="kbytes";;
                5) GUESSED_TABLE_TYPE="dec_enc_keygen_dh";;
                # 5) GUESSED_TABLE_TYPE="sig_ver";;  # or use "-l" option
                4) GUESSED_TABLE_TYPE="sig_ver_keygen";;
                "4 5") GUESSED_TABLE_TYPE="sig_enc_mix";;
                3) GUESSED_TABLE_TYPE="sig_ver_from_cycles";;
                2) GUESSED_TABLE_TYPE="dh";;
                0|1) echo "Warning: ${DAT} has no appropriate table!";
                return 1;;
                # exit 1;;
                *) echo "Error: unknown data format!";
                return 1;;
                # exit 1;;
            esac
            TABLE_TYPE=${GUESSED_TABLE_TYPE}
        fi
    else
        echo
        echo "Error: records are not in the same format!"
        echo
        return 1
    fi
    return 0
}


##
# @brief        Set graph title.
# @param[in]    global params
# @param[out]   global GRA_OPT_COMMON
set_gra_title () {
    if [ -n "${t_arg}" ]; then
        GRA_TITLE_APPENDIX="${t_arg}"
    else
        if [ "${PLOT_DATA_FILE}" == "1" ]; then
            GRA_TITLE_APPENDIX=""
        else
            # OPENSSL_VER_NOSPACE="$(echo "${OPENSSL_VER}" | awk '{print $1 $2}')"
            openssl_ver_nospace_from_command
            GRA_TITLE_APPENDIX="with ${OPENSSL_VER_NOSPACE}"
            if [ "${INC_OQS_ALGO}" == "yes" ]; then
                [ -z "${LIBOQS_VER}" ] && liboqs_ver_from_command
                GRA_TITLE_APPENDIX="${GRA_TITLE_APPENDIX} liboqs${LIBOQS_VER}"
            fi
        fi
    fi
    GRA_OPT_COMMON="\
        set key ${GRA_KEY_POS} tmargin horizontal;\
        "
    GRA_TITLE_ONE_LINE="Depicted by ${COMMAND} v${VER} ${GRA_TITLE_APPENDIX}"
    GRA_TITLE_TWO_LINES="Depicted by ${COMMAND} v${VER} \n${GRA_TITLE_APPENDIX}"
    echo "Title length: ${#GRA_TITLE_ONE_LINE}"
    # if [ "${#GRA_TITLE_ONE_LINE}" -gt 65 ] && [ "${NUM_OF_RECORDS}" -le 8 ]; then
    if [ "${#GRA_TITLE_ONE_LINE}" -gt 70 ]; then
        GRA_OPT_COMMON="${GRA_OPT_COMMON} set title \"${GRA_TITLE_TWO_LINES}\" noenhanced;"
    else
        GRA_OPT_COMMON="${GRA_OPT_COMMON} set title \"${GRA_TITLE_ONE_LINE}\" noenhanced;"
    fi
}


##
# @brief        Set params and plot.
# @param[in]    global t_arg
# @param[in]    global DAT [file name]
# @param[in]    global TABLE_TYPE
# @param[in]    global NUM_FIELD
# @param[in]    global LIBOQS_VER INC_OQS_ALGO
# @param[out]   Figure in global GRA_FILE
plot_data () {
    local COLUMN_VAL
    echo
    echo "--- plot ---"
    ## Graph type
    # GRA_TYPE=linespoints
    GRA_TYPE="histogram"

    GRA_YTICS=""
    if [ "${TABLE_TYPE}" == "kbytes" ]; then
        # symmetric algo's
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
    else
        # asymmetric algo
        XTICS_ROTATE_ANGLE="-15"
        SPEED_UNIT="operations/s"
        if [ "${TABLE_TYPE}" == "sig_ver_keygen" ]; then
            # The order '(verify or enc)/s' to '(sign or dec)/s' is for the compatibility to v0.0.0.
            GRA_PLOT=" \
                \"./${DAT}\" using ${GRA_CLM}3:xtic(1) with ${GRA_TYPE} title 'verify/s', \
                \"./${DAT}\" using ${GRA_CLM}2:xtic(1) with ${GRA_TYPE} title 'sign/s', \
                "
            COLUMN_VAL="$(awk '(! /^[ \t]*#/) {print $4}' "${DAT}" | uniq | tr -d '\r\n')"
            if ! [[ -z "${COLUMN_VAL}" || "${COLUMN_VAL}" == "0" ]]; then
                GRA_PLOT="${GRA_PLOT} \
                \"./${DAT}\" using ${GRA_CLM}4:xtic(1) with ${GRA_TYPE} title 'keygen/s', \
                "
            fi
        elif [ "${TABLE_TYPE}" == "dec_enc_keygen_dh" ]; then
            # The order '(verify or enc)/s' to '(sign or dec)/s' is for the compatibility to v0.0.0.
            unset GRA_PLOT
            COLUMN_VAL="$(awk '(! /^[ \t]*#/) {print $3}' "${DAT}" | uniq | tr -d '\r\n')"
            if ! [[ -z "${COLUMN_VAL}" || "${COLUMN_VAL}" == "0" ]]; then
                GRA_PLOT="${GRA_PLOT} \
                \"./${DAT}\" using ${GRA_CLM}3:xtic(1) with ${GRA_TYPE} title 'enc/s', \
                "
            fi
            COLUMN_VAL="$(awk '(! /^[ \t]*#/) {print $2}' "${DAT}" | uniq | tr -d '\r\n')"
            if ! [[ -z "${COLUMN_VAL}" || "${COLUMN_VAL}" == "0" ]]; then
                GRA_PLOT="${GRA_PLOT} \
                \"./${DAT}\" using ${GRA_CLM}2:xtic(1) with ${GRA_TYPE} title 'dec/s', \
                "
            fi
            COLUMN_VAL="$(awk '(! /^[ \t]*#/) {print $4}' "${DAT}" | uniq | tr -d '\r\n')"
            if ! [[ -z "${COLUMN_VAL}" || "${COLUMN_VAL}" == "0" ]]; then
                GRA_PLOT="${GRA_PLOT} \
                \"./${DAT}\" using ${GRA_CLM}4:xtic(1) with ${GRA_TYPE} title 'keygen/s', \
                "
            fi
            COLUMN_VAL="$(awk '(! /^[ \t]*#/) {print $5}' "${DAT}" | uniq | tr -d '\r\n')"
            if ! [[ -z "${COLUMN_VAL}" || "${COLUMN_VAL}" == "0" ]]; then
                GRA_PLOT="${GRA_PLOT} \
                \"./${DAT}\" using ${GRA_CLM}5:xtic(1) with ${GRA_TYPE} title 'dh/s', \
                "
            fi
        elif [ "${TABLE_TYPE}" == "sig_enc_mix" ]; then
            # The order '(verify or enc)/s' to '(sign or dec)/s' is for the compatibility to v0.0.0.
            GRA_PLOT=" \
                \"./${DAT}\" using ${GRA_CLM}3:xtic(1) with ${GRA_TYPE} title '(verify or enc)/s', \
                \"./${DAT}\" using ${GRA_CLM}2:xtic(1) with ${GRA_TYPE} title '(sign or dec)/s', \
                "
            COLUMN_VAL="$(awk '(! /^[ \t]*#/) {print $4}' "${DAT}" | uniq | tr -d '\r\n')"
            if ! [[ -z "${COLUMN_VAL}" || "${COLUMN_VAL}" == "0" ]]; then
                GRA_PLOT="${GRA_PLOT} \
                \"./${DAT}\" using ${GRA_CLM}4:xtic(1) with ${GRA_TYPE} title 'keygen/s', \
                "
            fi
            COLUMN_VAL="$(awk '(! /^[ \t]*#/) {print $5}' "${DAT}" | uniq | tr -d '\r\n')"
            if ! [[ -z "${COLUMN_VAL}" || "${COLUMN_VAL}" == "0" ]]; then
                GRA_PLOT="${GRA_PLOT} \
                \"./${DAT}\" using ${GRA_CLM}5:xtic(1) with ${GRA_TYPE} title 'dh/s', \
                "
            fi
        elif [ "${TABLE_TYPE}" == "sig_ver" ]; then
            # for 'algo sign verify sign/s verify/s'
            # The order '(verify or enc)/s' to '(sign or dec)/s' is for the compatibility to v0.0.0.
            GRA_PLOT=" \
                \"./${DAT}\" using ${GRA_CLM}5:xtic(1) with ${GRA_TYPE} title 'verify/s', \
                \"./${DAT}\" using ${GRA_CLM}4:xtic(1) with ${GRA_TYPE} title 'sign/s', \
                "
        elif [ "${TABLE_TYPE}" == "sig_ver_9columns" ]; then
            # for 'algo sign    verify    encrypt   decrypt   sign/s verify/s  encr./s  decr./s'
            # The order '(verify or enc)/s' to '(sign or dec)/s' is for the compatibility to v0.0.0.
            GRA_PLOT=" \
                \"./${DAT}\" using ${GRA_CLM}7:xtic(4) with ${GRA_TYPE} title 'verify/s', \
                \"./${DAT}\" using ${GRA_CLM}6:xtic(4) with ${GRA_TYPE} title 'sign/s', \
                "
        elif [ "${TABLE_TYPE}" == "dh" ]; then
            # for 'algo op op/s' or 'algo dh dh/s'
            GRA_PLOT=" \
                \"./${DAT}\" using ${GRA_CLM}3:xtic(1) with ${GRA_TYPE} title 'dh/s' \
                "
        elif [ "${TABLE_TYPE}" == "sig_cycles_real_comp" ]; then
            # for 'algo sign verify sign/s verify/s' converted with 2.5x10^9/cycles
            GRA_PLOT=" \
                \"./${DAT}\" using ${GRA_CLM}2:xtic(1) with ${GRA_TYPE} title 'sign/s', \
                \"./${DAT}\" using ${GRA_CLM}3:xtic(1) with ${GRA_TYPE} title 'sign/s (from cycles)', \
                "
        elif [ "${TABLE_TYPE}" == "ver_cycles_real_comp" ]; then
            # for 'algo sign verify sign/s verify/s' converted with 2.5x10^9/cycles
            GRA_PLOT=" \
                \"./${DAT}\" using ${GRA_CLM}2:xtic(1) with ${GRA_TYPE} title 'verify/s', \
                \"./${DAT}\" using ${GRA_CLM}3:xtic(1) with ${GRA_TYPE} title 'verify/s (from cycles)', \
                "
        elif [ "${TABLE_TYPE}" == "sig_ver_from_cycles" ]; then
            # for 'algo sign verify sign/s verify/s' converted with 2.5x10^9/cycles
            # The order '(verify or enc)/s' to '(sign or dec)/s' is for the compatibility to v0.0.0.
            GRA_PLOT=" \
                \"./${DAT}\" using ((2500000/\$3)*1000):xtic(1) with ${GRA_TYPE} title 'verify/s', \
                \"./${DAT}\" using ((2500000/\$2)*1000):xtic(1) with ${GRA_TYPE} title 'sign/s', \
                "
        else
            echo "Unknown TABLE_TYPE: ${TABLE_TYPE}"
        fi
    fi

    # Set graph params depending on # of records.
    declare -i NUM_OF_RECORDS
    # num="$(awk '(! /^[ \t]*#/) && (NF > 1) {n+=1} END{print n}' "${DAT}" | uniq)"
    NUM_OF_RECORDS="$(awk '(! /^[ \t]*#/) && (NF > 1) {n+=1} END{print n}' "${DAT}")"
    GRA_KEY_POS="center"  # default
    echo "# of records: ${NUM_OF_RECORDS}"
    if [ "${NUM_OF_RECORDS}" -ge 14 ]; then
        GRA_XTICS_ROTATE="set xtics rotate by -90;"
        # GRA_KEY_POS="center"
    elif [ "${NUM_OF_RECORDS}" -ge 6 ]; then
        # GRA_XTICS_ROTATE="set xtics rotate by -60 offset first -0.3,0;"
        GRA_XTICS_ROTATE="set xtics rotate by -45 offset first -0.4,0;"
        # GRA_KEY_POS="center"
    elif [ "${NUM_OF_RECORDS}" -ge 3 ]; then
        GRA_XTICS_ROTATE="set xtics rotate by ${XTICS_ROTATE_ANGLE} offset first -0.4,0;"
        # GRA_KEY_POS="center"
    else
        GRA_XTICS_ROTATE=""
        # GRA_KEY_POS="right"
    fi

    ## Graph title
    set_gra_title

    # "linespoints" or "histogram"
    if [ "$GRA_TYPE" == "linespoints" ]; then
        GRA_CLM="0:"
        GRA_OPT="${GRA_OPT_COMMON};"
    elif [ "$GRA_TYPE" == "histogram" ]; then
        GRA_CLM=""
        GRA_OPT="${GRA_OPT_COMMON}; \
            set style histogram clustered; \
            set style fill solid border lc rgb 'black';\
            "
    fi

    # NOTE:
    #   - "noenhanced" is to support the name of OV (and UOV) that
    #    includes '_', such as 'OV_I*'
    #   - cf. http://gnuplot.info/
    gnuplot -p -e "set terminal png noenhanced; set output '${GRA_FILE}'; \
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
# @brief        Add dynamic-link lib path for built openssl.
# @param[in]    OPENSSL
# @param[out]   DYLD_LIBRARY_PATH or LD_LIBRARY_PATH
add_ld_lib_path (){
    # neither openssl in the PATH nor <PATH>/openssl.exe 
    if [ "${OPENSSL}" != "openssl" ] && \
       [ "${OPENSSL}" == "${OPENSSL%.exe}" ]; then  # not <PATH>/*.exe
        echo "OPENSSL: ${OPENSSL}"
        echo "PWD: ${PWD}"
        if [[ ${OPENSSL} != *"wrap.pl"* ]]; then
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
            # if [[ "$(uname -s)" == "Darwin"* ]]; then
            if [ "${UNAME_S}" == "Darwin" ]; then
                # macOS
                # Add the path to lib{ssl,crypto}.3.dylib in ./tmp/openssl-*.*.*/ .
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
    fi
}


##
# @brief        Option check for common.
# @param[in]    global variables
# @exit         2 if error
optcheck_common () {
    ### opt check ###

    # override DEFAULT
    # echo "GRA_FILE=${GRA_FILE} DAT=${DAT}"
    if [ -n "${GRA_FILE}" ] && [ -z "${DAT}" ]; then
        # only -o
        DAT="${GRA_FILE%.png}.dat"
    elif [ -z "${GRA_FILE}" ] && [ -n "${DAT}" ]; then
        # only -d
        GRA_FILE="${DAT%.dat}.png"
    fi
    [ -z "${GRA_FILE}" ] && GRA_FILE=${DEFAULT_GRA_FILE}
    [ -z "${DAT}" ] && DAT=${DEFAULT_DAT_FILE}

    # usage() must be here since it depends on options
    [ "${flagh}" == "1" ] && { usage; exit 2;}

    # arg check for -o and -d
    check_path "${ALLOWED_DIR}" "${GRA_FILE}"
    check_path "${ALLOWED_DIR}" "${DAT}"

    # If the data filename to read differs from the filename that replaced
    # graph name's .png with .dat, duplicate it.
    DAT_FILENAME_FROM_GRAPH="${GRA_FILE%.*}.dat"
    if [ "${DAT}" != "${DAT_FILENAME_FROM_GRAPH}" ]; then
        # or ln -s
        cp -fp "${DAT}" "${DAT_FILENAME_FROM_GRAPH}"
    fi
}


##
# @brief        Option check for measure-plot mode.
# @param[in]    global variables
# @param[out]   global ARR_SPEED_OPT OPENSSL_VER
# @exit         2 if error
optcheck_measure_plot () {
    # arg check for -p
    if [ "${flagp}" == "1" ]; then
        # uncomment the next line to limit to "${ALLOWED_DIR}"
        # check_path "${ALLOWED_DIR}" "${OPENSSL}"
        #
        # -p /usr/bin/openssl
        # if [ "${OPENSSL: -7}" != openssl ]; then
        # -p /usr/bin/openssl or *openssl.exe
        if ! [[ "${OPENSSL: -7}" == openssl || "${OPENSSL: -11}" == openssl.exe ]]; then
            echo
            echo "Error: '-p ${OPENSSL}' option accepts only the combination of 'openssl'"
            echo "       command and the path to it!"
            echo
            exit 2
        fi
        # to avoid suspicious input
        # TODO: accept more flex patterns for util/wrap.pl
        if [ "${OPENSSL: 0: 28}" != "./util/wrap.pl -fips ./apps/" ]; then
            if [ "${OPENSSL}" != openssl ] && [ "${OPENSSL}" != openssl.exe ] && [ ! -s "${OPENSSL}" ]; then
                echo
                echo "Error: '${OPENSSL}' given by -p option does not exist!"
                echo
                exit 2
            fi
        fi
    fi
    add_ld_lib_path
    OPENSSL_VER=$(${OPENSSL} version)
    # arg check for -s
    if [ -n "${s_arg}" ]; then
        if [[ "${s_arg}" =~ ^[1-9][0-9]?$ ]]; then
            ARR_SPEED_OPT=("-seconds" "${s_arg}")  # shall be an array to make "${ARR_SPEED_OPT[@]}" null
        else
            echo
            echo "Error: invalid '${s_arg}' for -s option!"
            echo
            usage; exit 2
        fi
        if [[ "${OPENSSL_VER}" == "LibreSSL"* ]]; then
            echo
            echo "Warning: -s option for \"${ARR_SPEED_OPT[*]}\" is ignored on LibreSSL."
            echo "  Change '${COMMAND}' after LibreSSL supports it."
            ARR_SPEED_OPT=()
        fi
    fi
}


##
# @brief        Option check for data-plot mode.
# @param[in]    $1 : $#
#               $2 : $flagp
#               global variables
# @exit         2 if error
optcheck_data_plot () {
    # opt check
    flagp="$2"
    if [ "${flagp}" == "1" ]; then
        echo
        echo "Warning: -p option is ignored."
    fi
    if [ -n "${ARR_SPEED_OPT[*]}" ]; then
        echo
        echo "Warning: -s option for \"${ARR_SPEED_OPT[*]}\" is ignored."
    fi
    if [ "$1" == "0" ] && [ ! -s "${DAT}" ]; then
        echo
        echo "Error: '${DAT}' does not exist!"
        echo
        exit 2
    fi
}


### getopts ###

OPENSSL=${DEFAULT_OPENSSL}
# GRA_FILE=${DEFAULT_GRA_FILE}

s_arg=""; t_arg=""
ARR_SPEED_OPT=()  # default: 3s for symmetric, 10s for asymmetric
flagh=0; flagp=0
while getopts 'd:l:o:p:s:t:h?' OPTION
do
    case $OPTION in
        d) DAT="${OPTARG}";;                # override
        l) TABLE_TYPE="${OPTARG}";;
        o) GRA_FILE="${OPTARG}";;
        p) flagp=1;OPENSSL="${OPTARG}";;      # override
        s) s_arg=${OPTARG};;  # openssl speed -seconds
        t) t_arg=${OPTARG};;
        h|?|*) flagh=1;;
    esac
done
shift $((OPTIND - 1))

##### main and opt check #####
optcheck_common
[ $# -eq 0 ] && PLOT_DATA_FILE=1
if [ "$PLOT_DATA_FILE" != "1" ]; then
    optcheck_measure_plot
    # NOTE:
    #   - $@ is either an algo or an array of algo's.
    #   - If inappropriate strings are given to $@,
    #     it will be "Unknown algorithm" error.
    measure "$@"
else
    optcheck_data_plot "$#" "$flagp"
fi

# Set TABLE_TYPE and NUM_FIELD
if [ ! -s "${DAT}" ]; then
    echo
    echo "Warning: '${DAT}' does not exist. Skipped!"
    echo
    exit 0
fi
# Check if records exist and they are in the same format.
# On macOS:
#   $ wc -l  ./graph.dat
#   "    0 ./graph.dat"
# NUM_FIELD=$(awk '(! /^[ \t]*#/) && (NF > 1) {print NF}' "${DAT}" | sort -u | tr '\r\n' ' ' | sed -E 's/[ ]+/ /g' )
NUM_FIELD="$(awk '(! /^[ \t]*#/) && (NF > 1) {print NF}' "${DAT}" | sort -u | tr '\r\n' '  ' | tr -s ' ' )"
if [ -z "${NUM_FIELD}" ]; then
    echo
    echo "Warning: '${DAT}' has no data. Skipped!"
    echo
    exit 0
fi
table_type "${DAT}" || exit 1
plot_data

echo
# echo "Graph is in ${GRA_FILE}"
echo "Graph is in $(realpath "${GRA_FILE}")"
