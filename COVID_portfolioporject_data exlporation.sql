Select *
From [portfolio project]..CovidDeaths$
where continent is not null
order by 3,4


--select data that we are going to be using


Select location, date, total_cases, new_cases, total_deaths, population
From [portfolio project]..CovidDeaths$
where continent is not null -- for visual purpose
order by 1,2


-- Looking at total cases vs total countries
-- shows the likihood of dying if you contract covid in your country

Select location, date, total_cases, total_deaths, (total_deaths/total_cases)*100 as DeathPercentage
From [portfolio project]..CovidDeaths$
where location like '%states%'
and continent is not null -- for visual purpose
order by 1,2


-- looling at the total case vs population
-- shows what percentage of people got covid

Select location, date, Population, total_cases, (total_cases/population)*100 as DeathPercentage
From [portfolio project]..CovidDeaths$
-- where location like '%states%'
order by 1,2



-- looking at countries with Higest Infection Rate compared to population

Select location, Population, MAX(total_cases) as HigestInfectionCount, MAX((total_cases/population))*100  as PercentPopulationInfected
From [portfolio project]..CovidDeaths$
-- where location like '%states%'
Group by location, population
order by PercentPopulationInfected desc

-- countries with Highest Death Count per Population 
-- the datatype in nvarchar, we are converting into integer

Select location, MAX(cast(total_deaths as int)) as TotalDeathCount
From [portfolio project]..CovidDeaths$
-- where location like '%states%'
where continent is not null 
Group by location
order by TotalDeathCount desc


-- LET'S BREAK THINGS DOWN BY CONTINENT



-- Showing continets with higest death count per population

Select continent, MAX(cast(total_deaths as int)) as TotalDeathCount
From [portfolio project]..CovidDeaths$
-- where location like '%states%'
where continent is not null 
Group by continent
order by TotalDeathCount desc



-- GLOBAL NUMBERS

Select date, SUM (new_cases) as total_cases, 
SUM(cast(new_deaths as int)) as total_deaths, SUM(cast(new_deaths as int))/
SUM(new_cases)*100 as DeathPercentage
From [portfolio project]..CovidDeaths$
-- where location like '%states%'
where continent is not null 
group by date
order by 1,2



Select SUM (new_cases) as total_cases, 
SUM(cast(new_deaths as int)) as total_deaths, SUM(cast(new_deaths as int))/
SUM(new_cases)*100 as DeathPercentage
From [portfolio project]..CovidDeaths$
-- where location like '%states%'
where continent is not null 
-- group by date
order by 1,2




-- Looking for Total Population vs Vaccinations

Select dea.continent, dea.location,dea.date,dea.population, vac.new_vaccinations
, SUM(CONVERT(int,vac.new_vaccinations)) OVER (Partition by dea.location order by dea.location, dea.date) -- adds up every single location
  as RollingPeopleVaccinated
-- (RollingPeopleVaccinated/population)*100 
from [portfolio project]..CovidDeaths$ dea -- dea is a alias 
Join [portfolio project]..CovidVaccinations$ vac -- vac is a alias
     on dea.location = vac.location -- joining tables by location
     and dea.date = vac.date -- joining tables by date
where dea.continent is not null
order by 2,3


-- USE CTE (Temp table)

With PopvsVac (Continent, Location, Date, Population, New_Vaccinations, RollingPeopleVaccinated)
as
(
Select dea.continent, dea.location,dea.date,dea.population, vac.new_vaccinations
, SUM(CONVERT(int,vac.new_vaccinations)) OVER (Partition by dea.location order by dea.location, dea.date) -- adds up every single location
  as RollingPeopleVaccinated
-- (RollingPeopleVaccinated/population)*100 
from [portfolio project]..CovidDeaths$ dea -- dea is a alias 
Join [portfolio project]..CovidVaccinations$ vac -- vac is a alias
     on dea.location = vac.location -- joining tables by location
     and dea.date = vac.date -- joining tables by date
where dea.continent is not null
-- order by 2,3
)
Select *, (RollingPeopleVaccinated/Population)*100
From PopvsVac


-- TEMP TABLE

DROP Table if exists #PercentagePeopleVaccinated
Create Table #PercentagePeopleVaccinated -- we are creating geunine table so we have to provide date type
(
Continent nvarchar(255),
Location nvarchar(255),
Date datetime,
Population numeric,
New_vaccinations numeric,
RollingPeopleVaccinated numeric
)

Insert into #PercentagePeopleVaccinated
Select dea.continent, dea.location,dea.date,dea.population, vac.new_vaccinations
, SUM(CONVERT(int,vac.new_vaccinations)) OVER (Partition by dea.location order by dea.location, dea.date) -- adds up every single location
  as RollingPeopleVaccinated
-- (RollingPeopleVaccinated/population)*100 
from [portfolio project]..CovidDeaths$ dea -- dea is a alias 
Join [portfolio project]..CovidVaccinations$ vac -- vac is a alias
     on dea.location = vac.location -- joining tables by location
     and dea.date = vac.date -- joining tables by date
-- where dea.continent is not null
-- order by 2,3


Select *, (RollingPeopleVaccinated/Population)*100
From #PercentagePeopleVaccinated


-- Creating view for storing data for later visulizations

Create View PercentagePeopleVaccinated as
Select dea.continent, dea.location,dea.date,dea.population, vac.new_vaccinations
, SUM(CONVERT(int,vac.new_vaccinations)) OVER (Partition by dea.location order by dea.location, dea.date) -- adds up every single location
  as RollingPeopleVaccinated
-- (RollingPeopleVaccinated/population)*100 
from [portfolio project]..CovidDeaths$ dea -- dea is a alias 
Join [portfolio project]..CovidVaccinations$ vac -- vac is a alias
     on dea.location = vac.location -- joining tables by location
     and dea.date = vac.date -- joining tables by date
 where dea.continent is not null
 -- order by 2,3


 Select *
 From RollingPeopleVaccinated

