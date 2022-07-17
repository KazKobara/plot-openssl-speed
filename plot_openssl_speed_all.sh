#!/usr/bin/env bash
# Wrapper of ${PLOT_SCRIPT}
# This file is part of https://github.com/KazKobara/plot_openssl_speed
#set -e

VER=0.0.0
COMMAND=$(basename "$0")
TMP_DIR="./tmp"
GRA_DIR="graphs"
# PLOT_SCRIPT's PATH is from ${TMP_DIR}/${openssl_dir}/
PLOT_SCRIPT="../../plot_openssl_speed.sh"
# PLOT_FIT_SCRIPT's PATH is from ${TMP_DIR}/${openssl_dir}/${GRA_DIR}/
PLOT_FIT_SCRIPT="../../../plot_fit.sh"
GIT_CLONE="git clone"
# GIT_CLONE="gh repo clone"
TAG_MINGW="-mingw"

### functions ###
usage () {
    echo " Wrapper of $(basename "${PLOT_SCRIPT}") v${VER}"
    echo
    echo " Usage:"
    echo "   Edit 'crypt-algorithms' in this script. Then"
    echo
    echo "   \$ ./${COMMAND} [options] [openssl_tag[${TAG_MINGW}]"
    echo "                                       ... [openssl_tag[${TAG_MINGW}]]]"
    echo
    echo "   where "
    echo "     - 'openssl_tag' is a tag,"
    echo "       such as 'openssl-3.0.5' or 'OpenSSL_1_1_1p',"
    echo "       named in https://github.com/openssl/openssl ,"
    echo "       or simply 'openssl' to use the command in the PATH"
    echo "       (default: openssl)." 
    echo "     - append '${TAG_MINGW}' to 'openssl_tag' (except 'openssl')"
    echo "       to cross-compile it for 64bit MinGW with"
    echo "       gcc on Linux (Debian/Ubuntu) and run it on WSL."
    echo
    echo "   options:"
    echo "     [-s seconds] Seconds [1-99] to measure the speed."
    echo "                  Set '1' to speed up for debug."
    echo "     [-(h|?)]     Show this usage"
    echo
}

