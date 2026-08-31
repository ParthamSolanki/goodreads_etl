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

-- Verifying data was loaded.
SELECT COUNT(*) AS row_count
FROM books_raw;