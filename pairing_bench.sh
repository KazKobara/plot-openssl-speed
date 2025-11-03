#!/usr/bin/env bash
# This file is part of https://github.com/KazKobara/plot_openssl_speed
# Copyright (C) 2025 National Institute of Advanced Industrial Science and Technology (AIST). All Rights Reserved.
set -e
# set -x

ARCH=$(uname -m)

TMP_DIR="./tmp"
# PAIRING_DIR="${TMP_DIR}/Pairing"                 # relative path
PAIRING_DIR="$(readlink -f "${TMP_DIR}/Pairing")"  # absolute path

GIT="git"
# GIT="gh repo"
GIT_CLONE="${GIT} clone"
COMMAND=$(basename "$0")
DIR_OF_COMMAND="$(dirname "$(readlink -f "$0")")"

show_version () {
    echo " ${COMMAND} with (data-plot mode of)$("${DIR_OF_COMMAND}"/plot_openssl_speed.sh -v)";
}


usage () {
    show_version
    echo
    echo " Usage:"
    echo
    echo "   \$ ./${COMMAND} [options] [<REPO>:<TAG> [<REPO>:<TAG> [<REPO>:<TAG> ...]]]"
    echo
    echo "   where"
    echo "     <REPO> is either 'relic' 'miracle' 'mcl' corresponding with"
    echo "     the following repositories, respectively:"
    echo "       https://github.com/relic-toolkit/relic"
    echo "       https://github.com/miracl/core"
    echo "       https://github.com/herumi/mcl/"
    echo "     <TAG> is a tag/branch name of the <REPO>."
    echo
    echo "   options:"
    echo "     [-t TIME_OR_TSC]"
    echo "         TIME_OR_TSC is either 'time' for real time [msec] or"
    echo "         'tsc' for CPU Time Stamp Counter [cycles] (default: 'time')."
    echo "     [-v]"
    echo "         Show version."
    echo "     [-h]"
    echo "         Show this usage."
    echo
    echo " Example:"
    echo "   ./${COMMAND} mcl:v3.04 relic:0.7.0 miracle:v4.1"
    echo
}


##
# @brief        Set header to a file
# @param[in]    $1: string of SPEED_UNIT, such as "msec" or "cycles"
# @param[in]    $2: file name to write this header
# @param[out]   header to $2
set_header () {
    # printf "%20s %15s %15s %15s\n",$1,$2,$3,$4
    {
        echo "#                                      $1"
        echo "#              curve            loop            fexp         pairing"
    } > "$2"
}


