/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Дмитрий Ниткин 
 * Дата: 30.12.2025 г.
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
SELECT COUNT (ID) AS sum_players,
		SUM(payer) FILTER(WHERE payer = 1) AS sum_pay_players,
		ROUND((SELECT COUNT(ID)
		FROM fantasy.users u 
		WHERE payer = 1) / COUNT(ID)::NUMERIC*100, 2) AS share_payer 
FROM fantasy.users u;

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
WITH race_sum_payers AS (SELECT race_id,
						COUNT(id) FILTER(WHERE payer = 1) AS race_sum_payer
						FROM fantasy.users
						GROUP BY race_id),
sum_players AS (SELECT race_id,
				COUNT(id) AS sum_players
				FROM fantasy.users u
				GROUP BY race_id)
SELECT  race,
		race_sum_payer,
		sum_players,
		ROUND(race_sum_payer/sum_players::NUMERIC*100, 2) AS share_payer_race
FROM sum_players sp 
JOIN race_sum_payers rsp ON sp.race_id = rsp.race_id
JOIN fantasy.race r ON sp.race_id = r.race_id

-- Задача 2. Исследование внутриигровых покупок

-- 2.1. Статистические показатели по полю amount:
SELECT COUNT(amount),
		SUM(amount),
		MIN(amount),
		MAX(amount),
		AVG(amount),
		PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount) AS mediana,
		STDDEV(amount) AS stand_deviation
FROM fantasy.events e;

-- 2.2: Аномальные нулевые покупки:
SELECT COUNT(amount) FILTER(WHERE amount = 0) AS  sum_0_amount,
 	   COUNT(amount) FILTER(WHERE amount = 0)/ COUNT(amount)::REAL AS share_sum_0
FROM fantasy.events

-- 2.3: Популярные эпические предметы:
WITH item_sales AS (
 SELECT
  item_code,
  COUNT(*) FILTER (WHERE amount <> 0) AS total_sales
 FROM fantasy.events e 
 GROUP BY item_code
), 
item_popularity AS (
 SELECT it.item_code,
  		total_sales,
 		total_sales::NUMERIC / (SELECT SUM(total_sales) FROM item_sales) AS relative_sales,
  		COUNT(DISTINCT id) AS buyers_count,
  		COUNT(DISTINCT id)::NUMERIC / (SELECT COUNT(DISTINCT id) FROM fantasy.users) AS buyers_share
 FROM item_sales AS it
 JOIN fantasy.events is2 ON it.item_code = is2.item_code
 GROUP BY
  it.item_code,
  total_sales
)
SELECT
 game_items,
 total_sales,
 relative_sales,
 buyers_count,
 buyers_share * 100 AS buyers_share
FROM
 item_popularity ip 
JOIN fantasy.items i ON ip.item_code = i.item_code 
ORDER BY
 buyers_share DESC;

-- Часть 2. Решение ad hoc-задачи
-- Задача: Зависимость активности игроков от расы персонажа:
WITH count_players AS (
  SELECT race_id,
      COUNT(id) AS count_players
  FROM fantasy.users u
  GROUP BY race_id
),
trans_users AS (
  SELECT  race_id,
      	  COUNT(id) AS sum_payers
  FROM fantasy.users u
  WHERE id IN (SELECT id FROM fantasy.events WHERE amount > 0)
  GROUP BY race_id
),
purchases AS (
  SELECT u.race_id,
		COUNT(id)/sum_payers::NUMERIC AS count_purchases 
  FROM fantasy.users u
  JOIN trans_users tp ON u.race_id= tp.race_id
  WHERE payer = 1 AND id IN (SELECT id FROM fantasy.events WHERE amount > 0)
  GROUP BY u.race_id, sum_payers
),
all_data_users AS (
SELECT DISTINCT u.id,
		r.race_id,
		COUNT(transaction_id) OVER (PARTITION BY e.id, r.race_id) AS sum_trans,
		AVG(amount) OVER (PARTITION BY e.id, r.race_id) AS avg_amount,
		SUM(amount) OVER (PARTITION BY e.id, r.race_id) AS sum_amount
FROM fantasy.events e 
JOIN fantasy.users u ON e.id = u.id
JOIN fantasy.race r ON u.race_id = r.race_id
)
SELECT race AS Раса,
    count_players AS Общее_колво_игроков,
    sum_payers AS Сколько_игроков_покупают,
    sum_payers/count_players::NUMERIC AS Доля_покупающих_от_общего_числа_игроков, 
    count_purchases AS Доля_платящих_игроков_от_количества_игроков_которые_совершили_покупки,
    AVG(sum_trans) AS среднее_количество_покупок_на_одного_игрока,
	AVG(sum_amount) / AVG(sum_trans) AS средняя_стоимость_одной_покупки_на_одного_игрока,
	AVG(sum_amount) AS средняя_суммарная_стоимость_всех_покупок_на_одного_игрока
FROM count_players sp 
JOIN trans_users tu ON sp.race_id = tu.race_id
JOIN purchases p ON sp.race_id = p.race_id
JOIN all_data_users adu ON tu.race_id = adu.race_id
JOIN fantasy.race r ON sp.race_id = r.race_id 
GROUP BY race,
		count_players,
		sum_payers,
		count_purchases
ORDER BY Общее_колво_игроков DESC
