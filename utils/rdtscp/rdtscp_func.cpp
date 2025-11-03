/*
 * This file is part of https://github.com/KazKobara/plot_openssl_speed
 * Copyright (C) 2025 National Institute of Advanced Industrial Science and Technology (AIST). All Rights Reserved.
 */

#include <assert.h>

static uint64_t start_tsc, tsc_diff;
static uint32_t start_proc_id, proc_id;

static inline uint64_t rdtscp( uint32_t * proc_id_a )
{
    uint64_t lo,hi;
    asm volatile ( "rdtscp\n" : "=a" (lo), "=d" (hi), "=c" (*proc_id_a) : : );
    return (hi << 32) + lo;
}
