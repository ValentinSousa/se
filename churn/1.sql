CREATE TABLE green_fact_customer_monthly_snapshots AS
WITH customer_milestones AS (
    -- Шаг 1: Находим 3 ключевые даты для каждого клиента
    SELECT 
        customer_id,
        MIN(order_date) as first_order_date,
        MAX(CASE WHEN order_seq_desc = 2 THEN order_date END) as penultimate_order_date,
        MAX(CASE WHEN order_seq_desc = 1 THEN order_date END) as last_order_date
    FROM (
        SELECT customer_id, order_date,
               ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date DESC) as order_seq_desc
        FROM fact_all
    ) GROUP BY customer_id
),

month_ends AS (
    -- Шаг 2: Получаем список дат концов месяцев (можно из dim_calendar или рассчитать)
    -- Здесь генерируем концы месяцев динамически от минимальной даты заказа до сегодня
    SELECT DISTINCT LAST_DAY(order_date) as month_end_date
    FROM fact_all
),

customer_months AS (
    -- Шаг 3: Соединяем клиентов с месяцами, которые наступили ПОСЛЕ их первого заказа
    SELECT 
        m.customer_id,
        me.month_end_date,
        m.first_order_date,
        m.penultimate_order_date,
        m.last_order_date
    FROM customer_milestones m
    CROSS JOIN month_ends me
    WHERE me.month_end_date >= LAST_DAY(m.first_order_date)
      AND me.month_end_date <= CURRENT_DATE
)

-- Шаг 4: Считаем статус клиента на конец каждого исторического месяца
SELECT 
    month_end_date,
    customer_id,
    CASE 
        -- 1. Новый (первый заказ в последние 90 дней от даты среза)
        WHEN DATEDIFF('day', first_order_date, month_end_date) <= 90 
            THEN 'New'
            
        -- 2. Ушедший (последний заказ старше 360 дней от даты среза)
        WHEN DATEDIFF('day', last_order_date, month_end_date) > 360 
            THEN 'Churned'
            
        -- 3. Уходящий (последний заказ старше 180 дней от даты среза)
        WHEN DATEDIFF('day', last_order_date, month_end_date) > 180 
            THEN 'Churning'
            
        -- 4. Реактивированный (промежуток между последним и предпоследним > 180 дней)
        -- Важно: проверяем, что последний заказ случился до или в месяц среза
        WHEN last_order_date <= month_end_date 
         AND DATEDIFF('day', penultimate_order_date, last_order_date) > 180 
            THEN 'Reactivated'
            
        -- 5. Активный
        ELSE 'Active'
    END AS status
FROM customer_months;