##
# @brief        Measure pairing speed of Relic
# @details      See also
#               https://github.com/relic-toolkit/relic/issues/77
# @param[in]    $1: tag or branch name (default: main)
# @param[in]    global TIME_OR_TSC: 'time' or 'tsc'
# @param[in]    global PAIRING_DIR: dir for results (*.{log,dat,png})
# @param[out]   global RELIC_DAT: data file name
measure_relic () {
    local relic_timer timer_div
    case "${TIME_OR_TSC}" in
        "tsc") relic_timer=CYCLE; timer_div="1";;
        "time") relic_timer=HREAL; timer_div="1000000";;  # msec/nanosec
        *) echo "Error: unknown TIME_OR_TSC: '${TIME_OR_TSC}'!"; exit 1
    esac
    local tag source_dir
    local bench=bench_pp
    tag="$1"
    if [ -z "${tag}" ]; then
        tag=main
    fi
    RELIC_DAT="${PAIRING_DIR}/relic${tag}_${TIME_OR_TSC}.dat"
    rm -f "${RELIC_DAT}"  # header shall be added after sort
    mkdir -p Relic
    (
    cd Relic || exit 1
    source_dir=relic-"${tag}"
    if [ -d "${source_dir}" ]; then
        echo
        echo "Notice: '${source_dir}' dir already exists."
        echo "  Move or remove it to renew the contents."
    else
        ${GIT_CLONE} https://github.com/relic-toolkit/relic.git -b "${tag}" --depth 1 "${source_dir}"
    fi
    cd "${source_dir}" || exit 1
    if [ "${ARCH}" == x86_64 ]; then
        PRESET_LIST="$(cd preset && ls -1 x64-pbc-*.sh)"
        # as of 0.7.0
        # minimal list:
        # PRESET_LIST="x64-pbc-bn382.sh x64-pbc-bls12-381.sh x64-pbc-bls24-509.sh x64-pbc-bls48-575.sh"
        # full list:
        # PRESET_LIST="x64-pbc-afg16-510.sh x64-pbc-afg16-766.sh x64-pbc-bls12-377.sh x64-pbc-bls12-381.sh x64-pbc-bls12-446.sh x64-pbc-bls12-455.sh x64-pbc-bls12-638.sh x64-pbc-bls24-315.sh x64-pbc-bls24-317.sh x64-pbc-bls24-509.sh x64-pbc-bls48-575.sh x64-pbc-bn254.sh x64-pbc-bn382.sh x64-pbc-bn446.sh x64-pbc-fm16-765.sh x64-pbc-fm18-768.sh x64-pbc-kss16-330.sh x64-pbc-kss16-766.sh x64-pbc-kss18-354.sh x64-pbc-kss18-638.sh"
    else
        echo
        echo "Error: '${ARCH}' is not supported!"
        echo "       Edit ${source_dir}/preset/*.sh and this script."
        echo
        exit 2
    fi
    for i in ${PRESET_LIST}; do
        log="${PAIRING_DIR}/relic${tag}_${i%.sh}_${TIME_OR_TSC}.log"
        RELIC_TARGET_DIR=relic-target-"${i%.sh}-${relic_timer}"
        # ./preset/x64-pbc-bn254.sh "-B ./relic-target-x64-pbc-bn254"
        # (cd relic-target-x64-pbc-bn254 && make && ./bin/"${bench}")
        if [ -d "./${RELIC_TARGET_DIR}" ]; then
            echo
            echo "Notice: './${RELIC_TARGET_DIR}' already exists."
            echo "  Move or remove it to renew it."
        else
            # cf. CMakeLists.txt
            #   WITH=PP only does not work
            #   TIMER=HREAL   GNU/Linux realtime high-resolution timer.
            ./preset/"$i" "-DTIMER=${relic_timer} -B ./${RELIC_TARGET_DIR}"
        fi
        cd "${RELIC_TARGET_DIR}"
        if [ -x "./bin/${bench}" ]; then
            echo
            echo "Notice: './${RELIC_TARGET_DIR}/bin/${bench}' already exists."
            echo "  Move or remove it to renew it."
        else
            make
        fi
        if [ -s "${log}" ]; then
            echo
            echo "Notice: '${log}' already exists."
            echo "  Move or remove it to renew it."
        else
            ./bin/"${bench}" > >(tee "${log}") 2>&1 || { echo "Warning: skipped '${RELIC_TARGET_DIR}'"; cd ..; continue; }
        fi
        # extract necessary data
:<<'# COMMENT_EOF'
        cat relic-target-x64-pbc-bls48-575-HREAL/bench_pp_HREAL.log
        -- Curve B48-P575:

        ** Arithmetic:

        BENCH: pp_add_k48                       = 52635 nanosec
        BENCH: pp_add_k48_basic                 = 42425 nanosec
        BENCH: pp_add_k48_projc                 = 47495 nanosec
        BENCH: pp_dbl_k48                       = 30746 nanosec
        BENCH: pp_dbl_k48_basic                 = 42253 nanosec
        BENCH: pp_dbl_k48_projc                 = 28765 nanosec
        BENCH: pp_exp_k48                       = 21289271 nanosec
        BENCH: pp_map_k48                       = 26181995 nanosec
        BENCH: pp_map_sim_k48 (2)               = 27778707 nanosec
# COMMENT_EOF
        # pp_map only
        #            B48-P575          26.182
        # awk -v TIMER_DIV="${timer_div}" '{if($1 == "--" && $2 == "Curve") printf "%20s ", substr($3,0,length($3)-1)} \
        #    {if($1 == "BENCH:" && $2 ~ /pp_map_.[1-9][0-9]/) printf "%15s\n",$4 / TIMER_DIV}' "${log}" >> ../"${RELIC_DAT}"
        # map and map_sim
        # loop and fexp where fexp = 2*pp_map - pp_map_sim(2) and loop = pp_map - fexp
        if [ "$i" == "x64-pbc-kss16-766.sh" ]; then
            # NOTE:
            #  grep AFG16-P766 relic-target-x64-pbc-*-HREAL/*.log
            #  relic-target-x64-pbc-afg16-766-HREAL/bench_pp_HREAL.log:-- Curve AFG16-P766:
            #  relic-target-x64-pbc-kss16-766-HREAL/bench_pp_HREAL.log:-- Curve AFG16-P766:
            awk -v TIMER_DIV="${timer_div}" '\
                {if($1 == "--" && $2 == "Curve") printf "%20s ","KSS16-766"} \
                {if($1 == "BENCH:" && $2 ~ /pp_map_.[1-9][0-9]/) map = $4 / TIMER_DIV} \
                {if($1 == "BENCH:" && $2 ~ /pp_map_sim_.[1-9][0-9]/ && $3 == "(2)") {\
                    map_sim = $5 / TIMER_DIV; fexp = 2 * map - map_sim; loop = map - fexp; \
                    printf "%15s %15s %15s\n",loop, fexp, map}} \
                ' "${log}" >> "${RELIC_DAT}"
        else
            awk -v TIMER_DIV="${timer_div}" '\
                {if($1 == "--" && $2 == "Curve") printf "%20s ", substr($3,0,length($3)-1)} \
                {if($1 == "BENCH:" && $2 ~ /pp_map_.[1-9][0-9]/) map = $4 / TIMER_DIV} \
                {if($1 == "BENCH:" && $2 ~ /pp_map_sim_.[1-9][0-9]/ && $3 == "(2)") {\
                    map_sim = $5 / TIMER_DIV; fexp = 2 * map - map_sim; loop = map - fexp; \
                    printf "%15s %15s %15s\n",loop, fexp, map}} \
                ' "${log}" >> "${RELIC_DAT}"
        fi
        cd ..
    done
    sort -k 4,4 -n -u "${RELIC_DAT}" -o "${RELIC_DAT}.tmp"
    set_header "${SPEED_UNIT}" "${RELIC_DAT}"
    cat "${RELIC_DAT}.tmp" >> "${RELIC_DAT}"
    rm "${RELIC_DAT}.tmp"
    # Relic all
    # ../../../../plot_openssl_speed.sh -l pairing -u "${SPEED_UNIT}" -d ./"${RELIC_DAT}"
    )
    # NOTE:
    #   To add TAG (version) after algorithm names,
    #   use '-v TAG_RELIC="${tag}"' below
    #   though this may result in overlap in name positions in the figures.
    # 128 bit security
    awk -v TAG_RELIC="" '$1 ~ /(BN-P382|B12-P381)/ \
        {$1=$1"@Relic"TAG_RELIC; printf "%20s %15s %15s %15s\n",$1,$2,$3,$4}' \
        "${RELIC_DAT}" >> "${PAIRING_DAT_128}"
    TMP_NAME_128="${TMP_NAME_128}_relic${tag}"
    # 192 bit security
    awk -v TAG_RELIC="" '$1 == "B24-P509" \
        {$1=$1"@Relic"TAG_RELIC; printf "%20s %15s %15s %15s\n",$1,$2,$3,$4}' \
        "${RELIC_DAT}" >> "${PAIRING_DAT_192}"
    TMP_NAME_192="${TMP_NAME_192}_relic${tag}"
    # 256 bit security
    awk -v TAG_RELIC="" '$1 == "B48-P575" \
        {$1=$1"@Relic"TAG_RELIC; printf "%20s %15s %15s %15s\n",$1,$2,$3,$4}' \
        "${RELIC_DAT}" >> "${PAIRING_DAT_256}"
    TMP_NAME_256="${TMP_NAME_256}_relic${tag}"
}


