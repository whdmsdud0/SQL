/*
============================================================
[5장 1강] 실습문제: EXPLAIN 결과 해석과 실행계획 요소 식별
============================================================

[실습 목표]
- 복합 쿼리의 EXPLAIN 결과를 아래에서 위로 읽을 수 있다.
- Scan, Join, Sort, Aggregate, WindowAgg 노드를 식별할 수 있다.
- cost, rows, actual rows, actual time의 의미를 구분할 수 있다.
- 실행계획에서 병목 후보 노드를 찾을 수 있다.
- 실행계획을 바탕으로 개선 방향 후보를 설명할 수 있다.

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
- orders
- order_items
- customers

[주요 관계]
- orders.order_id = order_items.order_id
- orders.customer_id = customers.customer_id

[주의사항]
- 실행계획의 cost와 actual time은 환경에 따라 달라질 수 있습니다.
- 특정 숫자를 외우는 것이 아니라, 어떤 노드가 어떤 작업을 하는지 해석하는 것이 핵심입니다.
*/


/*
============================================================
필수 1. 복합 쿼리 실행계획 요소 식별
============================================================

[문제 1-1] 평균보다 비싼 주문상품의 고객별 가격 순위 분석

[문제 설명]
평균 가격보다 비싼 주문상품만 조회하고,
고객별로 상품 가격 순위를 계산하려고 합니다.

JOIN, 서브쿼리, 윈도우 함수가 함께 포함된 쿼리에 EXPLAIN을 적용하고
실행계획의 주요 노드를 식별하세요.

[요구사항]
1. orders와 order_items를 order_id 기준으로 JOIN하세요.
2. order_items.price가 전체 order_items.price 평균보다 큰 행만 조회하세요.
3. 다음 컬럼을 조회하세요.
   - orders.customer_id
   - orders.order_id
   - order_items.product_id
   - order_items.price
4. RANK()를 사용하여 고객별 가격 순위를 계산하세요.
5. PARTITION BY customer_id를 사용하세요.
6. ORDER BY price DESC를 사용하세요.
7. 전체 쿼리에 EXPLAIN을 적용하세요.
8. 실행계획에서 다음 요소가 있는지 확인하세요.
   - Seq Scan 또는 Index Scan
   - Aggregate 또는 InitPlan
   - Join 노드
   - Sort
   - WindowAgg
9. 실행계획을 아래에서 위로 읽으면서 처리 순서를 작성하세요.
10. 다음 질문에 답하세요.
    Q1. 평균 price를 계산하는 작업은 실행계획에서 어떤 노드로 나타날 수 있나요?
    -> Aggregate 노드로 나타날 수 있음
    -> InitPlan 아래에 Aggregate로도 나타날 수 있음(서브쿼리가 별도로 먼저 계산되는 경우)
    
    Q2. orders와 order_items를 결합하는 작업은 어떤 Join 노드로 나타날 수 있나요?
    -> Hash Join, Nested Loop, Merge Join 중 하나로 나타날 수 있음
    
    Q3. WindowAgg 이전에 Sort가 나타날 수 있는 이유는 무엇인가요?
    -> RANK()가 PARTITION BY  고개_ID, ORDER BY 부분이 있기 때문에
    -> 순위 꼐산 전 필요한 순서로 데이터를 정렬하는 과정이 있음
    

[작성 결과]
- 복합 SQL
- EXPLAIN SQL
- 실행계획 주요 노드
- 처리 순서
- Q1~Q3 답변
*/

-- [코드 작성란]

explain
   
SELECT o.customer_id, o.order_id, oi.product_id, oi.price,
rank() over(PARTITION BY o.customer_id ORDER BY oi.price desc) AS price_rank
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE oi.price > (SELECT avg(price)
FROM order_items)



