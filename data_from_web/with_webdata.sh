#!/usr/bin/env bash
#
# This file is part of https://github.com/KazKobara/plot_openssl_speed
# Copyright (C) 2024 National Institute of Advanced Industrial Science and Technology (AIST). All Rights Reserved.
set -e
# set -x

### Params ###
VER=1.0.1
COMMAND=$(basename "$0")
COMMAND_TMP="${COMMAND%.sh}.tmp"
rm -f "${COMMAND_TMP}"
GNUPLOT_VER=$(gnuplot -V)

##### functions #####
### for cycles and size

usage () {
    echo " Plot cycles with web-data ${VER}"
    echo
    echo " Usage:"
    echo "   Collect and plot (collect-plot mode):"
    echo
    echo "     \$ ./${COMMAND}"
    echo
    echo "   Plot given data (data-plot mode):"
    echo
    echo "     \$ ./${COMMAND} -d data_file_to_graph [-o filename.png]"
    echo
    echo "   options:"
    echo "     [-d data_file_to_graph]"
    echo "         For the format, cf. https://github.com/KazKobara/plot-openssl-speed?tab=readme-ov-file#data-file-format-for-with_webdatash ."
    echo "     [-o filename.png]"
    echo "         Output png file (default: '<filename>.png' for"
    echo "         -d <filename>.dat' is given)."
    echo "     [-(h|?)]"
    echo "         Show this usage."
    echo
    echo " With:"
    echo "   ${GNUPLOT_VER}"
}


##
# @brief        Check the necessary commands or exit 0
# @param[in]    ${NODE}
check_necessary_commands () {
    local warned npm_list 
    warned=0
    if [ -z "$(command -v "${NODE}")" ]; then
        warned=1
    else
        # '|| echo' is necessary to avoid macOS's zsh catches `npm list`'s return code 1 and exits.
        npm_list="$(cd ../../../data_from_web && npm list || echo )"
        echo "${npm_list}" | grep -q -E "puppeteer@[0-9]" || warned=2
    fi
    if [ "${warned}" -gt "0" ]; then
        echo
        echo "Notice: To compare with benchmarks on the web"
        [ "${warned}" == "1" ] && \
        echo "      - Install '${NODE}' command"
        echo "      - Run (in the './data_from_web' dir)"
        echo "        $ npm install --save puppeteer"
        echo "        $ npx @puppeteer/browsers install chrome@stable"
        echo
        # exit with 0 to continue the script invoked this script.
        exit 0
    fi
}

### for cycles only

##
# @brief        Append candlestick-data of ${DSV_SIG_PQS} to ${COMP_DAT}
# @param[in]    ${URL_DSV_ARR} ${NODE} ${HTML_TABLE2DSV}
#               ${TAG_KEYGEN} ${TAG_SIG_DEC} ${TAG_VER_ENC}
# @param[out]   ${COMP_DAT}
append_dsv_sig_pqs2candlesticks () {
    # Scheme^IParameterset^INIST level^ISign (cycles)^IVerify (cycles)
    # ML-DSA (Dilithium)^IML-DSA-87^I5^I642,192^I279,936
    # ML-DSA (Dilithium)^IML-DSA-65^I3^I529,106^I179,424
    # ML-DSA (Dilithium)^IML-DSA-44^I2^I333,013^I118,412
    #
    # Falcon^I1024^I5^I2,053,080^I160,596
    # Falcon^I512^I1^I1,009,764^I81,036
    #
    # SLH-DSA (SPHINCS+)^ISHAKE-192s^I3^I8,091,419,556^I6,465,506
    # SLH-DSA (SPHINCS+)^ISHAKE-256s^I5^I7,085,272,100^I10,216,560
    # SLH-DSA (SPHINCS+)^ISHAKE-128s^I1^I4,682,570,992^I4,764,084
    # SLH-DSA (SPHINCS+)^ISHAKE-256f^I5^I763,942,250^I19,886,032
    # SLH-DSA (SPHINCS+)^ISHAKE-192f^I3^I386,861,992^I19,876,926
    # SLH-DSA (SPHINCS+)^ISHAKE-128f^I1^I239,793,806^I12,909,924
    #
    # where '^I' is '\t'
    awk -F'\t' -v ALGO_TO_PREPEND_TO_PARAMS_PQS="${ALGO_TO_PREPEND_TO_PARAMS_PQS}" \
        -v WEB_NAME="${web_name}" -v ALGO_REGEX="${algo_to_find}" \
        -v TAG_K="${TAG_KEYGEN}" -v TAG_S="${TAG_SIG_DEC}" -v TAG_V="${TAG_VER_ENC}" \
        '$1$2$3 ~ ALGO_REGEX {if (NF==5) {
        gsub(" ","",$2);
        gsub(",","",$4);gsub(",","",$5); $7=$2; gsub(/[^0-9]*/,_,$7);
        {printf "%s %10s %10s %10s %10s %-30s %10s\n",
            "0",$4,$4,$4,$4,TAG_S ALGO_TO_PREPEND_TO_PARAMS_PQS $2"("WEB_NAME")",$7};
        {printf "%s %10s %10s %10s %10s %-30s %10s\n",
            "0",$5,$5,$5,$5,TAG_V ALGO_TO_PREPEND_TO_PARAMS_PQS $2"("WEB_NAME")",$7}
        }
    }' "${dsv}" >> "${COMP_DAT}"
}

##
# @brief        Append candlestick-data of ${DSV_SIG_EBATS_*} to ${COMP_DAT}
# @param[in]    ${name} ${URL_DSV_ARR} ${NODE} ${HTML_TABLE2DSV}
#               ${TAG_KEYGEN} ${TAG_SIG_DEC} ${TAG_VER_ENC}
# @param[out]   ${COMP_DAT}
append_dsv_ebats2candlesticks () {
    # 25%^I50%^I75%^Isystem
    # where '^I' is '\t' for
    # Cycles to generate a key pair
    # 33094^I33541^I33924^Idilithium2aes
    # 14506697^I15339650^I16428953^IT:falcon512tree
    # 14565379^I15878830^I16793475^IT:falcon512dyn
    # 427365^I427745^I445804^IT:sphincsf128harakasimple
    # 497278^I498453^I499666^IT:sphincsf128harakarobust
    # Cycles to sign 59 bytes
    # 76090?^I86116?^I134869?^Idilithium2aes
    # "Cycles to verify 59 bytes"
    # 42770^I42987^I43140^Idilithium2aes

    # kem
    # 9460^I9573^I9711^Ikyber90s512
    # 13664^I13837^I14162^Ikyber90s768
    # 19550^I19655^I19933^Ikyber512
    # 19517^I19772^I20286^Ikyber90s1024
    #

    # TODO: use ML-DSA if measured
    # NOTE: MacOS's awk (version 20200816) causes "illegal primary in regular expression ? at" gsub("?","")
    awk -F'\t' -v WEB_NAME="${web_name}" \
        -v ALGO_REGEX="${algo_to_find}" \
        -v TAG_K="${TAG_KEYGEN}" -v TAG_S="${TAG_SIG_DEC}" -v TAG_V="${TAG_VER_ENC}" \
        'BEGIN {cou1=0; } {
        if ($4 ~ ALGO_REGEX ) {cou1++; gsub(/¥?/,"");
            $7=$4; gsub(/[^0-9]*/,_,$7);
            if (cou1==1) {printf "%s %10s %10s %10s %10s %-30s %10s\n",
                "0",$1,$2,$3,$3,TAG_K$4"("WEB_NAME")",$7} else
            if (cou1==2) {printf "%s %10s %10s %10s %10s %-30s %10s\n",
                "0",$1,$2,$3,$3,TAG_S$4"("WEB_NAME")",$7} else
            if (cou1==3) {printf "%s %10s %10s %10s %10s %-30s %10s\n",
                "0",$1,$2,$3,$3,TAG_V$4"("WEB_NAME")",$7}
            }
        }' "${dsv}" >> "${COMP_DAT}"
}