##
# @brief        Amend benchtest source code
# @details      Leave only pairing and add cycles measurement
#               from benchtest_all.cpp (at least at v4.1)
# @param[in]    global TIME_OR_TSC: 'time' or 'tsc'
# @param[in]    $1: name of source file to amend
# @param[out]   $2: name of amended file
amend_miracle_benchtest () {
    # comment out non-pairing and below-128-bit security algorithms,
    #   such as bn254, ed25519, nist256,
    #   goldilocks (Ed448-Goldilocks), and rsa2048
    sed -e 's/bn254(&/\/\/ bn254(&/' \
        -e 's/ed25519(&/\/\/ ed25519(&/' \
        -e 's/nist256(&/\/\/ nist256(&/' \
        -e 's/goldilocks(&/\/\/ goldilocks(&/' \
        -e 's/rsa2048(&/\/\/ rsa2048(&/' \
        "$1" > "$2"
    # TODO:
    #   comment out non-paring arithmetics,
    #   such as point additions and scalar multiplications,
    #   and then add the following "E*_*(&*);".
:<<'# COMMENT_EOF'
    printf(" %8.2lf ms per iteration\n", elapsed);

    // add
    ECP_generator(&P);
    ECP2_generator(&W);
    FP2_rand(&rz2,RNG);
    ECP2_map2point(&Q,&rz2);
    ECP2_cfp(&Q);

    iterations = 0;
    start = clock();
# COMMENT_EOF
    if [ "${TIME_OR_TSC}" == "tsc" ]; then
        # amend $1 as follows:
        # - insert rdtscp function
        # - append rdtscp start
        # - read rdtscp end
        sed -i \
            -e '/using namespace core;/i #include "..\/..\/..\/..\/..\/utils\/rdtscp_func.cpp"' \
            -e '/iterations = 0;/i \\tdo {' \
            -e '/start = clock();/a \\tstart_tsc = rdtscp(&start_proc_id);' \
            -e '/} while (elapsed/r ../../../../../utils/rdtscp_miracle_end.cpp' \
            "$2"
    fi
}


