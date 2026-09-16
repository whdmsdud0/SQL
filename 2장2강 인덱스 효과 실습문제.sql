/*
============================================================
[2장 2강] 실습문제: 인덱스가 효과적인 경우와 비효과적인 경우 판단
============================================================

[실습 목표]
- 컬럼의 카디널리티와 조건의 선택도를 확인할 수 있다.
- 인덱스가 효과적인 조건과 비효과적인 조건을 구분할 수 있다.
- 인덱스 컬럼을 그대로 비교하는 조건과 가공한 조건의 실행계획 차이를 확인할 수 있다.
- 테이블 크기와 데이터 분포를 함께 고려하여 인덱스 추가 여부를 판단할 수 있다.

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
- orders     : 300,000행
- shipments  : 300,000행
- stores     : 100행

[주의사항]
- 실행계획의 스캔 방식과 Execution Time은 PostgreSQL 환경에 따라 달라질 수 있습니다.
- 특정 숫자를 맞히는 것이 아니라 데이터 분포와 실행계획을 근거로 인덱스가 효과적인지 판단하는 것이 핵심입니다.
- 이전 강에서 생성한 실습용 인덱스가 남아 있을 수 있으므로 필요한 경우 DROP INDEX IF EXISTS를 먼저 실행합니다.
*/

- 선택도: 특정 조건에 남는 행의 비율
- 카디널리티: 컬럼의 고유값의 수

/*
============================================================
필수 1. 카디널리티와 선택도로 인덱스 효과 판단하기
============================================================

[문제 1-1] customer_id와 status의 인덱스 적합성 비교

[문제 설명]
온라인 리테일 운영팀에서 두 가지 조회 기능을 자주 사용한다고 가정합니다.

① 특정 고객의 주문 조회
② 특정 배송 상태의 배송 정보 조회

두 컬럼 모두 WHERE 절에 사용되지만,
데이터 분포는 서로 크게 다릅니다.

orders.customer_id와 shipments.status의 카디널리티와 선택도를 확인하고,
어느 컬럼에 인덱스를 추가하는 것이 더 효과적일 가능성이 높은지 판단하세요.

[요구사항]
1. orders 테이블의 전체 행 수와 customer_id의 고유값 수를 조회하세요.
2. customer_id = 31428 조건을 만족하는 행 수를 조회하세요.
3. customer_id = 31428의 선택도를 다음 식으로 계산하세요.

   조건 만족 행 수 / 전체 행 수 * 100

4. shipments 테이블의 전체 행 수와 status의 고유값 수를 조회하세요.
5. status별 행 수와 각 상태가 전체에서 차지하는 비율을 조회하세요.
6. customer_id와 status 중 어느 컬럼이 카디널리티가 더 높은지 설명하세요.
7. 특정 customer_id 조회와 status = 'shipped' 조회 중
   어느 조건의 선택도가 더 낮은지 설명하세요.
8. 데이터 분포만을 기준으로 보았을 때
   어느 컬럼에 인덱스를 추가하는 것이 더 효과적일 가능성이 높은지 판단하고 이유를 작성하세요.

[작성 결과]
- customer_id 카디널리티
- customer_id = 31428의 선택도
- status 카디널리티
- status별 선택도
- 인덱스 효과 판단 및 근거
*/

-- [코드 작성란]


SELECT count(*) AS total_rows, count(DISTINCT customer_id) AS customer_id_cardinality
FROM orders;

SELECT count(*) AS matched_rows, round(count(*) * 100.0 / (SELECT count(*) FROM orders),6)
AS selectivity_pct
FROM orders
WHERE customer_id = 31428;

SELECT count(*) AS total_rows, count(DISTINCT status) AS status_cardinality
FROM shipments;

SELECT status, count(*) AS matchedd_rows, round(count(*) * 100.0 / (SELECT count(*)
FROM shipments),2)
AS selsctivity_pct
FROM shipments
GROUP BY status
ORDER BY status;

