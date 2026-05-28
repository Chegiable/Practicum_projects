/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 *
 * Автор: Ниткин Дмитрий
 * Дата:28.01.2026
*/


-- Часть 1 Исследовательский анализ данных
-- Задача 1: Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- Основной запрос
main_info AS(
	SELECT
		a.id,
		days_exposition,
		last_price,
		city_id,
		total_area,
		rooms,
		balcony,
		f.floor 
	FROM real_estate.advertisement a
	JOIN real_estate.flats f USING(id)
	JOIN real_estate.type t ON  f.type_id = t.type_id
	WHERE a.id IN (SELECT * FROM filtered_id) AND type = 'город' AND EXTRACT(YEAR FROM first_day_exposition) NOT IN (2014, 2019) -- Исключил 2014 и 2019 (не полные года)
),
-- Группируем основную выборку по регионам и сегментам скоростей продаж в днях
group_info AS(
	SELECT
		CASE 
			WHEN days_exposition <= 30 THEN '1-30 days'
			WHEN days_exposition > 30 AND days_exposition <= 90 THEN '31-90 days' 
			WHEN days_exposition > 90 AND days_exposition <= 180 THEN '91-180 days' 
			WHEN days_exposition > 180 THEN '181+ days'
			ELSE 'non category'
		END AS sales_days,
		CASE
			WHEN city = 'Санкт-Петербург' THEN 'Санкт-Петербург' 
			ELSE 'Города Ленинградской области'
		END AS city_type,
		COUNT(id) AS count_flats,
		ROUND(AVG(last_price)::numeric/AVG(total_area)::numeric,2) AS avg_price_per_sqm,
		ROUND(AVG(total_area)::numeric,2) AS avg_area,
		ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY rooms))::numeric,0) AS med_rooms,
		ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY balcony))::numeric,0) AS med_balcony,
		ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY floor))::numeric,0) AS med_floor
	FROM main_info
	LEFT JOIN real_estate.city USING(city_id)
	GROUP BY sales_days, city_type
)
SELECT *
FROM group_info
ORDER BY city_type DESC, CASE sales_days
        WHEN '1-30 days' THEN 1
        WHEN '31-90 days' THEN 2
        WHEN '91-180 days' THEN 3
        WHEN '181+ days' THEN 4
        WHEN 'non category' THEN 5
    END;

sales_days  |city_type                   |count_flats|avg_price_per_sqm|avg_area|med_rooms|med_balcony|med_floor|
------------+----------------------------+-----------+-----------------+--------+---------+-----------+---------+
1-30 days   |Санкт-Петербург             |       1794|        111477.86|   54.66|        2|          1|        5|
31-90 days  |Санкт-Петербург             |       3020|        114401.79|   56.58|        2|          1|        5|
91-180 days |Санкт-Петербург             |       2244|        115582.29|   60.55|        2|          1|        5|
181+ days   |Санкт-Петербург             |       3506|        121348.98|   65.76|        2|          1|        5|
non category|Санкт-Петербург             |        653|        140301.48|   81.38|        3|          1|        4|
1-30 days   |Города Ленинградской области|        340|         71794.51|   48.75|        2|          1|        4|
31-90 days  |Города Ленинградской области|        864|         67202.79|   50.85|        2|          1|        3|
91-180 days |Города Ленинградской области|        553|         69853.99|   51.83|        2|          1|        3|
181+ days   |Города Ленинградской области|        873|         68570.28|   55.03|        2|          1|        3|
non category|Города Ленинградской области|        198|         74469.04|   62.78|        2|          1|        3|

-- Промежуточные выводы и аналитический комментарий:
-- 1. Какие категории объявлений являются самыми распространёнными в Санкт-Петербурге и городах Ленинградской области?
-- В Санкт-Петербурге самые распространенные это 181+ days (3506 объявления) и 31-90 days (3020 объявления).
-- В городах Ленинградской области самые распространенные это 181+ days (873 объявлений) и 31-90 days (864 объявление).
-- 2. Какие характеристики недвижимости, включая площадь недвижимости, среднюю стоимость квадратного метра, количество комнат и балконов и другие параметры, влияют на время активности объявлений? Как эти зависимости варьируют между регионами?
-- Санкт-Петербург:
-- В Санкт-Петербурге продаются лучше всего квартиры с меньшей площадью (средняя 54.66) и с меньшей ценой за квадратный метр (средняя 111477.86), дольше всего продаются квартиры с площадью больше (средняя 65.76) и с ценой за квадратный метр (средняя 121348.98)
-- Ленинградская область:
-- В Ленинградской области продаются лучше всего квартиры с меньшей площадью (средняя 48.75), но при этом с бОльшей ценой за квадратный метр (средняя 71794.51), дольше всего продаются большие квартиры с площадью (средняя 55.03) и с ценой за квадратный метр (средняя 68570.28). 
-- Чем больше площадь квартиры, тем дольше висит объявление о продаже. 
-- В Санкт-Петербурге прямая зависимость между ценой за квадратный метр и длительностью продажи, в Ленинградской области практически нет зависимости между ценой и скоростью продажи. 
-- 3. Есть ли различия между недвижимостью Санкт-Петербурга и Ленинградской области по полученным результатам?
-- Да, В Санкт-Петербурге более дорогая недвижимость (примерно в 1.5 раз дороже).
-- В Санкт-Петербурге преобладают более просторные квартиры.
-- В Санкт-Петербурге везде встречается 5 этаж, а в Ленинградской области это чаще 3 этажи (иногда 4).


