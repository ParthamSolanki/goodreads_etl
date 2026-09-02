-- dim publisher
-- table for publisher name and publisher_key
DROP TABLE IF EXISTS dim_publisher;


CREATE TABLE dim_publisher AS
SELECT
    ROW_NUMBER() OVER (ORDER BY publisher) AS publisher_key,
    publisher AS publisher_name
FROM (
    SELECT DISTINCT publisher
    FROM books_clean
    WHERE publisher IS NOT NULL AND publisher != ''
);


-- dim language and full languages
-- table for language code using it as the language key and the full form of the code.
DROP TABLE IF EXISTS dim_language;


CREATE TABLE dim_language AS
SELECT
    ROW_NUMBER() OVER (ORDER BY language_code) AS language_key,
    language_code,
    CASE
        WHEN language_code = 'ale' THEN 'Aleut'
        WHEN language_code = 'ara' THEN 'Arabic'
        WHEN language_code = 'eng' THEN 'English'
        WHEN language_code = 'fre' THEN 'French'
        WHEN language_code = 'ger' THEN 'German'
        WHEN language_code = 'gla' THEN 'Scottish Gaelic'
        WHEN language_code = 'glg' THEN 'Galician'
        WHEN language_code = 'grc' THEN 'Ancient Greek'
        WHEN language_code = 'ita' THEN 'Italian'
        WHEN language_code = 'jpn' THEN 'Japanese'
        WHEN language_code = 'lat' THEN 'Latin'
        WHEN language_code = 'msa' THEN 'Malay'
        WHEN language_code = 'mul' THEN 'Multiple languages'
        WHEN language_code = 'nl' THEN 'Dutch'
        WHEN language_code = 'nor' THEN 'Norwegian'
        WHEN language_code = 'por' THEN 'Portuguese'
        WHEN language_code = 'rus' THEN 'Russian'
        WHEN language_code = 'spa' THEN 'Spanish'
        WHEN language_code = 'srp' THEN 'Serbian'
        WHEN language_code = 'swe' THEN 'Swedish'
        WHEN language_code = 'tur' THEN 'Turkish'
        WHEN language_code = 'wel' THEN 'Welsh'
        WHEN language_code = 'zho' THEN 'Chinese'
        WHEN language_code = 'unknown' Then 'Unknown / Unassigned'
        ELSE UPPER(language_code)
    END AS language_name
FROM (
    SELECT DISTINCT language_code
    FROM books_clean
);


-- dim date
-- table for publication date, using the date YYYYMMDD as the key, full_date is the normal publication date, year, quarter, month number and name extracted, month_year is combination of month name and year, and lastly decade extracted using year.
DROP TABLE IF EXISTS dim_date;


CREATE TABLE dim_date AS
SELECT
    CAST(STRFTIME(publication_date, '%Y%m%d') AS INTEGER) AS date_key,
    publication_date AS full_date,
    CAST(EXTRACT(YEAR FROM publication_date) AS INTEGER) AS year,
    CAST(EXTRACT(QUARTER FROM publication_date) AS INTEGER) AS quarter,
    CAST(EXTRACT(MONTH FROM publication_date) AS INTEGER) AS month_num,
    STRFTIME(publication_date, '%B') AS month_name,
    CONCAT(STRFTIME(publication_date, '%b'), ' ', STRFTIME(publication_date, '%Y')) AS month_year,
    CAST(FLOOR(EXTRACT(YEAR FROM publication_date) / 10) AS INTEGER) * 10 AS decade
FROM (
    SELECT DISTINCT publication_date
    FROM books_clean
    WHERE publication_date IS NOT NULL
)
ORDER BY full_date;


-- dim author & one where co-authors are separated.
-- dim_author is the table with separated author names and keys generated according to these names.
DROP TABLE IF EXISTS dim_authors;

CREATE TABLE dim_authors AS
WITH exploded_auth AS (
    SELECT DISTINCT TRIM(UNNEST(STRING_SPLIT(authors_raw, '/'))) AS author_name
    FROM books_clean
)
SELECT
    ROW_NUMBER() OVER (ORDER BY author_name) AS author_key,
    author_name
FROM exploded_auth
WHERE author_name != '';

-- dim book_authod_bridge -> book_id and author key (name used to generate key in previous table) linked.
DROP TABLE IF EXISTS book_author_bridge;


CREATE TABLE book_author_bridge AS
WITH exploded_auth AS (
    SELECT
        book_id,
        TRIM(UNNEST(STRING_SPLIT(authors_raw, '/'))) AS author_name
    FROM books_clean
)
SELECT DISTINCT
    b.book_id,
    a.author_key
FROM exploded_auth AS b
INNER JOIN dim_author AS a
    ON b.author_name = a.author_name;


-- fact_books, most of the needed data and the keys from publisher and language codes using left join from books_clean. Generating date key as that is faster than joining with the date dim.


DROP TABLE IF EXISTS fact_books;


CREATE TABLE fact_books AS
SELECT
    b.book_id,
    b.title,
    b.isbn,
    b.isbn13,
    b.page_bucket,
    COALESCE(p.publisher_key, -1) AS publisher_key,
    COALESCE(l.language_key, -1) AS language_key,
    CAST(STRFTIME(b.publication_date, '%Y%m%d') AS INTEGER) AS date_key,
    b.num_pages,
    b.ratings_count,
    b.text_reviews_count,
    b.average_rating
FROM books_clean AS b
LEFT JOIN dim_publisher AS p
    ON b.publisher = p.publisher_name
LEFT JOIN dim_language AS l
    ON b.language_code = l.language_code;