/*
============================================================
필수 2. 인덱스 컬럼을 가공했을 때 실행계획 비교하기
============================================================

[문제 2-1] 같은 값을 찾는 두 WHERE 조건 비교

[문제 설명]
orders.customer_id에 인덱스를 생성한 뒤 다음 두 조건을 비교합니다.

A. customer_id = 31428
B. customer_id + 0 = 31428

두 조건은 사람이 보기에는 같은 customer_id를 찾지만,
일반 B-Tree 인덱스는 원래 customer_id 값을 기준으로 구성되어 있습니다.

EXPLAIN ANALYZE를 이용하여 두 쿼리의 실행계획을 비교하세요.

[요구사항]
1. 기존 idx_orders_customer_id 인덱스가 있다면 삭제하세요.
2. orders.customer_id에 idx_orders_customer_id 인덱스를 생성하세요.
3. 다음 두 쿼리에 각각 EXPLAIN ANALYZE를 적용하세요.

   A. WHERE customer_id = 31428
   B. WHERE customer_id + 0 = 31428

4. 두 실행계획에서 다음 항목을 비교하세요.
   - 스캔 방식
   - 조건이 표시되는 위치(Index Cond 또는 Filter)
   - cost
   - actual rows
   - Execution Time
  
 항목        	 		조건 a      |      조건 b
 스캔방식  			index scan |     seq scan
 조건표시위치 			index cond |     filter
 cost       			0.00..4.48 |     0.00.4558.06
 actual rows/loop   	 19/1      |        19/1
 execution time     	 0.088ms   |     92.880 ms
   
   
5. 다음 질문에 답하세요.
   Q1. 두 쿼리는 같은 customer_id를 찾는데도 실행계획이 달라질 수 있는 이유는 무엇인가요?
   
   -> 일반 B-Tree 인덱스는 customer_id의 원래 값을 기준으로 구성되어 있음
   -> customer_id = 31428은 인덱스의 키를 직접 비교
   -> customer_id + 0 = 31428은 컬럼을 가공한 결과를 기준으로 비교
   -> customer_id + 0는 기존 인덱스의 정렬 구조를 직접 활용하기 어려움
   
   Q2. 일반 B-Tree 인덱스를 효과적으로 사용하려면 WHERE 절을 어떤 형태로 작성하는 것이 좋은가요?
   
   -> 가능하면 인덱스 컬럼을 함수나 연산으로 가공하지 않고 , 원래 컬럼 값을 그대로 비교하는 형태로 작성하는 것이 좋음
	->
6. 실습 종료 후 idx_orders_customer_id 인덱스를 삭제하세요.

[작성 결과]
- CREATE INDEX 문
- 조건 A의 EXPLAIN ANALYZE
- 조건 B의 EXPLAIN ANALYZE
- 실행계획 비교
- Q1~Q2 답변
- DROP INDEX 문
*/

-- [코드 작성란]
drop index if exists idx_orders_customer_id;

create index idx_orders_customer_id on orders(customer_id);

explain analyze
select *
from orders
where customer_id = 31428;

explain analyze
select *
from orders
where customer_id = 31428;



