{{ config(materialized='table') }}

WITH source AS (
    SELECT * FROM {{ source('transactional_movielens', 'ratings') }}
)
SELECT 
    "userId" as userid,
    "movieId" as movieid,
    rating,
    timestamp AS rating_timestamp
FROM source