##
# @brief        Append candlestick-data of OQS ${dsv} to ${COMP_DAT}
# @param[in]    ${dsv} ${LIBOQS_VER} ${MHZ}
#               ${TAG_KEYGEN} ${TAG_SIG_DEC} ${TAG_VER_ENC}
# @param[out]   ${COMP_DAT}
append_oqs_dsv2candlesticks () {
    if [ -s "${dsv}" ]; then
        awk -v MHZ="${MHZ}" -v LIBOQS_VER="${LIBOQS_VER}" \
            -v ALGO_REGEX="^${algo_to_find}" \
            -v TAG_K="${TAG_KEYGEN}" -v TAG_S="${TAG_SIG_DEC}" -v TAG_V="${TAG_VER_ENC}" \
            '$1 ~ ALGO_REGEX {
            { CYCLE=(MHZ*1000/$4)*1000; $7=$1; gsub(/[^0-9]*/,_,$7);
            printf "%s %10s %10s %10s %10s %-30s %10s\n",
                "0",CYCLE,CYCLE,CYCLE,CYCLE,TAG_K $1"(liboqs"LIBOQS_VER")",$7};
            { CYCLE=(MHZ*1000/$2)*1000; $7=$1; gsub(/[^0-9]*/,_,$7);
            printf "%s %10s %10s %10s %10s %-30s %10s\n",
                "0",CYCLE,CYCLE,CYCLE,CYCLE,TAG_S $1"(liboqs"LIBOQS_VER")",$7};
            { CYCLE=(MHZ*1000/$3)*1000; $7=$1; gsub(/[^0-9]*/,_,$7);
            printf "%s %10s %10s %10s %10s %-30s %10s\n",
                "0",CYCLE,CYCLE,CYCLE,CYCLE,TAG_V $1"(liboqs"LIBOQS_VER")",$7};
        }' "${dsv}" >> "${COMP_DAT}"
    else
        echo
        echo "Warning: '${dsv}' does not exist, skipped!"
        echo
    fi
}

##
# @brief        Make candlestick data from Web
# @details      Get delimiter separated value files from Web if not yet.
#               Then convert it to candlestick data.
# @param[in]    ${COMP_DAT}
#               ${URL_DSV_ARR} ${NODE} ${HTML_TABLE2DSV} ${UNI_OR_DIV}
# @param[out]   ${DSV_*} file, which is ${dsv} in ${URL_DSV_ARR}
candlesticks_from_web () {
    local IFS url dsv web_name
    for i in "${URL_DSV_ARR[@]}" ; do
        # parse to url dsv web_data_name algo_to_find algo_to_prepend_to_params
        IFS=" " read -r -a d <<< "${i}"
        url="${d[0]}"
        dsv="${d[1]}"
        web_name="${d[2]}"
        algo_to_find="${d[3]}"
        [ ${#d[@]} -gt 4 ] && ALGO_TO_PREPEND_TO_PARAMS_PQS="${d[4]}"
        if [[ "${dsv}" == *".dat" ]]; then
            # measured oqs data
            if [ -s "${dsv}" ]; then
                append_oqs_dsv2candlesticks
            else
                echo "Notice: '${dsv}' does not exist. Skipped!"
            fi
        else
            # get dsv from web
            if [ ! -s "${dsv}" ]; then
                "${NODE}" "${HTML_TABLE2DSV}" "${url}" > "${dsv}"
            else
                echo "Notice: '${dsv}' was used. To update, move/remove it!" >> "${COMMAND_TMP}"
            fi
            # dsv to candlestick data
            case "${dsv}" in 
                "${DSV_SIG_PQS}") append_dsv_sig_pqs2candlesticks ;;
                *"ebats"*)  append_dsv_ebats2candlesticks ;;
            esac
        fi
    done

    if [ -z "${UNI_OR_DIV}" ]; then
        # UNI_OR_DIV="unified_only"  # an unified graph of keygen, sig/dec and ver/enc
        # UNI_OR_DIV="divided_only"  # divided graphs of them
        UNI_OR_DIV="both"
    fi
    # keygen sig/dec and ver/enc
    sort -V -k 6 -o "${COMP_DAT}" "${COMP_DAT}"
    # sort -k 6.1,6.3 -o "${COMP_DAT}" "${COMP_DAT}"
    # shellcheck disable=SC2094  # intentional overwrite
    # nl -w 3 -s" " -b p'^[ \t]*0[ \t]*' < "${COMP_DAT}" 1<> "${COMP_DAT}"

    awk 'BEGIN {cou=0} {
        if ($1 ~ /^#/) { print } else { cou++;
            printf "%3d ",cou; print;
        }}' < "${COMP_DAT}" 1<> "${COMP_DAT}"

    # add header
    {
        echo "# x min      25%        50%        75%        max (k|s|v|d|e):name(source)             parameter";
        echo "# x dummy    25%        50%        75%      dummy (k|s|v|d|e):'25/50/75% are given'    parameter";
        echo "# x dummy  dummy       mean      dummy      dummy (k|s|v|d|e):'only the mean is given' parameter";
    } >> "${COMP_DAT}.tmp"
    cat "${COMP_DAT}" >> "${COMP_DAT}.tmp"
    mv -f "${COMP_DAT}.tmp" "${COMP_DAT}"

    if [ "${UNI_OR_DIV}" == "unified_only" ] || 
        [ "${UNI_OR_DIV}" == "both" ]; then
        GRA_FILE="${COMP_DAT%.dat}.png"
        plot_as_candlesticks
    fi
    if [ "${UNI_OR_DIV}" == "divided_only" ] || 
        [ "${UNI_OR_DIV}" == "both" ]; then
        # divide them into keygen sig/dec ver/enc
        COMP_DAT_ORG="${COMP_DAT}"
        for tag_func in "${TAG_KEYGEN}" "${TAG_SIG_DEC}" "${TAG_VER_ENC}" ; do
            # cp "${COMP_DAT}_before_numbering" "${COMP_DAT}_${TAG_func:0:1}"
            COMP_DAT="${COMP_DAT_ORG%.dat}_${tag_func:0:1}.dat"
            # num 0   14565379   15878830   16793475   16793475 k:T:falcon512dyn(ebats-ryzen7)
            awk -v REGEXP="^${tag_func}" 'BEGIN {cou=0} {if ($7 ~ REGEXP) {
                cou++;
                printf "%3d ",cou; printf "%s %10s %10s %10s %10s %-30s %10s\n",$2,$3,$4,$5,$6,$7,$8;
                } else
                if ($1 ~ /^#/) { print } 
                }' "${COMP_DAT_ORG}" > "${COMP_DAT}"
            # append_oqs_dsv2candlesticks
            # sort -k 6 -o "${COMP_DAT}" "${COMP_DAT}"
            # shellcheck disable=SC2094  # intentional overwrite
            # nl -s" " -b p'[^#].*' < "${COMP_DAT}" 1<> "${COMP_DAT}"
            # nl -s" " -b p'^[ \t]*0[ \t]*' < "${COMP_DAT}" 1<> "${COMP_DAT}"
            # TODO: remove the spaces before '#', which are added by this 'nl' command
            GRA_FILE="${COMP_DAT%.dat}.png"
            plot_as_candlesticks
        done
    fi
}


