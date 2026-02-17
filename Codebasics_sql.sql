create schema Newspaper;
CREATE TABLE cities (
    city_id VARCHAR(10) PRIMARY KEY,
    city VARCHAR(100) NOT NULL,
    state varchar(100) NOT NULL,
    tier VARCHAR(20) NOT NULL
);
CREATE TABLE ad_categories (
    ad_category_id VARCHAR(10) PRIMARY KEY,
    standard_ad_category VARCHAR(100) NOT NULL,
    category_group VARCHAR(100) NOT NULL,
    example_brands VARCHAR(100)
);

-- Create fact_digital_pilot table
CREATE TABLE fact_digital_pilot (
    fact_digital_pilot_id INT AUTO_INCREMENT PRIMARY KEY,
    platform VARCHAR(100) NOT NULL,
    launch_month DATE NOT NULL,
    ad_category_id VARCHAR(10),
    dev_cost DECIMAL(12,2),
    marketing_cost DECIMAL(12,2),
    users_reached INT,
    downloads_or_accesses INT,
    avg_bounce_rate DECIMAL(5,2),
    cumulative_feedback_from_customers TEXT,
    city_id VARCHAR(10),
    
    -- Foreign Keys
    CONSTRAINT fk_ad_category FOREIGN KEY (ad_category_id) REFERENCES ad_categories(ad_category_id),
    CONSTRAINT fk_city FOREIGN KEY (city_id) REFERENCES cities(city_id)
);
CREATE TABLE editions (
    edition_id VARCHAR(20) NOT NULL,
    city_id VARCHAR(10) NOT NULL,
    language VARCHAR(50) NOT NULL,
    state VARCHAR(100) NOT NULL,
    month DATE NOT NULL,
    copies_sold INT NOT NULL,
    copies_returned INT NOT NULL,
    net_circulation INT NOT NULL,
    FOREIGN KEY (city_id) REFERENCES cities(city_id)
);

CREATE TABLE fact_city_readline (
    Fact_ad_city_read_id INT NOT NULL PRIMARY KEY,
    city_id VARCHAR(10) NOT NULL,
    year date,
    literacy_rate DECIMAL(10 , 2 ),
    smartphone_penetration DECIMAL(10 , 2 ),
    internet_penetration DECIMAL(10 , 2 ),
    quarter varchar(10),
    CONSTRAINT fk_city_id FOREIGN KEY (city_id) REFERENCES cities (city_id)
);

create table fact_ad_revenue (
edition_id	 varchar(10) not null,
ad_category	varchar(10)	not null,
ad_revenue	decimal(10,2)	,
currency	varchar(10)	,
year Date not null,
quarter varchar(10),
foreign key (ad_category) references ad_categories(ad_category_id)
);

-- Business Request – 1: Monthly Circulation Drop Check 
-- Generate a report showing the top 3 months (2019–2024) where any city recorded the 
-- sharpest month-over-month decline in net_circulation. 
-- Fields: 
-- • city_name 
-- • month (YYYY-MM) 
-- • net_circulation 

select c.city,e.net_circulation, DATE_FORMAT(e.month, '%Y-%m') AS month,
LAG(e.net_circulation, 1, 0) OVER (ORDER BY e.month) AS previous_month_conversions,
(e.net_circulation - LAG(e.net_circulation, 1, 0) OVER (ORDER BY e.month)) AS Declined_Convertion 
from editions as e
join cities as c
on c.city_id = e.city_id
order by (e.net_circulation - LAG(e.net_circulation, 1, 0) OVER (ORDER BY e.month)) desc
limit 4;


-- Business Request – 2: Yearly Revenue Concentration by Category 
-- Identify ad categories that contributed > 50% of total yearly ad revenue. 
-- Fields: 
-- • year 
-- • category_name 
-- • category_revenue  
-- • total_revenue_year  
-- • pct_of_year_total
select f.year,a.standard_ad_category as Ad_category, sum(f.ad_revenue) as Revenue_By_Category_Year, yearly.total_revenue_year as Total_Revenue_In_Year,
ROUND(SUM(f.ad_revenue) / yearly.total_revenue_year * 100, 2) AS pct_of_year_total
from fact_ad_revenue as f
join ad_categories as a
on a.ad_category_id = f.ad_category
join (SELECT 
        year,
        sum(ad_revenue) AS total_revenue_year
    FROM fact_ad_revenue
    GROUP BY year) as yearly
on yearly.year = f.year
group by 1,2
order by f.year desc;


-- Business Request – 3: 2024 Print Efficiency Leaderboard 
-- For 2024, rank cities by print efficiency = net_circulation / copies_printed. Return top 5. 
-- Fields: 
-- • city_name 
-- • copies_printed_2024 
-- • net_circulation_2024 
-- • efficiency_ratio = net_circulation_2024 / copies_printed_2024 
-- • efficiency_rank_2024 
SELECT 
    c.city,
    (e.copies_sold + e.copies_returned) AS copies_printed_2024,
    e.net_circulation AS net_circulation_2024,
    (e.net_circulation) / (e.copies_sold + e.copies_returned) AS efficiency_ratio,
    RANK() OVER (ORDER BY  (e.net_circulation) / (e.copies_sold + e.copies_returned) DESC) AS efficiency_rank_2024
from editions as e
join cities as c
on c.city_id = e.city_id
order by efficiency_ratio desc
limit 5;

