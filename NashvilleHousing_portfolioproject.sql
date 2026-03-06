--
-- Nashville Housing Portfolio Project SQL Script
--
-- Created on 2026-03-06 09:23:29 UTC
-- This script contains refined SQL queries for analysis of the Nashville housing market.
--

-- Query 1: Select all listings
SELECT *
FROM listings;

-- Query 2: Count number of listings by neighborhood
SELECT neighborhood, COUNT(*) AS listing_count
FROM listings
GROUP BY neighborhood
ORDER BY listing_count DESC;

-- Query 3: Average listing price by neighborhood
SELECT neighborhood, AVG(price) AS average_price
FROM listings
GROUP BY neighborhood
ORDER BY average_price DESC;

-- Query 4: Total listings and average price for each type
SELECT type, COUNT(*) AS total_listings, AVG(price) AS average_price
FROM listings
GROUP BY type;
