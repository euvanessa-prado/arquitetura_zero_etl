{{ config(materialized='table') }}

WITH source AS (
    SELECT * FROM {{ source('transactional_movielens', 'movies') }}
)
SELECT 
    "movieId" as movieid,
    title,
    genres
FROM source