##
# @brief        Save measurement results of specified crypt-algorithms
# @details      Save graphs in the specified *.png files and their data file
#               in *.dat files of the same name.
plot_graphs () {
    # depends on $tag
    # PATH from ${TMP_DIR}/${openssl_dir}/
    PLOT_SCRIPT_FOR_FILE="${PLOT_SCRIPT}"
    PLOT_SCRIPT="${PLOT_SCRIPT} -p ${OPENSSL} ${SPEED_OPT}"
    OPENSSL_VER_SHORT="$(echo "${OPENSSL_VER}" | awk '{print $1,$2}')"
    echo "OPENSSL_VER_SHORT: ${OPENSSL_VER_SHORT}"
    mkdir -p ${GRA_DIR}
    ${OPENSSL} version -a > ${GRA_DIR}/openssl_ver_a.log
    ####################################################################
    ##### Edit crypt-algorithms (and output graph file name) below #####
    ### Asymmetric-key algorithms:
    ###   - Digital signatures:
    ###     - All the supported algorithms:
    ${PLOT_SCRIPT} -o "./${GRA_DIR}/rsa.png" rsa
    ${PLOT_SCRIPT} -o "./${GRA_DIR}/dsa.png" ecdsa eddsa dsa
    ###     - Around 128-bit security:
    if [ -e "./${GRA_DIR}/rsa.dat" ] && [ -e "./${GRA_DIR}/dsa.dat" ]; then
        # pick up the above algorithms from sig.dat
        # rsa3072 rsa4096 EdDSA(Ed25519) ecdsa(nistp256) ecdsa(nistk283) ecdsa(nistb283) ecdsa(brainpoolP256r1) ecdsa(brainpoolP256t1) 
        rm -rf "./${GRA_DIR}/sig256.dat"
        awk '/^rsa[34]0.*/' "./${GRA_DIR}/rsa.dat" >> "./${GRA_DIR}/sig256.dat"
        awk '/^(EdDSA\(Ed255|ecdsa\((nist[pkb]|brainpoolP)2[5-8]|dsa[34]0).*/' "./${GRA_DIR}/dsa.dat" >> "./${GRA_DIR}/sig256.dat"
        ${PLOT_SCRIPT_FOR_FILE} -o "./${GRA_DIR}/sig256.png" -t "with ${OPENSSL_VER_SHORT}"
        # TODO: Add the case that either rsa.dat or dsa.dat exists.
    else
        ${PLOT_SCRIPT} -o "./${GRA_DIR}/sig256.png" rsa3072 rsa4096 ed25519 ecdsap256 ecdsak283 ecdsab283 ecdsabrp256r1 ecdsabrp256t1
    fi
    ###   - Diffie-Hellman key exchange:
    ###     - All the supported:
    if [[ "${OPENSSL_VER}" == "OpenSSL 1."* ]]; then
        ${PLOT_SCRIPT} -o "./${GRA_DIR}/dh.png" ecdh
    elif [[ "${OPENSSL_VER}" == "OpenSSL 3."* ]]; then
        ${PLOT_SCRIPT} -o "./${GRA_DIR}/dh.png" ecdh ffdh
    fi
:<<'COMMENT'
    #### Comment out since it seems obvious from dh.png
    ###     - Around 128-bit security:
    if [ ! -e "./${GRA_DIR}/dh.dat" ]; then
        if [[ "${OPENSSL_VER}" == "OpenSSL 1."* ]]; then
            ${PLOT_SCRIPT} -o "./${GRA_DIR}/dh256.png" ecdhp256 ecdhk283 ecdhb283 ecdhbrp256r1 ecdhbrp256t1 ecdhx25519
        elif [[ "${OPENSSL_VER}" == "OpenSSL 3."* ]]; then
            ${PLOT_SCRIPT} -o "./${GRA_DIR}/dh256.png" ecdhp256 ecdhk283 ecdhb283 ecdhbrp256r1 ecdhbrp256t1 ecdhx25519 ffdh3072 ffdh4096
        fi
    else
        # pick up the above algorithms from dh.dat
        # ecdh(nistp256) ecdh(nistk283) ecdh(nistb283) ecdh(brainpoolP256r1) ecdh(brainpoolP256t1) ecdh(X25519) ffdh3072 ffdh4096
        awk '/^(ecdh\((X|nist[pkb]|brainpoolP)2[5-8]|ffdh[34]0).*/' "./${GRA_DIR}/dh.dat" > "./${GRA_DIR}/dh256.dat"
        ${PLOT_SCRIPT_FOR_FILE} -o "./${GRA_DIR}/dh256.png" -t "with ${OPENSSL_VER_SHORT}"
    fi
COMMENT
    ###   - Examples of proportional for ecdh
    if [ ! -e "./${GRA_DIR}/dh.dat" ]; then
        ${PLOT_SCRIPT} -o "./${GRA_DIR}/ecdh_b.png" ecdhb163 ecdhb233 ecdhb283 ecdhb409 ecdhb571
        ${PLOT_SCRIPT} -o "./${GRA_DIR}/ecdh_brp_r1.png" ecdhbrp256r1 ecdhbrp384r1 ecdhbrp512r1
        # ${PLOT_SCRIPT} -o "./${GRA_DIR}/ecdh_p.png" ecdhp160 ecdhp192 ecdhp224 ecdhp256 ecdhp384 ecdhp521
        # ${PLOT_SCRIPT} -o "./${GRA_DIR}/ecdsa_p.png" ecdsap160 ecdsap192 ecdsap224 ecdsap256 ecdsap384 ecdsap521
        ${PLOT_SCRIPT} -o "./${GRA_DIR}/ecdh_p.png" ecdhp192 ecdhp224 ecdhp256 ecdhp384 ecdhp521
        ${PLOT_SCRIPT} -o "./${GRA_DIR}/ecdsa_p.png" ecdsap192 ecdsap224 ecdsap256 ecdsap384 ecdsap521
    else
        # pick up the above algorithms from dh.dat
        # ecdh(nistp256) ecdh(nistk283) ecdh(nistb283) ecdh(brainpoolP256r1) ecdh(brainpoolP256t1) ecdh(X25519) ffdh3072 ffdh4096
        awk '/^ecdh\(nistb.*/' "./${GRA_DIR}/dh.dat" > "./${GRA_DIR}/ecdh_b.dat"
        ${PLOT_SCRIPT_FOR_FILE} -o "./${GRA_DIR}/ecdh_b.png" -t "with ${OPENSSL_VER_SHORT}"
        awk '/^ecdh\(brainpoolP[1-9][0-9]*r1\)/' "./${GRA_DIR}/dh.dat" > "./${GRA_DIR}/ecdh_brp_r1.dat"
        ${PLOT_SCRIPT_FOR_FILE} -o "./${GRA_DIR}/ecdh_brp_r1.png" -t "with ${OPENSSL_VER_SHORT}"
        awk '/^ecdh\(nistp[1-9][0-9]*\)/' "./${GRA_DIR}/dh.dat" > "./${GRA_DIR}/ecdh_p.dat"
        ${PLOT_SCRIPT_FOR_FILE} -o "./${GRA_DIR}/ecdh_p.png" -t "with ${OPENSSL_VER_SHORT}"
        awk '/^ecdsa\(nistp[1-9][0-9]*\)/' "./${GRA_DIR}/dsa.dat" > "./${GRA_DIR}/ecdsa_p.dat"
        ${PLOT_SCRIPT_FOR_FILE} -o "./${GRA_DIR}/ecdsa_p.png" -t "with ${OPENSSL_VER_SHORT}"
    fi
    (cd ${GRA_DIR} && ${PLOT_FIT_SCRIPT})
    ### Symmetric or no key algorithms where *-no-evp means with old low-level API:"
    ###   - Ciphters with around 128/256-bit security:"
    ${PLOT_SCRIPT} -o "./${GRA_DIR}/cipher128-256.png" aes-128-ctr aes-128-gcm aes-128-ccm chacha20-poly1305 aes-256-ctr aes-256-gcm aes-256-ccm
    ${PLOT_SCRIPT} -o "./${GRA_DIR}/aes128-cbc.png" aes-128-cbc aes-128-cbc-no-evp
    ###   - Hash functions with 112-bit or more security:
    ${PLOT_SCRIPT} -o "./${GRA_DIR}/hash.png" sha512-224 sha512-256 sha384 sha512-no-evp sha512 sha224 sha256-no-evp sha256 sha3-224 sha3-256 sha3-384 sha3-512
    ###   - HMAC:
    if [[ "${OPENSSL_VER}" == "OpenSSL 1."* ]]; then
        ${PLOT_SCRIPT} -o "./${GRA_DIR}/hmac.png" hmac-no-evp
    elif [[ "${OPENSSL_VER}" == "OpenSSL 3."* ]]; then
        ${PLOT_SCRIPT} -o "./${GRA_DIR}/hmac.png" hmac-no-evp hmac-md5 hmac-sha1 hmac-sha224 hmac-sha256 hmac-sha512-256 hmac-sha384 hmac-sha512 hmac-sha3-224 hmac-sha3-256 hmac-sha3-384 hmac-sha3-512
    fi
    ####################################################################
}


