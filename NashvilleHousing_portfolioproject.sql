/*
=======================================================================================
	PROJECT: Nashville Housing Data Cleaning
	PURPOSE: Data standardization, cleaning, and preparation for analysis
=======================================================================================
*/

-- ===== 1. VIEW RAW DATA =====

SELECT *
FROM [portfolio project]..NashvilleHousing;


-- ===== 2. STANDARDIZE DATE FORMAT =====

-- Step 1: Preview the date conversion
SELECT 
	SaleDateConverted, 
	CONVERT(DATE, SaleDate) AS ConvertedDate
FROM [portfolio project]..NashvilleHousing;

-- Step 2: Add new column for standardized date
ALTER TABLE NashvilleHousing
ADD SaleDateConverted DATE;

-- Step 3: Populate the new column with converted dates
UPDATE NashvilleHousing
SET SaleDateConverted = CONVERT(DATE, SaleDate);


-- ===== 3. POPULATE MISSING PROPERTY ADDRESS DATA =====

-- Step 1: View all data ordered by ParcelID
SELECT *
FROM [portfolio project]..NashvilleHousing
ORDER BY ParcelID;

-- Step 2: Identify missing addresses using self-join
-- Logic: If ParcelID is the same, PropertyAddress must be the same
SELECT 
	a.ParcelID, 
	a.PropertyAddress,
	b.ParcelID,
	b.PropertyAddress, 
	ISNULL(a.PropertyAddress, b.PropertyAddress) AS PopulatedAddress
FROM [portfolio project]..NashvilleHousing a
JOIN [portfolio project]..NashvilleHousing b
	ON a.ParcelID = b.ParcelID
	AND a.[UniqueID ] <> b.[UniqueID ]
WHERE a.PropertyAddress IS NULL;

-- Step 3: Update missing addresses with matching ParcelID addresses
UPDATE a
SET PropertyAddress = ISNULL(a.PropertyAddress, b.PropertyAddress)
FROM [portfolio project]..NashvilleHousing a
JOIN [portfolio project]..NashvilleHousing b
	ON a.ParcelID = b.ParcelID
	AND a.[UniqueID ] <> b.[UniqueID ]
WHERE a.PropertyAddress IS NULL;


-- ===== 4. BREAK OUT ADDRESS INTO INDIVIDUAL COLUMNS (ADDRESS, CITY, STATE) =====

-- ===== 4A: PROPERTY ADDRESS SPLIT =====

-- Step 1: Preview PropertyAddress split
SELECT PropertyAddress
FROM [portfolio project]..NashvilleHousing;

-- Step 2: Preview the split operation
SELECT 
	SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress) - 1) AS Address,
	SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress) + 1, LEN(PropertyAddress)) AS City
FROM [portfolio project]..NashvilleHousing;

-- Step 3: Add PropertySplitAddress column
ALTER TABLE NashvilleHousing
ADD PropertySplitAddress NVARCHAR(255);

-- Step 4: Populate PropertySplitAddress
UPDATE NashvilleHousing
SET PropertySplitAddress = SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress) - 1);

-- Step 5: Add PropertySplitCity column
ALTER TABLE NashvilleHousing
ADD PropertySplitCity NVARCHAR(255);

-- Step 6: Populate PropertySplitCity
UPDATE NashvilleHousing
SET PropertySplitCity = SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress) + 1, LEN(PropertyAddress));

-- Step 7: View updated table
SELECT *
FROM [portfolio project]..NashvilleHousing;


-- ===== 4B: OWNER ADDRESS SPLIT =====

-- Step 1: Preview OwnerAddress
SELECT OwnerAddress
FROM [portfolio project]..NashvilleHousing;

-- Step 2: Preview the split operation using PARSENAME
-- PARSENAME reads from right to left; commas are replaced with periods as delimiters
SELECT
	PARSENAME(REPLACE(OwnerAddress, ',', '.'), 3) AS Address,
	PARSENAME(REPLACE(OwnerAddress, ',', '.'), 2) AS City,
	PARSENAME(REPLACE(OwnerAddress, ',', '.'), 1) AS State