##
# @brief        Get cpu frequency as MHz.
# @param[out]   ${MHZ}
get_cpu_mhz () {
    # NOTE: alternative
    # for linux
    # MHZ="$(awk '$1$2 == "cpuMHz" {print $4; exit}' /proc/cpuinfo)"
    # for mac
    # MHZ="$(sudo powermetrics | awk '$0 ~ "CPU Average frequency as fraction of nominal" {sub(/\(/,_,$9); print $9; exit})"
    # MHZ="$(sudo powermetrics | awk '$0 ~ "CPU Average frequency as fraction of nominal" {print substr($9,2); exit})"
    local hz_line hz
    if [[ "$(uname -s)" == "Darwin"* ]]; then
        # machdep.cpu.brand_string: Intel(R) Core(TM) i7-10810U CPU @ 1.10GHz
        hz_line="$(sysctl -a | grep "machdep.cpu.brand_string:")"
    else
        # model name      : Intel(R) Core(TM) i7-10810U CPU @ 1.10GHz
        hz_line="$(grep -i -m1 'model name' /proc/cpuinfo)"
    fi
    hz="$(echo "${hz_line}" | tr " " "\n" | grep -i "Hz")"
    local hz_num="${hz//[^0-9.]/}"  # remove non-numbers
    local hz_g_or_m="${hz: -3:1}"
    if [ "${hz_g_or_m}" == "G" ]; then
        MHZ="$(echo "${hz_num} * 1000" | bc)"
    else
        MHZ="${hz_num}"
    fi
}


##
# @brief        Plot as candlesticks.
# @param[in]    Data in the following files:
#               ${COMP_DAT}
#               ${Y_LOG_BASIS} : 0 for no logarithm scale
# @param[out]   Data in the following files:
#               ${GRA_FILE}
plot_as_candlesticks () {
    local tmp nr log_basis_e log_comp_dat comp_dat_org gra_file_org
    if [ -z "${Y_LOG_BASIS}" ]; then
        # Y_LOG_BASIS=0  # not logarithm
        Y_LOG_BASIS=2
    fi
    if [ "${Y_LOG_BASIS}" == 0 ]; then
        Y_LABEL="Cycles"
        Y_MIN=0
        # tmp="$(wc -l "${COMP_DAT}")"
        # nr="${tmp%[ ]+$}"
        nr="$(awk '$1 ~ /^[0-9]+$/' "${COMP_DAT}" | wc -l )"
    else
        Y_LABEL="log${Y_LOG_BASIS}(Cycles)"
        log_comp_dat="log${Y_LOG_BASIS}_${COMP_DAT}"
        log_basis_e="$(bc -l <<< "l(${Y_LOG_BASIS})")"
        awk -v LOG_BASIS_E="${log_basis_e}" '
            {if ($1 ~ /^#/) {
                print;
            } else {
                $3=log($3) / LOG_BASIS_E;
                $4=log($4) / LOG_BASIS_E;
                $5=log($5) / LOG_BASIS_E;
                $6=log($6) / LOG_BASIS_E;
                printf "%3d %s %10s %10s %10s %10s %-30s %10s\n",
                    $1,$2,$3,$4,$5,$6,$7,$8;
            }}
        ' "${COMP_DAT}" > "${log_comp_dat}"
        # switch to logarithm
        comp_dat_org="${COMP_DAT}"
        gra_file_org="${GRA_FILE}"
        COMP_DAT="${log_comp_dat}"
        GRA_FILE="${COMP_DAT%.dat}.png"
        # NOTE:
        #   "$1 ~ /[^#]/" counts blank lines.
        y_min_and_nr="$(awk '
            BEGIN {cou=0};
            $1 ~ /^[0-9]+$/ { cou++;
                if (cou==1)
                    {y_min=$3}
                else {
                    y_min=($3<y_min)?$3:y_min;
                }
            };
            END {print y_min-1,cou}
        ' "${COMP_DAT}")"
        Y_MIN="${y_min_and_nr%[ ][^ ]*}"
        nr="${y_min_and_nr##[^ ]*[ ]}"
    fi
    if [ "${nr}" -ge 15 ]; then
        xtics_rotate="-90"
        key_position="outside top horizontal"
    else
        xtics_rotate="-45"
        key_position="right outside vertical"
    fi
    gnuplot -p -e "
        set border 3; set grid;
        set title 'Depicted by ${COMMAND} of plot-openssl-speed v${VER}' noenhanced;
        set key ${key_position};
        set terminal png; set output '${GRA_FILE}';
        set xtics rotate by '${xtics_rotate}';\
        set boxwidth 0.5 absolute;
        set yrange [ '${Y_MIN}' : * ];
        set xrange [ 0 : '$((nr + 1))' ];
        set ylabel '${Y_LABEL}';
        plot [] ['${Y_MIN}':] '${COMP_DAT}' 
            using 1:3:3:5:5:xtic(7) with candlesticks lt 3 lw 2 title '25%-75%',
         '' using 1:4:4:4:4 with candlesticks lt -1 lw 2 title '50% or mean'"
:<<'# COMMENT_EOF'
        set key outside horizontal;
        set key right outside vertical;
        set key right tmargin horizontal;
    # gnuplot alternative options
        set xtics rotate by -45 offset first -0.4,0;
    # did not work with candlesticks
        set yrange [ 1 : * ];
        set logscale y 10;
# COMMENT_EOF
    if [ "${Y_LOG_BASIS}" != 0 ]; then
        COMP_DAT="${comp_dat_org}"
        GRA_FILE="${gra_file_org}"
    fi
}

##
# @brief        Setting for ML-DSA cycle data.
# @param[in]    ${OQS_SIG_SEL_DAT}
#               ${URL_SIG_PQS} ${DSV_SIG_PQS} ${WEB_NAME_PQS}
#               ${URL_SIG_EBATS_RYZEN7} ${DSV_SIG_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7}
# @param[out]   ${URL_DSV_ARR} ${COMP_DAT}
mldsa () {
    COMP_DAT=mldsa_cycles.dat
    rm -f "${COMP_DAT}"

    ### for liboqs ###
    # dummy ${OQS_SIG_SEL_DAT} dummy algorithm_name_to_find
    URL_DSV_ARR=(
        "- ${OQS_SIG_SEL_DAT} - mldsa"
    )

    ### for pqs ###
    local algo_to_find_pqs algo_to_prepend_to_params_pqs
    algo_to_find_pqs="ML-DSA"
    algo_to_prepend_to_params_pqs=""  # param includes algo name for ML-DSA
    # "${URL_SIG_PQS} ${DSV_SIG_PQS} ${WEB_NAME_PQS} ${algo_to_find_pqs} ${algo_to_prepend_to_params_pqs}"\
    URL_DSV_ARR+=(
        "${URL_SIG_PQS} ${DSV_SIG_PQS} ${WEB_NAME_PQS} ${algo_to_find_pqs} ${algo_to_prepend_to_params_pqs}"
    )

    ### for ebats ###
    # RYZEN7
    URL_DSV_ARR+=(
        "${URL_SIG_EBATS_RYZEN7} ${DSV_SIG_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7} dilithium2aes"
        "${URL_SIG_EBATS_RYZEN7} ${DSV_SIG_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7} dilithium3aes"
        "${URL_SIG_EBATS_RYZEN7} ${DSV_SIG_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7} dilithium5aes"
    )
:<<'# COMMENT_EOF'
    # NOTE: do not remove 
    # COREI7
    # "${URL_SIG_EBATS_COREI7} ${DSV_SIG_EBATS_COREI7} ${WEB_NAME_EBATS_COREI7} ${ALGO_TO_FIND}"
    URL_DSV_ARR+=(
        "${URL_SIG_EBATS_COREI7} ${DSV_SIG_EBATS_COREI7} ${WEB_NAME_EBATS_COREI7} dilithium2aes"
        "${URL_SIG_EBATS_COREI7} ${DSV_SIG_EBATS_COREI7} ${WEB_NAME_EBATS_COREI7} dilithium3aes"
        "${URL_SIG_EBATS_COREI7} ${DSV_SIG_EBATS_COREI7} ${WEB_NAME_EBATS_COREI7} dilithium5aes"
    )
# COMMENT_EOF
    candlesticks_from_web
}