##
# @brief        Convert log to dat for Miracle
# @param[in]    global TIME_OR_TSC: 'time' or 'tsc'
# @param[in]    $1: name of log file
# @param[out]   $2: name of dat file
miracle_log_to_dat () {
    if [ "${TIME_OR_TSC}" == "tsc" ]; then
        set_header "cycles" "$2"
:<<'# COMMENT_EOF'
        Testing/Timing BLS24479 Pairings
                proc_id: 1:0 tsc_diff= 643124 tsc_diff/elapsed= 1.61 [GHz]
                proc_id: 0:1 tsc_diff= 624687 tsc_diff/elapsed= 1.61 [GHz]
                proc_id: 1:1 tsc_diff= 629170 tsc_diff/elapsed= 1.61 [GHz]
        G1 mul              -    25558 iterations       0.39 ms per iteration
                proc_id: 1:0 tsc_diff= 3901497 tsc_diff/elapsed= 1.61 [GHz]
                proc_id: 0:0 tsc_diff= 3854514 tsc_diff/elapsed= 1.61 [GHz]
        G2 mul              -     4172 iterations       2.40 ms per iteration
                proc_id: 0:11 tsc_diff= 6301177 tsc_diff/elapsed= 1.61 [GHz]
                proc_id: 11:11 tsc_diff= 6192210 tsc_diff/elapsed= 1.61 [GHz]
        GT pow              -     2597 iterations       3.85 ms per iteration
                proc_id: 11:11 tsc_diff= 4199502 tsc_diff/elapsed= 1.61 [GHz]
        PAIRing ATE         -     3830 iterations       2.61 ms per iteration
                proc_id: 11:11 tsc_diff= 9865569 tsc_diff/elapsed= 1.61 [GHz]
        PAIRing FEXP        -     1631 iterations       6.14 ms per iteration
# COMMENT_EOF
        # BLS12383     1291998     1888524     3180522
        # BLS24479     4199502     9865569    14065071
        # BLS48556    10743268    47685814    58429082
        awk '($1 == "Testing/Timing" && $3 == "Pairings"),($1 == "PAIRing" && $2 == "FEXP") {\
                {if($1 == "Testing/Timing" && $3 == "Pairings") curve=$2} \
                {if($1 == "proc_id:") prev4=$4} \
                {if($1 == "PAIRing" && $2 == "ATE") loop=prev4} \
                {if($1 == "PAIRing" && $2 == "FEXP") \
                    {printf "%20s %15s %15s %15s\n",curve,loop,prev4,loop + prev4}} \
            }' "$1" >> "$2"
    else
        # "${TIME_OR_TSC}" == "time"
        set_header "msec" "$2"
:<<'# COMMENT_EOF'
        Testing/Timing BLS48556 Pairings
        G1 mul              -    15414 iterations       0.65 ms per iteration
        G2 mul              -      784 iterations      12.76 ms per iteration
        GT pow              -      515 iterations      19.45 ms per iteration
        PAIRing ATE         -     1376 iterations       7.27 ms per iteration
        PAIRing FEXP        -      297 iterations      33.70 ms per iteration

        Testing/Timing 2048-bit RSA
        Generating 2048-bit RSA public/private key pair
        RSA gen -       43 iterations     234.40 ms per iteration
        RSA enc -    30442 iterations       0.33 ms per iteration
        RSA dec -     5342 iterations       1.87 ms per iteration
# COMMENT_EOF
        # 2 columns
        # BLS48556_ATE        7.27
        # BLS48556_FEXP      33.70
        # awk '($1 == "Testing/Timing" && $3 == "Pairings"),($1 == "PAIRing" && $2 == "FEXP")\
        #   {if($1 == "Testing/Timing" && $3 == "Pairings") curve=$2} \
        #   {if($1 == "PAIRing") printf "%10s_%-4s %11s\n",curve,$2,$6}' "${log}" >> "${MIRACLE_DAT}"
        # ../../../../../plot_openssl_speed.sh -l op_cycles -d "${MIRACLE_DAT}"
        awk '($1 == "Testing/Timing" && $3 == "Pairings"),($1 == "PAIRing" && $2 == "FEXP") \
            {{if($1 == "Testing/Timing" && $3 == "Pairings") curve=$2} \
            {if($1 == "PAIRing" && $2 == "ATE") loop=$6} \
            {if($1 == "PAIRing" && $2 == "FEXP") printf "%20s %15s %15s %15s\n",curve,loop,$6,loop + $6}}' "$1" >> "$2"
        #    {if($1 == "PAIRing" && $2 == "FEXP") printf "%10s %11s %11s %11s\n",curve,loop,$6,loop + $6}}' "${log}" >> "${MIRACLE_DAT}"
        # Miracle all
        # ../../../../../plot_openssl_speed.sh -l pairing -u "${SPEED_UNIT}" -d "${MIRACLE_DAT}"
    fi
}