# @param[out]    openssl_in_path_dir
plot_openssl_in_path () {
    # default openssl in PATH
    openssl_in_path_dir="default_openssl_$(openssl version | awk '{print $2}')"
    mkdir -p "${openssl_in_path_dir}"
    pushd "$(pwd)" || exit 2
    cd "${openssl_in_path_dir}" || exit 2;
        echo
        echo "--- ${openssl_in_path_dir} ---"
        OPENSSL="openssl"
        OPENSSL_VER=$(${OPENSSL} version)
        plot_graphs
    popd || exit 2  # ./${TMP_DIR}
}

plot_openssl_tagged () {
    echo
    echo "--- ${openssl_dir} ---"
    # whether "*${TAG_MINGW}" or not
    if [ "${openssl_dir: -${#TAG_MINGW}}" == "${TAG_MINGW}" ]; then
        tag=${openssl_dir%${TAG_MINGW}}
        EXE=".exe"
        # TODO: -fstack-clash-protection in CONFIG_OPT causes the following `make` error:
        #       crypto/cryptlib.c:270:1: internal compiler error: in seh_emit_stackalloc, at config/i386/winnt.c:1043
        # CONFIG_OPT="-fstack-protector-strong -fstack-clash-protection -fcf-protection"
        CONFIG_OPT="-fstack-protector-strong -fcf-protection"
        CONFIG="./Configure --cross-compile-prefix=x86_64-w64-mingw32- mingw64 ${CONFIG_OPT}"
        # shellcheck disable=SC2016  # $num are not shell's variables but awk's.
        MINGW_GCC_VER=$(/usr/bin/x86_64-w64-mingw32-gcc-posix --version | awk '/x86_64-w64-mingw32-gcc-posix/ {print substr($3,1,index($3,"-")-1)}')
    else
        tag=${openssl_dir}
        # NOTE: -fstack-clash-protection in CONFIG_OPT seems to be ignored.
        #       Cf. hardening-check ./apps/openssl
        CONFIG_OPT="-fstack-protector-strong -fstack-clash-protection -fcf-protection"
        CONFIG="./config ${CONFIG_OPT}"
        if [[ "$(uname -s)" =~ Darwin.* ]]; then
            # macOS
            EXPORT_LIB="export DYLD_LIBRARY_PATH=./${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"
        else
            EXPORT_LIB="export LD_LIBRARY_PATH=./${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
        fi
    fi
    if [ -d "${openssl_dir}" ]; then
        echo
        echo "Notice: ${openssl_dir} dir already exists."
        echo "        Move/remove it to renew the contents."
        echo         
    else
        ${GIT_CLONE} https://github.com/openssl/openssl.git -b "${tag}" --depth 1 "${openssl_dir}"
    fi
    pushd "$(pwd)" || exit 2
    cd "${openssl_dir}" || exit 2;
        if [ "${EXE}" == ".exe" ]; then
            if [ ! -e ./libssp-0.dll ]; then
                cp -p  "/usr/lib/gcc/x86_64-w64-mingw32/${MINGW_GCC_VER}-posix/libssp-0.dll" .
            fi
        else
            ${EXPORT_LIB}
        fi
        OPENSSL="./apps/openssl${EXE}"
        if [ ! -e "${OPENSSL}" ]; then
            ${CONFIG} || exit 2
            make || exit 2
        fi
        OPENSSL_VER=$(${OPENSSL} version)
        plot_graphs
    popd || exit 2  # ./${TMP_DIR}
}

