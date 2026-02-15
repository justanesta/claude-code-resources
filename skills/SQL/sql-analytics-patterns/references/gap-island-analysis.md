# Gap and Island Analysis

## Core Concept

**Gaps** are missing values in a sequence (missing dates, skipped IDs).
**Islands** are consecutive groups of related values (login streaks, active periods, status spans).

The fundamental technique: subtract a monotonically increasing sequence (ROW_NUMBER) from the values. Consecutive values produce the same difference, forming a group identifier.

## Gap Detection in Sequences

```sql
-- Find missing order IDs (gaps in a numeric sequence)
WITH id_sequence AS (
    SELECT
        order_id,
        LEAD(order_id) OVER (ORDER BY order_id) AS next_id
    FROM orders
)
SELECT
    order_id AS gap_start_after,
    next_id AS gap_ends_before,
    next_id - order_id - 1 AS missing_count
FROM id_sequence
WHERE next_id - order_id > 1
ORDER BY order_id;

-- Find gaps in date sequences
WITH date_series AS (
    SELECT
        event_date,
        LEAD(event_date) OVER (ORDER BY event_date) AS next_date
    FROM (SELECT DISTINCT event_date FROM daily_events) d
)
SELECT
    event_date AS last_date_before_gap,
    next_date AS first_date_after_gap,
    next_date - event_date - 1 AS days_missing
FROM date_series
WHERE next_date - event_date > 1
ORDER BY event_date;

-- Per-user variant: add PARTITION BY user_id to the LEAD call
```

## Island Detection: The ROW_NUMBER Technique

```sql
-- Identify consecutive login streaks
-- Key insight: for consecutive dates, (date - ROW_NUMBER) is constant
WITH daily_logins AS (
    SELECT DISTINCT user_id, login_date::DATE AS login_date
    FROM user_logins
),
with_groups AS (
    SELECT
        user_id,
        login_date,
        login_date - (ROW_NUMBER() OVER (
            PARTITION BY user_id ORDER BY login_date
        ))::INT AS island_group
    FROM daily_logins
)
SELECT
    user_id,
    MIN(login_date) AS streak_start,
    MAX(login_date) AS streak_end,
    COUNT(*) AS streak_days
FROM with_groups
GROUP BY user_id, island_group
ORDER BY user_id, streak_start;

-- Example of the math:
-- login_date | ROW_NUMBER | date - rn (island_group)
-- 2024-01-01 | 1          | 2023-12-31
-- 2024-01-02 | 2          | 2023-12-31  (same group!)
-- 2024-01-03 | 3          | 2023-12-31  (same group!)
-- 2024-01-06 | 4          | 2024-01-02  (new group - gap detected)
-- 2024-01-07 | 5          | 2024-01-02  (same group as 01-06)
```

## Island Detection for Numeric Sequences

```sql
-- Find consecutive seat blocks (e.g., theater, flights)
WITH seat_groups AS (
    SELECT
        seat_number,
        seat_number - ROW_NUMBER() OVER (ORDER BY seat_number) AS grp
    FROM available_seats
    WHERE row_id = 'A'
)
SELECT
    MIN(seat_number) AS block_start,
    MAX(seat_number) AS block_end,
    COUNT(*) AS block_size
FROM seat_groups
GROUP BY grp
HAVING COUNT(*) >= 2  -- At least 2 consecutive seats
ORDER BY block_start;

-- Same technique works for months, timestamps, or any ordered sequence
-- by adjusting the ROW_NUMBER subtraction to match the data type
```

## Status Change Tracking

```sql
-- Track how long each server was in each status
WITH status_changes AS (
    SELECT
        server_id,
        status,
        recorded_at,
        LEAD(recorded_at) OVER (
            PARTITION BY server_id ORDER BY recorded_at
        ) AS next_change_at,
        ROW_NUMBER() OVER (PARTITION BY server_id ORDER BY recorded_at) AS rn
    FROM server_status_log
),
-- Collapse consecutive identical statuses into islands
status_groups AS (
    SELECT
        server_id,
        status,
        recorded_at,
        next_change_at,
        rn - ROW_NUMBER() OVER (
            PARTITION BY server_id, status ORDER BY recorded_at
        ) AS status_group
    FROM status_changes
)
SELECT
    server_id,
    status,
    MIN(recorded_at) AS status_started,
    MAX(COALESCE(next_change_at, CURRENT_TIMESTAMP)) AS status_ended,
    MAX(COALESCE(next_change_at, CURRENT_TIMESTAMP)) - MIN(recorded_at) AS duration
FROM status_groups
GROUP BY server_id, status, status_group
ORDER BY server_id, status_started;

```