##
# @brief        Measure pairing speed of Miracle core
# @details      For https://github.com/miracl/core/tree/master/cpp
# @param[in]    $1: tag or branch name (default: master)
# @param[in]    global TIME_OR_TSC: 'time' or 'tsc'
# @param[in]    global PAIRING_DIR: dir for results (*.{log,dat,png})
# @param[out]   global MIRACLE_DAT: data file name
measure_miracle () {
    local tag source_dir
    local bench_org=benchtest_all
    if [ "${TIME_OR_TSC}" == "tsc" ]; then
        local bench=benchtest_pairing_w_tsc
    else
        local bench=benchtest_pairing
    fi
    local tag="$1"
    if [ -z "${tag}" ]; then
        tag=master
    fi
    local log="${PAIRING_DIR}/miracle${tag}_${TIME_OR_TSC}.log"
    MIRACLE_DAT=${log%.log}.dat
    mkdir -p Miracle_core
    (
    cd Miracle_core || exit 1
    source_dir=miracle-"${tag}"
    if [ -d "${source_dir}" ]; then
        echo
        echo "Notice: '${source_dir}' dir already exists."
        echo "  Move or remove it to renew the contents."
    else
        ${GIT_CLONE} https://github.com/miracl/core -b "${tag}" --depth 1 "${source_dir}"
    fi
    # NOTE: "${source_dir}/c" causes build errors
    cd "${source_dir}/cpp" || exit 1
    if [ -s ./core.a ]; then
        echo
        echo "Notice: 'core.a' already exists."
        echo "  Move or remove it to renew it."
    else
        case "${ARCH}" in
            aarch64|x86_64) arch_bits=64;;
            armv7l|x86)     arch_bits=32;;
            *)              echo "Error: specify 'arch_bits'!"; exit 1;;
        esac
        python3 config"${arch_bits}".py test
        # python3 config"${arch_bits}".py
        # Choose a Scheme to support - 0 to finish: 25 26 27 28 29 30 31 32 33 34 35
    fi
    if [ -x "./${bench}" ]; then
        echo
        echo "Notice: './${bench}' already exists."
        echo "  Move or remove it to renew it."
    else
        amend_miracle_benchtest "${bench_org}".cpp "${bench}".cpp
        # NOTE:
        #   Performances of -O2 and -O3 seem similar.
        #   "${source_dir}/c" causes build errors
        # gcc -O2 -std=c99 "${bench}".c core.a -o "${bench}""
        g++ -O2  "${bench}".cpp core.a -o "${bench}"
    fi
    if [ -s "${log}" ]; then
        echo
        echo "Notice: '${log}' already exists."
        echo "  Move or remove it to renew it."
    else
        echo -e "\n'./${bench}' takes time. Wait for a while."
        # NOTE: ./${bench} with a redirect displays the results at the end
        ./"${bench}" > >(tee "${log}") 2>&1
    fi
    miracle_log_to_dat "${log}" "${MIRACLE_DAT}"
    )
    # NOTE:
    #   To add TAG (version) after algorithm names,
    #   use '-v TAG_MIRACLE="${tag}"' below
    #   though this may result in overlap in name positions in the figures.
    # 128 bit security
    awk -v TAG_MIRACLE="" '$1 == "BLS12383" \
        {$1=$1"@Miracle"TAG_MIRACLE; printf "%20s %15s %15s %15s\n",$1,$2,$3,$4}' \
        "${MIRACLE_DAT}" >> "${PAIRING_DAT_128}"
    TMP_NAME_128="${TMP_NAME_128}_miracle${tag}"
    # 192 bit security
    awk -v TAG_MIRACLE="" '$1 == "BLS24479" \
        {$1=$1"@Miracle"TAG_MIRACLE; printf "%20s %15s %15s %15s\n",$1,$2,$3,$4}' \
        "${MIRACLE_DAT}" >> "${PAIRING_DAT_192}"
    TMP_NAME_192="${TMP_NAME_192}_miracle${tag}"
    # 256 bit security
    awk -v TAG_MIRACLE="" '$1 == "BLS48556" \
        {$1=$1"@Miracle"TAG_MIRACLE; printf "%20s %15s %15s %15s\n",$1,$2,$3,$4}' \
        "${MIRACLE_DAT}" >> "${PAIRING_DAT_256}"
    TMP_NAME_256="${TMP_NAME_256}_miracle${tag}"
}


