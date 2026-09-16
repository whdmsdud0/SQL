/*
============================================================
[2장 1강] 실습문제: 인덱스 구조와 동작 원리
============================================================

[실습 목표]
- B-Tree 인덱스가 검색 범위를 줄여 데이터를 탐색하는 원리를 이해할 수 있다.
- CREATE INDEX와 DROP INDEX를 이용하여 인덱스를 생성하고 삭제할 수 있다.
- EXPLAIN ANALYZE를 이용하여 인덱스 생성 전후의 실행계획을 비교할 수 있다.
- pg_indexes를 이용하여 생성된 인덱스 목록을 확인할 수 있다.
- 인덱스 생성에 따라 INSERT, UPDATE, DELETE 시 추가 작업이 필요한 이유를 설명할 수 있다.

[사용 환경]
- PostgreSQL
- DBeaver

[사용 데이터]
- orders      : 300,000행
- products    : 10,000행

[주의사항]
- 실행 시간과 cost는 PostgreSQL 환경에 따라 달라질 수 있습니다.
- 특정 실행계획 형태를 정답으로 고정하지 않습니다.
- 학생은 자신의 EXPLAIN ANALYZE 결과를 기준으로 작성합니다.
*/


/*
============================================================
실습 준비
============================================================
*/

SELECT COUNT(*) AS order_count
FROM orders;

SELECT COUNT(*) AS product_count
FROM products;


/*
============================================================
필수 1. customer_id 인덱스 생성 전후 비교
============================================================

[문제 1-1]

[문제 설명]
orders에서 특정 고객의 주문을 조회할 때
customer_id 인덱스 생성 전후의 실행계획이 어떻게 달라지는지 확인하세요.

[요구사항]
1. idx_orders_customer_id 인덱스가 있다면 삭제하세요.
2. customer_id = 31428 조건으로 주문을 조회하고 EXPLAIN ANALYZE를 적용하세요.
3. 인덱스 생성 전 실행계획에서 다음 항목을 기록하세요.
   - 스캔 방식
   - cost
   - actual rows
   - Execution Time
4. orders.customer_id에 idx_orders_customer_id 인덱스를 생성하세요.
5. 동일한 SELECT문에 다시 EXPLAIN ANALYZE를 적용하세요.

6. 인덱스 생성 후 실행계획에서 다음 항목을 기록하세요.
 	인덱스 생성 후
   - 스캔 방식 :Index Scan using idx_orders_customer_id on orders  
   - cost: cost=0.14..8.16
   - actual rows: rows=1
   - Execution Time: actual time=0.004..0.004 rows=0.00 loops=1)
   
7. 인덱스 생성 전후 결과를 비교하세요.
		인덱스 생성 전
   - 스캔 방식 : Seq Scan on orders 
   - cost : cost=0.00..10.62
   - actual rows : rows=1 
   - Execution Time : actual time=0.008..0.008


8. 다음 질문에 답하세요.
   Q1. 인덱스 생성 전과 후의 스캔 방식은 어떻게 달라졌나요? Seq 스캔에서 index 스캔으로 바뀜
   Q2. B-Tree 인덱스가 customer_id = 31428을 찾을 때
       모든 주문을 처음부터 확인하지 않아도 되는 이유는 무엇인가요? B-Tree 인덱스가 customer_id 값을 정렬된 구조로 저장하기 때문
   Q3. cost와 Execution Time은 같은 의미인가요?

[제출 결과]
- DROP INDEX 문
- 인덱스 생성 전 EXPLAIN ANALYZE
- 개선 전 기록표
- CREATE INDEX 문
- 인덱스 생성 후 EXPLAIN ANALYZE
- 개선 후 기록표
- 전후 비교
- Q1~Q3 답변
*/

-- [코드 작성란]

EXPLAIN analyze
select *
from orders
where customer_id = 31428;

/*
============================================================
필수 2. 인덱스 생성·확인·삭제와 쓰기 비용 이해
============================================================

[문제 2-1]

[문제 설명]
products 테이블의 category_id와 supplier_id 컬럼에
실습용 B-Tree 인덱스를 생성하고,
PostgreSQL 시스템 뷰에서 생성 결과를 확인한 뒤 삭제하세요.

인덱스 생성과 삭제 문법을 익히고,
테이블의 데이터가 변경될 때 관련 인덱스에도 추가 작업이 필요한 이유를 설명하세요.

[요구사항]
1. 다음 실습용 인덱스가 있다면 삭제하세요.
   - idx_products_category_practice
   - idx_products_supplier_practice
2. products.category_id에 idx_products_category_practice 인덱스를 생성하세요.
3. products.supplier_id에 idx_products_supplier_practice 인덱스를 생성하세요.
4. pg_indexes에서 products 테이블의 인덱스 이름과 정의를 조회하세요.
5. 조회 결과에서 두 실습용 인덱스가 생성되었는지 확인하세요.
6. 두 실습용 인덱스를 삭제하세요.
7. pg_indexes를 다시 조회하여 두 인덱스가 삭제되었는지 확인하세요.
8. 다음 질문에 답하세요.
   Q1. CREATE INDEX와 DROP INDEX는 각각 어떤 작업을 수행하나요?
   -create index는 지정한 컬럼 값을 기반으로 인덱스 구조를 생성
   -drop index는 해당 인덱스 구조를 삭제
   
   Q2. INSERT 시 테이블 외에 인덱스에도 추가 작업이 필요한 이유는 무엇인가요?
   - 새행의 인덱스 대상 컬럼값과 테이블 위치 정보를 관련 인덱스의 정렬된 구조에도 추가해야 하기 때문
   
   Q3. 인덱스 컬럼을 UPDATE하거나 행을 DELETE할 때 인덱스에는 어떤 작업이 필요한가요?
   - 인덱스 대상 값이 뱐경되먄 새 값과 행 버전에 맞는 인덱스 항목 필요

[제출 결과]
- 기존 실습용 인덱스 DROP INDEX 문
- 두 개의 CREATE INDEX 문
- pg_indexes 확인 SQL과 생성 확인 결과
- 두 개의 DROP INDEX 문
- pg_indexes 재확인 SQL과 삭제 확인 결과
- 쓰기 작업 시 인덱스 유지 비용에 대한 설명
- Q1~Q3 답변
*/