/*
============================================================
필수 2. EXPLAIN ANALYZE로 병목 후보 찾기
============================================================

[문제 2-1] 날짜 조건 주문 조회의 실행계획 해석

[문제 설명]
2023년 주문을 조회하고 order_date 내림차순으로 정렬하는 쿼리의
실제 실행계획을 확인하려고 합니다.

EXPLAIN ANALYZE를 이용하여
예상 비용과 실제 실행 결과를 함께 확인하고
병목 후보가 되는 노드를 찾아보세요.

[요구사항]
1. orders 테이블에서 다음 기간의 주문을 조회하세요.

   order_date >= DATE '2023-01-01'
   order_date <  DATE '2024-01-01'

2. 결과를 order_date DESC로 정렬하세요.
3. 전체 쿼리에 EXPLAIN ANALYZE를 적용하세요.
4. 실행계획에서 다음 항목을 확인하세요.
   - Scan 방식
   - Filter
   - Rows Removed by Filter
   - Sort
   - cost
   - rows
   - actual rows
   - actual time
   - Execution Time
5. 가장 비용 또는 실제 시간이 크게 나타나는 노드를 병목 후보로 정하세요.
-> 1.actual time이 상대적으로 큰노드
-> 2.처리 행 수가 많은 노드
-> 3.Row Removed by Filter가 많은 노드
-> Sort와 같이 추가 비용이 발생하는 노드
6. 다음 질문에 답하세요.
   Q1. cost와 actual time은 어떤 차이가 있나요?
   -> cost는 옵티마이저가 계산한 상대적 비용
   -> actual time은 explain analyze로 실제 쿼리를 실행했을 때 실행된 실제 측정 시간
   
   Q2. rows와 actual rows 차이가 크다면 무엇을 의심할 수 있나요?
   -> 옵티마이저가 실제 데이터 분포를 정확하게 추정하지 못했을 가능성
   -> 데이터 분포 확인 필요
   
   Q3. Rows Removed by Filter가 많다는 것은 무엇을 의미하나요?
   -> where 조건을 만족하지 않아 제거된 행이 많음
   -> 많으면 병목현상을 유발하는 요인 중 하나
   
   Q4. Sort가 큰 비용을 차지한다면 어떤 작업이 성능에 영향을 주고 있다고 볼 수 있나요?
	-> order_date 기준 정렬 작업을 먼저 점검
	-> 정렬 대상 행수와 메모리 확인 필요

[작성 결과]
- EXPLAIN ANALYZE SQL
- 주요 노드 기록
- 병목 후보
- Q1~Q4 답변
*/

-- [코드 작성란]

explain analyze

SELECT *
FROM orders
WHERE order_date >= date '2023-01-01'AND order_date < date '2024-01-01'
ORDER BY order_date DESC;



/*
============================================================
과제. JOIN + 정렬 실행계획 해석
============================================================

[문제 3-1] 고객 주문 조회 실행계획 분석

[문제 설명]
고객 주문 정보를 조회하면서
주문일 기준으로 정렬하는 쿼리의 실행계획을 분석하세요.

이번 문제에서는 실행계획에서
Scan → Join → Sort 흐름을 직접 확인하는 것이 핵심입니다.

※ 과제는 필수 문제와 동일한 수준입니다.

[요구사항]
1. orders와 customers를 customer_id 기준으로 JOIN하세요.
2. 2023년 주문만 조회하세요.
3. 다음 컬럼을 조회하세요.
   - orders.order_id
   - orders.order_date
   - customers.customer_id
   - customers.city
4. 결과를 order_date DESC로 정렬하세요.
5. EXPLAIN ANALYZE를 적용하세요.
6. 실행계획에서 다음 항목을 확인하세요.
   - orders Scan 방식
   - customers Scan 방식
   - Join 방식
   - Sort
   - estimated rows
   - actual rows
   - Execution Time
7. 실행계획을 아래에서 위로 읽으면서 실제 처리 흐름을 설명하세요.
8. 가장 먼저 확인할 병목 후보 노드를 하나 선택하고 이유를 작성하세요.
9. 다음 질문에 답하세요.
   Q1. Scan 노드에서는 무엇을 확인해야 하나요?
   Q2. Join 노드에서는 무엇을 확인해야 하나요?
   Q3. Sort 노드에서는 무엇을 확인해야 하나요?
   Q4. Seq Scan이 나타났다고 해서 무조건 잘못된 실행계획이라고 할 수 있나요?

[제출 결과]
- 전체 SQL
- EXPLAIN ANALYZE 결과
- 실행 흐름
- 병목 후보
- Q1~Q4 답변
*/

-- [코드 작성란]
select 
	orders.order_id,
	orders.order_date,
	customers.customer_id,
	customers.city
from orders
join customers on orders.customer_id = customers.customer_id::integer
where orders.order_date >= '2023-01-01'
	and orders.order_date < '2024-01-01'
order by orders.order_date desc;



/*
============================================================
실습 마무리
============================================================

아래 내용을 한 문단으로 정리하세요.

1. 실행계획은 왜 아래에서 위로 읽는 것이 좋은가요?
-> 실행계획은 하위 노드의 결과가 상위 노드로 전달되는 트리구조
-> 가장 아래 Scan부터 읽으면 데이터의 처리 관정을 이해하기 쉬움

2. Scan, Join, Sort, WindowAgg는 각각 어떤 작업을 의미하나요?
-> Scan: 데이터를 읽는 작업(index,seq 등)
-> Join: 데이터의 결합
-> Sort: 지정된 기준으로 정렬
-> WindowAgg : 윈도우 함수 계산

3. cost와 actual time은 어떻게 다른가요?
-> cost는 옵티마이저가 예상한 상대 비용
-> actual time은 EXPLAIN ANALYZE에서 측정한 실제 실행 시간
4. 병목 노드를 찾을 때 어떤 정보를 함께 봐야 하나요?
->1.actual time이 상대적으로 큰노드
-> 2.처리 행 수가 많은 노드
-> 3.Row Removed by Filter가 많은 노드
-> Sort와 같이 추가 비용이 발생하는 노드
*/
