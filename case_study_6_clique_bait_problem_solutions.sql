SET search_path TO case_study_6_clique_bait;

SELECT * FROM event_identifier
SELECT * FROM campaign_identifier
SELECT * FROM page_hierarchy
SELECT * FROM users
SELECT * FROM events

------------------------------------------------------------------------------------1. Digital Analysis-------------------------------------------------------------------------

--How many users are there?
	SELECT COUNT (DISTINCT user_id) AS no_of_users
	FROM users
--How many cookies does each user have on average?
	SELECT ROUND(avg(count),2) avg_no_of_cookies
	FROM
		(SELECT user_id,COUNT(cookie_id)
		FROM users
		GROUP BY user_id)x
--What is the unique number of visits by all users per month?
	SELECT to_char(event_time,'mon') as month,COUNT(DISTINCT visit_id)
	FROM events e 
	GROUP BY to_char(event_time,'mon') 

--What is the number of events for each event type?
	SELECT ei.event_name , e.event_type,count(e.event_type) no_of_events
	FROM events e
	JOIN event_identifier ei ON e.event_type=ei.event_type
	GROUP BY ei.event_name , e.event_type
	ORDER BY  e.event_type

--What is the percentage of visits which have a purchase event?
	SELECT ROUND(count(visit_id)*100.0/(SELECT count(distinct visit_id) FROM events),2)
	FROM events 
	WHERE event_type=3 

--What is the percentage of visits which view the checkout page but do not have a purchase event?
	WITH CTE AS
			(SELECT *,
			 CASE WHEN page_id=12 then 1 ELSE 0 END as checkout_flag,
			 CASE WHEN event_type=3 THEN 1 ELSE 0 END AS purchase_flag
			 FROM events)
	SELECT ROUND((SUM(checkout_flag)-SUM(purchase_flag))*100.0/SUM(checkout_flag),2) AS visit_percentage FROM CTE
--What are the top 3 pages by number of views?

	SELECT e.page_id,ph.page_name,count(e.event_type) number_of_views 
	FROM events e
	JOIN page_hierarchy ph ON ph.page_id=e.page_id
	WHERE event_type=1
	GROUP BY e.page_id,ph.page_name
	ORDER BY count(e.event_type) desc
	LIMIT 3
--What is the number of views and cart adds for each product category?
WITH product_category_views AS 
		(SELECT ph.product_category , COUNT(e.event_type)
		FROM events e
		JOIN  page_hierarchy ph ON e.page_id=ph.page_id
		WHERE e.event_type=1 AND e.page_id IN (SELECT page_id FROM page_hierarchy WHERE product_id IS NOT NULL)
		GROUP BY ph.product_category),
     product_category_cart_Add AS
		(SELECT ph.product_category , COUNT(e.event_type)
		FROM events e
		JOIN  page_hierarchy ph ON e.page_id=ph.page_id
		WHERE e.event_type=2 AND e.page_id IN (SELECT page_id FROM page_hierarchy WHERE product_id IS NOT NULL)
		GROUP BY ph.product_category)
SELECT pv.product_category,	pv.count AS no_of_views,pc.count AS no_of_cart_add
FROM product_category_views pv
JOIN product_category_cart_Add pc ON pv.product_category=pc.product_category


--What are the top 3 products by purchases?  
WITH CTE AS
		(SELECT * ,
		CASE WHEN MAX(event_type)over(partition by visit_id,cookie_id)=3 THEN 1 ELSE 0 END AS flag
		FROM events 
		WHERE event_type=2 OR event_type=3)
SELECT ph.page_name as product ,count(event_type) AS no_of_purchase
FROM CTE e
JOIN page_hierarchy ph ON e.page_id=ph.page_id
WHERE e.flag=1 AND e.event_type=2 AND e.page_id IN (SELECT page_id FROM page_hierarchy WHERE product_id IS NOT NULL) 
GROUP BY ph.page_name 
ORDER BY count(event_type) DESC
LIMIT 3

--------------------------------------------------------------------------3. Product Funnel Analysis--------------------------------------------------------------------
/*Using a single SQL query - create a new output table which has the following details:

How many times was each product viewed?
How many times was each product added to cart?
How many times was each product added to a cart but not purchased (abandoned)?
How many times was each product purchased?*/

