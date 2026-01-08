/*******************************************************************************
 * POSTGRESQL PERFORMANCE HEALTH CHECK SUITE
 * Use these queries to identify the causes of 7s to 27s latency spikes.
 *******************************************************************************/

-- 1. METRIC: THE CACHE KILLER (Cold vs. Warm Data)
-- High disk_reads mean the query is not in RAM. 
-- If hit_ratio is < 95%, you are physically waiting for the SSD.
SELECT 
    query, 
    calls, 
    shared_blks_hit AS ram_hits, 
    shared_blks_read AS disk_reads,
    round(100.0 * shared_blks_hit / nullif(shared_blks_hit + shared_blks_read, 0), 2) AS hit_ratio_pct
FROM pg_stat_statements
WHERE query NOT LIKE '%pg_stat_statements%'
ORDER BY shared_blks_read DESC
LIMIT 10;


-- 2. METRIC: RAM STARVATION (Temp File Creation)
-- If temp_blks_written > 0, your 'work_mem' is too low for the query size.
-- This causes the database to use the Disk as a "scratchpad," which is extremely slow.
SELECT 
    query, 
    calls, 
    temp_blks_read, 
    temp_blks_written
FROM pg_stat_statements
WHERE temp_blks_written > 0
ORDER BY temp_blks_written DESC
LIMIT 10;


-- 3. METRIC: THE CPU BULLY (Total System Impact)
-- Shows which queries are consuming the most cumulative time on the CPU.
-- High total_seconds indicates the query is the primary driver of server load.
SELECT 
    query, 
    calls, 
    round(total_exec_time::numeric / 1000, 2) as total_seconds,
    round(mean_exec_time::numeric / 1000, 2) as avg_seconds
FROM pg_stat_statements
WHERE query NOT LIKE '%pg_stat_statements%'
ORDER BY total_exec_time DESC
LIMIT 10;


-- 4. METRIC: THE I/O STALL (Wait for Hardware)
-- Measures the percentage of execution time spent waiting for Disk I/O.
-- If io_wait_percent > 20%, your hardware/SSD throughput is the bottleneck.
SELECT 
    query, 
    round((total_exec_time / 1000)::numeric, 2) as total_sec,
    round(((blk_read_time + blk_write_time) / 1000)::numeric, 2) as io_wait_sec,
    round((100 * (blk_read_time + blk_write_time) / nullif(total_exec_time, 0))::numeric, 2) as io_wait_percent
FROM pg_stat_statements
WHERE total_exec_time > 0 AND query NOT LIKE '%pg_stat_statements%'
ORDER BY io_wait_sec DESC
LIMIT 10;


-- 5. METRIC: THE DATA OVERLOAD (Row Efficiency)
-- High rows_per_call suggests you are fetching massive amounts of data 
-- just to display a small summary. Very common with ORM 'getMany()' calls.
SELECT 
    query, 
    calls, 
    rows, 
    rows / calls AS rows_per_call
FROM pg_stat_statements
WHERE query NOT LIKE '%pg_stat_statements%'
ORDER BY rows_per_call DESC
LIMIT 10;


-- 6. METRIC: GLOBAL INSTANCE HEALTH
-- Run this for a "High Level" view of the entire database.
-- If cache_hit_ratio is low, your 'shared_buffers' (DB RAM) needs to be increased.
SELECT 
    datname, 
    round(100 * blks_hit / nullif(blks_hit + blks_read, 0), 2) AS global_cache_hit_ratio,
    tup_returned, 
    tup_fetched, 
    (tup_returned - tup_fetched) AS inefficient_full_scans
FROM pg_stat_database
WHERE datname = current_database();