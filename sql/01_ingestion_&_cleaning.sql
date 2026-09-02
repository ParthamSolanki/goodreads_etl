DROP TABLE IF EXISTS books_raw;


CREATE TABLE books_raw AS
SELECT *
FROM read_csv(
    'data/books.csv',
    header = true,
    -- VARCHAR makes it so there are no errors regarding datatypes if there is a mismatch while ingesting.
    all_varchar = true, -- Will deal with the datatypes while cleaning.
    normalize_names = true, -- Remove whitespaces from column names.
    ignore_errors = true -- Errors as data not enclosed in "" in the csv.
);


DROP TABLE IF EXISTS books_clean;


CREATE TABLE books_clean AS
WITH duplicate AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY TRIM(title), TRIM(authors)
            ORDER BY TRY_CAST(ratings_count AS BIGINT) DESC NULLS LAST
        ) AS row_num
    FROM books_raw
)
SELECT
    TRY_CAST(bookid AS INTEGER) AS book_id,
    TRIM(title) AS title,
    TRIM(authors) AS authors_raw,
    TRY_CAST(average_rating AS DECIMAL(4, 2)) AS average_rating,
    TRIM(isbn) AS isbn,
    TRIM(isbn13) AS isbn13,
    CASE
        WHEN LOWER(TRIM(language_code)) LIKE 'en%' THEN 'eng'
        WHEN language_code IS NULL OR TRIM(language_code) = '' THEN 'unknown'
        ELSE LOWER(TRIM(language_code))
    END AS language_code,
    TRY_CAST(num_pages AS INTEGER) AS num_pages,
    COALESCE(TRY_CAST(ratings_count AS BIGINT), 0) AS ratings_count,
    COALESCE(TRY_CAST(text_reviews_count AS BIGINT), 0) AS text_reviews_count,
    CAST(TRY_STRPTIME(TRIM(publication_date), '%m/%d/%Y') AS DATE) AS publication_date,
    TRIM(publisher) AS publisher,
    CASE
        WHEN TRY_CAST(num_pages AS INTEGER) IS NULL OR TRY_CAST(num_pages AS INTEGER) <= 0 THEN 'Unknown'
        WHEN TRY_CAST(num_pages AS INTEGER) < 200 THEN 'Novella (<200)'
        WHEN TRY_CAST(num_pages AS INTEGER) BETWEEN 200 AND 499 THEN 'Standard (200-499)'
        WHEN TRY_CAST(num_pages AS INTEGER) BETWEEN 500 AND 799 THEN 'Long (500-799)'
        ELSE 'Epic (800+)'
    END AS page_bucket
FROM duplicate
WHERE row_num = 1
    AND TRY_STRPTIME(TRIM(publication_date), '%m/%d/%Y') IS NOT NULL;