WITH CTE AS -- flagging all the activities
		(SELECT *,
		CASE WHEN event_type=1 THEN 1 ELSE 0 END AS view_flag,
		CASE WHEN event_type=2 THEN 1 ELSE 0 END AS cart_flag,
		CASE WHEN MAX(event_type)over(partition by visit_id,cookie_id)=3 AND event_type=2  THEN 1 ELSE 0 END AS purchase_flag
		FROM events
		)
SELECT ph.page_name AS product,SUM(CTE.view_flag) no_of_product_view,SUM(CTE.cart_flag)no_of_added_to_cart,
       SUM(CTE.cart_flag-CTE.purchase_flag)no_of_added_to_cart_but_no_purchase,SUM(CTE.purchase_flag)no_of_purchase
FROM CTE
JOIN page_hierarchy ph ON CTE.page_id=ph.page_id
WHERE CTE.page_id NOT IN (SELECT page_id FROM page_hierarchy WHERE product_id IS NULL)
GROUP BY ph.page_name
ORDER BY SUM(CTE.view_flag) DESC


--Additionally, create another table which further aggregates the data for the above points but this time for each product category instead of individual products.

WITH CTE AS
		(SELECT *,
		CASE WHEN event_type=1 THEN 1 ELSE 0 END AS view_flag,
		CASE WHEN event_type=2 THEN 1 ELSE 0 END AS cart_flag,
		CASE WHEN MAX(event_type)over(partition by visit_id,cookie_id)=3 AND event_type=2  THEN 1 ELSE 0 END AS purchase_flag
		FROM events
		)
SELECT ph.product_category AS product_category,SUM(CTE.view_flag) no_of_product_view,SUM(CTE.cart_flag)no_of_added_to_cart,
       SUM(CTE.cart_flag-CTE.purchase_flag)no_of_added_to_cart_but_no_purchase,SUM(CTE.purchase_flag)no_of_purchase
FROM CTE
JOIN page_hierarchy ph ON CTE.page_id=ph.page_id
WHERE CTE.page_id NOT IN (SELECT page_id FROM page_hierarchy WHERE product_id IS NULL)
GROUP BY ph.product_category


--Use your 2 new output tables - answer the following questions:
--Which product had the most views, cart adds and purchases?
  most_views=Oyster
  most_cart_add= Lobster
  most_purchases=Lobster
--Which product was most likely to be abandoned?
  most_likely_to_be_abandoned=Crab
--Which product had the highest view to purchase percentage?
WITH CTE AS
		(SELECT *,
		CASE WHEN event_type=1 THEN 1 ELSE 0 END AS view_flag,
		CASE WHEN event_type=2 THEN 1 ELSE 0 END AS cart_flag,
		CASE WHEN MAX(event_type)over(partition by visit_id,cookie_id)=3 AND event_type=2  THEN 1 ELSE 0 END AS purchase_flag
		FROM events
		),
	CTE_2 AS	
		(SELECT ph.page_name AS product,SUM(CTE.view_flag) no_of_product_view,SUM(CTE.cart_flag)no_of_added_to_cart,
			   SUM(CTE.cart_flag-CTE.purchase_flag)no_of_added_to_cart_but_no_purchase,SUM(CTE.purchase_flag)no_of_purchase
		FROM CTE
		JOIN page_hierarchy ph ON CTE.page_id=ph.page_id
		WHERE CTE.page_id NOT IN (SELECT page_id FROM page_hierarchy WHERE product_id IS NULL)
		GROUP BY ph.page_name
		ORDER BY SUM(CTE.view_flag) DESC)	
SELECT product, ROUND(no_of_purchase*100.0/no_of_product_view,2) as purchase_view_to_percentage
FROM CTE_2 	
ORDER BY ROUND(no_of_purchase*100.0/no_of_product_view,2) desc
		
		
		