-- Задача 2: Сезонность объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- Основной запрос
exposition_info AS(
	SELECT
		EXTRACT(MONTH FROM first_day_exposition) AS info_month,
		COUNT(a.id) AS exposition_count,
		ROUND(AVG(last_price)::numeric/AVG(total_area)::numeric,2) AS avg_price_per_sqm,
		ROUND(AVG(total_area)::numeric,2) AS avg_area
	FROM real_estate.advertisement a
	JOIN real_estate.flats f USING(id)
	WHERE a.id IN (SELECT * FROM filtered_id) AND EXTRACT(YEAR FROM first_day_exposition) NOT IN (2014, 2019) AND type_id = 'F8EM' -- исключил все населенные пункты, кроме городов
	GROUP BY info_month
), sales_info AS (
	SELECT
		EXTRACT(MONTH FROM (first_day_exposition + (days_exposition * interval '1 day'))) AS sales_month,
		COUNT(id) AS sales_count,
		ROUND(AVG(last_price)::numeric/AVG(total_area)::numeric,2) AS sales_avg_price_per_sqm,
		ROUND(AVG(total_area)::numeric,2) AS sales_avg_area
	FROM real_estate.advertisement
	JOIN real_estate.flats f USING(id)
	WHERE days_exposition IS NOT NULL AND id IN (SELECT * FROM filtered_id) AND EXTRACT(YEAR FROM first_day_exposition) NOT IN (2014, 2019) AND type_id = 'F8EM' -- исключил все населенные пункты, кроме городов
	GROUP BY sales_month
)
SELECT 
	info_month,
	exposition_count,
	avg_price_per_sqm AS exp_avg_price_per_sqm,
	avg_area AS exp_avg_area,
	RANK() OVER(ORDER BY exposition_count DESC) AS exposition_rank,
	sales_count,
	sales_avg_price_per_sqm,
	sales_avg_area,
	RANK() OVER(ORDER BY sales_count DESC) AS sales_rank
FROM exposition_info AS ei
FULL JOIN sales_info AS si ON ei.info_month = si.sales_month
ORDER BY info_month;

info_month|exposition_count|exp_avg_price_per_sqm|exp_avg_area|exposition_rank|sales_count|sales_avg_price_per_sqm|sales_avg_area|sales_rank|
----------+----------------+---------------------+------------+---------------+-----------+-----------------------+--------------+----------+
         1|             735|            112096.65|       59.16|             12|       1225|              111053.27|         57.53|         4|
         2|            1369|            108839.74|       60.10|              3|       1048|              106982.53|         61.12|         9|
         3|            1119|            105960.36|       60.00|              8|       1071|              114649.84|         60.37|         8|
         4|            1021|            110118.57|       60.60|             10|       1031|              105920.42|         59.22|        10|
         5|             891|            106855.55|       59.19|             11|        729|              103777.01|         57.78|        12|
         6|            1224|            110331.25|       58.37|              5|        771|              106690.65|         59.82|        11|
         7|            1149|            108659.94|       60.42|              7|       1108|              107895.44|         58.54|         7|
         8|            1166|            113430.57|       58.99|              6|       1137|              104076.43|         56.83|         6|
         9|            1341|            111898.27|       61.04|              4|       1238|              108772.08|         57.49|         3|
        10|            1437|            108760.66|       59.43|              2|       1360|              107065.40|         58.86|         1|
        11|            1569|            109798.10|       59.58|              1|       1301|              110050.07|         56.71|         2|
        12|            1024|            110384.79|       58.84|              9|       1175|              109107.04|         59.26|         5|
  
-- Промежуточные выводы и аналитический комментарий:
-- 1. В какие месяцы наблюдается наибольшая активность в публикации объявлений о продаже недвижимости? А в какие — по снятию? Это показывает динамику активности покупателей.
-- Больше всего публикаций в ноябре (1569) и октябре (1437), меньше всего в январе (735) и мае (891)
-- По снятию публикации больше всего в октябре (1360) и ноябре (1301), меньше всего в мае (729) и июне (771)
-- 2. Совпадают ли периоды активной публикации объявлений и периоды, когда происходит повышенная продажа недвижимости (по месяцам снятия объявлений)?
-- Нет, не совпадают.
-- Но есть интересное наблюдение с месяцами ноябрь и октябрь. По публикации ноябрь на первом месте, а по продаже на втором, а октябрь, наоборот, второе место по публикации, а вот по продаже на первом месте
-- 3. Как сезонные колебания влияют на среднюю стоимость квадратного метра и среднюю площадь квартир? Что можно сказать о зависимости этих параметров от месяца?
-- Цены и площади квартир не так зависимы от сезона, как количество публикаций и снятие их, поэтому сезонные колебания незначительно влияют на эти показатели.

-- Часть 2. Общие выводы и рекомендации:
-- Общие выводы:
-- Региональные рынки структурно различны.
-- Санкт-Петербург характеризуется более высокой стоимостью квадратного метра (в среднем на 40%) и большими площадями объектов.
-- Ленинградская область предлагает более бюджетные варианты с меньшей площадью.
-- Наиболее ликвидны 1-2-комнатные квартиры площадью 50-60 м²
-- Увеличение площади и стоимости пропорционально увеличивает срок времени продажи.
-- Объекты с активностью более 180 дней часто имеют завышенную цену в СПб
-- Рынок имеет выраженную сезонность. Пик публикаций и пик сделок приходится на осень, а именно на октябрь и ноябрь

-- Рекомендации:
-- В СПб делайте акцент на качестве и локации, в области — на ценовом преимуществе.
-- Разработайте отдельные ценовые стратегии и пакеты услуг для каждого региона.
-- Планируйте основные маркетинговые кампании на октябрь и ноябрь.
-- Увеличивайте операционные мощности к осенним пикам сделок.
-- Формируйте портфель предложений из квартир с параметрами быстрой продажи.
-- Для объектов долгосрочной экспозиции разработайте услуги по оптимизации цены и маркетинг.