-- [코드 작성란]
drop index if exists idx_products_category_practice;
drop index if exists idx_products_supplier_practice;

create index idx_products_category_practice on products (category_id;)
create index idx_products_supplier_practice on products (supplier_id;)

select indexname, indexdef
from pg_indexes
where schemaname = 'public' and tablename 'productsand'
order by indexname;

drop index if exists idx_products_category_practice;
drop index if exists idx_products_supplier_practice;

select indexname, indexdef
from pg_indexes
where schemaname = 'public' and tablename 'productsand'
order by indexname;

/* 
============================================================
과제. 범위 검색에서 B-Tree 인덱스 확인
============================================================

[문제 3-1]

[문제 설명]
products.price에 B-Tree 인덱스를 생성하고
price가 100 이상 120 미만인 범위 조회의 실행계획을 비교하세요.

※ 필수 문제와 동일한 수준의 독립 실습입니다.

[요구사항]
1. products.price의 최솟값과 최댓값을 확인하세요.
2. idx_products_price 인덱스가 있다면 삭제하세요.
3. price >= 100 AND price < 120 조건에 EXPLAIN ANALYZE를 적용하세요.
4. 인덱스 생성 전 다음 항목을 기록하세요.
   - 스캔 방식
   - cost
   - actual rows
   - Execution Time
5. products.price에 idx_products_price 인덱스를 생성하세요.
6. 동일한 SELECT문에 다시 EXPLAIN ANALYZE를 적용하세요.
7. 인덱스 생성 후 다음 항목을 기록하세요.
   - 스캔 방식
   - cost
   - actual rows
   - Execution Time
8. 인덱스 생성 전후 결과를 비교하세요.
9. 실습이 끝나면 idx_products_price 인덱스를 삭제하세요.
10. 다음 질문에 답하세요.
    Q1. B-Tree 인덱스는 등호 검색 외에 어떤 비교 조건에 활용될 수 있나요?
    
    Q2. B-Tree 인덱스가 범위 검색에서 검색 범위를 줄일 수 있는 이유는 무엇인가요?
  
    Q3. 인덱스를 많이 만들수록 INSERT, UPDATE, DELETE 비용이 커질 수 있는 이유는 무엇인가요?

[제출 결과]
- MIN/MAX 확인 SQL
- DROP INDEX 문
- 인덱스 생성 전 EXPLAIN ANALYZE
- 개선 전 기록표
- CREATE INDEX 문
- 인덱스 생성 후 EXPLAIN ANALYZE
- 개선 후 기록표
- 전후 비교
- 최종 DROP INDEX 문
- Q1~Q3 답변
*/

-- [코드 작성란]

drop index if exists idx_products_price;

EXPLAIN ANALYZE
select min (products.price), max (products.price)
from products
where price >= 100 AND price < 120;

---스캔 방식: Seq Scan
--- cost : 1.14~1.15
--- actual rows : 1
--- Execution Time: 0.067

create index idx_products_price on products (price);

EXPLAIN ANALYZE
select min (products.price), max (products.price)
from products
where price >= 100 AND price < 120;

---스캔 방식: Seq Scan
--- cost : 0.00 ~ 1.4
--- actual rows : 1
--- Execution Time: 0.067

/*
============================================================
실습 마무리
============================================================

1. B-Tree 인덱스가 검색 속도를 높일 수 있는 핵심 원리는 무엇인가요? 
B-Tree는 키를 정렬된 트리구조로 관리하여 전체 데이터를
순서대로 읽지 않고 검색 범위를 줄일 수 있다.

2. B-Tree 인덱스는 등호 검색과 범위 검색에서 각각 어떻게 활용될 수 있나요?
등호검색에서는 정렬된 트리를 따라 특정 키가 있는 위치로 이동.
범위 검색에서는 범위의 시작 위치를 찾은 뒤 해당 구간을 따라 검색


3. 인덱스를 만들 때 조회 성능뿐 아니라 쓰기 성능도 고려해야 하는 이유는 무엇인가요?
insert delete update시 데이블뿐 아니라 관련 인덱스의 항복 추가 및 유지 그리고 과거 항복 정리가 필요할 수 있다.


*/