##
# @brief        Measure pairing speed of MCL
# @details      
# @param[in]    $1: tag or branch name (default: master)
# @param[in]    global TIME_OR_TSC: 'time' or 'tsc'
# @param[in]    global PAIRING_DIR: dir for results (*.{log,dat,png})
# @param[out]   global MCL_DAT: data file name
# @param[out]   global MCL_UNIT_IN_DAT: time unit of MCL_DAT
measure_mcl () {
    local tag source_dir makefile
    local bench_name_in_makefile=bin/bls12_test.exe
    local bench=bin/bls12_test_"${TIME_OR_TSC}".exe
    local tag="$1"
    if [ -z "${tag}" ]; then
        tag=master
    fi
    mkdir -p Mcl
    local log="${PAIRING_DIR}/mcl${tag}_${TIME_OR_TSC}.log"
    MCL_DAT=${log%.log}.dat
    # clock or time
    if [ "${TIME_OR_TSC}" == "time" ]; then
        makefile=Makefile_"${TIME_OR_TSC}"
        # gettimeofday
        MCL_UNIT_IN_DAT="msec"
        local mcl_unit1="msec"    # unit in log
        # convert to ${MCL_UNIT_IN_DAT}
        local mcl_unit2="usec"
        local mcl_unit3="nsec"
        local ratio_2_1=0.001     # msec/usec
        local ratio_3_1=0.000001  # msec/nsec
    elif [ "${TIME_OR_TSC}" == "tsc" ]; then
        makefile=Makefile
        MCL_UNIT_IN_DAT="cycles"
        local mcl_unit1="clk"    # unit in log
        # convert to ${MCL_UNIT_IN_DAT}
        local mcl_unit2="Kclk"
        local mcl_unit3="Mclk"
        local ratio_2_1=1000     # Kclk/clk
        local ratio_3_1=1000000  # Mclk/clk
    else
        echo "Error: unknown TIME_OR_TSC: '${TIME_OR_TSC}'!"
        exit 2
    fi
    (
    cd Mcl || exit 1
    source_dir=mcl-"${tag}"
    if [ -d "${source_dir}" ]; then
        echo
        echo "Notice: '${source_dir}' dir already exists."
        echo "  Move or remove it to renew the contents."
    else
        ${GIT_CLONE} https://github.com/herumi/mcl.git -b "${tag}" --depth 1 "${source_dir}"
    fi
    cd "${source_dir}" || exit 1
    if [ -s "${log}" ]; then
        echo
        echo "Notice: '${log}' already exists."
        echo "  Move or remove it to renew it."
    else
        make clean
        if [ "${TIME_OR_TSC}" == "time" ]; then
            rm -f "${makefile}"
            cp -fp Makefile "${makefile}"
            if ! grep -q "CFLAGS+=-DCYBOZU_BENCH_USE_GETTIMEOFDAY" "${makefile}"; then
                # add "CFLAGS+=-DCYBOZU_BENCH_USE_GETTIMEOFDAY" in ./Makefile
                # "-i inplace -v INPLACE_SUFFIX" is available with gawk 4.1.0 or newer
                awk -i inplace -v INPLACE_SUFFIX=.org 'BEGIN {cou=0;} {if (cou == 0 && $1 ~ /^CFLAGS/ ) {cou += 1; print "CFLAGS+=-DCYBOZU_BENCH_USE_GETTIMEOFDAY"; print;} else {print;}}' "${makefile}"
            fi
            # NOTE: alternative is to comment out the following defs
            #       in include/cybozu/benchmark.hpp
            #   #define CYBOZU_BENCH_USE_RDTSC
            #   #define CYBOZU_BENCH_USE_CPU_TIMER
        fi
        make -f "${makefile}" -j "${bench_name_in_makefile}"
        mv -f "${bench_name_in_makefile}" "${bench}"
        ./"${bench}" > >(tee "${log}") 2>&1
    fi
:<<'# COMMENT_EOF'
ctest:module=naive
i=0 curve=BLS12_381
testLagrange

hashAndMapToG1 451.177Kclk
hashAndMapToG2 895.852Kclk

pairing          4.539Mclk
millerLoop       1.801Mclk
finalExp         2.329Mclk

BN254
mapToG1  51.466Kclk
naiveG1  58.074Kclk
mapToG2 210.619Kclk
naiveG2  93.434Kclk
BLS12_381
mapToG1 355.918Kclk
naiveG1 121.807Kclk
mapToG2 687.335Kclk
naiveG2 255.508Kclk
# COMMENT_EOF
    set_header "${MCL_UNIT_IN_DAT}" "${MCL_DAT}"
    awk -v mcl_unit1="${mcl_unit1}" \
        -v mcl_unit2="${mcl_unit2}" \
        -v mcl_unit3="${mcl_unit3}" \
        -v ratio_2_1="${ratio_2_1}" \
        -v ratio_3_1="${ratio_3_1}" \
        '$2 ~ /^curve=/,$1 == "precomputeG2" {\
        {if($2 ~ /^curve=/) {sub("curve=",_,$2); curve=$2}} \
        {if($1 == "pairing") {\
            if($2 ~ mcl_unit2){sub(mcl_unit2,_,$2); $2*=ratio_2_1} \
            else if($2 ~ mcl_unit3){sub(mcl_unit3,_,$2); $2*=ratio_3_1} \
            else {sub(mcl_unit1,_,$2)}; \
            pairing=$2}} \
        {if($1 == "millerLoop") {\
            if($2 ~ mcl_unit2){sub(mcl_unit2,_,$2); $2*=ratio_2_1} \
            else if($2 ~ mcl_unit3){sub(mcl_unit3,_,$2); $2*=ratio_3_1} \
            else {sub(mcl_unit1,_,$2)}; \
            loop=$2}} \
        {if($1 == "finalExp") {\
            if($2 ~ mcl_unit2){sub(mcl_unit2,_,$2); $2*=ratio_2_1} \
            else if($2 ~ mcl_unit3){sub(mcl_unit3,_,$2); $2*=ratio_3_1} \
            else {sub(mcl_unit1,_,$2)}; \
            printf "%20s %15s %15s %15s\n",curve,loop,$2,pairing}}}' \
        "${log}" >> "${MCL_DAT}"
    # MCL all
    # ../../../../plot_openssl_speed.sh -l pairing -u "${SPEED_UNIT}" -d "${MCL_DAT}"
    )
    # NOTE:
    #   To add TAG (version) after algorithm names,
    #   use '-v TAG_MCL="${tag}"' below
    #   though this may result in overlap in name positions in the figures.
    # 128 bit security
    awk -v TAG_MCL="" '$1 == "BLS12_381" \
        {$1=$1"@MCL"TAG_MCL; printf "%20s %15s %15s %15s\n",$1,$2,$3,$4}' \
        "${MCL_DAT}" >> "${PAIRING_DAT_128}"
    TMP_NAME_128="${TMP_NAME_128}_mcl${tag}"
}