--What is the average conversion rate from view to cart add?
WITH CTE AS
		(SELECT *,
		CASE WHEN event_type=1 THEN 1 ELSE 0 END AS view_flag,
		CASE WHEN event_type=2 THEN 1 ELSE 0 END AS cart_flag,
		CASE WHEN MAX(event_type)over(partition by visit_id,cookie_id)=3 AND event_type=2  THEN 1 ELSE 0 END AS purchase_flag
		FROM events
		),
	CTE_2 AS	
		(SELECT ph.page_name AS product,SUM(CTE.view_flag) no_of_product_view,SUM(CTE.cart_flag)no_of_added_to_cart,
			   SUM(CTE.cart_flag-CTE.purchase_flag)no_of_added_to_cart_but_no_purchase,SUM(CTE.purchase_flag)no_of_purchase
		FROM CTE
		JOIN page_hierarchy ph ON CTE.page_id=ph.page_id
		WHERE CTE.page_id NOT IN (SELECT page_id FROM page_hierarchy WHERE product_id IS NULL)
		GROUP BY ph.page_name
		ORDER BY SUM(CTE.view_flag) DESC)	
SELECT ROUND(AVG(no_of_added_to_cart*100.0/no_of_product_view),2) average_conversion_rate_view_to_cart
FROM CTE_2		

--What is the average conversion rate from cart add to purchase?

WITH CTE AS
		(SELECT *,
		CASE WHEN event_type=1 THEN 1 ELSE 0 END AS view_flag,
		CASE WHEN event_type=2 THEN 1 ELSE 0 END AS cart_flag,
		CASE WHEN MAX(event_type)over(partition by visit_id,cookie_id)=3 AND event_type=2  THEN 1 ELSE 0 END AS purchase_flag
		FROM events
		),
	CTE_2 AS	
		(SELECT ph.page_name AS product,SUM(CTE.view_flag) no_of_product_view,SUM(CTE.cart_flag)no_of_added_to_cart,
			   SUM(CTE.cart_flag-CTE.purchase_flag)no_of_added_to_cart_but_no_purchase,SUM(CTE.purchase_flag)no_of_purchase
		FROM CTE
		JOIN page_hierarchy ph ON CTE.page_id=ph.page_id
		WHERE CTE.page_id NOT IN (SELECT page_id FROM page_hierarchy WHERE product_id IS NULL)
		GROUP BY ph.page_name
		ORDER BY SUM(CTE.view_flag) DESC)	
SELECT ROUND(AVG(no_of_purchase*100.0/no_of_added_to_cart),2) average_conversion_rate_cart_to_purchase
FROM CTE_2	


--------------------------------------------------------------------3. Campaigns Analysis--------------------------------------------------------------------
/*Generate a table that has 1 single row for every unique visit_id record and has the following columns:

user_id
visit_id
visit_start_time: the earliest event_time for each visit
page_views: count of page views for each visit
cart_adds: count of product cart add events for each visit
purchase: 1/0 flag if a purchase event exists for each visit
campaign_name: map the visit to a campaign if the visit_start_time falls between the start_date and end_date
impression: count of ad impressions for each visit
click: count of ad clicks for each visit
(Optional column) cart_products: a comma separated text value with products added to the cart sorted by the order they were added to the cart (hint: use the sequence_number)*/

SELECT * FROM event_identifier
SELECT * FROM campaign_identifier
SELECT * FROM page_hierarchy
SELECT * FROM users
SELECT * FROM events

CREATE TEMP TABLE summary AS(
WITH CTE AS(SELECT campaign_id,split_part(products,'-',1)::int as prod1,split_part(products,'-',2)::int as prod2,campaign_name,start_date,end_date
		   FROM campaign_identifier),
     CTE2 AS
		(SELECT u.user_id,e.visit_id , MIN(event_time)over(partition by user_id,visit_id)visit_start_time,ei.event_name,ph.page_name,e.sequence_number,ph.page_name,CTE.campaign_name,
			   CASE WHEN e.event_type=1 THEN 1 ELSE 0 END AS flag_page_view,
			   CASE WHEN e.event_type=2 THEN 1 ELSE 0 END AS flag_add_cart,
			   CASE WHEN e.event_type=3 THEN 1 ELSE 0 END AS flag_purchase,
			   CASE WHEN e.event_type=4 THEN 1 ELSE 0 END AS flag_Ad_Impression,
			   CASE WHEN e.event_type=5 THEN 1 ELSE 0 END AS flag_Ad_Click
		FROM events e
		JOIN event_identifier ei ON e.event_type=ei.event_type  
		JOIN users u ON e.cookie_id=u.cookie_id
		JOIN page_hierarchy ph ON e.page_id=ph.page_id
		LEFT JOIN CTE ON (ph.product_id between CTE.prod1 AND CTE.prod2) AND e.event_time between CTE.start_date AND CTE.end_date) 
SELECT user_id,visit_id, visit_start_time,SUM(flag_page_view)page_views,
       SUM(flag_add_cart)cart_adds,
	   MAX(flag_purchase) purchase,
	   MAX(campaign_name) campaign_name,
	   SUM(flag_Ad_Impression)impression,
	   SUM(flag_Ad_Click)click
FROM CTE2		
GROUP BY user_id,visit_id,visit_start_time
ORDER BY user_id )
SELECT * FROM summary

		
/*Some ideas you might want to investigate further include:

--Identifying users who have received impressions during each campaign period and comparing each metric with other users who did not have an impression event
--Does clicking on an impression lead to higher purchase rates?
--What is the uplift in purchase rate when comparing users who click on a campaign impression versus users who do not receive an impression? What if we compare them with users who just an impression but do not click?
--What metrics can you use to quantify the success or failure of each campaign compared to eachother?*/

