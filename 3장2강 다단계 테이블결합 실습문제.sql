/*
============================================================
[3장 2강] 실습문제: 다단계 테이블 결합으로 복합 데이터셋 구성
============================================================

[실습 목표]
- 3개 이상의 테이블 관계를 따라 다단계 JOIN을 작성할 수 있다.
- INNER JOIN과 LEFT JOIN을 요구사항에 맞게 선택할 수 있다.
- LEFT JOIN에서 ON과 WHERE의 필터 위치에 따른 결과 차이를 설명할 수 있다.
- 1:N 관계로 인한 정상적인 행 증가와 잘못된 중복을 구분할 수 있다.
- 조인 후 행 수와 NULL 여부를 검증하여 결과의 적절성을 확인할 수 있다.

[사용 환경]
- PostgreSQL
- DBeaver

[사용 데이터]
이번 과정에서는 아래 12개 CSV로 구성된 동일한 Retail Data Warehouse 데이터셋을 계속 사용합니다.

- customers
- employees
- order_items
- orders
- payments
- products
- promotions
- returns
- shipments
- stores
- suppliers
- categories

[이번 강에서 주로 사용하는 테이블]
- customers
- orders
- order_items
- products
- shipments

[주요 관계]
- customers.customer_id = orders.customer_id
- orders.order_id = order_items.order_id
- order_items.product_id = products.product_id
- orders.order_id = shipments.order_id

[주의사항]
- 하나의 주문에 여러 상품이 포함되면 같은 order_id가 여러 행으로 나타날 수 있습니다.
- 이 행 증가는 1:N 관계에 의한 정상적인 결과일 수 있으므로, 무조건 중복으로 판단하지 않습니다.
- 이번 강에서는 조인 결과가 요구사항에 맞게 구성되었는지를 검증하는 것이 핵심입니다.
*/


/*
============================================================
필수 1. 4개 테이블을 이용한 주문 상세 데이터셋 구성
============================================================

[문제 1-1] 고객-주문-주문상세-상품 정보 결합하기

[문제 설명]
운영팀에서 "어떤 고객이 어떤 상품을 주문했는지" 확인할 수 있는
주문 상세 데이터셋을 만들려고 합니다.

필요한 정보는 customers, orders, order_items, products에 나뉘어 있습니다.

테이블 간 관계를 따라 4개 테이블을 단계적으로 JOIN하고,
결과 행 수가 증가하는 이유까지 확인하세요.

[요구사항]
1. orders를 기준으로 customers를 customer_id로 JOIN하세요.
2. orders와 order_items를 order_id로 JOIN하세요.
3. order_items와 products를 product_id로 JOIN하세요.
4. 다음 컬럼을 조회하세요.
   - orders.order_id
   - orders.order_date
   - customers.customer_id
   - customers.city
   - products.product_id
   - order_items.qty
   - order_items.price
5. 결과를 order_id 오름차순, product_id 오름차순으로 정렬하세요.
6. 조인 전 orders 전체 행 수와 조인 후 결과 행 수를 각각 확인하세요.
7. order_id별 행 수를 GROUP BY로 계산하고,
   2행 이상 나타나는 주문만 조회하세요.
8. 다음 질문에 답하세요.
   Q1. 조인 후 결과 행 수가 orders 행 수보다 많아질 수 있는 이유는 무엇인가요?
   -> orders와 order_items가 1:N 관계
   -> 주문 하나에 여러 주문 상품이 포함될 수 있음
   
   Q2. 같은 order_id가 여러 행으로 나타났다고 해서 무조건 잘못된 중복인가요?
   -> No, 한 주문엥 여러 상품이 포함되어 있으면 order_id가 여러행으로 나타날 수 있다.
   
   Q3. 이번 조회에서 order_items가 중요한 연결 테이블인 이유는 무엇인가요?
   -> orders 테이블에는 주문 정보가 들어 있고, products에는 상품정보가 있지만
   -> 어떤 주문에 어떤 상품이 포함되어 있는 지는 order_items가 연결한다.

[작성 결과]
- 4개 테이블 JOIN SQL
- 조인 전/후 행 수
- order_id별 중복 확인 SQL
- Q1~Q3 답변
*/

-- [코드 작성란]
SELECT
	o.order_id,
    	o.order_date,
    c.customer_id,
    c.city,
    product_id,
    oi.qty,
    oi.price
FROM orders o 
JOIN customer ON orders.customer_id = customers.customer_id
JOIN order_items ON orders.order_id = order_items.order_id
JOIN products ON order_items.product_id = products.product_id
ORDER BY orders.order_items.order_id ASC, products.product_id DESC;