FROM [portfolio project]..NashvilleHousing;

-- Step 3: Add OwnerSplitAddress column
ALTER TABLE NashvilleHousing
ADD OwnerSplitAddress NVARCHAR(255);

-- Step 4: Populate OwnerSplitAddress
UPDATE NashvilleHousing
SET OwnerSplitAddress = PARSENAME(REPLACE(OwnerAddress, ',', '.'), 3);

-- Step 5: Add OwnerSplitCity column
ALTER TABLE NashvilleHousing
ADD OwnerSplitCity NVARCHAR(255);

-- Step 6: Populate OwnerSplitCity
UPDATE NashvilleHousing
SET OwnerSplitCity = PARSENAME(REPLACE(OwnerAddress, ',', '.'), 2);

-- Step 7: Add OwnerSplitState column
ALTER TABLE NashvilleHousing
ADD OwnerSplitState NVARCHAR(255);

-- Step 8: Populate OwnerSplitState
UPDATE NashvilleHousing
SET OwnerSplitState = PARSENAME(REPLACE(OwnerAddress, ',', '.'), 1);

-- Step 9: View updated table with all new columns
SELECT *
FROM [portfolio project]..NashvilleHousing;


-- ===== 5. STANDARDIZE 'SOLD AS VACANT' FIELD (Y/N to YES/NO) =====

-- Step 1: Check distinct values and their count
SELECT 
	DISTINCT(SoldAsVacant), 
	COUNT(SoldAsVacant) AS Count
FROM [portfolio project]..NashvilleHousing
GROUP BY SoldAsVacant
ORDER BY Count;

-- Step 2: Preview the conversion using CASE statement
SELECT 
	SoldAsVacant,
	CASE 
		WHEN SoldAsVacant = 'Y' THEN 'Yes'
		WHEN SoldAsVacant = 'N' THEN 'No'
		ELSE SoldAsVacant
	END AS SoldAsVacantStandardized
FROM [portfolio project]..NashvilleHousing;

-- Step 3: Update the column with standardized values
UPDATE NashvilleHousing
SET SoldAsVacant = CASE 
		WHEN SoldAsVacant = 'Y' THEN 'Yes'
		WHEN SoldAsVacant = 'N' THEN 'No'
		ELSE SoldAsVacant
	END;


-- ===== 6. IDENTIFY AND REMOVE DUPLICATES =====

-- NOTE: Best practice is NOT to delete duplicates from raw data directly
-- This query identifies duplicates; use DELETE instead of SELECT to remove them

-- Step 1: Create CTE to identify duplicate records
WITH RowNumCTE AS (
	SELECT 
		*,
		ROW_NUMBER() OVER(
			PARTITION BY 
				ParcelID,
				PropertyAddress,
				SalePrice,
				SaleDate,
				LegalReference
			ORDER BY UniqueID
		) AS row_num
	FROM [portfolio project]..NashvilleHousing
)

-- Step 2: View duplicate records (row_num > 1)
SELECT *
FROM RowNumCTE
WHERE row_num > 1;

-- To DELETE duplicates, replace SELECT with DELETE in the query above


-- ===== 7. DELETE UNUSED COLUMNS =====

-- NOTE: Best practice is NOT to delete columns from raw data
-- Only do this on a cleaned copy of the data

-- Step 1: View all columns before deletion
SELECT *
FROM [portfolio project]..NashvilleHousing;

-- Step 2: Drop unused columns (SaleDate, PropertyAddress, OwnerAddress, TaxDistrict)
ALTER TABLE [portfolio project]..NashvilleHousing
DROP COLUMN SaleDate, PropertyAddress, OwnerAddress, TaxDistrict;

/*
=======================================================================================
	END OF DATA CLEANING PROCESS
	All columns are now standardized and ready for analysis
=======================================================================================
*/