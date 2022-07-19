#!/usr/bin/env bash
# This file is part of https://github.com/KazKobara/plot_openssl_speed

# Depict fit graphs for "${fit_array[@]}" using the files corresponding to
# IN_FILE="${proc%%_*}.dat".
#
# This script is used in ./plot_openssl_speed_all.sh, or 
# run directly in the directory where "${proc%%_*}.dat" exists
# with 'fit_array' as the arguments.

if [ "$#" == "0" ]; then
    fit_array=(rsa_verify rsa_sign ecdh_b ecdh_brp_r1)
else
    fit_array=("$@")
fi

##
# @brief        Depict fit graphs of "${IN_FILE}".
# @param[in]    fit_array=(rsa_verify rsa_sign ecdh_b ecdh_brp_r1)
# @param[out]   Fit graphs to FIT_FILE="${proc}_fit.dat"
for proc in "${fit_array[@]}"; do
    FIT_FILE="${proc}_fit.dat"
    case "$proc" in
        rsa*)
            # rsa7680
            # rsa15360
            SUBSTR_START=4
            SUBSTR_LEN=""  # to the end
            IN_FILE="${proc%%_*}.dat"
            case "$proc" in
                rsa_sign)   POS=\$4 ; A_INIT=6.0 ;;
                rsa_verify) POS=\$5 ; A_INIT=3.0 ;;
            esac
            # echo "B_INIT: ${B_INIT}"
            ;;
        ecdh*)
            # TODO: Change to extract the size.
            # ecdh(nistb163)
            SUBSTR_LEN=",3"
            case "$proc" in
                # ecdh(nistb163)
                ecdh_b)      SUBSTR_START=11 ;;
                # ecdh(brainpoolP512r1)
                ecdh_brp_r1) SUBSTR_START=16 ;;
            esac
            IN_FILE="${proc}.dat";
            POS=\$3 ; A_INIT=3.0;
            ;;
        *) echo "Error: unknown process!";;
    esac
    echo
    echo "--- ${IN_FILE} ---> ${FIT_FILE} ---"
    if [ ! -e "${IN_FILE}" ]; then
        echo "Warning: no ${IN_FILE}, skipped!"
        continue
    fi
    B_INIT=$(awk "(! /#/) && (NR==1) {print ${POS}}" "${IN_FILE}")
    if [ "${B_INIT}" == "" ]; then
        echo "Warning: ${IN_FILE} does not contain a table, skipped!"
        continue
    fi
    awk "{print substr(\$1,${SUBSTR_START}${SUBSTR_LEN}), ${POS} }" "${IN_FILE}" > "${FIT_FILE}"
    LOGX_OFFSET=$(awk 'NR==1 {print $1}' "${FIT_FILE}")
    #   set grid; \
    gnuplot -p -e "set terminal png; set output \"${proc}_fit.png\"; \
        set ylabel 'Speed [operations/s]'; \
        set xlabel 'Size'; \
        set logscale x 2; \
        f(x)=b*(1/a)**(log(x/${LOGX_OFFSET})/log(2)); a=${A_INIT}; b=${B_INIT}; fit f(x) './${FIT_FILE}' via a,b; \
        plot [] [0:] \
            '${FIT_FILE}' u 1:2:xtic(1) with points pt 2, \
            f(x) title sprintf(\"y=b*(1/a)**log2(x/${LOGX_OFFSET}), a=%.1f; b=%.0f\", a, b)"
done