##
# @brief        Setting for SLH-DSA cycle data.
# @param[in]    ${OQS_SIG_SEL_DAT}
#               ${URL_SIG_PQS} ${DSV_SIG_PQS} ${WEB_NAME_PQS}
#               ${URL_SIG_EBATS_RYZEN7} ${DSV_SIG_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7}
# @param[out]   ${URL_DSV_ARR} ${COMP_DAT}
slhdsa() {
    COMP_DAT=slhdsa_cycles.dat
    rm -f "${COMP_DAT}"

    ### for liboqs ###
    # asymmetric_algorithm        sign/s   verify/s   keygen/s
    # sphincssha2128fsimple          142.0     1515.0     3183.0
    # sphincssha2128ssimple            6.7     3903.0       46.5
    # sphincssha2192fsimple           78.2     1048.0     2066.0
    # sphincsshake128fsimple          71.3      984.0     1589.0
    # dummy ${OQS_SIG_SEL_DAT} dummy algorithm_name_to_find
    URL_DSV_ARR=(
        "- ${OQS_SIG_SEL_DAT} - sphincssha2[0-9]+"
    )

    ### for pqs ###
    # SLH-DSA (SPHINCS+)      SHAKE-128s      1       4,682,570,992   4,764,084
    local algo_to_find_pqs algo_to_prepend_to_params_pqs
    algo_to_find_pqs="SLH-DSA.*[0-9]+f"
    algo_to_prepend_to_params_pqs="SLH-DSA-"
    # "${URL_SIG_PQS} ${DSV_SIG_PQS} ${WEB_NAME_PQS} ${algo_to_find_pqs} ${algo_to_prepend_to_params_pqs}"\
    URL_DSV_ARR+=(
        "${URL_SIG_PQS} ${DSV_SIG_PQS} ${WEB_NAME_PQS} ${algo_to_find_pqs} ${algo_to_prepend_to_params_pqs}"
    )

    ### for ebats ###
    # RYZEN7
    URL_DSV_ARR+=(
        "${URL_SIG_EBATS_RYZEN7} ${DSV_SIG_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7} sphincsf128harakasimple"
        "${URL_SIG_EBATS_RYZEN7} ${DSV_SIG_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7} sphincsf192harakasimple"
        "${URL_SIG_EBATS_RYZEN7} ${DSV_SIG_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7} sphincsf256harakasimple"
    )
:<<'# COMMENT_EOF'
    # NOTE: do not remove 
    # COREI7
    # "${URL_SIG_EBATS_COREI7} ${DSV_SIG_EBATS_COREI7} ${WEB_NAME_EBATS_COREI7} ${ALGO_TO_FIND}"
    URL_DSV_ARR+=(
        "${URL_SIG_EBATS_COREI7} ${DSV_SIG_EBATS_COREI7} ${WEB_NAME_EBATS_COREI7} sphincsf128harakasimple"
        "${URL_SIG_EBATS_COREI7} ${DSV_SIG_EBATS_COREI7} ${WEB_NAME_EBATS_COREI7} sphincsf192harakasimple"
        "${URL_SIG_EBATS_COREI7} ${DSV_SIG_EBATS_COREI7} ${WEB_NAME_EBATS_COREI7} sphincsf256harakasimple"
    )
# COMMENT_EOF
    candlesticks_from_web
}


##
# @brief        Setting for Falcon cycle data.
# @param[in]    $1 : parameter (512|1025)
#               ${OQS_SIG_SEL_DAT}
#               ${URL_SIG_PQS} ${DSV_SIG_PQS} ${WEB_NAME_PQS}
#               ${URL_SIG_EBATS_RYZEN7} ${DSV_SIG_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7}
# @param[out]   ${URL_DSV_ARR} ${COMP_DAT}
falcon () {
    COMP_DAT=falcon"$1"_cycles.dat
    rm -f "${COMP_DAT}"

    ### for liboqs ###
    # dummy ${OQS_SIG_SEL_DAT} dummy algorithm_name_to_find
    URL_DSV_ARR=(
        "- ${OQS_SIG_SEL_DAT} - falcon.*$1"
    )

    ### for pqs ###
    local algo_to_find_pqs algo_to_prepend_to_params_pqs
    algo_to_find_pqs="Falcon$1"
    algo_to_prepend_to_params_pqs="Falcon"  # param includes algo name for ML-DSA
    # url dsv web_name algo1 [algo2 ...]
    URL_DSV_ARR+=(
        "${URL_SIG_PQS} ${DSV_SIG_PQS} ${WEB_NAME_PQS} ${algo_to_find_pqs} ${algo_to_prepend_to_params_pqs}"
    )

    ### for ebats ###
    if [ "$1" == "512" ] || [ -z "$1" ]; then
        # RYZEN7 falcon512
        URL_DSV_ARR+=(
            "${URL_SIG_EBATS_RYZEN7} ${DSV_SIG_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7} falcon512tree"
            "${URL_SIG_EBATS_RYZEN7} ${DSV_SIG_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7} falcon512dyn"
        )
    fi
    if [ "$1" == "1024" ] || [ -z "$1" ]; then
        # RYZEN7 falcon1024
        URL_DSV_ARR+=(
            "${URL_SIG_EBATS_RYZEN7} ${DSV_SIG_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7} falcon1024tree"
            "${URL_SIG_EBATS_RYZEN7} ${DSV_SIG_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7} falcon1024dyn"
        )
    fi
:<<'# COMMENT_EOF'
    # NOTE: do not remove 
    # COREI7 falcon512
    if [ "$1" == "512" ] || [ -n "$1" ]; then
        URL_DSV_ARR+=(
            "${URL_SIG_EBATS_COREI7} ${DSV_SIG_EBATS_COREI7} ${WEB_NAME_EBATS_COREI7} falcon512tree"
            "${URL_SIG_EBATS_COREI7} ${DSV_SIG_EBATS_COREI7} ${WEB_NAME_EBATS_COREI7} falcon512dyn"
        )
    fi
    # COREI7 falcon1024
    if [ "$1" == "1024" ] || [ -n "$1" ]; then
        URL_DSV_ARR+=(
            "${URL_SIG_EBATS_COREI7} ${DSV_SIG_EBATS_COREI7} ${WEB_NAME_EBATS_COREI7} falcon1024tree"
            "${URL_SIG_EBATS_COREI7} ${DSV_SIG_EBATS_COREI7} ${WEB_NAME_EBATS_COREI7} falcon1024dyn"
        )
    fi
# COMMENT_EOF
    candlesticks_from_web
}


