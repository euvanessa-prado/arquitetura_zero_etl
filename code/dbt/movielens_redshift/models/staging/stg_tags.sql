{{ config(materialized='table') }}

WITH source AS (
    SELECT * FROM {{ source('transactional_movielens', 'tags') }}
)
SELECT 
    "userId" as userid,
    "movieId" as movieid,
    "tag",
    "timestamp" AS tag_timestamp
FROM source