## Session Analysis (Sessionization)

```sql
-- Define sessions: a new session starts after 30 minutes of inactivity
WITH events_with_lag AS (
    SELECT
        user_id,
        event_timestamp,
        event_type,
        LAG(event_timestamp) OVER (
            PARTITION BY user_id ORDER BY event_timestamp
        ) AS prev_event_at,
        EXTRACT(EPOCH FROM (
            event_timestamp - LAG(event_timestamp) OVER (
                PARTITION BY user_id ORDER BY event_timestamp
            )
        )) / 60.0 AS minutes_since_last
    FROM user_events
),
session_starts AS (
    SELECT
        user_id,
        event_timestamp,
        event_type,
        CASE
            WHEN prev_event_at IS NULL THEN 1
            WHEN minutes_since_last > 30 THEN 1
            ELSE 0
        END AS is_new_session
    FROM events_with_lag
),
with_session_id AS (
    SELECT
        user_id,
        event_timestamp,
        event_type,
        SUM(is_new_session) OVER (
            PARTITION BY user_id ORDER BY event_timestamp
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS session_number
    FROM session_starts
)
SELECT
    user_id,
    session_number,
    MIN(event_timestamp) AS session_start,
    MAX(event_timestamp) AS session_end,
    COUNT(*) AS event_count
FROM with_session_id
GROUP BY user_id, session_number;
```

## Subscription / Membership Periods

```sql
-- Merge overlapping subscription periods per customer
WITH ordered_subs AS (
    SELECT
        customer_id,
        start_date,
        end_date,
        MAX(end_date) OVER (
            PARTITION BY customer_id
            ORDER BY start_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ) AS max_prev_end
    FROM subscriptions
),
island_starts AS (
    SELECT
        customer_id,
        start_date,
        end_date,
        CASE
            WHEN start_date <= max_prev_end THEN 0
            ELSE 1
        END AS is_new_island
    FROM ordered_subs
),
island_groups AS (
    SELECT
        customer_id,
        start_date,
        end_date,
        SUM(is_new_island) OVER (
            PARTITION BY customer_id ORDER BY start_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS island_id
    FROM island_starts
)
SELECT
    customer_id,
    MIN(start_date) AS membership_start,
    MAX(end_date) AS membership_end,
    MAX(end_date) - MIN(start_date) AS total_duration,
    COUNT(*) AS merged_subscription_count
FROM island_groups
GROUP BY customer_id, island_id
ORDER BY customer_id, membership_start;
```

## Winning / Losing Streaks

```sql
-- Sports analytics: team win/loss streaks
WITH game_results AS (
    SELECT
        team_id,
        game_date,
        result,  -- 'W' or 'L'
        ROW_NUMBER() OVER (PARTITION BY team_id ORDER BY game_date) AS game_num,
        ROW_NUMBER() OVER (PARTITION BY team_id, result ORDER BY game_date) AS result_num
    FROM team_games
),
streaks AS (
    SELECT
        team_id,
        result,
        game_num - result_num AS streak_group,
        MIN(game_date) AS streak_start,
        MAX(game_date) AS streak_end,
        COUNT(*) AS streak_length
    FROM game_results
    GROUP BY team_id, result, game_num - result_num
)
SELECT
    team_id,
    result,
    streak_start,
    streak_end,
    streak_length
FROM streaks
WHERE streak_length >= 3
ORDER BY team_id, streak_start;

```

## Cross-Database Notes

```sql
-- Date subtraction for island grouping:

-- PostgreSQL: date arithmetic returns integers
login_date - ROW_NUMBER()::INT  -- Works directly

-- MySQL: Use DATE_SUB
DATE_SUB(login_date, INTERVAL ROW_NUMBER() OVER (...) DAY)

-- SQL Server: Use DATEADD
DATEADD(DAY, -ROW_NUMBER() OVER (...), login_date)
```
