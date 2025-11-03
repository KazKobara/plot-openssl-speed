#!/usr/bin/env bash
# Wrapper of ${PLOT_SCRIPT}
# This file is part of https://github.com/KazKobara/plot_openssl_speed
# Copyright (C) 2025 National Institute of Advanced Industrial Science and Technology (AIST). All Rights Reserved.
set -e
# set -x

### Patch management ###
# OpenSSL 3.5.0 to at least 3.5.4 cause
# "Error while initializing signing data structs"
# for `openssl speed ML-DSA-{44,65,87} SLH-DSA-SHA{2,KE}-{128,192,256}{s,f}`
# Making the following "True" applies a workaround patch in
# https://github.com/openssl/openssl/issues/27108 to fix this error.
# This error is fixed in OpenSSL 3.6.0.
PATCH_SPEED_PQCSIGS_IN_DEFAULT_PROVIDER="True"  # applied only to OpenSSL 3.5

### Params ###
COMMAND=$(basename "$0")
# GRA_DIR="graphs"
# PLOT_SCRIPT's PATH is from ${TMP_DIR}/${openssl_type}/
PLOT_SCRIPT="../../plot_openssl_speed.sh"
# PLOT_FIT_SCRIPT's PATH is from ${TMP_DIR}/${openssl_type}/${GRA_DIR}/
PLOT_FIT_SCRIPT="../../../utils/plot_fit.sh"
PLOT_WITH_WEB_DATA="../../../data_from_web/with_webdata.sh"

GIT="git"
# GIT="gh repo"
GIT_CLONE="${GIT} clone"
# NOTE:
#   TAG_MINGW and TAG_FIPS can be case-insensitive in bash 4.4.20 and newer
#   by using "${VAR,,}". Search ",,}" in this script and edit there.
TAG_MINGW="-mingw"
TAG_FIPS="fips-"

DEFAULT_RUN_MODE=full

TMP_DIR="./tmp"
mkdir -p "${TMP_DIR}"
ALLOWED_DIR=$(realpath ${TMP_DIR})

### functions ###
# . ./utils/common.sh
COMMON_SCRIPT="$(dirname "$(readlink -f "$0")")"/utils/common.sh
if [ -s "${COMMON_SCRIPT}" ]; then
    # shellcheck source=./utils/common.sh
    . "${COMMON_SCRIPT}"
else
    echo "Error: failed to source ${COMMON_SCRIPT}!"
    exit 3
fi

usage () {
    echo " Wrapper of $(basename "${PLOT_SCRIPT}") v${VER}"
    echo
    echo " Usage:"
    echo "   Edit 'crypt-algorithms' in this script. Then"
    echo
    echo "   \$ ./${COMMAND} [options] [openssl_type] ... [openssl_type]"
    echo
    echo "   where "
    echo "     - 'openssl_type' is a form of"
    echo "       '[${TAG_FIPS}]openssl_tag[(-oqsprovider_type|${TAG_MINGW})]'"
    echo "       such as "
    echo "       'openssl-3.6.0-oqsprovider0.10.0-liboqs0.14.0'"
    echo "       'openssl-3.6.0${TAG_MINGW}'"
    echo "       '${TAG_FIPS}openssl-3.1.2'"
    echo "       'master-oqsprovidermain-liboqsmain' ."
    echo "     - 'openssl_type' is also used as"
    echo "       a folder name to work under the ./tmp folder"
    echo "       except the following case."
    echo "     - If 'openssl_type' is either blank or 'openssl' only,"
    echo "       the openssl command in the PATH is used (default)."
    echo "     - In this case, its folder to work is"
    echo "       'default_<OPENSSL_VER_NOSPACE>' ."
    echo
    echo "     - 'openssl_tag' is a tag or branch name."
    echo "     - For the OpenSSL project, it may be"
    echo "       'openssl-3.6.0', 'master', and so on,"
    echo "        in accordance with https://github.com/openssl/openssl ."
    echo
    echo "     - For forked openssl projects 'openssl_tag' is a form of"
    echo "       '<project_name>-<tag>' such as"
    echo "       'libressl-v4.1.0', 'libressl-master' or 'libressl-OPENBSD_7_4'"
    echo "       for https://github.com/libressl/portable.git"
    echo "       or 'libressl-4.1.0'"
    echo "       for https://ftp.openbsd.org/pub/OpenBSD/LibreSSL/ ."
    echo
    echo "     - append '${TAG_MINGW}' to 'openssl_tag' (except 'openssl')"
    echo "       to cross-compile it for 64bit MinGW with"
    echo "       gcc on Linux (Debian/Ubuntu) and run it on WSL."
    echo
    echo "     - 'oqsprovider_type' is available with openssl 3.2 and newer"
    echo "       with a form of"
    echo "       'oqsprovider<OQSPROVIDER_BRANCH>-<LIBOQS_BRANCH> where "
    echo "       '*_BRANCH' are branch or tag names in "
    echo "       https://github.com/open-quantum-safe/oqs-provider and "
    echo "       https://github.com/open-quantum-safe/liboqs , respectively."
    echo
    echo "   options:"
    echo "     [-s seconds] Seconds [1-99] to measure the speed."
    echo "                  Set '1' to speed up for debug."
    echo "                  LibreSSL at least 2.8.3 does not support this."
    echo "     [-r run_mode] 'run_mode' is one of 'build_only', 'full',"
    echo "                  'skip_symmetric', or 'skip_asymmetric'"
    echo "                  (default: '${DEFAULT_RUN_MODE}')"
    echo "     [-h]         Show this usage"
    echo
}