##
# @brief        Setting for ML-KEM cycle data.
# @param[in]    ${OQS_KEM_SEL_DAT}
#               ${URL_KEM_PQS} ${DSV_KEM_PQS} ${WEB_NAME_PQS}
#               ${URL_KEM_EBATS_RYZEN7} ${DSV_KEM_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7}
# @param[out]   ${URL_DSV_ARR} ${COMP_DAT}
mlkem () {
    COMP_DAT=mlkem_cycles.dat
    rm -f "${COMP_DAT}"

    ### for liboqs ###
    # dummy ${OQS_KEM_SEL_DAT} dummy algorithm_name_to_find
    URL_DSV_ARR=(
        "- ${OQS_KEM_SEL_DAT} - mlkem"
    )

    ### for ebats ###
    # RYZEN7
    # url dsv web_name algo1 [algo2 ...]
    URL_DSV_ARR+=(
        "${URL_KEM_EBATS_RYZEN7} ${DSV_KEM_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7} kyber90s512"
        "${URL_KEM_EBATS_RYZEN7} ${DSV_KEM_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7} kyber512"
        "${URL_KEM_EBATS_RYZEN7} ${DSV_KEM_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7} kyber90s768"
        "${URL_KEM_EBATS_RYZEN7} ${DSV_KEM_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7} kyber768"
        "${URL_KEM_EBATS_RYZEN7} ${DSV_KEM_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7} kyber90s1024"
        "${URL_KEM_EBATS_RYZEN7} ${DSV_KEM_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7} kyber1024"
    )
:<<'# COMMENT_EOF'
    # COREI7
    URL_DSV_ARR+=(
        "${URL_KEM_EBATS_COREI7} ${DSV_KEM_EBATS_COREI7} ${WEB_NAME_EBATS_COREI7} kyber90s512"
        "${URL_KEM_EBATS_COREI7} ${DSV_KEM_EBATS_COREI7} ${WEB_NAME_EBATS_COREI7} kyber512"
        "${URL_KEM_EBATS_COREI7} ${DSV_KEM_EBATS_COREI7} ${WEB_NAME_EBATS_COREI7} kyber90s768"
        "${URL_KEM_EBATS_COREI7} ${DSV_KEM_EBATS_COREI7} ${WEB_NAME_EBATS_COREI7} kyber768"
        "${URL_KEM_EBATS_COREI7} ${DSV_KEM_EBATS_COREI7} ${WEB_NAME_EBATS_COREI7} kyber90s1024"
        "${URL_KEM_EBATS_COREI7} ${DSV_KEM_EBATS_COREI7} ${WEB_NAME_EBATS_COREI7} kyber1024"
    )
# COMMENT_EOF
    candlesticks_from_web
}


##
# @brief        Setting for KEM selections cycle data.
# @param[in]    ${OQS_KEM_SEL_DAT}
#               ${URL_KEM_PQS} ${DSV_KEM_PQS} ${WEB_NAME_PQS}
#               ${URL_KEM_EBATS_RYZEN7} ${DSV_KEM_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7}
# @param[out]   ${URL_DSV_ARR} ${COMP_DAT}
kem_sel_128bs () {
    COMP_DAT=kem_sel_128bs_cycles.dat
    rm -f "${COMP_DAT}"

    ### for liboqs ###
    # dummy ${OQS_KEM_SEL_DAT} dummy algorithm_name_to_find
    URL_DSV_ARR=(
        "- ${OQS_KEM_SEL_DAT} - mlkem512"
        "- ${OQS_KEM_SEL_DAT} - bikel1"
        "- ${OQS_KEM_SEL_DAT} - hqc128"
    )

    ### for ebats ###
    # RYZEN7
    # url dsv web_name algo1 [algo2 ...]
    URL_DSV_ARR+=(
        "${URL_KEM_EBATS_RYZEN7} ${DSV_KEM_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7} kyber90s512"
        "${URL_KEM_EBATS_RYZEN7} ${DSV_KEM_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7} kyber512"
    )
    URL_DSV_ARR+=(
        "${URL_KEM_EBATS_RYZEN7} ${DSV_KEM_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7} mceliece348864f"
        "${URL_KEM_EBATS_RYZEN7} ${DSV_KEM_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7} bikel1"
        "${URL_KEM_EBATS_RYZEN7} ${DSV_KEM_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7} hqc128round4"
    )
    URL_DSV_ARR+=(
        "${URL_KEM_EBATS_RYZEN7} ${DSV_KEM_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7} ntruhps2048509"
        "${URL_KEM_EBATS_RYZEN7} ${DSV_KEM_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7} ntruhrss701"
    )
    candlesticks_from_web
}


kem_sel () {
    COMP_DAT=kem_sel_128bs_cycles.dat
    rm -f "${COMP_DAT}"

    ### for liboqs ###
    # dummy ${OQS_KEM_SEL_DAT} dummy algorithm_name_to_find
    URL_DSV_ARR=(
        "- ${OQS_KEM_SEL_DAT} - mlkem512"
        "- ${OQS_KEM_SEL_DAT} - bikel1"
        "- ${OQS_KEM_SEL_DAT} - hqc128"
    )

    ### for ebats ###
    # RYZEN7
    # url dsv web_name algo1 [algo2 ...]
    URL_DSV_ARR+=(
        "${URL_KEM_EBATS_RYZEN7} ${DSV_KEM_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7} kyber90s512"
        "${URL_KEM_EBATS_RYZEN7} ${DSV_KEM_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7} kyber90s768"
        "${URL_KEM_EBATS_RYZEN7} ${DSV_KEM_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7} kyber90s1024"
    )
    URL_DSV_ARR+=(
        "${URL_KEM_EBATS_RYZEN7} ${DSV_KEM_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7} mceliece348864f"
        "${URL_KEM_EBATS_RYZEN7} ${DSV_KEM_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7} mceliece460896f"
    )
    URL_DSV_ARR+=(
        "${URL_KEM_EBATS_RYZEN7} ${DSV_KEM_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7} bikel1"
        "${URL_KEM_EBATS_RYZEN7} ${DSV_KEM_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7} bikel3"
        "${URL_KEM_EBATS_RYZEN7} ${DSV_KEM_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7} hqc128round4"
        "${URL_KEM_EBATS_RYZEN7} ${DSV_KEM_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7} hqc192round4"
        "${URL_KEM_EBATS_RYZEN7} ${DSV_KEM_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7} hqc256round4"
    )
    URL_DSV_ARR+=(
        "${URL_KEM_EBATS_RYZEN7} ${DSV_KEM_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7} ntruhps4096821"
    )

:<<'# COMMENT_EOF'
        "${URL_KEM_EBATS_RYZEN7} ${DSV_KEM_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7} kyber512"
        "${URL_KEM_EBATS_RYZEN7} ${DSV_KEM_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7} kyber768"
        "${URL_KEM_EBATS_RYZEN7} ${DSV_KEM_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7} kyber1024"

        "${URL_KEM_EBATS_RYZEN7} ${DSV_KEM_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7} mceliece6688128f"
        "${URL_KEM_EBATS_RYZEN7} ${DSV_KEM_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7} mceliece8192128f"
    )
# COMMENT_EOF
    candlesticks_from_web
}


##
# @brief        Setting for McEliece cycle data.
# @param[in]    ${OQS_KEM_SEL_DAT}
#               ${URL_KEM_PQS} ${DSV_KEM_PQS} ${WEB_NAME_PQS}
#               ${URL_KEM_EBATS_RYZEN7} ${DSV_KEM_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7}
# @param[out]   ${URL_DSV_ARR} ${COMP_DAT}
mceliece () {
    COMP_DAT=mceliece_cycles.dat
    rm -f "${COMP_DAT}"
    URL_DSV_ARR=()

    ### for ebats ###
    # RYZEN7
    # url dsv web_name algo1 [algo2 ...]
    URL_DSV_ARR+=(
        "${URL_KEM_EBATS_RYZEN7} ${DSV_KEM_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7} mceliece348864f"
        "${URL_KEM_EBATS_RYZEN7} ${DSV_KEM_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7} mceliece460896f"
        "${URL_KEM_EBATS_RYZEN7} ${DSV_KEM_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7} mceliece6688128f"
        "${URL_KEM_EBATS_RYZEN7} ${DSV_KEM_EBATS_RYZEN7} ${WEB_NAME_EBATS_RYZEN7} mceliece8192128f"
    )
# COMMENT_EOF
    candlesticks_from_web
}


