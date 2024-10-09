#!/usr/bin/env bash

# This file is part of https://github.com/KazKobara/plot_openssl_speed
# Copyright (C) 2024 National Institute of Advanced Industrial Science and Technology (AIST). All Rights Reserved.

##
# @brief        Depict fit graphs.
# @details      The data is in IN_FILE="${proc%%_*}.dat" where ${proc} is
#               given by ${fit_array}.
#               Run this in ${GRA_DIR} or in ./plot_openssl_speed_all.sh.
# @param[in]    fit_array=(rsa_verify rsa_sign ecdh_b ecdh_brp_r1)
# @param[in]    global GRA_TITLE_APPENDIX LIBOQS_VER
# @param[out]   Fit graphs to FIT_FILE="${proc}_fit.dat"

if [ "$#" == "0" ]; then
    fit_array=(rsa_verify rsa_sign ecdh_b ecdh_brp_r1)
else
    fit_array=("$@")
fi

VER=1.0.0
COMMAND=$(basename "$0")
GRA_TITLE_APPENDIX=""  # TODO: add
GRA_OPT_COMMON=""
GRA_TITLE_ONE_LINE="Depicted by ${COMMAND} of plot-openssl-speed v${VER} ${GRA_TITLE_APPENDIX}"
GRA_TITLE_TWO_LINES="Depicted by ${COMMAND} v${VER} \n${GRA_TITLE_APPENDIX}"
echo "Title length: ${#GRA_TITLE_ONE_LINE}"
# if [ "${#GRA_TITLE_ONE_LINE}" -gt 65 ] && [ "${NUM_OF_RECORDS}" -le 8 ]; then
if [ "${#GRA_TITLE_ONE_LINE}" -gt 70 ]; then
    GRA_OPT_COMMON="${GRA_OPT_COMMON} set title \"${GRA_TITLE_TWO_LINES}\" noenhanced;"
else
    GRA_OPT_COMMON="${GRA_OPT_COMMON} set title \"${GRA_TITLE_ONE_LINE}\" noenhanced;"
fi
GRA_OPT="${GRA_OPT_COMMON};"

for proc in "${fit_array[@]}"; do
    FIT_FILE="${proc}_fit.dat"
    case "${proc}" in
        rsa*)
            # rsa7680
            # rsa15360
            SUBSTR_START=4
            SUBSTR_LEN=""  # to the end
            IN_FILE="${proc%%_*}.dat"
            case "${proc}" in
                # for old TABLE_TYPE
                # rsa_sign)   POS=\$4 ; A_INIT=6.0 ;;
                # rsa_verify) POS=\$5 ; A_INIT=3.0 ;;
                # for TABLE_TYPE=sig_ver_keygen
                rsa_sign)   POS=\$2 ; A_INIT=6.0 ;;
                rsa_verify) POS=\$3 ; A_INIT=3.0 ;;
            esac
            # echo "B_INIT: ${B_INIT}"
            ;;
        ecdh*)
            # TODO: Change to extract the size.
            # ecdh(nistb163)
            SUBSTR_LEN=",3"
            case "${proc}" in
                # ecdh(nistb163)
                ecdh_b)      SUBSTR_START=11 ;;
                # ecdh(brainpoolP512r1)
                ecdh_brp_r1) SUBSTR_START=16 ;;
            esac
            IN_FILE="${proc}.dat";
            # for old TABLE_TYPE
            # POS=\$3 ; A_INIT=3.0;
            # for TABLE_TYPE=dec_enc_keygen_dh
            POS=\$5 ; A_INIT=3.0;
            ;;
        *) echo "Error: unknown process!";;
    esac
    echo
    echo "--- ${IN_FILE} ---> ${FIT_FILE} ---"
    if [ ! -s "${IN_FILE}" ]; then
        echo "Warning: no ${IN_FILE} or it is empty, skipped!"
        continue
    fi
    if [ -z "$(awk '(! /^[ \t]*#/) && (NF > 1) {print NF}' "${IN_FILE}")" ]; then
        echo "Warning: '${IN_FILE}' has no data. Skipped!"
        continue
    fi
    awk "(! /^[ \t]*#/) {print substr(\$1,${SUBSTR_START}${SUBSTR_LEN}), ${POS} }" "${IN_FILE}" > "${FIT_FILE}"
    B_INIT=$(awk 'NR==1 {print $2}' "${FIT_FILE}")
    LOGX_OFFSET=$(awk 'NR==1 {print $1}' "${FIT_FILE}")
    #   set grid; \
    gnuplot -p -e "set terminal png; set output \"${proc}_fit.png\"; \
        set ylabel 'Speed [operations/s]'; \
        set xlabel 'Size'; \
        set logscale x 2; \
        f(x)=b*(1/a)**(log(x/${LOGX_OFFSET})/log(2)); a=${A_INIT}; b=${B_INIT}; \
        fit f(x) './${FIT_FILE}' via a,b; \
        ${GRA_OPT} \
        plot [] [0:] \
            '${FIT_FILE}' u 1:2:xtic(1) with points pt 2, \
            f(x) title sprintf(\"y=b*(1/a)**log2(x/${LOGX_OFFSET}), a=%.1f; b=%.0f\", a, b)"
done