##
# @brief        Parse given openssl_type.
# @param[in]    openssl_type
# @param[out]   global OPENSSL_INFO OPENSSL_BRANCH LIBOQS_BRANCH OQSPROVIDER_BRANCH
openssl_type_to_oqs_branches () {
    local tmp
    # openssl_type=openssl-3.4.0-alpha1-oqsprovider0.6.1-rc1-liboqs0.10.1-rc1
    OPENSSL_BRANCH=${openssl_type%%-oqsprovider*}
    # OPENSSL_BRANCH=openssl-3.4.0-alpha1
    tmp=${OQSPROVIDER_DIR##*oqsprovider}
    # tmp=0.6.1-rc1-liboqs0.10.1-rc1
    OQSPROVIDER_BRANCH=${tmp%%-liboqs*}
    # OQSPROVIDER_BRANCH=0.6.1-rc1
    LIBOQS_BRANCH=${tmp##*liboqs}
    # LIBOQS_BRANCH=0.10.1-rc1
    # LIBOQS_INFO=liboqs${LIBOQS_BRANCH}
    ## LIBOQS_BRANCH=liboqs0.10.1-rc1
}


##
# @brief        Plot graphs for asymmetric-key algorithms including PQC
# @param[in]    global ARR_PLOT_SCRIPT GRA_DIR OPENSSL_VER_NOSPACE
# @param[out]   *.png files under GRA_DIR
plot_graph_asymmetric () {
    GRA_TITLE_APPENDIX="with ${OPENSSL_VER_NOSPACE}"
    ### Asymmetric-key algorithms:
    ## Post-Quantum (@ default provider)
    if [ -s "./${GRA_DIR}/pqc_kem_def.png" ]; then
        echo
        echo "Notice: './${GRA_DIR}/pqc_kem_def.png' already exists."
        echo "  Move or remove it to renew it."
    else
        # ${PLOT_SCRIPT} -o "./${GRA_DIR}/pqc_kem_def.png" ML-KEM-{512,768,1024}
        "${ARR_PLOT_SCRIPT[@]}" -o "./${GRA_DIR}/pqc_kem_def.png" ML-KEM-{512,768,1024}
    fi
    if [ -s "./${GRA_DIR}/pqc_sig_def.png" ]; then
        echo
        echo "Notice: './${GRA_DIR}/pqc_sig_def.png' already exists."
        echo "  Move or remove it to renew it."
    else
        "${ARR_PLOT_SCRIPT[@]}" -o "./${GRA_DIR}/pqc_sig_def.png" ML-DSA-{44,65,87} SLH-DSA-SHA{2,KE}-{128,192,256}{s,f}
    fi

    ## Post-Quantum (Open Quantum Safe)
    # NOTE: even if [ -n "${LIBOQS_VER}" ] is true,
    #       GRA_TITLE_APPENDIX does not require 'liboqs${LIBOQS_VER}'
    #       unless the graph includes any oqs algorithm.
    get_arr_oqs kem signature
    export ARR_OQS_SIG ARR_OQS_KEM
    # OQS_SIG_SEL_DAT="oqs_sig_sel.dat"
    # OQS_KEM_SEL_DAT="oqs_kem_sel.dat"
    OQS_SIG_SEL_DAT="pqc_sig_sel.dat"
    OQS_KEM_SEL_DAT="pqc_kem_sel.dat"
    if [ -n "${LIBOQS_VER}" ]; then
        ## OQS signatures
        #             keygen sign/s verify/s
        # mldsa44    25758.0 12073.0 32701.0
        #
        # all
        if [ -s "./${GRA_DIR}/oqs_sig_all.png" ]; then
            echo
            echo "Notice: './${GRA_DIR}/oqs_sig_all.png' already exists."
            echo "  Move or remove it to renew it."
        else
            "${ARR_PLOT_SCRIPT[@]}" -o "./${GRA_DIR}/oqs_sig_all.png" "${ARR_OQS_SIG[@]}"
        fi
        ## OQS KEM
        #              keygen encaps/s decaps/s
        # mlkem512    70717.2 108815.3 112732.0
        #
        # all
        if [ -s "./${GRA_DIR}/oqs_kem_all.png" ]; then
            echo
            echo "Notice: './${GRA_DIR}/oqs_kem_all.png' already exists."
            echo "  Move or remove it to renew it."
        else
            "${ARR_PLOT_SCRIPT[@]}" -o "./${GRA_DIR}/oqs_kem_all.png" "${ARR_OQS_KEM[@]}"
        fi
        # plot with web data
        # NOTE:
        #   "TimeoutError: Navigation timeout" happens when some servers
        #   where ./data_from_web/with_webdata.sh retrieves data
        #   do not respond.
        #   Retry the same script after a while
        #   or after commenting out the following line
        #   if the necessity of the data is low:
        (cd "${GRA_DIR}" && { ${PLOT_WITH_WEB_DATA} || true;})  # void exit by set -e
    fi

    # PQC selections
    # PQC SIG
    # rm -rf "./${GRA_DIR}/${OQS_SIG_SEL_DAT}"
    echo "# asymmetric_algorithm        sign/s   verify/s   keygen/s" > "./${GRA_DIR}/${OQS_SIG_SEL_DAT}"
    # from oqs all
    if [ -s "./${GRA_DIR}/oqs_sig_all.dat" ]; then
        awk '$1 ~ /(^[ \t]*#|sphincs|falcon|mldsa|mayo)/ {print}' "./${GRA_DIR}/oqs_sig_all.dat" >> "./${GRA_DIR}/${OQS_SIG_SEL_DAT}"
    fi
    # from sig def
    if [ -s "./${GRA_DIR}/pqc_sig_def.dat" ]; then
        awk '$1 ~ /(^[ \t]*#|ML-DSA|SLH-DSA)/ {print}' "./${GRA_DIR}/pqc_sig_def.dat" >> "./${GRA_DIR}/${OQS_SIG_SEL_DAT}"
    fi
    # plot file
    if [ -s "./${GRA_DIR}/${OQS_SIG_SEL_DAT}" ]; then
        if [ -n "${LIBOQS_VER}" ]; then
            GRA_TITLE_APPENDIX_FINAL="${GRA_TITLE_APPENDIX} liboqs${LIBOQS_VER}"
        else
            GRA_TITLE_APPENDIX_FINAL="${GRA_TITLE_APPENDIX}"
        fi
        ${PLOT_SCRIPT_FOR_FILE} -o "./${GRA_DIR}/pqc_sig_sel.png" -t "${GRA_TITLE_APPENDIX_FINAL}"
    fi
:<<'# COMMENT_EOF'
    # NOTE: Do not remove for debug
    # by measure-plot
    "${ARR_PLOT_SCRIPT[@]}" -o "./${GRA_DIR}/pqc_sig_sel.png" \
        sphincssha{2128fsimple,2128ssimple,2192fsimple,ke128fsimple} \
        falcon{512,padded512,1024,padded1024} \
        mldsa{44,65,87} mayo{1,2,3,5} \
        # TODO:
        #   Uncomment after "Error while initializing signing data structs"
        #   is fixed
        # ML-DSA-{44,65,87} SLH-DSA-SHA{2,KE}-{128,192,256}{s,f} \
# COMMENT_EOF

    # PQC KEM
    # rm -rf "./${GRA_DIR}/${OQS_KEM_SEL_DAT}"
    echo "# asymmetric_algorithm         dec/s      enc/s   keygen/s       dh/s" > "./${GRA_DIR}/${OQS_KEM_SEL_DAT}"
    # from oqs all
    if [ -s "./${GRA_DIR}/oqs_kem_all.dat" ]; then
        # awk '$1 ~ /(^[ \t]*#|mlkem|bike|hqc)/ {print}' "./${GRA_DIR}/oqs_kem_all.dat" >> "./${GRA_DIR}/${OQS_KEM_SEL_DAT}"
        awk '$1 ~ /(mlkem|bike|hqc)/ {print}' "./${GRA_DIR}/oqs_kem_all.dat" >> "./${GRA_DIR}/${OQS_KEM_SEL_DAT}"
    fi
    # from kem def
    if [ -s "./${GRA_DIR}/pqc_kem_def.dat" ]; then
        # awk '$1 ~ /(^[ \t]*#|ML-KEM)/ {print}' "./${GRA_DIR}/pqc_kem_def.dat" >> "./${GRA_DIR}/${OQS_KEM_SEL_DAT}"
        awk '$1 ~ "ML-KEM" {print}' "./${GRA_DIR}/pqc_kem_def.dat" >> "./${GRA_DIR}/${OQS_KEM_SEL_DAT}"
    fi
    # plot file
    if [ -s "./${GRA_DIR}/${OQS_KEM_SEL_DAT}" ]; then
        if [ -n "${LIBOQS_VER}" ]; then
            GRA_TITLE_APPENDIX_FINAL="${GRA_TITLE_APPENDIX} liboqs${LIBOQS_VER}"
        else
            GRA_TITLE_APPENDIX_FINAL="${GRA_TITLE_APPENDIX}"
        fi
        ${PLOT_SCRIPT_FOR_FILE} -o "./${GRA_DIR}/pqc_kem_sel.png" -t "${GRA_TITLE_APPENDIX_FINAL}"
    fi
:<<'# COMMENT_EOF'
    # NOTE: Do not remove for debug
    # by measure-plot
    "${ARR_PLOT_SCRIPT[@]}" -o "./${GRA_DIR}/pqc_kem_sel.png" \
        ML-KEM-{512,768,1024} mlkem{512,768,1024} \
        bikel{1,3,5} hqc{128,192,256}
        # mlkem512 mlkem768 mlkem1024 \
        # bikel1 bikel3 bikel5 \
        # hqc128 hqc192 hqc256
# COMMENT_EOF

    # comparison among mldsa's and mlkem's
    if [ -s "./${GRA_DIR}/${OQS_SIG_SEL_DAT}" ] && [ -s "./${GRA_DIR}/${OQS_KEM_SEL_DAT}" ] ; then
        echo "# asymmetric_algorithm (sig or dec)/s (ver or enc)/s keygen/s    dh/s" > "./${GRA_DIR}/ml_dsa_kem.dat"
        awk '$1 ~ /^(ML-DSA|mldsa)/ {print}' "./${GRA_DIR}/${OQS_SIG_SEL_DAT}" >> "./${GRA_DIR}/ml_dsa_kem.dat"
        awk '$1 ~ /^(ML-KEM|mlkem)/ {print}' "./${GRA_DIR}/${OQS_KEM_SEL_DAT}" >> "./${GRA_DIR}/ml_dsa_kem.dat"
        if [ -n "${LIBOQS_VER}" ]; then
            GRA_TITLE_APPENDIX_FINAL="${GRA_TITLE_APPENDIX} liboqs${LIBOQS_VER}"
        else
            GRA_TITLE_APPENDIX_FINAL="${GRA_TITLE_APPENDIX}"
        fi
        ${PLOT_SCRIPT_FOR_FILE} -o "./${GRA_DIR}/ml_dsa_kem.png" -t "${GRA_TITLE_APPENDIX_FINAL}"
    fi

    ## RSA
    # all
    # This also generates rsa_enc.{png,dat} if possible.
    if [ -s "./${GRA_DIR}/rsa.png" ]; then
        echo
        echo "Notice: './${GRA_DIR}/rsa.png' already exists."
        echo "  Move or remove it to renew it."
    else
        "${ARR_PLOT_SCRIPT[@]}" -o "./${GRA_DIR}/rsa.png" rsa
        # NOTE:
        #   The above 'rsa' fails in fips-openssl.3.5.0 and so on with
        #   the following failures:
        #   --------------------------------
        #   RSA sign setup failure.  No RSA sign will be done.
        #   807B5FF94F7F0000:error:1C800069:Provider routines:ossl_fips_ind_rsa_key_check:invalid key length:providers/common/securitycheck_fips.c:45:operation: RSA Sign Init
        #   RSA verify setup failure.  No RSA verify will be done.
        #   RSA encrypt setup failure.  No RSA encrypt will be done.
        #   RSA decrypt setup failure.  No RSA decrypt will be done.
        #   --------------------------------
        #   while the following 'rsa<bit-length>' does work despite
        #   the following failures:
        #   --------------------------------
        #   RSA encrypt setup failure.  No RSA encrypt will be done.
        #   80BB94AA357F0000:error:1C8000A8:Provider routines:rsa_encrypt:invalid padding mode:providers/implementations/asymciphers/rsa_enc.c:166:
        #   RSA decrypt setup failure.  No RSA decrypt will be done.
        #   --------------------------------
        if [ ! -s "./${GRA_DIR}/rsa.png" ]; then
            "${ARR_PLOT_SCRIPT[@]}" -o "./${GRA_DIR}/rsa.png" rsa3072 rsa4096 rsa7680 rsa15360
            # "${ARR_PLOT_SCRIPT[@]}" -o "./${GRA_DIR}/rsa.png" rsa3072 rsa4096 rsa7680
        fi
    fi
    ## DL-based DSA, such as ECDSA, EdDSA and FFDSA.
    if [ -s "./${GRA_DIR}/dsa_all.png" ]; then
        echo
        echo "Notice: './${GRA_DIR}/dsa_all.png' already exists."
        echo "  Move or remove it to renew it."
    else
        # ecdsa
        if [ -s "./${GRA_DIR}/ecdsa.png" ]; then
            echo
            echo "Notice: './${GRA_DIR}/ecdsa.png' already exists."
            echo "  Move or remove it to renew it."
        else
            rm -rf "./${GRA_DIR}/ecdsa.dat"
            "${ARR_PLOT_SCRIPT[@]}" -o "./${GRA_DIR}/ecdsa.png" ecdsa
            if [ ! -s "./${GRA_DIR}/ecdsa.png" ]; then
                echo "Retrying with specific names."
                "${ARR_PLOT_SCRIPT[@]}" -o "./${GRA_DIR}/ecdsa.png" ecdsap256 ecdsap384 ecdsap521
            fi
        fi
        # eddsa
        if [ -s "./${GRA_DIR}/eddsa.png" ]; then
            echo
            echo "Notice: './${GRA_DIR}/eddsa.png' already exists."
            echo "  Move or remove it to renew it."
        else
            rm -rf "./${GRA_DIR}/eddsa.dat"
            "${ARR_PLOT_SCRIPT[@]}" -o "./${GRA_DIR}/eddsa.png" eddsa
            if [ ! -s "./${GRA_DIR}/eddsa.png" ]; then
                echo "Retrying with specific names."
                "${ARR_PLOT_SCRIPT[@]}" -o "./${GRA_DIR}/eddsa.png" ed25519 ed448
            fi
        fi
        # dsa (over finite field)
        if [ -s "./${GRA_DIR}/dsa.png" ]; then
            echo
            echo "Notice: './${GRA_DIR}/dsa.png' already exists."
            echo "  Move or remove it to renew it."
        else
            rm -rf "./${GRA_DIR}/dsa.dat"
            "${ARR_PLOT_SCRIPT[@]}" -o "./${GRA_DIR}/dsa.png" dsa
            # not retry due to obsolete
        fi
        # dsa_all from ecdsa, eddsa and dsa
        # "${ARR_PLOT_SCRIPT[@]}" -o "./${GRA_DIR}/dsa_all.png" ecdsa eddsa dsa
        rm -rf "./${GRA_DIR}/dsa_all.dat"
        for dsa_type in ecdsa eddsa dsa; do
            [ -s "./${GRA_DIR}/${dsa_type}.dat" ] && cat "./${GRA_DIR}/${dsa_type}.dat" >> "./${GRA_DIR}/dsa_all.dat"
        done
        ${PLOT_SCRIPT_FOR_FILE} -o "./${GRA_DIR}/dsa_all.png" -t "${GRA_TITLE_APPENDIX}"
    fi
    ## comparisons
    # 128/192/256 (classical) bit securities for "sig_ver_keygen"
    arr_bits=(128 192 256)
    for bits in "${arr_bits[@]}"; do
        echo -e "#\n# asymmetric_algorithm        sign/s   verify/s   keygen/s" > "./${GRA_DIR}/sig_${bits}bs.dat"
    done
    # pick up the corresponding algorithms from *.dat
    if [ -s "./${GRA_DIR}/rsa.dat" ]; then
        awk '$1 ~ /rsa(3072|4096)/' "./${GRA_DIR}/rsa.dat" >> "./${GRA_DIR}/sig_128bs.dat"
        awk '$1 == "rsa7680"'       "./${GRA_DIR}/rsa.dat" >> "./${GRA_DIR}/sig_192bs.dat"
        awk '$1 == "rsa15360"'      "./${GRA_DIR}/rsa.dat" >> "./${GRA_DIR}/sig_256bs.dat"
    fi
    if [ -s "./${GRA_DIR}/dsa_all.dat" ]; then
        # EdDSA(Ed25519) ecdsa(nistp256)
        # awk '$1 ~ /^([ \t]*#|EdDSA\(Ed255|ecdsa\(nistp2[5-8][0-9])/' \
        awk '$1 ~ /^(EdDSA\(Ed255|ecdsa\(nistp2[5-8][0-9])/' \
            "./${GRA_DIR}/dsa_all.dat" >> "./${GRA_DIR}/sig_128bs.dat"
        # EdDSA(Ed448) ecdsa(nistp384)
        # awk '$1 ~ /^([ \t]*#|EdDSA\(Ed448|ecdsa\(nistp384)/' \
        awk '$1 ~ /^(EdDSA\(Ed448|ecdsa\(nistp384)/' \
            "./${GRA_DIR}/dsa_all.dat" >> "./${GRA_DIR}/sig_192bs.dat"
        # EdDSA(Ed448) ecdsa(nistp521)
        # awk '$1 ~ /^([ \t]*#|EdDSA\(Ed448|ecdsa\(nistp521)/' \
        # awk '$1 ~ /^(EdDSA\(Ed448|ecdsa\(nistp521)/' \
        # ecdsa(nistp521)
        # awk '$1 ~ /^([ \t]*#|ecdsa\(nistp521)/' \
        awk '$1 ~ /^(ecdsa\(nistp521)/' \
            "./${GRA_DIR}/dsa_all.dat" >> "./${GRA_DIR}/sig_256bs.dat"
    fi
    if [ -s "./${GRA_DIR}/${OQS_SIG_SEL_DAT}" ]; then
        awk '$1 ~ /(ML-DSA-44|mldsa44|mayo[12])/' "./${GRA_DIR}/${OQS_SIG_SEL_DAT}" >> "./${GRA_DIR}/sig_128bs.dat"
        awk '$1 ~ /(ML-DSA-65|mldsa65|mayo3)/' "./${GRA_DIR}/${OQS_SIG_SEL_DAT}" >> "./${GRA_DIR}/sig_192bs.dat"
        awk '$1 ~ /(ML-DSA-87|mldsa87|mayo5)/' "./${GRA_DIR}/${OQS_SIG_SEL_DAT}" >> "./${GRA_DIR}/sig_256bs.dat"
    fi
    if [ -n "${LIBOQS_VER}" ]; then
        # NOTE: precisely if the algorithms are added from oqs_sig_all.dat
        GRA_TITLE_APPENDIX_FINAL="${GRA_TITLE_APPENDIX} liboqs${LIBOQS_VER}"
    else
        GRA_TITLE_APPENDIX_FINAL="${GRA_TITLE_APPENDIX}"
    fi
    # depict
    for bits in "${arr_bits[@]}"; do
        ${PLOT_SCRIPT_FOR_FILE} -o "./${GRA_DIR}/sig_${bits}bs.png" -t "${GRA_TITLE_APPENDIX_FINAL}"
    done
:<<'# COMMENT_EOF'
        # NOTE: some versions may include dsa2048, dsa4096 and larger dsa's
        if [ -n "${LIBOQS_VER}" ]; then
            # "${ARR_PLOT_SCRIPT[@]}" -o "./${GRA_DIR}/sig_128bs.png" ed25519 ecdsap256 ecdsak283 ecdsab283 ecdsabrp256r1 ecdsabrp256t1 rsa3072 rsa4096 mldsa44
            "${ARR_PLOT_SCRIPT[@]}" -o "./${GRA_DIR}/sig_128bs.png" ed25519 ecdsap256 rsa3072 rsa4096 mldsa44
            "${ARR_PLOT_SCRIPT[@]}" -o "./${GRA_DIR}/sig_192bs.png" ed448 ecdsap384 rsa7680 mldsa65
            "${ARR_PLOT_SCRIPT[@]}" -o "./${GRA_DIR}/sig_256bs.png" ed448 ecdsap521 rsa15360 mldsa87
        else
            "${ARR_PLOT_SCRIPT[@]}" -o "./${GRA_DIR}/sig_128bs.png" ed25519 ecdsap256 rsa3072 rsa4096
            "${ARR_PLOT_SCRIPT[@]}" -o "./${GRA_DIR}/sig_192bs.png" ed448 ecdsap384 rsa7680
            # "${ARR_PLOT_SCRIPT[@]}" -o "./${GRA_DIR}/sig_256bs.png" ed448 ecdsap521 rsa15360
            "${ARR_PLOT_SCRIPT[@]}" -o "./${GRA_DIR}/sig_256bs.png" ecdsap521 rsa15360
        fi
# COMMENT_EOF
    ### Diffie-Hellman key exchange
    ## all
    if [ -s "./${GRA_DIR}/dh_all.png" ]; then
        echo
        echo "Notice: './${GRA_DIR}/dh_all.png' already exists."
        echo "  Move or remove it to renew it."
    else
        # ecdh
        if [ -s "./${GRA_DIR}/ecdh.png" ]; then
            echo
            echo "Notice: './${GRA_DIR}/ecdh.png' already exists."
            echo "  Move or remove it to renew it."
        else
            rm -rf "./${GRA_DIR}/ecdh.dat"
            "${ARR_PLOT_SCRIPT[@]}" -o "./${GRA_DIR}/ecdh.png" ecdh
            if [ ! -s "./${GRA_DIR}/ecdh.png" ]; then
                echo "Retrying with specific names."
                "${ARR_PLOT_SCRIPT[@]}" -o "./${GRA_DIR}/ecdh.png" ecdhp256 ecdhp384 ecdhp521 ecdhx25519 ecdhx448
            fi
        fi
        # ffdh
        # NOTE:
        #   "ffdh" is unknown for LibreSSL at least up to 4.0.0 and OpenSSL 1.
        if [ -s "./${GRA_DIR}/ffdh.png" ]; then
            echo
            echo "Notice: './${GRA_DIR}/ffdh.png' already exists."
            echo "  Move or remove it to renew it."
        else
            rm -rf "./${GRA_DIR}/ffdh.dat"
            "${ARR_PLOT_SCRIPT[@]}" -o "./${GRA_DIR}/ffdh.png" ffdh
            # not retry due to obsolete
        fi
        # dh_all from both ecdh and ffdh
        # "${ARR_PLOT_SCRIPT[@]}" -o "./${GRA_DIR}/dh_all.png" ecdh ffdh
        rm -rf "./${GRA_DIR}/dh_all.dat"
        for dh_type in ecdh ffdh; do
            [ -s "./${GRA_DIR}/${dh_type}.dat" ] && cat "./${GRA_DIR}/${dh_type}.dat" >> "./${GRA_DIR}/dh_all.dat"
        done
        ${PLOT_SCRIPT_FOR_FILE} -o "./${GRA_DIR}/dh_all.png" -t "${GRA_TITLE_APPENDIX}"
    fi
    ###   - Examples of proportional for ecdh
    if [ -s "./${GRA_DIR}/ecdh.dat" ]; then
        # pick up nistb, brainpoolP, nistp, respectively, from ecdh.dat
        # ecdh(nistp256) ecdh(nistk283) ecdh(nistb283) ecdh(brainpoolP256r1) ecdh(brainpoolP256t1) ecdh(X25519) ffdh3072 ffdh4096
        awk '$1 ~ /^([ \t]*#|ecdh\(nistb.*)/' "./${GRA_DIR}/ecdh.dat" > "./${GRA_DIR}/ecdh_b.dat"
        ${PLOT_SCRIPT_FOR_FILE} -o "./${GRA_DIR}/ecdh_b.png" -t "${GRA_TITLE_APPENDIX}"
        awk '$1 ~ /^([ \t]*#|ecdh\(brainpoolP[1-9][0-9]*r1\))/' "./${GRA_DIR}/ecdh.dat" > "./${GRA_DIR}/ecdh_brp_r1.dat"
        ${PLOT_SCRIPT_FOR_FILE} -o "./${GRA_DIR}/ecdh_brp_r1.png" -t "${GRA_TITLE_APPENDIX}"
        awk '$1 ~ /^([ \t]*#|ecdh\(nistp[1-9][0-9]*\))/' "./${GRA_DIR}/ecdh.dat" > "./${GRA_DIR}/ecdh_p.dat"
        ${PLOT_SCRIPT_FOR_FILE} -o "./${GRA_DIR}/ecdh_p.png" -t "${GRA_TITLE_APPENDIX}"
    else
        "${ARR_PLOT_SCRIPT[@]}" -o "./${GRA_DIR}/ecdh_b.png" ecdhb163 ecdhb233 ecdhb283 ecdhb409 ecdhb571
        "${ARR_PLOT_SCRIPT[@]}" -o "./${GRA_DIR}/ecdh_brp_r1.png" ecdhbrp256r1 ecdhbrp384r1 ecdhbrp512r1
        # "${ARR_PLOT_SCRIPT[@]}" -o "./${GRA_DIR}/ecdh_p.png" ecdhp160 ecdhp192 ecdhp224 ecdhp256 ecdhp384 ecdhp521
        "${ARR_PLOT_SCRIPT[@]}" -o "./${GRA_DIR}/ecdh_p.png" ecdhp192 ecdhp224 ecdhp256 ecdhp384 ecdhp521
    fi
    ###   - Examples of proportional for ecdsa
    if [ -s "./${GRA_DIR}/ecdsa.dat" ]; then
        awk '$1 ~ /^([ \t]*#|ecdsa\(nistp[1-9][0-9]*\))/' "./${GRA_DIR}/ecdsa.dat" > "./${GRA_DIR}/ecdsa_p.dat"
        ${PLOT_SCRIPT_FOR_FILE} -o "./${GRA_DIR}/ecdsa_p.png" -t "${GRA_TITLE_APPENDIX}"
    else
        # "${ARR_PLOT_SCRIPT[@]}" -o "./${GRA_DIR}/ecdsa_p.png" ecdsap160 ecdsap192 ecdsap224 ecdsap256 ecdsap384 ecdsap521
        "${ARR_PLOT_SCRIPT[@]}" -o "./${GRA_DIR}/ecdsa_p.png" ecdsap192 ecdsap224 ecdsap256 ecdsap384 ecdsap521
    fi
    ###################
    # 128/192/256 (classical) bit securities for "dec_enc_keygen_dh"
    for bits in "${arr_bits[@]}"; do
        echo -e "#\n# asymmetric_algorithm         dec/s      enc/s   keygen/s       dh/s" > "./${GRA_DIR}/dec_enc_keygen_dh_${bits}bs.dat"
    done
    if [ -s "./${GRA_DIR}/rsa_enc.dat" ]; then
        awk '$1 ~ /rsa(3072|4096)/' "./${GRA_DIR}/rsa_enc.dat" >> "./${GRA_DIR}/dec_enc_keygen_dh_128bs.dat"
        awk '$1 == "rsa7680"'       "./${GRA_DIR}/rsa_enc.dat" >> "./${GRA_DIR}/dec_enc_keygen_dh_192bs.dat"
        awk '$1 == "rsa15360"'      "./${GRA_DIR}/rsa_enc.dat" >> "./${GRA_DIR}/dec_enc_keygen_dh_256bs.dat"
    fi
:<<'# COMMENT_EOF'
    # from rsa.log
    if [ -s "./${GRA_DIR}/rsa.log" ]; then
        # "${TABLE_TYPE}" == "dec_enc_keygen_dh"
        # ./${GRA_DIR}/rsa.log
        # OpenSSL 1 rsa
        #                   sign    verify    sign/s verify/s
        # rsa 4096 bits 0.007594s 0.000115s    131.7   8662.4
        #
        # OpenSSL 3 rsa
        #                     sign    verify    encrypt   decrypt   sign/s verify/s  encr./s  decr./s
        # rsa  4096 bits 0.010000s 0.000126s 0.000124s 0.008361s    100.0   7960.4   8046.5    119.6
        awk '$1$2 ~ /rsa(3072|4096)/ {if (NF == 11) { printf "%-25s %10s %10s %10s %10s\n" ,$1$2,$11,$10,"0","0" } else if (NF == 7) { printf "%-25s %10s %10s %10s %10s\n" ,$1$2,$6,$7,"0","0" }}' \
            "./${GRA_DIR}/rsa.log" >> "./${GRA_DIR}/dec_enc_keygen_dh_128bs.dat"
        awk '$1$2 == "rsa7680" {if (NF == 11) { printf "%-25s %10s %10s %10s %10s\n" ,$1$2,$11,$10,"0","0" } else if (NF == 7) { printf "%-25s %10s %10s %10s %10s\n" ,$1$2,$6,$7,"0","0" }}' \
            "./${GRA_DIR}/rsa.log" >> "./${GRA_DIR}/dec_enc_keygen_dh_192bs.dat"
        awk '$1$2 == "rsa15360" {if (NF == 11) { printf "%-25s %10s %10s %10s %10s\n" ,$1$2,$11,$10,"0","0" } else if (NF == 7) { printf "%-25s %10s %10s %10s %10s\n" ,$1$2,$6,$7,"0","0" }}' \
            "./${GRA_DIR}/rsa.log" >> "./${GRA_DIR}/dec_enc_keygen_dh_256bs.dat"
        # dec_enc_keygen_dh_128bs.dat
        #                              decr./s  encr./s   keygen/s(N/A) dh/s(N/A)
        # rsa3072                        545.0    28380.2          0          0
        # rsa4096                        251.0    17429.0          0          0
    fi
# COMMENT_EOF
    if [ -s "./${GRA_DIR}/ecdh.dat" ]; then
        # ecdh(nistp256)  0.0000s 20228.4
        awk '$1 ~ /ecdh\((nistp256|X25519)\)/ {print}' "./${GRA_DIR}/ecdh.dat" >> "./${GRA_DIR}/dec_enc_keygen_dh_128bs.dat"
        awk '$1 ~ /ecdh\((nistp384|X448)\)/ {print}' "./${GRA_DIR}/ecdh.dat" >> "./${GRA_DIR}/dec_enc_keygen_dh_192bs.dat"
        # for 224bs and greater
        # awk '$1 ~ /ecdh\((nistp521|X448)\)/ {print}' "./${GRA_DIR}/dh_all.dat" >> "./${GRA_DIR}/dec_enc_keygen_dh_224bs.dat"
        awk '$1 ~ /ecdh\(nistp521\)/ {print}' "./${GRA_DIR}/ecdh.dat" >> "./${GRA_DIR}/dec_enc_keygen_dh_256bs.dat"
    fi
    if [ -s "./${GRA_DIR}/${OQS_KEM_SEL_DAT}" ]; then
        awk '$1 ~ /(ML-KEM-|mlkem)512/' "./${GRA_DIR}/${OQS_KEM_SEL_DAT}" >> "./${GRA_DIR}/dec_enc_keygen_dh_128bs.dat"
        awk '$1 ~ /(ML-KEM-|mlkem)768/' "./${GRA_DIR}/${OQS_KEM_SEL_DAT}" >> "./${GRA_DIR}/dec_enc_keygen_dh_192bs.dat"
        awk '$1 ~ /(ML-KEM-|mlkem)1024/' "./${GRA_DIR}/${OQS_KEM_SEL_DAT}" >> "./${GRA_DIR}/dec_enc_keygen_dh_256bs.dat"
    fi
    if [ -n "${LIBOQS_VER}" ]; then
        # NOTE: precisely if the algorithms are added from oqs_kem_all.dat
        GRA_TITLE_APPENDIX_FINAL="${GRA_TITLE_APPENDIX} liboqs${LIBOQS_VER}"
    else
        GRA_TITLE_APPENDIX_FINAL="${GRA_TITLE_APPENDIX}"
    fi
    # depict
    for bits in "${arr_bits[@]}"; do
        ${PLOT_SCRIPT_FOR_FILE} -o "./${GRA_DIR}/dec_enc_keygen_dh_${bits}bs.png" -t "${GRA_TITLE_APPENDIX_FINAL}"
    done
    ### plot fit ###
    (cd "${GRA_DIR}" && ${PLOT_FIT_SCRIPT})
}


##
# @brief        Plot graphs for symmetric-key and no-key (cryptographic hash) algorithms
# @details      *-no-evp means with old low-level API.
# @param[in]    global PLOT_SCRIPT GRA_DIR OPENSSL_VER_NOSPACE
# @param[out]   *.png files under GRA_DIR
plot_graph_symmetric () {
    # NOTE:
    #   ${PLOT_SCRIPT} in "${ARR_PLOT_SCRIPT[@]}" ignores unsupported algorithms.
    #   So you do not need to remove them.
    #
    # Comment out if not necessary
    ###   - Ciphers with around 128/256 (classical) bit security:"
    "${ARR_PLOT_SCRIPT[@]}" -o "./${GRA_DIR}/cipher128-256.png" \
        aes-128-ctr aes-128-gcm aes-128-ccm chacha20-poly1305\
        aes-256-ctr aes-256-gcm aes-256-ccm
    "${ARR_PLOT_SCRIPT[@]}" -o "./${GRA_DIR}/aes128-cbc.png" \
        aes-128-cbc aes-128-cbc-no-evp
    ###   - Hash functions with 112-bit or more security:
    # NOTE: 
    #   "whirlpool" is unknown for OpenSSL 3.
    #   "ghash-no-evp" is too fast to depict with the following algorithms.
    "${ARR_PLOT_SCRIPT[@]}" -o "./${GRA_DIR}/hash.png"\
        sha512-224 sha512-256 sha384 sha512 sha512-no-evp\
        sha224 sha256 sha256-no-evp\
        SHAKE128 SHAKE256 whirlpool\
        sha3-224 sha3-256 sha3-384 sha3-512
        # \ ghash-no-evp
    ###   - HMAC and KMAC:
    # NOTE: OpenSSL1 and LibreSSL at least up to 4.0.0 seem to support
    #       only "hmac(-no-evp)".
    "${ARR_PLOT_SCRIPT[@]}" -o "./${GRA_DIR}/hmac.png" hmac-md5 hmac-sha1 \
        hmac-sha512-224 hmac-sha512-256 hmac-sha384 hmac-sha512 \
        hmac-sha224 hmac-sha256 hmac-no-evp \
        kmac128-no-evp kmac256-no-evp
        # hmac-sha3-224 hmac-sha3-256 hmac-sha3-384 hmac-sha3-512 \
        # KECCAK-KMAC128 KECCAK-KMAC256
        # cmac aes-192-cbc aes-256-cbc
    # NOTE:
    #   - sha3 does not require hmac but for comparison with kmac.
    #   - KECCAK-KMAC is picking up the KMAC digest (without key-prepend) not the KMAC MAC.
    #     The MAC is called KMAC128 or KMAC256.
    #     https://github.com/openssl/openssl/issues/22619
    #   - cmac (aes-128-cbc), aes-192-cbc and aes-256-cbc are available.
    ###   - KECCAK derived algorithms
    # 128 bit security
    # ../../plot_openssl_speed.sh -o ./graphs/hmac_kmac_128bs.png -p ./openssl/apps/openssl SHAKE128 KECCAK-KMAC128 kmac128-no-evp sha3-256 hmac-sha3-256
    # "${ARR_PLOT_SCRIPT[@]}" -o "./${GRA_DIR}/keccak_128bs.png" -p ./openssl/apps/openssl SHAKE128 KECCAK-KMAC128 kmac128-no-evp sha3-256 hmac-sha3-256
    "${ARR_PLOT_SCRIPT[@]}" -o "./${GRA_DIR}/keccak_128bs.png" SHAKE128 KECCAK-KMAC128 kmac128-no-evp sha3-256 hmac-sha3-256
    # 256 bit security
    # ../../plot_openssl_speed.sh -o ./graphs/hmac_kmac_256bs.png -p ./openssl/apps/openssl SHAKE256 KECCAK-KMAC256 kmac256-no-evp sha3-512 hmac-sha3-512
    # "${ARR_PLOT_SCRIPT[@]}" -o "./${GRA_DIR}/keccak_256bs.png" -p ./openssl/apps/openssl SHAKE256 KECCAK-KMAC256 kmac256-no-evp sha3-512 hmac-sha3-512
    "${ARR_PLOT_SCRIPT[@]}" -o "./${GRA_DIR}/keccak_256bs.png" SHAKE256 KECCAK-KMAC256 kmac256-no-evp sha3-512 hmac-sha3-512
    ####################################################################
}


##
# @brief        Save measurement results of specified crypt-algorithms.
# @details      Save graphs in the specified *.png files and their data file
#               in *.dat files of the same name.
# @param[in]    global OPENSSL (openssl command)
# @param[out]   <graph_filename>.png <graph_filename>.dat
plot_graphs () {
    # depends on $tag
    # PATH from ${TMP_DIR}/${openssl_type}/
    PLOT_SCRIPT_FOR_FILE="${PLOT_SCRIPT}"
    # PLOT_SCRIPT="${PLOT_SCRIPT} -p ${OPENSSL} ${SPEED_OPT}"
    # PLOT_SCRIPT="${PLOT_SCRIPT} -p ${OPENSSL} ${ARR_SPEED_OPT[@]}"
    ARR_PLOT_SCRIPT=("${PLOT_SCRIPT}" -p "${OPENSSL}" "${ARR_SPEED_OPT[@]}")
    # TODO: Run once for OPENSSL_VER_NOSPACE
    #       Not necessary after set_openssl_in_path().
    if [ -z "${OPENSSL_VER_NOSPACE}" ]; then
        # OPENSSL_VER_NOSPACE="$(echo "${OPENSSL_VER}" | awk '{print $1 $2}')"
        openssl_ver_nospace_from_command
        echo "OPENSSL_VER_NOSPACE: ${OPENSSL_VER_NOSPACE}"
    fi
    mkdir -p "${GRA_DIR}"
    liboqs_ver_from_command
    # spec
    # ${OPENSSL} version -a > ${GRA_DIR}/openssl_ver_a.log
    echo "${OPENSSL_VER_ALL}" > "${GRA_DIR}"/openssl_ver_a.log
    echo "${OPENSSL_PROVIDER}" > "${GRA_DIR}"/openssl_provider.log
    uname -srm > "${GRA_DIR}"/spec.log
    if [ "${UNAME_S}" == "Darwin" ]; then
        {
            # sw_vers -productVersion;
            sw_vers;
            # system_profiler SPSoftwareDataType;
            sysctl machdep.cpu.brand_string;
            pkgutil --pkg-info=com.apple.pkg.CLTools_Executables;
        } >> "${GRA_DIR}"/spec.log
    else
        {
            awk '/^PRETTY/ {print substr($0,14,length($0)-14)}' /etc/os-release;
            awk '$1$2 == "modelname" {$1="";$2="";$3=""; print substr($0,4); exit;}' /proc/cpuinfo;
         } >> "${GRA_DIR}"/spec.log
    fi
    ####################################################################
    ##### Edit crypt-algorithms (and output graph file name) below #####
    ### TIPS: Place a short crypt-algorithm name at the rightest to avoid
    ###       space in the output graph.
    if [ "${RUN_MODE}" == "build_only" ]; then
        exit 0
    fi
    if [ "${RUN_MODE}" != "skip_asymmetric" ]; then
        plot_graph_asymmetric
    fi
    if [ "${RUN_MODE}" != "skip_symmetric" ]; then
        plot_graph_symmetric
    fi
    # [ "${RUN_MODE}" == "full" ]
}


:<<'# COMMENT_EOF'
# NOTE: Uncomment to build liboqs.a independently.
#       Currently it is build in set_with_oqsprovider().
# LIBOQS_BRANCH=0.10.1
LIBOQS_SRC_DIR=Liboqs_SRC
LIBOQS_DIR=./liboqs_${LIBOQS_BRANCH}
##
# @brief        Build liboqs.a under ${LIBOQS_SRC_DIR}/liboqs_${LIBOQS_BRANCH}/build/lib/ in ${TMP_DIR}.
# @details      This build requires commands in https://github.com/open-quantum-safe/liboqs/:
#               On Ubuntu:
#                   sudo apt install astyle cmake gcc ninja-build libssl-dev python3-pytest python3-pytest-xdist unzip xsltproc doxygen graphviz python3-yaml valgrind
#               On macOS with Homebrew:
#                    brew install cmake ninja openssl@3 wget doxygen graphviz astyle valgrind
#                    pip3 install pytest pytest-xdist pyyaml
# @param[in]    global LIBOQS_SRC_DIR LIBOQS_DIR LIBOQS_BRANCH
# @param[out]   liboqs.a under ${LIBOQS_SRC_DIR}/liboqs_${LIBOQS_BRANCH}/build/lib/
build_liboqs () {
    mkdir -p ${LIBOQS_SRC_DIR}
    pushd "$(pwd)" || exit 2  # ./${TMP_DIR}
    cd "${LIBOQS_SRC_DIR}" || exit 2;
        if [ -d "${LIBOQS_DIR}" ]; then
            echo
            echo "Notice: '${LIBOQS_DIR}' dir already exists."
            echo "  Move or remove it to renew the contents."
        else
            ${GIT_CLONE} https://github.com/open-quantum-safe/liboqs.git -b "${LIBOQS_BRANCH}" --depth 1 "${LIBOQS_DIR}"
            pushd "$(pwd)" || exit 2  # ./${TMP_DIR}/${LIBOQS_SRC_DIR}
            cd "${LIBOQS_DIR}" || exit 2;
                mkdir -p build
                pushd "$(pwd)" || exit 2  # ./${TMP_DIR}/${LIBOQS_SRC_DIR}/${LIBOQS_DIR}
                cd build || exit 2;
                    cmake -GNinja .. && ninja
                popd || exit 2  # ./${TMP_DIR}/${LIBOQS_SRC_DIR}/${LIBOQS_DIR}
            popd || exit 2  # ./${TMP_DIR}/${LIBOQS_SRC_DIR}
        fi
    popd || exit 2  # ./${TMP_DIR}
}
# COMMENT_EOF


##
# @brief        Build liboqs.a under ${LIBOQS_SRC_DIR}/liboqs_${LIBOQS_BRANCH}/build/lib/ in ${TMP_DIR}.
# @details      This build requires commands in https://github.com/open-quantum-safe/liboqs/:
#               On Ubuntu:
#                   sudo apt install astyle cmake gcc ninja-build libssl-dev python3-pytest python3-pytest-xdist unzip xsltproc doxygen graphviz python3-yaml valgrind
#               On macOS with Homebrew:
#                    brew install cmake ninja openssl@3 wget doxygen graphviz astyle valgrind 
#                    pip3 install pytest pytest-xdist pyyaml
# @param[in]    global LIBOQS_SRC_DIR LIBOQS_DIR LIBOQS_BRANCH
# @param[out]   liboqs.a under ${LIBOQS_SRC_DIR}/liboqs_${LIBOQS_BRANCH}/build/lib/
set_with_oqsprovider () {
    echo
    echo "--- ${openssl_type} ---"
    OQSPROVIDER_DIR=${openssl_type}
    # if false ; then
    if [ -d "${OQSPROVIDER_DIR}" ]; then
        echo
        echo "Notice: '${OQSPROVIDER_DIR}' dir already exists."
        echo "  Move or remove it to renew the contents."
    else
        openssl_type_to_oqs_branches
        ${GIT_CLONE} https://github.com/open-quantum-safe/oqs-provider.git -b "${OQSPROVIDER_BRANCH}" --depth 1 "${OQSPROVIDER_DIR}"
    fi
    pushd "$(pwd)" || exit 2  # ./${TMP_DIR}
    cd "${OQSPROVIDER_DIR}" || exit 2;
    # in ${OQSPROVIDER_DIR}
        OPENSSL_APP=$(pwd)/openssl/apps/openssl
        OPENSSL_CONF=$(pwd)/scripts/openssl-ca.cnf
        OPENSSL_MODULES=$(pwd)/_build/lib
        if [ -s "${OPENSSL_APP}" ] && [ -s "${OPENSSL_CONF}" ] && [ -d "${OPENSSL_MODULES}" ]; then
            echo "Notice: skip 'fullbuild.sh'."
        else
            if [ "${PATCH_SPEED_PQCSIGS_IN_DEFAULT_PROVIDER}" == "True" ]; then
                if [[ "${OPENSSL_BRANCH}" == "openssl-3.5"* ]]; then
                    if [ "${OPENSSL_BRANCH}" == "openssl-3.5.0" ]; then
                        V_FOR_PATCH="_3_5_0"
                    else
                        V_FOR_PATCH=""
                    fi
                fi
                # apply patch but avoid exit by set -e
                sed -i "s/\&\& cd openssl \&\& LDFLAGS/\&\& cd openssl \&\& { ${GIT} apply ..\/..\/..\/utils\/speed_pqcsigs_in_default_provider${V_FOR_PATCH}.patch \|\| true \;} \&\& LDFLAGS/" scripts/fullbuild.sh
            fi
            # can comment out the next sed command if git protocol is allowed in your network
            sed -i".org" 's/git:\/\/git.openssl.org/https:\/\/github.com\/openssl/' scripts/fullbuild.sh
            export OPENSSL_BRANCH LIBOQS_BRANCH
            set +e
            # TODO:
            #   - Make fullbuild.sh "set -e" compatible.
            #     Some commands before '$?'' return 'false' at least in oqsprovider 0.6.1.
            #   - Remove the next line after fullbuild.sh becomes shellcheck ready.
            # shellcheck source=/dev/null
            . ./scripts/fullbuild.sh
            set -e
        fi
        ## NOTE: for building oqsprovider only
        # cmake -S . -B _build && cmake --build _build

        export OPENSSL_APP
        export OPENSSL_CONF
        export OPENSSL_MODULES
        # if [[ "$(uname -s)" == "Darwin"* ]]; then
        if [ "${UNAME_S}" == "Darwin" ]; then
            # macOS
            DYLD_LIBRARY_PATH=$(pwd)/.local/lib64
            export DYLD_LIBRARY_PATH
        else
            LD_LIBRARY_PATH=$(pwd)/.local/lib64
            export LD_LIBRARY_PATH
        fi
        OPENSSL=${OPENSSL_APP}
        # ${OPENSSL} is available after setting
        OPENSSL_VER=$(${OPENSSL} version)
    #    plot_graphs
    # popd || exit 2  # ./${TMP_DIR}
}


# @param[out]    openssl_in_path_dir
set_openssl_in_path () {
    # default openssl in PATH
    OPENSSL="openssl"
    # `openssl version` shall run first to determine the folder name
    OPENSSL_VER=$(${OPENSSL} version)
    # TODO: run once for OPENSSL_VER_NOSPACE
    OPENSSL_VER_NOSPACE="$(echo "${OPENSSL_VER}" | awk '{print $1 $2}')"
    # local tmp=${OPENSSL_VER#* }; openssl_ver_num_only=${tmp%% *}
    # openssl_in_path_dir="default_openssl_${openssl_ver_num_only}"
    openssl_in_path_dir="default_${OPENSSL_VER_NOSPACE}"
    echo
    echo "--- ${openssl_in_path_dir} ---"
    # echo "OPENSSL_VER_NOSPACE: ${OPENSSL_VER_NOSPACE}"
    mkdir -p "${openssl_in_path_dir}"
    pushd "$(pwd)" || exit 2
    cd "${openssl_in_path_dir}" || exit 2;
    #    echo
    #    echo "--- ${openssl_in_path_dir} ---"
    #    plot_graphs
    # popd || exit 2  # ./${TMP_DIR}
}


set_openssl_tagged () {
    openssl_type_dir="${openssl_type}"
    if [ -n "${ENABLE_FIPS}" ]; then
        # remove ${TAG_FIPS}
        openssl_type="${openssl_type: ${#TAG_FIPS}}"
    fi
    # whether "*${TAG_MINGW}" or not
    # NOTE: lower case works in bash 4.4.20 and newer
    # if [ "${openssl_type: -${#TAG_MINGW}}" == "${TAG_MINGW,,}" ]; then
    if [ "${openssl_type: -${#TAG_MINGW}}" == "${TAG_MINGW}" ]; then
        # NOTE:
        #   - negative length works in bash 4.2 and newer
        #   - macOS's bash 3.2.57(1)-release accepts a negative value only
        #     for the start position but not the length (end position).
        # openssl_type=${openssl_type: 0: -${#TAG_MINGW}}
        # openssl_type=${openssl_type%"${TAG_MINGW}"}
        openssl_type=${openssl_type: 0: ${#openssl_type} - ${#TAG_MINGW}}
        EXE=".exe"
    fi
    if [ "${openssl_type}" == master ]; then
        project_name="openssl"
        tag_candidate="master"
    else
        # 'project_name' shall not contain '-' 
        tag_candidate="${openssl_type#*-}"
        # project_name="${openssl_type%-*}"
        project_name="${openssl_type/-${tag_candidate}/}"
    fi
    echo
    echo "--- ${openssl_type_dir} ---"
    if [ -d "${openssl_type_dir}" ]; then
        echo
        echo "Notice: '${openssl_type_dir}' dir already exists."
        echo "  Move or remove it to renew the contents."
    else
        # NOTE: lower case works in bash 4.4.20 and newer
        # case "${project_name,,}" in
        case "${project_name}" in
            openssl|OpenSSL|OPENSSL)
                if [[ "${tag_candidate}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    # tag=openssl-3.3.1
                    tag="${openssl_type}"
                else
                    # tag=master
                    tag="${tag_candidate}"
                fi
                git_url="https://github.com/openssl/openssl.git"
                # ${GIT_CLONE} "${git_url}" -b "${tag}" --depth 1 "${openssl_type}"
                ${GIT_CLONE} "${git_url}" -b "${tag}" --depth 1 "${openssl_type_dir}"
                if [ "${PATCH_SPEED_PQCSIGS_IN_DEFAULT_PROVIDER}" == "True" ]; then
                    if [[ "${tag}" == "openssl-3.5"* ]]; then
                        if [ "${tag}" == "openssl-3.5.0" ]; then
                            V_FOR_PATCH="_3_5_0"
                        else
                            V_FOR_PATCH=""
                        fi
                        (
                            cd "${openssl_type_dir}" && \
                            { ${GIT} apply ../../utils/speed_pqcsigs_in_default_provider"${V_FOR_PATCH}".patch || true;}  # avoid exit by set -e
                        )
                    fi
                fi
                ;;
            libressl|LibreSSL|LIBRESSL)
                tag="${tag_candidate}"
                if [[ "${tag}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    # NOTE:
                    #   "${tag}" consisting of only a version number, such as
                    #   tag=3.9.2, downloads the version from
                    #   https://ftp.openbsd.org/pub/OpenBSD/LibreSSL/
                    curl "https://ftp.openbsd.org/pub/OpenBSD/LibreSSL/libressl-${tag}.tar.gz" | tar zxv -C .
                else
                    # NOTE:
                    #   - The other "${tag}"'s, such as
                    #     'v3.9.2' (v with a version number),
                    #     'OPENBSD_7_4' ('OPENBSD_' with a version number),
                    #     'master' (or 'main') are tag/branch names of git.
                    #
                    #   - v4.1.0 requires some settings according to
                    #     https://gnu.org/s/automake/manual/automake.html#Libtool-library-used-but-LIBTOOL-is-undefined
                    #   - Both v4.0.0 and OPENBSD_7_6 cause the following error
                    #     in its ./autogen.sh
                    #     (though tag=4.0.0 (download version) or
                    #     master (at least 13a2874) work):
                    #       "Can't open perl script
                    #       "openbsd/src/lib/libcrypto/x86_64cpuid.pl":
                    #       No such file or directory"
                    git_url="https://github.com/libressl/portable.git"
                    ${GIT_CLONE} "${git_url}" -b "${tag}" --depth 1 "${openssl_type}"
                    (cd "${openssl_type_dir}" && ./autogen.sh)
                fi
                ;;
            *)
                echo "Error: unknown project_name: '${project_name}'";
                exit 1;;
        esac
        # ${GIT_CLONE} "${git_url}" -b "${tag}" --depth 1 "${openssl_type}"
    fi
    pushd "$(pwd)" || exit 2
    cd "${openssl_type_dir}" || exit 2;
        if [ -d ./apps/openssl ]; then
            # LibreSSL v3.0.0 and newer
            OPENSSL="./apps/openssl/openssl${EXE}"
        else
            OPENSSL="./apps/openssl${EXE}"
        fi
        if [ ! -e "${OPENSSL}" ]; then
            CONFIG_OPT=""
            if [ "${EXE}" == ".exe" ]; then
                # TODO: -fstack-clash-protection in CONFIG_OPT causes the following `make` error:
                #       crypto/cryptlib.c:270:1: internal compiler error: in seh_emit_stackalloc, at config/i386/winnt.c:1043
                # CONFIG_OPT="-fstack-protector-strong -fstack-clash-protection -fcf-protection"
                # CONFIG_OPT="-fstack-protector-strong -fcf-protection"
                # CONFIG_OPT=""
                # CONFIG="./Configure --cross-compile-prefix=x86_64-w64-mingw32- mingw64 ${CONFIG_OPT}"
                if [ -n "${ENABLE_FIPS+X}" ]; then
                    # CONFIG_OPT="-Wl,-rpath,$(pwd)/.local/lib64 ${CONFIG_OPT}"
                    CONFIG_OPT="--prefix=$(pwd)/.local/ ${CONFIG_OPT}"
                fi
                CONFIG="./Configure ${ENABLE_FIPS} --cross-compile-prefix=x86_64-w64-mingw32- mingw64 ${CONFIG_OPT}"
            else
                # NOTE: some compilers might ignore -fstack-clash-protection in CONFIG_OPT.
                #       Cf. hardening-check ./apps/openssl
                # CONFIG_OPT="-fstack-protector-strong -fstack-clash-protection -fcf-protection"
                # CONFIG_OPT="-DECP_NISTZ256_ASM"
                # CONFIG_OPT="-UECP_NISTZ256_ASM"
                # CONFIG_OPT="-DAESNI_ASM -DVPAES_ASM -DECP_NISTZ256_ASM -DX25519_ASM -DPOLY1305_ASM"
                # CONFIG_OPT=""
                if [ -n "${ENABLE_FIPS+X}" ]; then
                    # Configure is a wrapper of config
                    CONFIG="./Configure ${ENABLE_FIPS} ${CONFIG_OPT}"
                else
                    # NOTE:
                    #   autoconf is for https://github.com/libressl/portable.git
                    #   but still causes the above NOTE's error.
                    [ ! -e "./configure" ] && [ -s "./configure.ac" ] && autoconf
                    if [ -s ./config ] ; then
                        CONFIG="./config ${CONFIG_OPT}"
                    else
                        # for libressl-2.*.* tar.gz and newer.
                        CONFIG="./configure ${CONFIG_OPT}"
                        # NOTE:
                        #   LibreSSL at https://ftp.openbsd.org/pub/OpenBSD/LibreSSL/
                        #   2.9.1, 3.0.0 and newer (including 3.3.6):
                        #     `openssl speed aes-*-ccm`` (and OpenBSD bundled binary LibreSSL 3.3.6's aes-*-gcm)
                        #     show high throughput.
                        #   Up to 2.9.0, 2.8.3, and 2.7.5, respectively:
                        #     no aes-*-ccm
                        #   v2.5.0, v2.8.0 github on linux:
                        #       cp: cannot stat './plot-openssl-speed/tmp/libressl-v2.5.0/openbsd/src/lib/libcrypto/pem/pem2.h': No such file or directory
                        #   2.5.0 on macos?:
                        #       compat/arc4random.c:90:6: error: call to undeclared function 'getentropy'; ISO C99 and later do not support implicit function declarations [-Wimplicit-function-declaration]
                        #       if (getentropy(rnd, sizeof rnd) == -1)
                        #   2.0.0:
                        #     asn1/t_x509.c:503:15: error: variable 'l' set but not used [-Werror,-Wunused-but-set-variable]
                        #        int ret = 0, l, i;
                    fi
                fi
            fi
            ${CONFIG} || exit 2
            make || exit 2
            # post process
            if [ "${EXE}" == ".exe" ]; then
                local tmp
                mkdir -p .local/{ssl,lib64/ossl-modules}
                cp -np ./apps/openssl.cnf ./.local/ssl/.
                cp -np ./providers/fips.dll ./.local/lib64/ossl-modules/.
                cp -np ./providers/fipsmodule.cnf ./.local/ssl/.
                # if not yet, add fips-setting to openssl.cnf
                tmp=$(awk -v PWD="${PWD}" '{if (($1 ~ /^\.include$/) && ($2 == PWD"/.local/ssl/fipsmodule.cnf" )) print}' .local/ssl/openssl.cnf )
                # echo $tmp
                if [ -z "${tmp}" ]; then
                    # # .include fipsmodule.cnf
                    # .include $(pwd)/.local/ssl/fipsmodule.cnf
                    #
                    # # fips = fips_sect
                    # <contents of ../../utils/fips_setting_to_openssl_cnf.txt>
                    sed -i \
                        -e "/# .include fipsmodule.cnf/a .include ${PWD}/.local/ssl/fipsmodule.cnf" \
                        -e "/# fips = fips_sect/r ../../utils/fips_setting_to_openssl_cnf.txt" \
                        .local/ssl/openssl.cnf
                fi
            fi
        fi
        if [ "${EXE}" == ".exe" ]; then
            if [ ! -e ./libssp-0.dll ]; then
                # shellcheck disable=SC2016  # "$<number>" are not shell's variables but awk's.
                MINGW_GCC_VER=$(/usr/bin/x86_64-w64-mingw32-gcc-posix --version | awk '$1 ~ /^x86_64-w64-mingw32-gcc-posix/ {print substr($3,1,index($3,"-")-1)}')
                cp -p  "/usr/lib/gcc/x86_64-w64-mingw32/${MINGW_GCC_VER}-posix/libssp-0.dll" .
            fi
        else
            # if [[ "$(uname -s)" == "Darwin"* ]]; then
            if [ "${UNAME_S}" == "Darwin" ]; then
                # macOS
                export DYLD_LIBRARY_PATH=./"${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"
                # echo "DYLD_LIBRARY_PATH: ${DYLD_LIBRARY_PATH}"
            else
                export LD_LIBRARY_PATH=./"${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
                # echo "LD_LIBRARY_PATH: ${LD_LIBRARY_PATH}"
            fi
        fi
        # ${OPENSSL} is available after setting
        if [ -n "${ENABLE_FIPS+X}" ] && [ "${EXE}" != ".exe" ]; then
            OPENSSL="./util/wrap.pl -fips ${OPENSSL}"
        fi
        OPENSSL_VER=$(${OPENSSL} version)
    #    plot_graphs
    # popd || exit 2  # ./${TMP_DIR}
}


### opt check ###
# SPEED_OPT=""  # default: 3s for symmetric, 10s for asymmetric
ARR_SPEED_OPT=()  # default: 3s for symmetric, 10s for asymmetric
RUN_MODE="${DEFAULT_RUN_MODE}"  # default
while getopts 's:r:vh?' OPTION
do
    case $OPTION in
        s) s_arg=${OPTARG};;  # openssl speed -seconds
        r) RUN_MODE=${OPTARG};;
        h) usage; exit 0;;
        v) echo " ${COMMAND} v${VER}"; exit 0;;
        *) echo "Use '-h' option for help!"; exit 1;;
    esac
