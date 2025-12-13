{{ config(materialized='table') }}

WITH source AS (
    SELECT * FROM {{ source('transactional_movielens', 'links') }}
)
SELECT 
    "movieId" as movieid,
    "imdbId" as imdbid,
    "tmdbId" as tmdbid
FROM source
