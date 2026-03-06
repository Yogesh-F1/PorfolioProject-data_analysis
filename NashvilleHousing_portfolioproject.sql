/*
====================================================================================
    PROJECT      : Nashville Housing Data Cleaning
    TABLE        : NashvilleHousing
    DESCRIPTION  : This script cleans up a real-world housing dataset step by step.
                   We fix the date format, fill in missing addresses, break combined
                   address fields into separate columns, tidy up inconsistent values,
                   remove duplicate rows, and delete columns we no longer need.
====================================================================================
*/


SELECT *
FROM   [portfolio project]..NashvilleHousing;


/* ==================================================================================
   SECTION 1: Fix the Date Format
   The SaleDate column stores dates with a time stamp attached (always midnight),
   which we don't need. We'll create a new column that holds just the date.
   ================================================================================== */

/* First, let's take a look at what the original and converted dates look like */
SELECT SaleDateConverted,
       CONVERT(DATE, SaleDate)
FROM   [portfolio project]..NashvilleHousing;

/* Create a new column to store the clean date — we keep the original just in case */
ALTER TABLE NashvilleHousing
ADD SaleDateConverted DATE;

/* Fill the new column with the date only, dropping the time portion */
UPDATE NashvilleHousing
SET    SaleDateConverted = CONVERT(DATE, SaleDate);


/* ==================================================================================
   SECTION 2: Fill in Missing Property Addresses
   Some rows are missing a property address. But here's the thing — if two rows
   share the same ParcelID, they're the same property. So we can borrow the address
   from the other row to fill in the blank.
   ================================================================================== */

/* Check which rows are missing an address and what we could fill them with */
SELECT a.ParcelID,
       a.PropertyAddress,
       b.ParcelID,
       b.PropertyAddress,
       ISNULL(a.PropertyAddress, b.PropertyAddress) AS FilledAddress
FROM   [portfolio project]..NashvilleHousing a
JOIN   [portfolio project]..NashvilleHousing b
       ON  a.ParcelID      = b.ParcelID
       AND a.[UniqueID ]  <> b.[UniqueID ]   /* make sure we're not matching a row with itself */
WHERE  a.PropertyAddress IS NULL;

/* Now do the actual fill — only rows with a missing address will be updated */
UPDATE a
SET    PropertyAddress = ISNULL(a.PropertyAddress, b.PropertyAddress)
FROM   [portfolio project]..NashvilleHousing a
JOIN   [portfolio project]..NashvilleHousing b
       ON  a.ParcelID      = b.ParcelID
       AND a.[UniqueID ]  <> b.[UniqueID ]
WHERE  a.PropertyAddress IS NULL;


/* ==================================================================================
   SECTION 3: Split Addresses into Separate Columns
   Right now, PropertyAddress has the street and city crammed into one field.
   OwnerAddress has street, city, and state all together. We'll pull each piece
   out into its own column so the data is easier to work with.
   ================================================================================== */

/* --- 3a. Split PropertyAddress into Street and City --- */

/* Preview what the split will look like before we make any changes */
SELECT SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress) - 1) AS SplitAddress,
       SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress) + 1,
                 LEN(PropertyAddress)) AS SplitCity
FROM   [portfolio project]..NashvilleHousing;

/* Add a column for the street address, then fill it in */
ALTER TABLE NashvilleHousing
ADD PropertySplitAddress NVARCHAR(255);

UPDATE NashvilleHousing
SET    PropertySplitAddress = SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress) - 1);

/* Add a column for the city, then fill it in */
ALTER TABLE NashvilleHousing
ADD PropertySplitCity NVARCHAR(255);

UPDATE NashvilleHousing
SET    PropertySplitCity = SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress) + 1,
                                     LEN(PropertyAddress));


/* --- 3b. Split OwnerAddress into Street, City, and State --- */

/* Preview the three-way split before applying it
   (PARSENAME counts from right to left, so 3 = street, 2 = city, 1 = state) */
