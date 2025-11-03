    tsc_diff = rdtscp(&proc_id) - start_tsc;
    printf(
        "\tproc_id: %" PRIu32 ":%" PRIu32 " tsc_diff= %" PRIu64 " tsc_diff/elapsed= %4.2lf [GHz]\n",
        start_proc_id, proc_id, tsc_diff/iterations, tsc_diff/(1000000000 * elapsed));
    // assert(start_proc_id == proc_id);
} while ( start_proc_id != proc_id );
