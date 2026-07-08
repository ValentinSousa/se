CREATE TABLE green_fact_customer_state_transitions AS
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
)

-- Шаг 2: Математически вычисляем исторические и текущие переходы через UNION ALL

-- 1. Переход в "Уходящий" после предпоследнего заказа (в прошлом)
SELECT 
    customer_id,
    DATEADD('day', 180, penultimate_order_date) AS transition_date,
    'Active' AS previous_status,
    'Churning' AS new_status,
    180 AS days_in_previous_status
FROM customer_milestones
WHERE DATEDIFF('day', penultimate_order_date, last_order_date) > 180

UNION ALL

-- 2. Переход в "Ушедший" после предпоследнего заказа (в прошлом)
SELECT 
    customer_id,
    DATEADD('day', 360, penultimate_order_date) AS transition_date,
    'Churning' AS previous_status,
    'Churned' AS new_status,
    180 AS days_in_previous_status -- провел в Churning со 180 по 360 день
FROM customer_milestones
WHERE DATEDIFF('day', penultimate_order_date, last_order_date) > 360

UNION ALL

-- 3. Момент Реактивации (дата последнего заказа, если перед ним клиент спал > 180 дней)
SELECT 
    customer_id,
    last_order_date AS transition_date,
    CASE 
        WHEN DATEDIFF('day', penultimate_order_date, last_order_date) > 360 THEN 'Churned'
        ELSE 'Churning'
    END AS previous_status,
    'Reactivated' AS new_status,
    DATEDIFF('day', penultimate_order_date, last_order_date) - 180 AS days_in_previous_status 
FROM customer_milestones
WHERE DATEDIFF('day', penultimate_order_date, last_order_date) > 180

UNION ALL

-- 4. Текущий уход в "Уходящий" (если после последнего заказа прошло > 180 дней и новых заказов нет)
SELECT 
    customer_id,
    DATEADD('day', 180, last_order_date) AS transition_date,
    'Active' AS previous_status,
    'Churning' AS new_status,
    180 AS days_in_previous_status
FROM customer_milestones
WHERE DATEDIFF('day', last_order_date, CURRENT_DATE) > 180

UNION ALL

-- 5. Текущий уход в "Ушедший" (если после последнего заказа прошло > 360 дней)
SELECT 
    customer_id,
    DATEADD('day', 360, last_order_date) AS transition_date,
    'Churning' AS previous_status,
    'Churned' AS new_status,
    180 AS days_in_previous_status
FROM customer_milestones
WHERE DATEDIFF('day', last_order_date, CURRENT_DATE) > 360;