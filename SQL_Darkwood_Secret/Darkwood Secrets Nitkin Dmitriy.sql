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

sum_players|sum_pay_players|share_payer|
-----------+---------------+-----------+
      22214|           3929|      17.69|

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

race    |race_sum_payer|sum_players|share_payer_race|
--------+--------------+-----------+----------------+
Elf     |           427|       2501|           17.07|
Northman|           626|       3562|           17.57|
Angel   |           229|       1327|           17.26|
Orc     |           636|       3619|           17.57|
Hobbit  |           659|       3648|           18.06|
Human   |          1114|       6328|           17.60|
Demon   |           238|       1229|           19.37|
	
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

count  |sum      |min|max     |avg              |mediana|stand_deviation  |
-------+---------+---+--------+-----------------+-------+-----------------+
1307678|686615040|0.0|486615.1|525.6919663589833|  74.86|2517.345444427788|

-- 2.2: Аномальные нулевые покупки:
SELECT COUNT(amount) FILTER(WHERE amount = 0) AS  sum_0_amount,
 	   COUNT(amount) FILTER(WHERE amount = 0)/ COUNT(amount)::REAL AS share_sum_0
FROM fantasy.events

sum_0_amount|share_sum_0       |
------------+------------------+
         907|0.0006935958240484|
	
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

game_items               |total_sales|relative_sales            |buyers_count|buyers_share              |
-------------------------+-----------+--------------------------+------------+--------------------------+
Book of Legends          |    1004516|    0.76870086648693611964|       12195|   54.89781219051048888100|
Bag of Holding           |     271875|    0.20805098980617108889|       11968|   53.87593409561537769000|
Necklace of Wisdom       |      13828|    0.01058180813623810140|        1627|    7.32420995768434320700|
Gems of Insight          |       3833|    0.00293318416157077254|         926|    4.16854236067344917600|
Treasure Map             |       3084|    0.00236001564160820832|         753|    3.38975420905735122000|
Silver Flask             |        795|    0.00060836979088149339|         633|    2.84955433510398847600|
Amulet of Protection     |       1078|    0.00082493413153490550|         445|    2.00324119924372017600|
Glowing Pendant          |        563|    0.00043083294624689406|         354|    1.59358962816242009500|
-- и т.д

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

Раса    |Общее_колво_игроков|Сколько_игроков_покупают|Доля_покупающих_от_общего_числа_иг|Доля_платящих_игроков_от_количест|среднее_количество_покупок_на_одн|средняя_стоимость_одной_покупки_н|средняя_суммарная_стоимость_всех_|
--------+-------------------+------------------------+----------------------------------+---------------------------------+---------------------------------+---------------------------------+---------------------------------+
Human   |               6328|                    3921|            0.61962705436156763590|           0.18005610813567967355|             121.4078041315990819|               403.11251689740817|               48941.005494476456|
Hobbit  |               3648|                    2266|            0.62116228070175438596|           0.17696381288614298323|              86.0992501102779003|                 552.849327583903|                47599.91252894543|
Orc     |               3619|                    2276|            0.62890301188173528599|           0.17398945518453427065|              81.7442882249560633|               510.86192613160756|               41760.044532858345|
Northman|               3562|                    2229|            0.62577203818079730488|           0.18214445939883355765|              82.1090174966352624|                761.4347375840699|                62520.65819083627|
Elf     |               2501|                    1543|            0.61695321871251499400|           0.16267012313674659754|              79.3227478937135450|                677.7582654596782|                53761.64802393864|
Angel   |               1327|                     820|            0.61793519216277317257|           0.16707317073170731707|             106.8231707317073171|                455.6001113376441|                48668.64847880602|
Demon   |               1229|                     737|            0.59967453213995117982|           0.19945725915875169607|              77.8697421981004071|                 529.055041705268|                41197.37970619448|