-- 조인 전 orders 전체 행 수
SELECT count(*) AS orders_count
FROM orders;

--조인 후 결과 행
SELECT count(*) AS joined_count
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p ON p.product_id = oi.product_id;

--order_id별 행 수를 group by로 계산
SELECT o.order_id, count(*) AS row_count
FROM orders o
JOIN customer ON orders.customer_id = customers.customer_id
JOIN order_items ON orders.order_id = order_items.order_id
JOIN products ON order_items.product_id = products.product_id
GROUP BY o.order_id
HAVING count(*) >= 2;
--ORDER BY row_count DESC, o.order_id;

/*
============================================================
필수 2. LEFT JOIN에서 ON과 WHERE 필터 위치 비교
============================================================

[문제 2-1] 모든 고객을 유지하면서 특정 매장 주문만 연결하기

[문제 설명]
고객관리팀에서 전체 고객 목록은 유지하되,
특정 매장에서 발생한 주문이 있다면 주문 정보도 함께 보고 싶어합니다.

LEFT JOIN을 사용한 상태에서
store_id = 1 조건을 WHERE에 작성했을 때와 ON에 작성했을 때
결과가 어떻게 달라지는지 비교하세요.

[요구사항]
1. customers를 왼쪽 테이블로 사용하세요.
2. orders를 customer_id 기준으로 LEFT JOIN하세요.
3. 다음 컬럼을 조회하세요.
   - customers.customer_id
   - customers.city
   - orders.order_id
   - orders.store_id
4. 첫 번째 쿼리는 LEFT JOIN 후 WHERE o.store_id = 1 조건을 사용하세요.
5. 두 번째 쿼리는 LEFT JOIN의 ON 절에 AND o.store_id = 1 조건을 추가하세요.
6. 두 쿼리의 전체 결과 행 수를 각각 확인하세요.
7. 두 번째 쿼리에서 order_id가 NULL인 행의 수를 확인하세요.
8. 다음 질문에 답하세요.
   Q1. WHERE에 o.store_id = 1을 작성하면 주문이 없는 고객이 왜 사라지나요?
   -> left join으로 주문이 없는 고객은 orders 컬럼이 null인 상태로 생성
   -> 그 후 where o.store_id = 1 조건을 적용하면
   -> null = 1인 행은 True가 아니라 unknown으로 True 행만 남기는 wher에서 해당 고갱이 제외
   
   Q2. ON에 o.store_id = 1을 작성하면 주문이 없는 고객이 왜 유지되나요?
   -> on 조건은 어떤 orders행을 customers와 연결할 지를 결정
   -> 1번 매장 주문이 없더라도 left join의 왼쪽 테이블인 customer 행은 유지
   -> orders 컬럼만 null로 표시
   
   Q3. "전체 고객을 유지하면서 1번 매장 주문만 연결"이라는 요구사항에는 어느 쿼리가 더 적절한가요?
   -> on 절에 o.store_id = 1 조건 작성한 쿼리가 적절

[작성 결과]
- WHERE 조건 방식 SQL
- ON 조건 방식 SQL
- 두 방식의 행 수 비교
- NULL 행 수 확인
- Q1~Q3 답변
*/

-- [코드 작성란]

SELECT customers.customer_id, customers.city, orders.order_id, orders.store_id
FROM customers c
LEFT JOIN orders ON c.customer_id  = orders.customer_id
WHERE o.store_id = 1;



-- ON절에 조건 추가

SELECT customers.customer_id,customers.city,orders.order_id, orders.store_id
FROM customers c
LEFT JOIN orders ON c.customer_id  = orders.customer_id 
and o.store_id = 1;



-- where

select count(*) as where_count
from customer c
left join orders o on c.customer_id = o.customer
and o.store_id = 1;



--order_id가 null인 거 확인

select(*) as no_store_1_order_count
from customer c
left join orders o on c.customer_id = o.customer_id
and o.store_id = 1
where o.order_id is null;

