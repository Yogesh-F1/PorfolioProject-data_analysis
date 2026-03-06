Select *
from [portfolio project]..NashvilleHousing

-----------------------------------------------------------------------------------

-- Standardize Date Format

Select SaleDateConverted, CONVERT(Date, SaleDate)
from [portfolio project]..NashvilleHousing

Update NashvilleHousing
Set SaleDate = CONVERT(Date, SaleDate)

ALTER TABLE NashvilleHousing
Add SaleDateConverted Date;

Update NashvilleHousing
SET SaleDateConverted = CONVERT(Date, SaleDate)


-------------------------------------------------------------------------------------

-- Populate Property address data

Select *
from [portfolio project]..NashvilleHousing
-- Where PropertyAddress is null
order by ParcelID

-- If ParcelID does not have address (if ParcelID is same then PropertyAddress must be same)

Select a.ParcelID, a.PropertyAddress,b.ParcelID,b.PropertyAddress, ISNULL(a.PropertyAddress,b.PropertyAddress)
from [portfolio project]..NashvilleHousing a
JOIN [portfolio project]..NashvilleHousing b
     on a.ParcelID = b.ParcelID                 -- join two exact table the same
     AND a.[UniqueID ] <> b.[UniqueID ] 
Where a.PropertyAddress is null

Update a
SET PropertyAddress = ISNULL(a.PropertyAddress,b.PropertyAddress) -- checks if a.PropertyAddress is null then it can populate with b.PropertyAddress) 
from [portfolio project]..NashvilleHousing a
JOIN [portfolio project]..NashvilleHousing b
     on a.ParcelID = b.ParcelID                 -- join two exact table the same
     AND a.[UniqueID ] <> b.[UniqueID ] 
Where a.PropertyAddress is null


----------------------------------------------------------------------------------------------

-- Breaking out the address into Individual Columns (Address, City, State)


Select PropertyAddress
from [portfolio project]..NashvilleHousing


Select 
SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress) -1) as Address --(can put anything,e.g word in place of ,(',')
-- 1 is index postion, we are going to , and coming back one postion back to remove the ,
,SUBSTRING(PropertyAddress,CHARINDEX(',', PropertyAddress) +1, LEN(PropertyAddress)) as Address 
-- every address has a different address, thats why we mentioned len
from [portfolio project]..NashvilleHousing


ALTER TABLE NashvilleHousing
Add PropertySplitAddress nvarchar(255);

Update NashvilleHousing
SET PropertySplitAddress = SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress) -1)

ALTER TABLE NashvilleHousing   -- create new column
Add PropertySplitCity nvarchar(255);

Update NashvilleHousing  -- create new column
SET PropertySplitCity = SUBSTRING(PropertyAddress,CHARINDEX(',', PropertyAddress) +1, LEN(PropertyAddress))

Select *
from [portfolio project]..NashvilleHousing




Select OwnerAddress
from [portfolio project]..NashvilleHousing

Select
PARSENAME(REPLACE(OwnerAddress, ',', '.'), 3) -- PARSENAME goes backwards '.' is period (delimited by certain value)
,PARSENAME(REPLACE(OwnerAddress, ',', '.'), 2)
,PARSENAME(REPLACE(OwnerAddress, ',', '.'), 1)
from [portfolio project]..NashvilleHousing


ALTER TABLE NashvilleHousing
Add OwnerSplitAddress nvarchar(255);

Update NashvilleHousing
SET OwnerSplitAddress = PARSENAME(REPLACE(OwnerAddress, ',', '.'), 3)

ALTER TABLE NashvilleHousing   -- create new column
Add OwnerSplitCity nvarchar(255);

Update NashvilleHousing  -- create new column
SET OwnerSplitCity = PARSENAME(REPLACE(OwnerAddress, ',', '.'), 2)


ALTER TABLE NashvilleHousing   -- create new column
Add OwnerSplitState nvarchar(255);

Update NashvilleHousing  -- create new column
SET OwnerSplitState = PARSENAME(REPLACE(OwnerAddress, ',', '.'), 1)

Select *
from [portfolio project]..NashvilleHousing



-----------------------------------------------------------------------------------------------

-- Select Y or N as Yes or No as "sold or vacant" field

Select Distinct(SoldAsVacant), COUNT(SoldAsVacant)
from [portfolio project]..NashvilleHousing
Group by SoldAsVacant
order by 2


Select SoldAsVacant
, CASE When SoldAsVacant = 'Y' THEN 'Yes'
       When SoldAsVacant = 'N' THEN 'No'
       ELSE SoldAsVacant
       END
from [portfolio project]..NashvilleHousing

Update NashvilleHousing
SET SoldAsVacant = CASE When SoldAsVacant = 'Y' THEN 'Yes'
       When SoldAsVacant = 'N' THEN 'No'
       ELSE SoldAsVacant
       END




-----------------------------------------------------------------------------------

-- Remove Duplicates (its not a standard practise to delete the duplicates in the dataset)
-- create a cte table(temporary) to find out the duplicates
WITH RowNumCTE AS(
Select *,
     ROW_NUMBER() OVER(
     PARTITION BY ParcelID,
                  PropertyAddress,
                  SalePrice,
                  SaleDate,
                  LegalReference
                  ORDER BY
                  UniqueID
                  ) row_num

from [portfolio project]..NashvilleHousing
-- order by ParcelID
)

Select *   --(Instead of select, write DELETE for remove duplicates and again run to check the status)
from RowNumCTE
where row_num > 1
-- order by PropertyAddress


-------------------------------------------------------------------------------------------------------

-- Delete Unused Columns (don't do this to the raw data)

Select *
from [portfolio project]..NashvilleHousing

ALTER TABLE [portfolio project]..NashvilleHousing
DROP COLUMN SaleDate, PropertyAddress, OwnerAddress, TaxDistrict