--Identifying users who have received impressions during each campaign period and comparing each metric with other users who did not have an impression event
WITH got_impression_during_campaign AS 
			(SELECT * 
			FROM summary
			where campaign_name IS NOT NULL AND impression=1),
     no_impression_during_campaign AS
			(SELECT * 
			FROM summary
			where campaign_name IS NOT NULL AND impression=0)
SELECT 'Got_impression_during_campaign' as description ,COUNT(DISTINCT user_id)no_of_user_id,COUNT(visit_id)no_of_visits,
       ROUND(AVG(page_views),2) avg_no_of_page_views,ROUND(avg(cart_adds),2) avg_no_of_cart_adds, SUM(purchase)total_no_of_purchases,
	   ROUND(SUM(purchase)*100.0/COUNT(visit_id),2) conversion_of_visit_to_purchase
FROM got_impression_during_campaign
UNION
SELECT 'No_impression_during_campaign' as description,COUNT(DISTINCT user_id)no_of_user_id,COUNT(visit_id)no_of_visits,
       ROUND(AVG(page_views),2) avg_no_of_page_views,ROUND(avg(cart_adds),2) avg_no_of_cart_adds, SUM(purchase)total_no_of_purchases,
	   ROUND(SUM(purchase)*100.0/COUNT(visit_id),2) conversion_of_visit_to_purchase
FROM no_impression_during_campaign

--Does clicking on an impression lead to higher purchase rates?
SELECT * FROM summary
WITH click_on_impression_during_campaign AS 
			(SELECT * 
			FROM summary
			where campaign_name IS NOT NULL AND click=1),
     no_click_on_impression_during_campaign AS
			(SELECT * 
			FROM summary
			where campaign_name IS NOT NULL AND click=0)
SELECT 'click_on_impression_during_campaign' as description ,COUNT(DISTINCT user_id)no_of_user_id,COUNT(visit_id)no_of_visits,
       ROUND(AVG(page_views),2) avg_no_of_page_views,ROUND(avg(cart_adds),2) avg_no_of_cart_adds, SUM(purchase)total_no_of_purchases,
	   ROUND(SUM(purchase)*100.0/COUNT(visit_id),2) conversion_of_visit_to_purchase
FROM click_on_impression_during_campaign
UNION
SELECT 'No_click_on_impression_during_campaign' as description,COUNT(DISTINCT user_id)no_of_user_id,COUNT(visit_id)no_of_visits,
       ROUND(AVG(page_views),2) avg_no_of_page_views,ROUND(avg(cart_adds),2) avg_no_of_cart_adds, SUM(purchase)total_no_of_purchases,
	   ROUND(SUM(purchase)*100.0/COUNT(visit_id),2) conversion_of_visit_to_purchase
FROM no_click_on_impression_during_campaign

--What is the uplift in purchase rate when comparing users who click on a campaign impression versus users who do not receive an impression? What if we compare them with users who just an impression but do not click?

WITH click_on_impression_during_campaign AS 
			(SELECT * 
			FROM summary
			where campaign_name IS NOT NULL AND click=1),
     no_impression_during_campaign AS
			(SELECT * 
			FROM summary
			where campaign_name IS NOT NULL AND impression=0),
	impression_but_no_click_during_campaign AS
			(SELECT * 
			FROM summary
			where campaign_name IS NOT NULL AND impression=1 AND click=0)		