##
# @brief        Measure pairing speed of Blst (not completed)
# @details      TODO: prepare process for benchmarking pairing.
# @param[in]    $1: tag or branch name (default: master)
# @param[in]    global TIME_OR_TSC: 'time' or 'tsc'
# @param[in]    global PAIRING_DIR: dir for results (*.{log,dat,png})
# @param[out]   global RELIC_DAT: data file name
measure_blst () {
    local tag="$1"
    if [ -z "${tag}" ]; then
        tag=master
    fi
    mkdir -p Blst
    local log="${PAIRING_DIR}/mcl${tag}_${TIME_OR_TSC}.log"
    BLST_DAT=${log%.log}.dat
    cd Blst || exit 1
    source_dir=blst-"${tag}"
    if [ -d "${source_dir}" ]; then
        echo
        echo "Notice: '${source_dir}' dir already exists."
        echo "  Move or remove it to renew the contents."
    else
        ${GIT_CLONE} https://github.com/supranational/blst.git -b "${tag}" --depth 1 "${source_dir}"
    fi
    cd "${source_dir}" || exit 1
    if [ -s "${log}" ]; then
        echo
        echo "Notice: '${log}' already exists."
        echo "  Move or remove it to renew it."
    else
        cd bindings/rust/ || exit 1
        # TODO: prepare a process to benchmark pairing.
        #   This bench is for higher-level processes,
        #   such as signing and verification.
        cargo bench
        exit
    fi
}