### opt check ###
SPEED_OPT=""  # default: 3s for symmetric, 10s for asymmetric
while getopts 's:h?' OPTION
do
    case $OPTION in
        s) s_arg=${OPTARG};;  # openssl speed -seconds
        h|?|*) usage; exit 2;;
    esac
done
shift $((OPTIND - 1))

# arg check for -s option
if [ "$s_arg" != "" ]; then
    if [[ "$s_arg" =~ ^[1-9][0-9]?$ ]]; then
        SPEED_OPT="-s ${s_arg}"
    else
        "Error: invalid '${s_arg}' for -s option!"
        usage; exit 2
    fi
fi

mkdir -p "${TMP_DIR}"
pushd "$(pwd)" || exit 2
cd "${TMP_DIR}/" || exit 2
    if [ "$#" == "0" ];then
        plot_openssl_in_path
    else
        # git clone
        for openssl_dir in "$@"; do
            if [ "${openssl_dir}" == "openssl" ]; then
                # dir name is 'default_openssl_ver'
                plot_openssl_in_path
            else
                plot_openssl_tagged
            fi
        done
    fi
popd || exit 2  # ./
echo

echo "Results are in:"
if [ "$#" == "0" ];then
    echo "  ${TMP_DIR}/${openssl_in_path_dir}/${GRA_DIR}/"
else
    for openssl_dir in "$@"; do
        if [ "$openssl_dir" == "openssl" ]; then
            openssl_dir="${openssl_in_path_dir}"
        fi
        echo "  ${TMP_DIR}/${openssl_dir}/${GRA_DIR}/"
    done
fi