SELECT 'click on impression during campaign' Description ,COUNT(visit_id)as no_of_visits,SUM(purchase)as no_of_purchase, 
       (COUNT(visit_id)-SUM(purchase))times_purchase_didnot_happen,
       ROUND(SUM(purchase)*100.0/COUNT(visit_id),2)purchase_rate
FROM click_on_impression_during_campaign
UNION
SELECT 'no impression during campaign' Description ,COUNT(visit_id)as no_of_visits,SUM(purchase)as no_of_purchase, 
       (COUNT(visit_id)-SUM(purchase))times_purchase_didnot_happen,
       ROUND(SUM(purchase)*100.0/COUNT(visit_id),2)purchase_rate
FROM no_impression_during_campaign
UNION
SELECT 'got impression but no clicks during campaign' Description ,COUNT(visit_id)as no_of_visits,SUM(purchase)as no_of_purchase, 
       (COUNT(visit_id)-SUM(purchase))times_purchase_didnot_happen,
       ROUND(SUM(purchase)*100.0/COUNT(visit_id),2)purchase_rate
FROM impression_but_no_click_during_campaign


--What metrics can you use to quantify the success or failure of each campaign compared to eachother?*/

SELECT * FROM summary

WITH summary_campaign_3 AS 
			(SELECT * 
			FROM summary
			where campaign_name='Half Off - Treat Your Shellf(ish)'),
     summary_campaign_2 AS
			(SELECT * 
			FROM summary
			where campaign_name='25% Off - Living The Lux Life'),
     summary_campaign_1 AS
			(SELECT * 
			FROM summary
			where campaign_name='BOGOF - Fishing For Compliments')

SELECT 'Half Off - Treat Your Shellf(ish)' AS campaign_name , COUNT(DISTINCT user_id)no_of_users,COUNT(visit_id) no_of_visits,
       ROUND(AVG(page_views),2) avg_no_of_page_views,ROUND(avg(cart_adds),2) avg_no_of_cart_adds, SUM(purchase)total_no_of_purchases,
	   SUM(impression) as no_of_impressions , SUM(click) no_of_clicks,ROUND(SUM(impression)/COUNT(DISTINCT user_id),2) no_of_impression_per_user,ROUND(SUM(click)/COUNT(DISTINCT user_id),2) no_of_clicks_per_user,
	   ROUND(SUM(purchase)*100.0/COUNT(visit_id),2) conversion_of_visit_to_purchase,
	    ROUND(SUM(click)*100.0/ SUM(impression),2) click_through_rate
FROM summary_campaign_3
UNION
SELECT '25% Off - Living The Lux Life' AS campaign_name ,COUNT(DISTINCT user_id)no_of_users,COUNT(visit_id) no_of_visits,
       ROUND(AVG(page_views),2) avg_no_of_page_views,ROUND(avg(cart_adds),2) avg_no_of_cart_adds, SUM(purchase)total_no_of_purchases,
	   SUM(impression) as no_of_impressions , SUM(click) no_of_clicks,ROUND(SUM(impression)/COUNT(DISTINCT user_id),2) no_of_impression_per_user,ROUND(SUM(click)/COUNT(DISTINCT user_id),2)  no_of_clicks_per_user,
	   ROUND(SUM(purchase)*100.0/COUNT(visit_id),2) conversion_of_visit_to_purchase,
	   ROUND(SUM(click)*100.0/ SUM(impression),2) click_through_rate
FROM summary_campaign_2
UNION
SELECT 'BOGOF - Fishing For Compliments' AS campaign_name ,COUNT(DISTINCT user_id)no_of_users,COUNT(visit_id) no_of_visits,
       ROUND(AVG(page_views),2) avg_no_of_page_views,ROUND(avg(cart_adds),2) avg_no_of_cart_adds, SUM(purchase)total_no_of_purchases,
	   SUM(impression) as no_of_impressions , SUM(click) no_of_clicks,ROUND(SUM(impression)/COUNT(DISTINCT user_id),2) no_of_impression_per_user,ROUND(SUM(click)/COUNT(DISTINCT user_id),2)  no_of_clicks_per_user,
	   ROUND(SUM(purchase)*100.0/COUNT(visit_id),2) conversion_of_visit_to_purchase,
	   ROUND(SUM(click)*100.0/ SUM(impression),2) click_through_rate
FROM summary_campaign_1





