##
# @brief        Depict comparison graphs including cycle data from web.
# @details      Run this in ${GRA_DIR} or from plot_openssl_speed_all.sh.
# @param[in]    ${NODE} ${HTML_TABLE2DSV}
#               Data in the following files:
#               ${OQS_SIG_SEL_DAT} ${OQS_KEM_SEL_DAT}
# @param[out]   Data in the following files:
#               ${DSV_*}                  : delimiter separated value
#               ${COMP_DAT}=*"cycles.dat" : data to plot
#               ${GRA_FILE}               : graph 
get_webdata_plot_cycles () {
    # NOTE: "_x" is subscript in gnuplot. 
    WEB_NAME_PQS="pq-sig-zoo"
    WEB_NAME_EBATS_RYZEN7="ebats-ryzen7"
    WEB_NAME_EBATS_COREI7="ebats-corei7"

    get_cpu_mhz
    LIBOQS_VER_LOG=liboqs_ver.log
    [ -z "${LIBOQS_VER}" ] && [ -s "${LIBOQS_VER_LOG}" ] && LIBOQS_VER=$(cat "${LIBOQS_VER_LOG}")  # or blank
    # LIBOQS_VER=0.10.1

    ############### sig ###############
    TAG_KEYGEN="k:"
    TAG_SIG_DEC="s:"
    TAG_VER_ENC="v:"

    [ -z "${OQS_SIG_SEL_DAT}" ] && OQS_SIG_SEL_DAT="./oqs_sig_sel.dat"

    # URL_SIG_PQS="https://pqshield.github.io/nist-sigs-zoo/#performance"
    URL_SIG_PQS="https://pqshield.github.io/nist-sigs-zoo/"
    DSV_SIG_PQS="./${WEB_NAME_PQS}.dsv"

    # shellcheck disable=SC2034  # may be unused depending on the selection
    URL_SIG_EBATS_RYZEN7="https://bench.cr.yp.to/results-sign/amd64-hertz.html"
    # shellcheck disable=SC2034  # may be unused depending on the selection
    DSV_SIG_EBATS_RYZEN7="./sig_${WEB_NAME_EBATS_RYZEN7}_hertz.dsv"

    # shellcheck disable=SC2034  # may be unused depending on the selection
    URL_SIG_EBATS_COREI7="https://bench.cr.yp.to/results-sign/amd64-raptor.html"
    # shellcheck disable=SC2034  # may be unused depending on the selection
    DSV_SIG_EBATS_COREI7="./sig_${WEB_NAME_EBATS_COREI7}_raptor.dsv"

    # algorithms to plot with web data
    mldsa   # ML-DSA
    # falcon  # Falcon 512 and 1024
    falcon 512  # Falcon 512
    falcon 1024  # Falcon 1024

    # NOTE: reduce the number of comparison algorithms to use
    #   UNI_OR_DIV="unified_only" or "both" (default)
    UNI_OR_DIV="divided_only" 
    slhdsa  # SLH-DSA
    unset UNI_OR_DIV  # to default ("both")

    ############### kem ###############
    [ -z "${OQS_KEM_SEL_DAT}" ] && OQS_KEM_SEL_DAT="./oqs_kem_sel.dat"

    TAG_KEYGEN="k:"
    TAG_SIG_DEC="d:"
    TAG_VER_ENC="e:"

    # shellcheck disable=SC2034  # may be unused depending on the selection
    URL_KEM_EBATS_RYZEN7="https://bench.cr.yp.to/results-kem/amd64-hertz.html"
    # shellcheck disable=SC2034  # may be unused depending on the selection
    DSV_KEM_EBATS_RYZEN7="./kem_${WEB_NAME_EBATS_RYZEN7}_hertz.dsv"

    # shellcheck disable=SC2034  # may be unused depending on the selection
    URL_KEM_EBATS_COREI7="https://bench.cr.yp.to/results-kem/amd64-raptor.html"
    # shellcheck disable=SC2034  # may be unused depending on the selection
    DSV_KEM_EBATS_COREI7="./kem_${WEB_NAME_EBATS_COREI7}_raptor.dsv"

    # algorithms to plot with web data
    mlkem
    kem_sel_128bs
    mceliece

    # show Notice messages
    if [ -s "${COMMAND_TMP}" ]; then
        echo
        # NOTE: sort -u with -n removes the same length but nonidentical lines
        awk '{ print length, $0 }' "${COMMAND_TMP}" |  sort -n | uniq | awk '{sub("^" $1 FS, ""); print}'
        # awk '{ print length, $0 }' "${COMMAND_TMP}" |  sort -n | uniq | awk 'BEGIN {OFS=" "} {$1=""; print}'
        echo
        # rm -f "${COMMAND_TMP}"
    fi
}


### for size only

##
# @brief        Append scatter-data to ${COMP_DAT}
# @param[in]    ${SIG_ARR_EBATS_SIZE} ${SIG_ARR_PQS_SIZE}
#               ${URL_DSV_ARR} ${NODE} ${HTML_TABLE2DSV}
#               ${TAG_KEYGEN} ${TAG_SIG_DEC} ${TAG_VER_ENC}
# @param[out]   ${COMP_DAT}
append_sig_dsv2scatter () {
    echo "# sk pk s0 s23 s_many \"EBATS\"" >> "${COMP_DAT}"
    # echo "# pk s0 \"EBATS\"" >> "${COMP_DAT}"
    # NOTE:
    #   some sizes in EBATS, such as sig size of Falcon's, is in the form of
    #   "659..659..660" and this picks the middle value. 
    dsv="./sig_ebats_size.dsv"
    for algo in "${SIG_ARR_EBATS_SIZE[@]}"; do
        # sk pk s0 s23 s_many label
:<<'# COMMENT_EOF'
        awk -v algo="${algo}" 'BEGIN {cou = 0}; {
            if ( $2 == algo ) {cou++; {if (cou==1) {sk=$1; algo=$2} else if (cou==2){pk=$1} else if (cou==3){s0=$1} else if (cou==4){s23=$1} else if (cou==5){s_many=$1}}}};
            END {
                print sk,pk,s0,s23,s_many,algo};
        ' "${dsv}" >> "${COMP_DAT}"
                sub(/.*\.\./,_,s0);sub(/\.\..*/,_,s0);
                sub(/.*\.\./,_,s23);sub(/\.\..*/,_,s23);
                sub(/.*\.\./,_,s_many);sub(/\.\..*/,_,s_many);
# COMMENT_EOF
        # pk s0 label
        awk -v algo="${algo}" 'BEGIN {cou = 0}; {
            if ( $2 == algo ) {cou++; {if (cou==2){pk=$1;algo=$2} else if (cou==3){s0=$1}}}};
            END {sub(/.*\.\./,_,s0);sub(/\.\..*/,_,s0); print pk,s0,algo}
        ' "${dsv}" >> "${COMP_DAT}"
    done

    # pqs
    # already get in get_webdata_plot_cycles ()
    dsv="./pq-sig-zoo.dsv"
    if [ ! -s "${dsv}" ]; then
        url="https://pqshield.github.io/nist-sigs-zoo/"
        ${NODE} "${HTML_TABLE2DSV}" "${url}" > "${dsv}"
    else
        echo "Notice: '${dsv}' was used. To update, move/remove it!" >> "${COMMAND_TMP}"
    fi

    {   echo; echo;  # double blank lines to terminate the previous block
        # echo "# Scheme Parameterset NISTlevel Pk Sig pk+sig \"PQS\"" >> "${COMP_DAT}"
        echo "# Pk Sig \"pq-sig-zoo\""
    } >> "${COMP_DAT}"
    dsv="./pq-sig-zoo.dsv"
    for i in "${SIG_ARR_PQS_SIZE[@]}"; do
        IFS=" " read -r -a d <<< "${i}"
        awk -F'\t' -v algo="${algo}" -v ALGO_REGEX="${d[0]}" \
            -v ALGO_TO_PREPEND_TO_PARAMS_PQS="${d[1]}" \
            -v TAG_K="${TAG_KEYGEN}" -v TAG_S="${TAG_SIG_DEC}" -v TAG_V="${TAG_VER_ENC}" \
            '$1$2$3 ~ ALGO_REGEX {if (NF==6) {
            gsub(" ","",$2);
            gsub(",","",$4);gsub(",","",$5);
            print $4,$5,ALGO_TO_PREPEND_TO_PARAMS_PQS $2
            }
        }' "${dsv}" >> "${COMP_DAT}"
    done

    GRA_FILE="${COMP_DAT%.dat}.png"
    plot_as_scatter "sig"
}