SELECT PARSENAME(REPLACE(OwnerAddress, ',', '.'), 3) AS SplitAddress,
       PARSENAME(REPLACE(OwnerAddress, ',', '.'), 2) AS SplitCity,
       PARSENAME(REPLACE(OwnerAddress, ',', '.'), 1) AS SplitState
FROM   [portfolio project]..NashvilleHousing;

/* Add and fill the street address column */
ALTER TABLE NashvilleHousing
ADD OwnerSplitAddress NVARCHAR(255);

UPDATE NashvilleHousing
SET    OwnerSplitAddress = PARSENAME(REPLACE(OwnerAddress, ',', '.'), 3);

/* Add and fill the city column */
ALTER TABLE NashvilleHousing
ADD OwnerSplitCity NVARCHAR(255);

UPDATE NashvilleHousing
SET    OwnerSplitCity = PARSENAME(REPLACE(OwnerAddress, ',', '.'), 2);

/* Add and fill the state column */
ALTER TABLE NashvilleHousing
ADD OwnerSplitState NVARCHAR(255);

UPDATE NashvilleHousing
SET    OwnerSplitState = PARSENAME(REPLACE(OwnerAddress, ',', '.'), 1);

/* Double-check that all the new columns look right */
SELECT *
FROM   [portfolio project]..NashvilleHousing;


/* ==================================================================================
   SECTION 4: Make the SoldAsVacant Column Consistent
   This column has four different values floating around: 'Y', 'N', 'Yes', and 'No'.
   They all mean the same two things — we just need to pick one format and stick to it.
   ================================================================================== */

/* See how many of each value we have right now */
SELECT   DISTINCT(SoldAsVacant),
         COUNT(SoldAsVacant) AS RecordCount
FROM     [portfolio project]..NashvilleHousing
GROUP BY SoldAsVacant
ORDER BY 2;

/* Preview the change — 'Y' becomes 'Yes', 'N' becomes 'No', everything else stays */
SELECT SoldAsVacant,
       CASE
           WHEN SoldAsVacant = 'Y' THEN 'Yes'
           WHEN SoldAsVacant = 'N' THEN 'No'
           ELSE SoldAsVacant
       END AS NormalizedValue
FROM   [portfolio project]..NashvilleHousing;

/* Apply the change across the whole table */
UPDATE NashvilleHousing
SET    SoldAsVacant = CASE
                          WHEN SoldAsVacant = 'Y' THEN 'Yes'
                          WHEN SoldAsVacant = 'N' THEN 'No'
                          ELSE SoldAsVacant   /* rows already saying 'Yes' or 'No' are left alone */
                      END;


/* ==================================================================================
   SECTION 5: Find and Remove Duplicate Rows
   Some properties appear more than once with the exact same details. We use a CTE
   to number each group of matching rows — anything numbered 2 or higher is a duplicate.
   NOTE: Always run the SELECT version first to see what you'd be deleting.
         Once you're sure, swap SELECT * with DELETE to actually remove them.
   ================================================================================== */

WITH RowNumCTE AS
(
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY ParcelID,          /* group rows that share all these fields */
                            PropertyAddress,
                            SalePrice,
                            SaleDate,
                            LegalReference
               ORDER BY     UniqueID            /* keep the one with the lowest UniqueID */
           ) AS row_num
    FROM   [portfolio project]..NashvilleHousing
)

/* This shows you the duplicates — replace SELECT * with DELETE when you're ready */
SELECT *
FROM   RowNumCTE
WHERE  row_num > 1
ORDER BY PropertyAddress;


/* ==================================================================================
   SECTION 6: Remove Columns We No Longer Need
   Now that we've created cleaner, split-out versions of these columns,
   the originals are just taking up space. We can safely drop them.
   NOTE: Never do this to your original raw data — only on a working copy.
   ================================================================================== */

ALTER TABLE [portfolio project]..NashvilleHousing
DROP COLUMN SaleDate,         /* replaced by SaleDateConverted */
            PropertyAddress,  /* replaced by PropertySplitAddress and PropertySplitCity */
            OwnerAddress,     /* replaced by OwnerSplitAddress, OwnerSplitCity, OwnerSplitState */
            TaxDistrict;      /* not needed for our analysis */
