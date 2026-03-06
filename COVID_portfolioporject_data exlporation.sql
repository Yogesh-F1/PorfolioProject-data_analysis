/*
====================================================================================
    PROJECT      : COVID-19 Data Exploration
    TABLES       : CovidDeaths$, CovidVaccinations$
    DESCRIPTION  : This script explores global COVID-19 data to uncover trends in
                   cases, deaths, and vaccinations. We look at death rates by country,
                   infection rates relative to population, continent-level breakdowns,
                   worldwide totals, and how vaccination numbers grew over time.
                   The final section saves a key query as a View so it can be reused
                   later for dashboards or visualizations.
====================================================================================
*/


/* Quick look at everything in the deaths table to understand what we're working with */
SELECT *
FROM   [portfolio project]..CovidDeaths$
WHERE  continent IS NOT NULL
ORDER BY 3, 4;


/* ==================================================================================
   SECTION 1: Pick the Columns We Actually Need
   Instead of pulling every column, we narrow it down to the ones relevant
   to our analysis — location, date, cases, deaths, and population.
   ================================================================================== */

SELECT location,
       date,
       total_cases,
       new_cases,
       total_deaths,
       population
FROM   [portfolio project]..CovidDeaths$
WHERE  continent IS NOT NULL    /* rows where continent is null are continent-level totals, not countries */
ORDER BY 1, 2;


/* ==================================================================================
   SECTION 2: Death Rate — Total Cases vs Total Deaths
   This tells us: if someone caught COVID in a given country on a given day,
   what was the chance they died from it? We filter to the United States here
   but you can remove the WHERE line to see all countries.
   ================================================================================== */

SELECT location,
       date,
       total_cases,
       total_deaths,
       (total_deaths / total_cases) * 100 AS DeathPercentage
FROM   [portfolio project]..CovidDeaths$
WHERE  location    LIKE '%states%'
AND    continent   IS NOT NULL
ORDER BY 1, 2;


/* ==================================================================================
   SECTION 3: Infection Rate — Total Cases vs Population
   This answers: what percentage of a country's population ever tested positive?
   A higher number means the virus spread more widely through that population.
   ================================================================================== */

SELECT location,
       date,
       population,
       total_cases,
       (total_cases / population) * 100 AS PercentPopulationInfected
FROM   [portfolio project]..CovidDeaths$
ORDER BY 1, 2;


/* ==================================================================================
   SECTION 4: Countries with the Highest Infection Rate
   We take the peak case count for each country and compare it to population size.
   This shows which countries were hit hardest relative to how many people live there.
   ================================================================================== */

SELECT   location,
         population,
         MAX(total_cases)                        AS HighestInfectionCount,
         MAX((total_cases / population)) * 100   AS PercentPopulationInfected
FROM     [portfolio project]..CovidDeaths$
GROUP BY location,
         population
ORDER BY PercentPopulationInfected DESC;


/* ==================================================================================
   SECTION 5: Countries with the Highest Total Death Count
   We sum up total deaths per country to rank which countries lost the most lives.
   Note: total_deaths is stored as text (nvarchar) in the dataset, so we cast it
   to an integer before doing any math with it.
   ================================================================================== */

SELECT   location,
         MAX(CAST(total_deaths AS INT)) AS TotalDeathCount
FROM     [portfolio project]..CovidDeaths$
WHERE    continent IS NOT NULL
GROUP BY location
ORDER BY TotalDeathCount DESC;


/* ==================================================================================
   SECTION 6: Breaking It Down by Continent
   Now we zoom out from individual countries and look at entire continents.
   This gives a higher-level picture of where the most deaths occurred globally.
   ================================================================================== */

SELECT   continent,
         MAX(CAST(total_deaths AS INT)) AS TotalDeathCount
FROM     [portfolio project]..CovidDeaths$
WHERE    continent IS NOT NULL
GROUP BY continent
ORDER BY TotalDeathCount DESC;


/* ==================================================================================
   SECTION 7: Global Numbers by Day
   This rolls up every country's new cases and new deaths into a single worldwide
   total per day. The death percentage here reflects the global daily death rate.
   ================================================================================== */

SELECT   date,
         SUM(new_cases)                                            AS total_cases,
         SUM(CAST(new_deaths AS INT))                              AS total_deaths,
         SUM(CAST(new_deaths AS INT)) / SUM(new_cases) * 100      AS DeathPercentage
FROM     [portfolio project]..CovidDeaths$
WHERE    continent IS NOT NULL
GROUP BY date
ORDER BY 1, 2;


/* ==================================================================================
   SECTION 8: Single Global Total (All Time)
   Same as above but without grouping by date — this gives us one row:
   the overall worldwide case count, death count, and death rate across the whole dataset.
   ================================================================================== */

SELECT SUM(new_cases)                                        AS total_cases,
       SUM(CAST(new_deaths AS INT))                          AS total_deaths,
       SUM(CAST(new_deaths AS INT)) / SUM(new_cases) * 100  AS DeathPercentage