### main ###

while getopts 't:vh?' OPTION
do
    case $OPTION in
        t) TIME_OR_TSC="${OPTARG}";;
        h) usage; exit 0;;
        v) show_version; exit 0;;
        *) echo "Use '-h' option for help!"; exit 1;;
    esac
done
shift $((OPTIND - 1))

if [ -z "${TIME_OR_TSC}" ]; then
    TIME_OR_TSC="time"  # default
fi
case "${TIME_OR_TSC}" in
    "tsc")  SPEED_UNIT="cycles";;
    "time") SPEED_UNIT="msec";;
    *) echo "Error: unknown TIME_OR_TSC: '${TIME_OR_TSC}'!"; exit 1
esac

# body
mkdir -p "${PAIRING_DIR}/"
cd "${PAIRING_DIR}/" || exit 1

# TMP_NAME and PAIRING_DAT are modified in measure_*() and below
TMP_NAME_128=pairing_128bs
TMP_NAME_192=pairing_192bs
TMP_NAME_256=pairing_256bs
PAIRING_DAT_128=pairing_128bs.tmp
PAIRING_DAT_192=pairing_192bs.tmp
PAIRING_DAT_256=pairing_256bs.tmp
set_header "${SPEED_UNIT}" "${PAIRING_DAT_128}"
set_header "${SPEED_UNIT}" "${PAIRING_DAT_192}"
set_header "${SPEED_UNIT}" "${PAIRING_DAT_256}"
if [ "$#" == "0" ]; then
    # run all newest (master or main)
    # measure_blst "master"
    measure_mcl "master"
    measure_relic "main"
    measure_miracle "master"
else
    # run any combination of repo:tag
    while [ 0 -lt $# ]; do
        repo=${1%:*}
        tag=${1#*:}
        case "${repo}" in
            # blst)     measure_blst "${tag}";
            #     ../../plot_openssl_speed.sh -l pairing -u "${SPEED_UNIT}" -d "${BLST_DAT#"${PWD}"/}";;
            mcl)     measure_mcl "${tag}";
                ../../plot_openssl_speed.sh -l pairing -u "${SPEED_UNIT}" -d "${MCL_DAT#"${PWD}"/}";;
            relic)   measure_relic "${tag}";
                ../../plot_openssl_speed.sh -l pairing -u "${SPEED_UNIT}" -d ./"${RELIC_DAT#"${PWD}"/}";;
            miracle) measure_miracle "${tag}";
                ../../plot_openssl_speed.sh -l pairing -u "${SPEED_UNIT}" -d "${MIRACLE_DAT#"${PWD}"/}";;
            *) echo "Error: unknown <REPO>: '${repo}'!"; exit 1;;
        esac
        shift
    done
fi
# rename PAIRING_DAT_128 to TMP_NAME_128
TMP_NAME_128="${TMP_NAME_128}_${TIME_OR_TSC}.dat"
TMP_NAME_192="${TMP_NAME_192}_${TIME_OR_TSC}.dat"
TMP_NAME_256="${TMP_NAME_256}_${TIME_OR_TSC}.dat"
mv ${PAIRING_DAT_128} "${TMP_NAME_128}"
mv ${PAIRING_DAT_192} "${TMP_NAME_192}"
mv ${PAIRING_DAT_256} "${TMP_NAME_256}"
PAIRING_DAT_128="${TMP_NAME_128}"
PAIRING_DAT_192="${TMP_NAME_192}"
PAIRING_DAT_256="${TMP_NAME_256}"
../../plot_openssl_speed.sh -l pairing -u "${SPEED_UNIT}" -d "${PAIRING_DAT_128}"
../../plot_openssl_speed.sh -l pairing -u "${SPEED_UNIT}" -d "${PAIRING_DAT_192}"
../../plot_openssl_speed.sh -l pairing -u "${SPEED_UNIT}" -d "${PAIRING_DAT_256}"

echo "========================="
echo "All the results are in:"
echo "  ${PAIRING_DIR}/*.{log,dat,png}"
echo
# On WSL
# explorer.exe $(wslpath -w ./)
# explorer.exe $(wslpath -w ./tmp/Pairing/pairing_128bs_mclv3.02_relic0.7.0_miraclev4.1.png)