/*
============================================================
과제. 작은 테이블의 인덱스 추가 여부 판단하기
============================================================

[문제 3-1] stores.city에 인덱스를 추가해야 할까?

[문제 설명]
매장 조회 기능에서 특정 도시의 매장을 검색한다고 가정합니다.

stores 테이블은 전체 데이터가 100행으로 매우 작고,
city 컬럼에는 몇 개의 도시만 반복해서 저장되어 있습니다.

실제 데이터 분포와 실행계획을 확인한 뒤
stores.city에 인덱스를 추가하는 것이 효과적인 선택인지 판단하세요.

※ 과제는 필수 문제와 동일한 수준입니다.
   새로운 인덱스 기법을 사용하는 것이 아니라
   이번 강에서 배운 판단 기준을 스스로 적용하는 문제입니다.

[요구사항]
1. stores 테이블의 전체 행 수를 조회하세요.
2. city의 고유값 수를 조회하세요.
3. city별 행 수와 전체에서 차지하는 비율을 조회하세요.
4. 기존 idx_stores_city 인덱스가 있다면 삭제하세요.
5. city = 'Mumbai' 조건에 EXPLAIN ANALYZE를 적용하세요.
6. stores.city에 idx_stores_city 인덱스를 생성하세요.
7. 같은 조건에 다시 EXPLAIN ANALYZE를 적용하세요.
8. 인덱스 생성 전후의 스캔 방식과 Execution Time을 비교하세요.
9. 다음 네 가지 기준으로 stores.city 인덱스의 적절성을 판단하세요.
   - 카디널리티
   - 선택도
   - 테이블 크기
   - 인덱스 유지 비용
10. 최종적으로 "인덱스 추가를 적극적으로 권장한다 / 우선순위가 낮다" 중 하나를 선택하고 근거를 작성하세요.
11. 실습 종료 후 idx_stores_city 인덱스를 삭제하세요.

[제출 결과]
- 데이터 분포 확인 SQL
- 인덱스 생성 전 EXPLAIN ANALYZE
- CREATE INDEX 문
- 인덱스 생성 후 EXPLAIN ANALYZE
- 네 가지 기준에 따른 판단
- 최종 결론
- DROP INDEX 문
*/

-- [코드 작성란]

select count(*) as total_store
from stores;

select count(distinct city) as distinct_cities
from stores;

select
	city,
	count(*) as city_cnt,
	round(100.0 * count(*) / sum(count(*)) over (),2) as pct
from stores s
group by city;

drop index if exists idx_stores_city;

explain analyze
select * from stores where city = 'Mumbai';


--인덱스 생성 전
--스캔 방식: Seq Scan
--Execution Time :0.058ms 


create index idx_stores_city on stores (city);


explain analyze
select * from stores where city = 'Mumbai';

--인덱스 생성 후
--스캔 방식: Seq Scan
--Execution Time: 0.060



/*
============================================================
실습 마무리
============================================================

아래 내용을 한 문단으로 정리하세요.

1. 카디널리티가 높고 선택도가 낮은 조건에서 인덱스가 유리한 이유는 무엇인가요? 
-> 서로 다른 값이 많고 조건을 만족하는 행이 적으면 인덱스를 통해 전체 테이블을 읽지 않고 필요한 소수의 행 위치만 빠르게 찾을 수 있음

2. 인덱스가 존재해도 PostgreSQL이 Seq Scan을 선택할 수 있는 이유는 무엇인가요?
-> 옵티마이저는 인덱스 존재 여부만 보는 것이 아니라 조회해야 할 행의 비율, 테이블 크기, 통계정보 등을 이용해 예상 비용을 비교
-> 많은 행을 읽어야 하거나 테이블이 작은 편이라면 seq scan의 비용이 더 낮을 수도 있음

3. WHERE 절에서 인덱스 컬럼을 가공하지 않는 것이 좋은 이유는 무엇인가요?
-> 일반 B-Tree 인덱스는 원래 컬럼 값을 기준으로 구성됨
-> 함수나 연산을 적용하면 기존 인덱스의 정렬 구조를 직접적 검색 조건으로 활용하기 어려움

4. 인덱스 추가 여부를 판단할 때 확인해야 할 네 가지 기준은 무엇인가요?
-> 4-1 컬럼의 카디널리티가 충분히 높은가?
-> 4-2 조건을 적용했을 때 선택도가 낮은가?
-> 4-3 테이블 규모가 충분히 큰가?
-> 4-4 조회 이득이 insert update delete 시 발생하는 인덱스 유지 비용을 감당할 만큼 큰가?

*/