/*
============================================================
과제. 주문-배송 복합 데이터셋 구성 및 결과 검증
============================================================

[문제 3-1] 모든 주문을 유지하면서 배송 정보 결합하기

[문제 설명]
물류 운영팀에서 모든 주문을 기준으로 배송 정보를 함께 확인하려고 합니다.

배송 정보가 없는 주문도 결과에서 사라지면 안 되므로,
적절한 JOIN 종류를 선택해야 합니다.

또한 조인 후 주문 수가 의도와 맞는지 검증해야 합니다.

※ 과제는 필수 문제와 동일한 수준입니다.
   이번 강에서 배운 JOIN 종류 선택과 결과 검증을 스스로 적용하는 문제입니다.

[요구사항]
1. orders를 기준 테이블로 사용하세요.
2. customers를 customer_id 기준으로 JOIN하세요.
3. shipments를 order_id 기준으로 연결하되,
   배송 정보가 없는 주문도 유지되도록 적절한 JOIN 종류를 사용하세요.
4. 다음 컬럼을 조회하세요.
   - orders.order_id
   - orders.order_date
   - customers.customer_id
   - customers.city
   - shipments.shipment_id
   - shipments.status
5. orders 전체 행 수를 확인하세요.
6. 최종 조인 결과의 전체 행 수를 확인하세요.
7. shipment_id가 NULL인 주문 수를 확인하세요.
8. order_id별 행 수를 GROUP BY하고,
   2행 이상 나타나는 주문이 있는지 확인하세요.
   
   
9. 다음 질문에 답하세요.
   Q1. shipments를 INNER JOIN이 아니라 LEFT JOIN으로 연결해야 하는 이유는 무엇인가요?
   -> 배송정보가 없는 주문도 남겨야 하는데 inner join을 쓰면 미배송 주문이 통째로 사라진다.
   
   Q2. shipment_id가 NULL인 행은 어떤 의미인가요?
   -> order_id와 짝이 되는 행이 없다는 뜻이다. 
   
   Q3. 조인 후 행 수가 orders보다 많아졌다면 어떤 관계나 데이터를 먼저 점검해야 하나요?
   -> customrers 테이블과 shipments테이블을 하나씩 확인해본다. 키가 중복되는지 본다.
  
   Q4. 조인 결과 검증을 위해 행 수, 중복, NULL을 함께 확인해야 하는 이유는 무엇인가요?
   ->  행 수만 본다면 만약 미배송 주문 3건이 사라지고 동시에 다른 주문에서 3행이 늘어난다면 총합은
   그대로이기 때문이다. 
   -> 중복만 본다면 중복이 0이어도 행이 줄었을 수 있기 때문이다.
   -> NULL만 본다면 미배송 주문이 남아있어도, 중복 복제가 일어나 금액이 두배가 될 수 있다.
   
   Q5. LEFT JOIN한 shipments의 status 조건을
       ON 절에 작성하는 경우와 WHERE 절에 작성하는 경우
       결과가 어떻게 달라질 수 있나요?
       -> status 조건을 on에 쓰면 모든 주문이 남고, where에 쓰면 null행까지 걸러져서 inner join이 됩니다.

[제출 결과]
- 다단계 JOIN SQL
- orders 행 수
- 조인 후 행 수
- 배송 정보 없는 주문 수
- order_id 중복 검증
- Q1~Q5 답변
*/

-- [코드 작성란]

select 
	o.order_id,
	o.order_date,
	c.customer_id,
	c.city,
	s.shipment_id,
	s.status
from orders o
left join customers c
	on o.customer_id = c.customer_id
left join shipments s 
	on o.order_id = s.order_id 
order by o.order_id;


explain analyze
select 
	(select count(*) from orders) as orders_total,
	count(*) as joined_totals,
	count(*) - (select count(*) from orders) as row_diff,
	sum(case when shipment_id is null then 1 else 0 end) as no_shipment_cnt  
from orders o
left join customers c on o.customer_id = c.customer_id
left join shipments s on o.order_id = s.order_id		
group by o.order_id
having count(*) >= 2;

/*
============================================================
실습 마무리
============================================================

아래 내용을 한 문단으로 정리하세요.

1. 다단계 조인을 작성할 때 가장 먼저 확인해야 하는 것은 무엇인가요?
-> 최종 결과에 필요한 컬럼이 어느 테이블에 있는지
-> 테이블 간 열결 키 및 관계 유형 확인 필요

2. 1:N 관계에서 행 수가 증가하는 이유는 무엇인가요?
-> 기준 테이블의 한 행에 상대 테이블의 여러 행이 연결될 수 있음
-> 기준 행이 매칭되는 개수 만큼 여러 행으로 확장되기 때문

3. LEFT JOIN에서 오른쪽 테이블 조건을 ON과 WHERE에 둘 때 결과가 달라지는 이유는 무엇인가요?
-> on은 어떤 행을 연결할지 결정하는데
-> where은 조인이 끝난 결과에서 어떤 행을 남길 지를 결정하기 때문
4. 조인 결과를 검증할 때 어떤 항목을 확인해야 하나요?
-> 조인 전후 행 수, 기준 키의 중복 여부, left join 결과와 null 여부를 함께 확인
*/