-- Business Request – 4 : Internet Readiness Growth (2021) 
-- For each city, compute the change in internet penetration from Q1-2021 to Q4-2021 
-- and identify the city with the highest improvement. 
-- Fields: 
-- • city_name 
-- • internet_rate_q1_2021 
-- • internet_rate_q4_2021 
-- • delta_internet_rate = internet_rate_q4_2021 − internet_rate_q1_2021 
select City,Q1,Q4,(Q4-Q1) as delta_internet_rate
from
 ((select c.city  as City,f.internet_penetration as Q1  from fact_city_readline as f join cities as c 
on c.city_id = f.city_id
where YEAR(year) = 2021 AND quarter = "Q1") as internet_rate_q1_2021,
(select internet_penetration as Q4  from fact_city_readline
where YEAR(year) = 2021 AND quarter = "Q4") as internet_rate_q4_2021 )
order by delta_internet_rate desc
limit 1;

-- Business Request – 5: Consistent Multi-Year Decline (2019→2024) 
-- Find cities where both net_circulation and ad_revenue decreased every year from 2019 
-- through 2024 (strictly decreasing sequences). 
-- Fields: 
-- • city_name 
-- • year 
-- • yearly_net_circulation 
-- • yearly_ad_revenue 
-- • is_declining_print (Yes/No per city over 2019–2024) 
-- • is_declining_ad_revenue (Yes/No) 
-- • is_declining_both (Yes/No) 
select * from cities;
select * from editions;
select * from fact_ad_revenue;
select * from fact_city_readline;
select * from fact_digital_pilot;
select * from ad_categories;

select year(e.month),year(year),sum(f.ad_revenue), sum(e.net_circulation)
 from fact_ad_revenue as f
 join editions as e
 on e.edition_id = f.edition_id
 where year(e.month) = year(year) 
group by 1,2;
select year(month), sum(net_circulation)
from editions
group by 1;
select year(year), sum(ad_revenue)
from fact_ad_revenue
group by 1;
    
 WITH yearly_circulation AS (
 SELECT 
        e.city_id,
        YEAR(e.month) AS year,
        SUM(e.net_circulation) AS yearly_net_circulation
    FROM editions e
    WHERE YEAR(e.month) BETWEEN 2019 AND 2024
    GROUP BY e.city_id, YEAR(e.month)),
yearly_revenue AS (
SELECT 
        f.year,c.city,c.city_id,
        SUM(f.ad_revenue) AS yearly_ad_revenue
    FROM fact_ad_revenue f
    join editions as e
    on e.edition_id = f.edition_id
    join cities as c
    on c.city_id  = e.city_id
    GROUP BY c.city_id, f.year),
    combined as (
SELECT 
        c.city as city,
        year(r.year) as year,
        sum(n.yearly_net_circulation) as yearly_net_circulation,
        sum(r.yearly_ad_revenue) as yearly_ad_revenue
    FROM yearly_circulation n
    JOIN yearly_revenue r 
        ON n.city_id = r.city_id
    JOIN cities c 
        ON c.city_id = n.city_id
        group by 1,2)
SELECT 
    city,
    year,
   yearly_net_circulation,
   yearly_ad_revenue,
    
    -- Check if net circulation declines every year
     CASE 
        WHEN COUNT(*) = 6
         AND SUM(
                CASE WHEN yearly_net_circulation < LAG(yearly_net_circulation) OVER (PARTITION BY city  ORDER BY year) 
                     THEN 1 ELSE 0 END
             ) = 5
        THEN 'Yes' ELSE 'No'
    END AS is_declining_print,
    
    -- Check if ad revenue declines every year
    CASE 
        WHEN COUNT(*) = 6
         AND SUM(
                CASE WHEN yearly_ad_revenue < 
                          LAG(yearly_ad_revenue) OVER (PARTITION BY city  ORDER BY year) 
                     THEN 1 ELSE 0 END
             ) = 5
        THEN 'Yes' ELSE 'No'
    END AS is_declining_ad_revenue,
    
    -- Check if both decline
    CASE 
        WHEN COUNT(*) = 6
         AND SUM(
                CASE WHEN yearly_net_circulation < 
                          LAG(yearly_net_circulation,1,0) OVER (PARTITION BY city  ORDER BY year)

                     THEN 1 ELSE 0 END
             ) = 5
         AND SUM(
                CASE WHEN yearly_ad_revenue < 
                          LAG(yearly_ad_revenue) OVER (PARTITION BY city  ORDER BY year) 
                     THEN 1 ELSE 0 END
             ) = 5
        THEN 'Yes' ELSE 'No'
    END AS is_declining_both
    FROM combined
GROUP BY city, year, yearly_net_circulation, yearly_ad_revenue;
    

select * from cities;
select * from editions;
select * from fact_ad_revenue;
select * from fact_city_readline;
select * from fact_digital_pilot;
select * from ad_categories;
-- Business Request – 6 : 2021 Readiness vs Pilot Engagement Outlier 
-- In 2021, identify the city with the highest digital readiness score but among the bottom 3 
-- in digital pilot engagement. 
-- readiness_score = AVG(smartphone_rate, internet_rate, literacy_rate) 
-- “Bottom 3 engagement” uses the chosen engagement metric provided (e.g., 
-- engagement_rate, active_users, or sessions). 
-- Fields: 
-- • city_name 
-- • readiness_score_2021 
-- • engagement_metric_2021 
-- • readiness_rank_desc 
-- • engagement_rank_asc 
-- • is_outlier (Yes/No)

select avg(f.literacy_rate) as lit,avg(smartphone_penetration) as smart,avg(internet_penetration) as inter,
avg(avg(f.literacy_rate)+avg(smartphone_penetration)+avg(internet_penetration) )
from fact_city_readline as f
-- join cities as c
-- on c.city_id = f.city_id
where year(year) = 2021;