done
shift $((OPTIND - 1))

# arg check for -s option
if [ -n "${s_arg}" ]; then
    if [[ "$s_arg" =~ ^[1-9][0-9]?$ ]]; then
        # SPEED_OPT="-s ${s_arg}"
        ARR_SPEED_OPT=(-s "${s_arg}")
    else
        echo
        echo "Error: invalid '${s_arg}' for the '-s' option!"
        echo "       Use '-h' option for help!";
        echo
        exit 2
    fi
fi

# arg check for -r option
if [ "${RUN_MODE}" != "build_only" ] && \
        [ "${RUN_MODE}" != "full" ] && \
        [ "${RUN_MODE}" != "skip_symmetric" ] && \
        [ "${RUN_MODE}" != "skip_asymmetric" ]; then
    echo
    echo "Error: unknown run_mode '${RUN_MODE}' for the '-r' option!"
    echo "  'run_mode' is one of 'build_only', 'full',"
    echo "  'skip_symmetric', or 'skip_asymmetric'."
    echo
    exit 2
fi

# set openssl command(s) and then plot graphs obtained by the command(s)
# mkdir -p "${TMP_DIR}"
pushd "$(pwd)" || exit 2
cd "${TMP_DIR}/" || exit 2
    if [ "$#" == "0" ];then
        set_openssl_in_path  # enter ./${TMP_DIR}/${openssl_in_path_dir}
        plot_graphs       # still at ./${TMP_DIR}/${openssl_in_path_dir}
        popd || exit 2   # return to ./${TMP_DIR}
    else
        # multiple openssl_type's
        for openssl_type in "$@"; do
            # printenv
            unset ENABLE_FIPS OPENSSL_VER OPENSSL_VER_NOSPACE LIBOQS_VER EXE
            unset LD_LIBRARY_PATH DYLD_LIBRARY_PATH
            # unset variables set by set_with_oqsprovider
            unset OPENSSL_CONF OPENSSL_MODULES OPENSSL_APP
            PATH="${PATH#/home/"${USER}"/.local/bin:}"
            # echo "${PATH}"
            # printenv
            # set openssl command
            if [ "${openssl_type}" == "openssl" ]; then
                set_openssl_in_path
            else
                # git clone
                check_path "${ALLOWED_DIR}" "${openssl_type}"
                # ${TAG_FIPS} or not
                # NOTE: lower case works in bash 4.4.20 and newer
                # if [[ "${openssl_type,,}" == "${TAG_FIPS,,}"* ]]; then
                if [[ "${openssl_type}" == "${TAG_FIPS}"* ]]; then
                    # if [[ "${openssl_type,,}" == *"oqsprovider"* ]] || [[ "${openssl_type,,}" == *"libressl"* ]]; then
                    if [[ "${openssl_type}" == *"oqsprovider"* ]] || [[ "${openssl_type}" == *"libressl"* ]]; then
                        echo
                        echo "Error: remove '${openssl_type: 0: ${#TAG_FIPS}}' from '${openssl_type}'!"
                        echo "  'enable-fips' is not either tested or supported."
                        echo
                        exit 2
                    fi
                    ENABLE_FIPS="enable-fips"
                fi
                if [[ "${openssl_type}" == *"oqsprovider"* ]]; then
                    # NOTE: lower case works in bash 4.4.20 and newer
                    # if [[ "${openssl_type,,}" == *"${TAG_MINGW,,}" ]]; then
                    if [[ "${openssl_type}" == *"${TAG_MINGW}" ]]; then
                        echo
                        echo "Error: remove '${openssl_type: -${#TAG_MINGW}}' from '${openssl_type}'!"
                        echo "  'oqsprovider' for MinGW is not tested or supported."
                        echo
                        exit 2
                        # echo "       Skipped this openssl_type!"
                        # continue
                    fi
                    # build_liboqs
                    set_with_oqsprovider
                else
                    set_openssl_tagged
                fi
            fi
            # entering ./${TMP_DIR}/<command-depend dir>
            plot_graphs     # still at ./${TMP_DIR}/<command-depend dir>
            popd || exit 2  # return to ./${TMP_DIR}
        done
    fi
popd || exit 2  # ./
echo

echo "========================="
echo "All the results are in:"
if [ "$#" == "0" ];then
    echo "  ${TMP_DIR}/${openssl_in_path_dir}/${GRA_DIR}/"
else
    for openssl_type in "$@"; do
        if [ "$openssl_type" == "openssl" ]; then
            openssl_type="${openssl_in_path_dir}"
        fi
        echo "  ${TMP_DIR}/${openssl_type}/${GRA_DIR}/"
    done
fi
echo
