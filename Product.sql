WITH    duration_table AS (
                        SELECT PARSE_DATE("%Y%m%d",event_date) date,
                                user_pseudo_id id,
                                MIN(CASE WHEN event_name = "session_start" THEN TIMESTAMP_MICROS(event_timestamp) END) start_time, -- MIN because first arriving on site
                                MIN(CASE WHEN event_name = "purchase" THEN TIMESTAMP_MICROS(event_timestamp)END) purchase_time,--MIN because first purchase of certain day
                        FROM `tc-da-1.turing_data_analytics.raw_events`
                        WHERE event_name = "session_start" OR  event_name = "purchase"
                        GROUP BY date, user_pseudo_id
                        HAVING purchase_time IS NOT NULL AND start_time IS NOT NULL
                        ORDER BY date
                        ),

        info_table AS   ( --additional info on users that start a session
                        SELECT  CASE WHEN event_name = "session_start" THEN TIMESTAMP_MICROS(event_timestamp) END start_time,
                                user_pseudo_id id,
                                country,--Acquisition metric
                                traffic_source,--Acquisition metric
                                category, --Acquisition metric
                        FROM `turing_data_analytics.raw_events`
                        WHERE event_name = "session_start"
                        ),

        revenue_table AS( --amount of revenue per user per day
                        SELECT  PARSE_DATE("%Y%m%d",event_date) date,
                                user_pseudo_id id,
                                SUM(purchase_revenue_in_usd) OVER (PARTITION BY user_pseudo_id,PARSE_DATE("%Y%m%d",event_date)) daily_revenue
                        FROM `turing_data_analytics.raw_events`
                        WHERE  event_name = "purchase"
                        ),
        first_purchase_table AS(
                                SELECT  id,
                                        MIN(date) OVER (PARTITION BY id) first_purchase
                                FROM duration_table
                                )

SELECT  DISTINCT duration_table.date,
        duration_table.id,
        DATETIME_DIFF(duration_table.purchase_time,duration_table.start_time, MINUTE) duration,
        info_table.country,
        info_table.traffic_source,
        info_table.category,
        revenue_table.daily_revenue,
        CASE WHEN first_purchase = duration_table.date THEN 0 ELSE 1 END repeat_customer

FROM duration_table
JOIN info_table
ON duration_table.id = info_table.id AND duration_table.start_time = info_table.start_time
JOIN revenue_table
ON duration_table.id = revenue_table.id AND duration_table.date = revenue_table.date
JOIN first_purchase_table
ON first_purchase_table.id = duration_table.id

WHERE DATETIME_DIFF(duration_table.purchase_time,duration_table.start_time, MINUTE)>0
ORDER BY duration_table.date, duration_table.id