FROM   [portfolio project]..CovidDeaths$
WHERE  continent IS NOT NULL
ORDER BY 1, 2;


/* ==================================================================================
   SECTION 9: Population vs Vaccinations — Rolling Count
   Here we join the deaths table with the vaccinations table to see how many people
   in each country had been vaccinated over time. The rolling total adds up each
   day's new vaccinations to give a running cumulative count per country.
   ================================================================================== */

SELECT dea.continent,
       dea.location,
       dea.date,
       dea.population,
       vac.new_vaccinations,
       SUM(CONVERT(INT, vac.new_vaccinations))
           OVER (PARTITION BY dea.location               /* restart the running total for each new country */
                 ORDER BY     dea.location, dea.date)    /* add each day's vaccinations to the total so far */
           AS RollingPeopleVaccinated
FROM   [portfolio project]..CovidDeaths$      dea
JOIN   [portfolio project]..CovidVaccinations$ vac
       ON  dea.location = vac.location
       AND dea.date     = vac.date
WHERE  dea.continent IS NOT NULL
ORDER BY 2, 3;


/* ==================================================================================
   SECTION 10: Using a CTE to Calculate Vaccination Percentage
   We can't use a calculated column (like RollingPeopleVaccinated) inside the same
   SELECT that creates it. A CTE solves this — it lets us name the query above,
   then reference its result in a second SELECT to do the final percentage math.
   ================================================================================== */

WITH PopvsVac (Continent, Location, Date, Population, New_Vaccinations, RollingPeopleVaccinated)
AS
(
    SELECT dea.continent,
           dea.location,
           dea.date,
           dea.population,
           vac.new_vaccinations,
           SUM(CONVERT(INT, vac.new_vaccinations))
               OVER (PARTITION BY dea.location
                     ORDER BY     dea.location, dea.date)
               AS RollingPeopleVaccinated
    FROM   [portfolio project]..CovidDeaths$       dea
    JOIN   [portfolio project]..CovidVaccinations$ vac
           ON  dea.location = vac.location
           AND dea.date     = vac.date
    WHERE  dea.continent IS NOT NULL
)
/* Now we can use RollingPeopleVaccinated to calculate the percentage */
SELECT *,
       (RollingPeopleVaccinated / Population) * 100 AS PercentVaccinated
FROM   PopvsVac;


/* ==================================================================================
   SECTION 11: Temp Table — Same Result, Different Approach
   A temp table does the same job as the CTE above, but stores the data physically
   (just for the duration of your session). This can be useful for larger datasets
   or when you want to query the intermediate results multiple times.
   We drop it first in case it already exists from a previous run.
   ================================================================================== */

DROP TABLE IF EXISTS #PercentagePeopleVaccinated;

/* Define the shape of our temp table — column names and data types */
CREATE TABLE #PercentagePeopleVaccinated
(
    Continent              NVARCHAR(255),
    Location               NVARCHAR(255),
    Date                   DATETIME,
    Population             NUMERIC,
    New_Vaccinations       NUMERIC,
    RollingPeopleVaccinated NUMERIC
);

/* Fill the temp table with the same rolling vaccination data as before */
INSERT INTO #PercentagePeopleVaccinated
SELECT dea.continent,
       dea.location,
       dea.date,
       dea.population,
       vac.new_vaccinations,
       SUM(CONVERT(INT, vac.new_vaccinations))
           OVER (PARTITION BY dea.location
                 ORDER BY     dea.location, dea.date)
           AS RollingPeopleVaccinated
FROM   [portfolio project]..CovidDeaths$       dea
JOIN   [portfolio project]..CovidVaccinations$ vac
       ON  dea.location = vac.location
       AND dea.date     = vac.date;

/* Pull from the temp table and calculate the final vaccination percentage */
SELECT *,
       (RollingPeopleVaccinated / Population) * 100 AS PercentVaccinated
FROM   #PercentagePeopleVaccinated;


/* ==================================================================================
   SECTION 12: Create a View for Future Visualizations
   A View saves this query permanently in the database under a name we can reuse.
   Unlike a temp table, it doesn't go away when your session ends — making it
   ideal for connecting to tools like Tableau or Power BI later on.
   ================================================================================== */

CREATE VIEW PercentagePeopleVaccinated AS
SELECT dea.continent,
       dea.location,
       dea.date,
       dea.population,
       vac.new_vaccinations,
       SUM(CONVERT(INT, vac.new_vaccinations))
           OVER (PARTITION BY dea.location
                 ORDER BY     dea.location, dea.date)
           AS RollingPeopleVaccinated
FROM   [portfolio project]..CovidDeaths$       dea
JOIN   [portfolio project]..CovidVaccinations$ vac
       ON  dea.location = vac.location
       AND dea.date     = vac.date
WHERE  dea.continent IS NOT NULL;

/* Query the view just like any regular table */
SELECT *
FROM   PercentagePeopleVaccinated;