##
# @brief        Append scatter-data to ${COMP_DAT}
# @param[in]    ${KEM_ARR_EBATS_SIZE}
#               ${URL_DSV_ARR} ${NODE} ${HTML_TABLE2DSV}
#               ${TAG_KEYGEN} ${TAG_SIG_DEC} ${TAG_VER_ENC}
# @param[out]   ${COMP_DAT}
append_kem_dsv2scatter () {
    echo "# pk cipher \"EBATS\"" >> "${COMP_DAT}"
    # echo "# pk s0 \"EBATS\"" >> "${COMP_DAT}"
    # NOTE:
    #   some sizes in EBATS, such as sig size of Falcon's, is in the form of
    #   "659..659..660" and this picks the middle value. 
    dsv="./kem_ebats_size.dsv"
    for algo in "${KEM_ARR_EBATS_SIZE[@]}"; do
        # sk pk cipher sk_size -> pk s0 label
        awk -v algo="${algo}" 'BEGIN {cou = 0}; 
            { if ($2 ~ algo) {cou++; {if (cou==2){pk=$1;algo=$2} else if (cou==3){s0=$1}}}};
            END {sub(/.*\.\./,_,s0);sub(/\.\..*/,_,s0); print pk,s0,algo};
        ' "${dsv}" >> "${COMP_DAT}"
    done

    GRA_FILE="${COMP_DAT%.dat}.png"
    plot_as_scatter "kem"
}


##
# @brief        Depict comparison graphs of sizes using data from web.
# @details      Run this in ${GRA_DIR} or from plot_openssl_speed_all.sh.
# @param[in]    ${NODE} ${HTML_TABLE2DSV}
#               Data in the following files:
#               ${DSV_*}
# @param[out]   Data in the following files:
#               ${DSV_*}                : delimiter separated value
#               ${COMP_DAT}=*"size.dat" : data to plot
#               ${GRA_FILE}             : graph 
get_webdata_plot_size () {
    local sig_or_kem dsv url
    for sig_or_kem in sig kem ; do
        # ebats
        dsv="${sig_or_kem}_ebats_size.dsv"
        if [ ! -s "${dsv}" ]; then
            if [ "${sig_or_kem}" == "sig" ]; then
                # sig -> sign
                url="https://bench.cr.yp.to/results-${sig_or_kem}n.html"
            else
                url="https://bench.cr.yp.to/results-${sig_or_kem}.html"
            fi
            ${NODE} "${HTML_TABLE2DSV}" "${url}" > "${dsv}"
        else
            echo "Notice: '${dsv}' was used. To update, move/remove it!" >> "${COMMAND_TMP}"
        fi
        if [ "${sig_or_kem}" == "sig" ]; then
            ##### 128bs #####
            COMP_DAT=./sig_128bs_size.dat
            rm -f "${COMP_DAT}"
            # classic
            {   echo "# pk sig \"Classical\"";
                echo "33 65 ECDSA256";
                echo "384 384 RSA3072";
                echo "512 512 RSA4096";
                echo; echo;  # double blank lines to terminate this block
            } >> "${COMP_DAT}"
            SIG_ARR_EBATS_SIZE=("${SIG_ARR_128BS_EBATS_SIZE[@]}")
            SIG_ARR_PQS_SIZE=("${SIG_ARR_128BS_PQS_SIZE[@]}")
            append_sig_dsv2scatter

            ##### 192bs #####
            COMP_DAT=./sig_192bs_size.dat
            rm -f "${COMP_DAT}"
            # classic
            {   echo "# pk sig \"Classical\"";
                echo "49 97 ECDSA384";  # ((bits - 1)//8 + 1) + 1, 2*((bits - 1)//8 + 1) + 1
                echo "960 960 RSA7680";  # (bits - 1)//8 + 1
                echo; echo;  # double blank lines to terminate this block
            } >> "${COMP_DAT}"
            SIG_ARR_EBATS_SIZE=("${SIG_ARR_192BS_EBATS_SIZE[@]}")
            SIG_ARR_PQS_SIZE=("${SIG_ARR_192BS_PQS_SIZE[@]}")
            append_sig_dsv2scatter
            
            ##### 256bs #####
            COMP_DAT=./sig_256bs_size.dat
            rm -f "${COMP_DAT}"
            # classic
            {   echo "# pk sig \"Classical\"";
                echo "67 133 ECDSA521";  # ((bits - 1)//8 + 1) + 1, 2*((bits - 1)//8 + 1) + 1
                echo "1920 1920 RSA15360";  # (bits - 1)//8 + 1
                echo; echo;  # double blank lines to terminate this block
            } >> "${COMP_DAT}"
            SIG_ARR_EBATS_SIZE=("${SIG_ARR_256BS_EBATS_SIZE[@]}")
            SIG_ARR_PQS_SIZE=("${SIG_ARR_256BS_PQS_SIZE[@]}")
            append_sig_dsv2scatter
        fi
        if [ "${sig_or_kem}" == "kem" ]; then
            ##### 128bs KEM #####
            COMP_DAT=./${sig_or_kem}_128bs_size.dat
            rm -f "${COMP_DAT}"
            # classical
            {   echo "# pk cipher \"Classic\"";
                echo "33 65 ECIES-KEM256";
                echo "384 384 RSA3072";
                echo "512 512 RSA4096";
                echo; echo;
            } >> "${COMP_DAT}"
            KEM_ARR_EBATS_SIZE=("${KEM_ARR_128BS_EBATS_SIZE[@]}")
            append_kem_dsv2scatter

            ##### 192bs KEM #####
            COMP_DAT=./${sig_or_kem}_192bs_size.dat
            rm -f "${COMP_DAT}"
            # classical
            {   echo "# pk cipher \"Classic\"";
                echo "50 98 ECIES-KEM384";  # ((bits - 1)//8 + 1) + 1, 2*((bits - 1)//8 + 1) + 1
                echo "960 960 RSA7680";  # (bits - 1)//8 + 1
                echo; echo;
            } >> "${COMP_DAT}"
            KEM_ARR_EBATS_SIZE=("${KEM_ARR_192BS_EBATS_SIZE[@]}")
            append_kem_dsv2scatter

            ##### 256bs KEM #####
            COMP_DAT=./${sig_or_kem}_256bs_size.dat
            rm -f "${COMP_DAT}"
            # classical
            {   echo "# pk cipher \"Classic\"";
                echo "67 133 ECIES-KEM521";  # ((bits - 1)//8 + 1) + 1, 2*((bits - 1)//8 + 1) + 1
                echo "1920 1920 RSA15360";  # (bits - 1)//8 + 1
                echo; echo;
            } >> "${COMP_DAT}"
            KEM_ARR_EBATS_SIZE=("${KEM_ARR_256BS_EBATS_SIZE[@]}")
            append_kem_dsv2scatter
        fi
    done
}


