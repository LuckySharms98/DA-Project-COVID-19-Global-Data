SELECT *
FROM CovidPortfolio..CovidDeaths
WHERE continent is NOT NULL;--this helps us avoid continent locations, which have the continent field as NULL

SELECT *
FROM CovidPortfolio..CovidVaccinations
ORDER BY date;

--Let's start with the total deaths data
--SELECT location, date, total_cases, new_cases, total_deaths, population
--FROM CovidPortfolio..CovidDeaths;


--USA INFORMATION

--What percentage of the infected U.S. population has passed?
SELECT location, date, total_cases, total_deaths, (total_deaths/total_cases)*100 AS infected_death_percentage 
FROM CovidPortfolio..CovidDeaths
WHERE location = 'United States' AND continent is NOT NULL
ORDER BY date;

--What percentage of the U.S. population got infected?
SELECT location, date, population, total_cases, (total_cases/population)*100 AS infection_percentage
FROM CovidPortfolio..CovidDeaths
WHERE location = 'United States' AND continent is NOT NULL
ORDER BY date; 

--What percent of the U.S. population has passed from Covid?
SELECT location, date, population, total_deaths, (total_deaths/population)*100 AS total_death_percentage
FROM CovidPortfolio..CovidDeaths
WHERE location = 'United States' AND continent is NOT NULL
ORDER BY date; 

--TABLEAU TABLE 1: Let's look at ALL cases in total. This is insane. 
SELECT SUM(cast(new_cases as INT)) AS total_cases, SUM(cast(new_deaths as INT)) AS total_deaths, SUM(cast(new_deaths as INT))/SUM(new_cases)*100 AS death_percentage  --this lets us find the sum # of said statistic across ALL locations on a given date
FROM CovidPortfolio..CovidDeaths
WHERE continent IS NOT NULL; 

--TABLEAU TABLE 2: What's the breakdown of deaths per continent? 
SELECT location, max(cast(total_deaths as INT)) AS max_deaths_figure
FROM CovidPortfolio..CovidDeaths
WHERE continent IS NULL AND location NOT IN ('World','European Union', 'International') AND location NOT LIKE '%income%'
GROUP BY location 
ORDER BY max_deaths_figure DESC;

--Let's take a step back from the U.S. and instead look at something else.
--TABLEAU TABLE 3: What countries have the highest infection rate compared to the population? Let's look at the latest date given for each country. 
--Note that this is historical data relevant to the date at peak cases.
SELECT location, population, max(total_cases) AS max_cases_figure, max(total_cases/population)*100 AS max_cases_percentage
FROM CovidPortfolio..CovidDeaths
WHERE continent IS NOT NULL 
GROUP BY location, population
ORDER BY max_cases_percentage DESC;

--TABLEAU TABLE 4: Let's query the above but with the date field, so we can see how these cases evolve over time globally 
SELECT location, population, date, total_cases, (total_cases/population)*100 AS max_cases_percentage
FROM CovidPortfolio..CovidDeaths
WHERE continent IS NOT NULL 
GROUP BY location, population, date, total_cases
ORDER BY location, date;

SELECT location, population, date, max(total_cases), max(total_cases/population)*100 AS max_cases_percentage
FROM CovidPortfolio..CovidDeaths
WHERE continent IS NOT NULL AND location = 'Italy'
GROUP BY location, population, date
ORDER BY location, date;

--What countries have the highest death rate compared to the population?
--Note that this is historical data relevant to the date at peak cases.
SELECT location, population, max(cast(total_deaths as INT)) AS max_deaths_figure, max(total_deaths/population)*100 AS max_deaths_percentage
FROM CovidPortfolio..CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location, population
ORDER BY max_deaths_percentage DESC;


--Let's take a look at the global figures again. How do new cases and deaths evolve over time globally? Can we find a "peak time" for new cases/deaths? What about death rate? 
SELECT date, SUM(cast(new_cases as INT)) AS total_new_cases, SUM(cast(new_deaths as INT)) AS total_new_deaths, SUM(cast(new_deaths as INT))/SUM(new_cases)*100 AS death_percentage  --this lets us find the sum # of said statistic across ALL locations on a given date
FROM CovidPortfolio..CovidDeaths
WHERE continent IS NOT NULL 
GROUP BY date
ORDER BY date;



----------------------------------------------------------------------------------------
--JOINS--

--Let's join both our deaths and vaccinations tables, looking at total global population vs total vaccinations
SELECT *
FROM CovidPortfolio..CovidDeaths dea
JOIN CovidPortfolio..CovidVaccinations vac
	ON dea.location = vac.location AND dea.date = vac.date
WHERE dea.continent IS NOT NULL
--GROUP BY dea.location, dea.population, vac.total_vaccinations;


--I need to do an inner query where I select distinct population values, then do an outer query where I sum them up
SELECT DISTINCT population
FROM CovidPortfolio..CovidDeaths
WHERE continent is NOT NULL;

--then the outer query

SELECT SUM(cast(population AS float)) AS Global_Population
FROM
	(
	SELECT DISTINCT location, population
	FROM CovidPortfolio..CovidDeaths
	WHERE continent is NOT NULL
	) X --NEED ALIAS HERE
;

--Let's show a rolling total of vaccinations globally
SELECT dea.continent, dea.location, dea.population, dea.date, vac.new_vaccinations, SUM(cast(vac.new_vaccinations as bigint))
OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) AS rolling_total
FROM CovidPortfolio..CovidDeaths dea
JOIN CovidPortfolio..CovidVaccinations vac
	ON dea.location = vac.location AND dea.date = vac.date
WHERE dea.continent IS NOT NULL AND dea.location LIKE '%states%'
ORDER BY dea.location, dea.date;

--What if we wanted to look at a new statistic: rolling vaccination percentage? Let's use a CTE

With PopvsVac (Continent, Location, population, date, new_vaccinations, rolling_total)
AS
(
SELECT dea.continent, dea.location, dea.population, dea.date, vac.new_vaccinations, SUM(cast(vac.new_vaccinations as bigint))
OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) AS rolling_total-- (rolling_total/dea.population)*100 AS rolling_percent
FROM CovidPortfolio..CovidDeaths dea
JOIN CovidPortfolio..CovidVaccinations vac
	ON dea.location = vac.location AND dea.date = vac.date
WHERE dea.continent IS NOT NULL AND dea.location LIKE '%states%'
)
SELECT *, (rolling_total/population)*100 AS rolling_percentage
FROM PopvsVac
ORDER BY location, date


-- TEMP TABLE containing above data
DROP Table if exists #TempVacData
CREATE TABLE #TempVacData
(
Continent nvarchar(255), Location nvarchar(255), Date datetime, Population numeric, New_Vaccinations numeric, Rolling_Total numeric)

INSERT INTO #TempVacData
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations, SUM(cast(vac.new_vaccinations as bigint))
OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) AS rolling_total
FROM CovidPortfolio..CovidDeaths dea
JOIN CovidPortfolio..CovidVaccinations vac
	ON dea.location = vac.location AND dea.date = vac.date
WHERE dea.continent IS NOT NULL;

SELECT *
FROM #TempVacData;

--Now that we have all of this data, why don't we create a view?

USE CovidPortfolio
GO 
CREATE VIEW TempVacData AS
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations, SUM(cast(vac.new_vaccinations as bigint))
OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) AS rolling_total
FROM CovidPortfolio..CovidDeaths dea
JOIN CovidPortfolio..CovidVaccinations vac
	ON dea.location = vac.location AND dea.date = vac.date
WHERE dea.continent IS NOT NULL;
