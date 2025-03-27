#Task 1 - Croma Monthly Sold Quantity of different products for FY 2021

select * from fact_sales_monthly
where customer_code = 90002002 and 
fiscal_year = 2021
order by date asc

 # Created Function - "fiscal_year"
 
 create function 'fiscal_year' (
 calendar_date date
) 
RETURNS int
    DETERMINISTIC
BEGIN
	declare fiscal_year int;
    SET fiscal_year = Year(date_add(calendar_date, interval 4 month));
RETURN fiscal_year;
END

------------------------------------------------------------------------------------------

#Task 2 - Croma Monthly Sold Quantity of different products for FY 2021 by Quarters

select * from fact_sales_monthly
where customer_code = 90002002 and 
fiscal_year = 2021 and
fiscal_quarter = Q4
order by date asc

 # Created Function - "fiscal_quarter"
 
 create function 'fiscal_qurater' (
calendar_date date
) RETURNS char(2) CHARSET utf8mb4
    DETERMINISTIC
BEGIN
declare m tinyint;
declare qtr char(2);
set m = month(calendar_date);
case
	when m in (9,10,11) then
    set qtr = "Q1";
    when m in (12,1,2) then
    set qtr = "Q2";
    when m in (3,4,5) then
    set qtr = "Q3";
    Else
    Set qtr = "Q4"; 
    End Case;
RETURN qtr;
END

------------------------------------------------------------------------------------------

#Task 3 - Join fact_sales_monthly and dim_product 

select
s.date, s.product_code,
p.product, p.variant, s.sold_quantity
from fact_sales_monthly s
join dim_product p
on p.product_code = s.product_code
where
customer_code=90002002 and
fiscal_year = 2021
order by date asc
limit 1000000

------------------------------------------------------------------------------------------

#Task 4 - Join fact_sales_monthly and fact_gross_price to get gross price per item and total gross price

select
s.date, s.product_code,
p.product, p.variant, s.sold_quantity, g.fiscal_year, g.gross_price, round(sold_quantity*gross_price,2) as total_gross_price
from fact_sales_monthly s
join dim_product p
on p.product_code = s.product_code
join fact_gross_price g
on g.product_code = s.product_code and g.fiscal_year = fiscal_year(s.date)
where
customer_code=90002002 and
fiscal_year(s.date) = 2021
order by date asc
limit 1000000

------------------------------------------------------------------------------------------

#Task 5 - Total Gross Sales Amount by Month

select
s.date, 
SUM(round(sold_quantity*gross_price,2)) as total_gross_price
from fact_sales_monthly s
join fact_gross_price g
on g.product_code = s.product_code and g.fiscal_year = fiscal_year(s.date)
where customer_code=90002002 
group by s.date
order by s.date asc

 # Created Function - `get_monthly_gross_sales_for_customer`
 
CREATE DEFINER=`root`@`localhost` PROCEDURE `get_monthly_gross_sales_for_customer`(
in_customer_codes text
)
BEGIN
select 
	s.date,
    sum(round(g.gross_price*s.sold_quantity,2)) as monthly_sales
from fact_sales_monthly s
join fact_gross_price g
on  
	g.fiscal_year = fiscal_year(s.date) and
    g.product_code = s.product_code
where 
find_in_set(s.customer_code, in_customer_codes)>0
group by date;
END

------------------------------------------------------------------------------------------

#Task 6 - Total Gross Sales Amount by Year

select
s.fiscal_year,
SUM(round(sold_quantity*gross_price,2)) as total_gross_price
from fact_sales_monthly s
join fact_gross_price g
on g.product_code = s.product_code and g.fiscal_year = fiscal_year(s.date)
where customer_code=90002002 
group by s.fiscal_year
order by s.fiscal_year asc

------------------------------------------------------------------------------------------

#Task 7 -Store Procedure for Market Badge

select
c.market,
sum(s.sold_quantity) as total_sold_qty
from dim_customer c
join fact_sales_monthly s
on s.customer_code = c.customer_code
where fiscal_year(s.date) = 2021 and c.market = "India"
group by c.market

#Created Stored Procedure - get_market_badge

CREATE DEFINER=`root`@`localhost` PROCEDURE `get_market_badge`(
	IN in_market varchar(45),
    IN in_fiscal_year year,
    OUT market_badge varchar(45)
    )
BEGIN
    declare qty int default 0;
select
c.market,
sum(s.sold_quantity) as total_sold_qty
from dim_customer c
join fact_sales_monthly s
on s.customer_code = c.customer_code
where fiscal_year(s.date) = in_fiscal_year and c.market =in_market
group by c.market;