##
# @brief        Plot as scatter.
# @param[in]    $1 : ${sig_or_kem}
#               Data in the following files:
#               ${COMP_DAT}
#               ${sig_or_kem}
# @param[out]   Data in the following files:
#               ${GRA_FILE}
plot_as_scatter () {
    local tmp xy_min_max_arr sig_or_kem="$1"
    # find xy_min_max_arr, min and max of x and y coordinates
    tmp="$(awk '
            BEGIN {cou=0};
            $1 ~ /[0-9]+/ {
                if (cou==0)
                    {cou++;x_min=$1;x_max=$1;y_min=$2;y_max=$2;}
                else {
                    x_min=($1<x_min)?$1:x_min;
                    x_max=(x_max<$1)?$1:x_max;
                    y_min=($2<y_min)?$2:y_min;
                    y_max=(y_max<$2)?$2:y_max;
                }
            };
            END {print x_min*3/4,x_max*16,y_min*3/4,y_max*2}
        ' "${COMP_DAT}")"
    IFS=" " read -r -a xy_min_max_arr <<< "$tmp"

    # legend_y=0.92  # for gnuplot window
    legend_y=0.9  # for png
    # sig or kem
    if [ "${sig_or_kem}" == "sig" ]; then
            y_label="Signature"
            points_and_labels="
            '${COMP_DAT}' i 1 with labels tc ls 2 left offset char 1,0.4 notitle,
            '${COMP_DAT}' i 1 with points    ls 2 title 'PQC(from eBATS)' at screen 0.6,${legend_y},
            '${COMP_DAT}' i 2 with labels tc ls 3 left offset char 1,-0.4 notitle,
            '${COMP_DAT}' i 2 with points pt 4 lc rgb 'dark-green' title 'PQC(from pq-sig-zoo)' at screen 0.93,${legend_y}
            "
    elif [ "${sig_or_kem}" == "kem" ]; then
            y_label="Ciphertext"
            points_and_labels="
            '${COMP_DAT}' i 1 with labels tc ls 2 left offset char 1,0 notitle,
            '${COMP_DAT}' i 1 with points    ls 2 title 'PQC(from eBATS)' at screen 0.6,${legend_y}
            "
    else
        echo "Error: sig_or_kem:'${sig_or_kem}' is either 'sig' or 'kem'!"
        exit 2
    fi

    gnuplot -p -e "
        set style line 1 lc rgb 'red';
        set style line 2 lc rgb 'blue';
        set style line 3 lc rgb 'dark-green';
        set terminal png; set output '${GRA_FILE}';
        set logscale x 10;
        set logscale y 10;
        set xlabel 'Public key size [octets]';
        set ylabel '${y_label} size [octets]';
        set title 'Depicted by ${COMMAND} of plot-openssl-speed v${VER}' noenhanced;
        set border 3; set grid;
        plot [${xy_min_max_arr[0]}:${xy_min_max_arr[1]}] [${xy_min_max_arr[2]}:${xy_min_max_arr[3]}]
            '${COMP_DAT}' i 0 with labels tc ls 1 left offset char 1,0 notitle,
            '${COMP_DAT}' i 0 with points    ls 1 title 'Classic' at screen 0.25,${legend_y},
            ${points_and_labels};
    " 
:<<'# COMMENT_EOF'
# other options
            '${COMP_DAT}' i 0 title 'Classical' at graph 0.8,0.9,
            '${COMP_DAT}' i 0 title 'Classical' at screen 0.5,0.97,
    set border 3; 
        set terminal png; set output '${GRA_FILE}';
        set xrange [ 100 : * ];
        set yrange [ 100 : * ];
            using 2:3
# COMMENT_EOF
}


##
# @brief        Set algorithms to plot.
# @param[out]   algorithm arrays
set_algo () {
    ##### sig #####
    # sig 128bs
    SIG_ARR_128BS_EBATS_SIZE=(
        "dilithium2aes"
        "falcon512tree"
        "sphincss128sha256simple"
        "sphincsf128sha256simple"
    )
    # algo_fo_find(regexp) algo_to_prepend_to_params_pqs
    SIG_ARR_128BS_PQS_SIZE=(
        "Falcon512 Falcon"
        "MAYOone MAYO"
        "MAYOtwo MAYO"
        "ML-DSA-44"
        "SHAKE-128f SLH-DSA-"
        "SHAKE-128s SLH-DSA-"
    )

    # sig 192bs
    SIG_ARR_192BS_EBATS_SIZE=(
        "dilithium3aes"
        "sphincss192sha256simple"
        "sphincsf192sha256simple"
    )
    # algo_fo_find(regexp) algo_to_prepend_to_params_pqs
    SIG_ARR_192BS_PQS_SIZE=(
        "MAYOthree MAYO"
        "ML-DSA-65"
        "SHAKE-192f SLH-DSA-"
        "SHAKE-192s SLH-DSA-"
    )

    # sig 192bs
    SIG_ARR_256BS_EBATS_SIZE=(
        "dilithium5aes"
        "falcon1024tree"
        "sphincss256sha256simple"
        "sphincsf256sha256simple"
    )
    # algo_fo_find(with regexp) algo_to_prepend_to_params_pqs
    SIG_ARR_256BS_PQS_SIZE=(
        "Falcon1024 Falcon"
        "MAYOfive MAYO"
        "ML-DSA-87"
        "SHAKE-256f SLH-DSA-"
        "SHAKE-256s SLH-DSA-"
    )

    ##### kem #####
    # kem 128bs
    KEM_ARR_128BS_EBATS_SIZE=(
        "kyber512"
        "bikel1"
        "hqc128round4"
        "frodokem640aes"
        "mceliece348864f"
    )
    #   "ntruhps2048509"
    #   "ntruhrss701"

    # kem 192bs
    KEM_ARR_192BS_EBATS_SIZE=(
        "kyber768"
        "bikel3"
        "hqc192round4"
        "frodokem976aes"
        "mceliece460896f"
    )
    #   "ntruhps4096821"

    # kem 256bs
    KEM_ARR_256BS_EBATS_SIZE=(
        "kyber1024"
        "hqc256round4"
        "frodokem1344aes"
    )
    #    "mceliece6688128f"  # 256bs?
    #    "mceliece8192128f"  # 256bs?
    #    "bikel5"            # not available yet
}


##### main #####
if [ $# -eq 0 ]; then
    # GRA_DIR="graphs"
    NODE="node"
    HTML_TABLE2DSV="../../../data_from_web/html_table2dsv.mjs"
    check_necessary_commands
    # NOTE: choose one or both
    get_webdata_plot_cycles
    set_algo && get_webdata_plot_size
else
    # data plot mode
    while getopts 'd:o:h?' OPTION
    do
        case $OPTION in
            d) COMP_DAT="${OPTARG}";;
            o) GRA_FILE="${OPTARG}";;
            h|?|*) usage; exit 2;;
        esac
    done
    # shift $((OPTIND - 1))
    if [ -z "${COMP_DAT}" ] && [ -z "${GRA_FILE}" ]; then
        echo "Error: give either '-d' or '-o' option!"
        usage; exit 2;
    fi

    if [ -n "${COMP_DAT}" ] && [ -z "${GRA_FILE}" ]; then
        GRA_FILE="${COMP_DAT%.dat}.png"
    elif [ -z "${COMP_DAT}" ] && [ -n "${GRA_FILE}" ]; then
        COMP_DAT="${GRA_FILE%.png}.dat"
    fi
    # candlesticks or scatter
    if [ "${COMP_DAT: -10}" == "cycles.dat" ]; then
        plot_as_candlesticks
    elif [ "${COMP_DAT: -8}" == "size.dat" ]; then
        plot_as_scatter
    else
        echo
        echo "Error: '${COMP_DAT}' shall end with '(cycles|size).dat'!"
        echo
        exit 2
    fi
fi