if qty>5000000 then 
set market_badge = "GOLD";
else
set market_badge = "Silver";
end if;
END

------------------------------------------------------------------------------------------

#Task 8 - Add pre_invoice_discount_pct column by merging column with fact_pre_invoice_deductions

select
s.date, s.product_code,
p.product, p.variant, s.sold_quantity, g.fiscal_year, g.gross_price, round(sold_quantity*gross_price,2) as total_gross_price,
pre.pre_invoice_discount_pct
from fact_sales_monthly s
join dim_product p
on p.product_code = s.product_code
join fact_gross_price g
on g.product_code = s.product_code and g.fiscal_year = fiscal_year(s.date)
join fact_pre_invoice_deductions pre
on
	pre.customer_code = s.customer_code and
    pre.fiscal_year = fiscal_year(s.date)
where
fiscal_year(s.date) = 2021
order by date asc
limit 1000000

------------------------------------------------------------------------------------------

#Task 9 - Net_Invoice_Sales by using CTE

WITH cte1 AS (
select
s.date, s.product_code,
p.product, p.variant, s.sold_quantity, g.fiscal_year, g.gross_price, round(sold_quantity*gross_price,2) as total_gross_price,
pre.pre_invoice_discount_pct
from fact_sales_monthly s
join dim_product p
on p.product_code = s.product_code
join fact_gross_price g
on g.product_code = s.product_code and g.fiscal_year = fiscal_year(s.date)
join fact_pre_invoice_deductions pre
on
	pre.customer_code = s.customer_code and
    pre.fiscal_year = fiscal_year(s.date)
where
fiscal_year(s.date) = 2021)
Select *,
Round((total_gross_price - total_gross_price*pre_invoice_discount_pct),2) as net_invoice_sales
 from cte1
 
 # Create Database View for above quert=y
 
 Create view 'Sales_preinv_discount' as

select
s.date, s.product_code,
c.market,
p.product, p.variant, s.sold_quantity, g.fiscal_year, g.gross_price, round(sold_quantity*gross_price,2) as total_gross_price,
pre.pre_invoice_discount_pct
from fact_sales_monthly s
join dim_customer c on s.customer_code = c.customer_code
join dim_product p
on p.product_code = s.product_code
join fact_gross_price g
on g.product_code = s.product_code and g.fiscal_year = fiscal_year(s.date)
join fact_pre_invoice_deductions pre
on
	pre.customer_code = s.customer_code and
    pre.fiscal_year = fiscal_year(s.date))
    
------------------------------------------------------------------------------------------

#Task 10 - Net_Invoice _Sales using Database View - Sales_preinv_discount 

SELECT *,
round((gross_price_total - gross_price_total*pre_invoice_discount_pct),2) as net_invoice_sales
 FROM gdb0041.sales_preinv_discount;
 
 ------------------------------------------------------------------------------------------
 
 #Task 11 - Calculate Post_Invoice_Discount

SELECT *,
round((1 - pre_invoice_discount_pct)*gross_price_total,2) as net_invoice_sales,
(po.discounts_pct + po.other_deductions_pct) as post_invoice_discount_pct
 FROM sales_preinv_discount s 
 join fact_post_invoice_deductions po
 on s.date = po.date and
 s.product_code = po.product_code and
 s.customer_code = po.customer_code
 
 #Create post_invoice_discount View
 
 Create view 'sales_postinv_discount' as
 
 SELECT s.date, s.fiscal_year,
 s.customer_code, s.market, s.product_code, 
 s.product, s.variant, s.sold_quantity,
 s.gross_price_total,
 s.pre_invoice_discount_pct,
round((1 - pre_invoice_discount_pct)*gross_price_total,2) as net_invoice_sales,
(po.discounts_pct + po.other_deductions_pct) as post_invoice_discount_pct
 FROM sales_preinv_discount s 
 join fact_post_invoice_deductions po
 on s.date = po.date and
 s.product_code = po.product_code and
 s.customer_code = po.customer_code
 
------------------------------------------------------------------------------------------

#Task 12 - Calculate Net_Sales

SELECT *,
round((1-post_invoice_discount_pct)*net_invoice_sales,2) as net_sales
 FROM gdb0041.sales_postinv_discount;
 
 #Create Net_Sales View
 Create view 'net_sales' as
 SELECT *,
round((1-post_invoice_discount_pct)*net_invoice_sales,2) as net_sales
 FROM gdb0041.sales_postinv_discount; 
 



