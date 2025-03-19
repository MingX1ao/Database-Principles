DROP PROCEDURE IF EXISTS EvaluateDiscountedSales;
DELIMITER //

CREATE PROCEDURE EvaluateDiscountedSales(
    p_date_1 DATE,
    p_date_2 DATE,
    p_price_threshold INT, 
    p_cost_threshold INT, 
    p_city_1 VARCHAR(255), 
    p_city_2 VARCHAR(255),
    p_manufacturer_1 VARCHAR(255), 
    p_manufacturer_2 VARCHAR(255)
)
BEGIN




-- -----------------------------------------------我的操作----------------------------------------------------

    -- 声明临时变量
    DECLARE done BOOLEAN DEFAULT FALSE;
    DECLARE p_customer_id VARCHAR(15);

    
    DECLARE customer_cur CURSOR FOR
    SELECT id FROM Customer;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    -- 防止没除干净
    DROP TABLE IF EXISTS CustomersDiscount, CustomerTotalBefore, CustomerCost, RankedCustomers;

-- --------------------------------------------操作结束--------------------------------------------------------

    




    CREATE TABLE BigCustomer(
        cname VARCHAR(255),
        total_cost INT
    );
    CREATE TABLE NormalCustomer(
        cname VARCHAR(255),
        total_cost INT
    );





-- -------------------------------------------我的操作--------------------------------------------------------


    -- 存放所有用户的第二类折扣
    CREATE TABLE CustomersDiscount(
        cid VARCHAR(15),
        pid VARCHAR(15),
        purchase_count INT DEFAULT 0,
        total_price DECIMAL(20, 10) DEFAULT 0,
        discount DECIMAL(20, 10) DEFAULT 1,
        PRIMARY KEY (cid, pid)
    );

    -- 判断大客户，存放大客户折扣
    CREATE TABLE CustomerTotalBefore(
        cid VARCHAR(15),
        cname VARCHAR(255),
        credit INT UNSIGNED,
        high_price_total DECIMAL(20, 10) DEFAULT 0,
        is_big_customer BOOLEAN DEFAULT FALSE,
        discount DECIMAL(20, 10) DEFAULT 1,
        PRIMARY KEY (cid)
    );

    INSERT INTO CustomerTotalBefore (cid, cname, credit)
    SELECT id, cname, credit FROM Customer;

    -- 存放所有用户的第二类开销
    CREATE TABLE CustomerCost(
        cid VARCHAR(15),
        cname VARCHAR(255),
        total_cost DECIMAL(20, 10) DEFAULT 0,
        PRIMARY KEY (cid)
    );

    INSERT INTO CustomerCost (cid, cname)
    SELECT id, cname FROM Customer;

    
    OPEN customer_cur;
    read_loop: LOOP
        FETCH customer_cur INTO p_customer_id;
        IF done THEN
            LEAVE read_loop;
        END IF;

        
        -- 计算每个客户每种商品的第二类折扣
        INSERT INTO CustomersDiscount (cid, pid, purchase_count, total_price)
        SELECT p_customer_id, product_id, COUNT(*), SUM(quantity * price)
        FROM ProductOrder
        JOIN Product ON ProductOrder.product_id = Product.id
        WHERE customer_id = p_customer_id AND create_date <= p_date_1
        GROUP BY product_id;

        UPDATE CustomersDiscount c
        JOIN Product p ON p.id = c.pid
        SET c.discount = 
            CASE 
                WHEN p.manufacturer IN (p_manufacturer_1, p_manufacturer_2) THEN 1
                WHEN c.purchase_count >= 3 AND c.total_price >= 6000 THEN 0.9
                WHEN c.purchase_count >= 2 AND c.total_price >= 3000 THEN 0.95
                WHEN c.purchase_count >= 1 AND c.total_price >= 1000 THEN 0.98
                ELSE 1
            END
        WHERE c.cid = p_customer_id;

        -- 记录每个用户的第一类开销，不是大客户则默认是0
        UPDATE CustomerTotalBefore ctb
        SET high_price_total = (
            SELECT SUM(price * quantity)
            FROM ProductOrder
            JOIN Product ON ProductOrder.product_id = Product.id
            WHERE customer_id = p_customer_id 
			AND create_date <= p_date_1 
			AND price > p_price_threshold
              		AND (SELECT city FROM Customer WHERE id = p_customer_id) NOT IN (p_city_1, p_city_2)
        )
        WHERE ctb.cid = p_customer_id;

    END LOOP;
    CLOSE customer_cur;

    -- 给大客户排序，加label，计算第一类折扣
    CREATE TABLE RankedCustomers AS
    SELECT cid,
           RANK() OVER (ORDER BY credit DESC, high_price_total DESC) as rnk
    FROM CustomerTotalBefore
    WHERE high_price_total > p_cost_threshold;

    UPDATE CustomerTotalBefore c
    JOIN RankedCustomers r ON c.cid = r.cid
    SET c.is_big_customer = TRUE,
        c.discount = CASE 
	WHEN r.rnk <= 10 THEN 0.9 
	ELSE 0.95 
	END;


    -- 计算第二类开销
    CREATE TABLE TempCustomerTotal AS
    SELECT po.customer_id AS cid, 
    SUM(p.price * po.quantity * IFNULL(ctb.discount, 1) * IFNULL(cd.discount, 1)) AS total_add
    FROM ProductOrder po
    JOIN Product p ON po.product_id = p.id
    LEFT JOIN CustomerTotalBefore ctb ON po.customer_id = ctb.cid
    LEFT JOIN CustomersDiscount cd ON po.customer_id = cd.cid AND po.product_id = cd.pid
    WHERE po.create_date >= p_date_2
    GROUP BY po.customer_id;

    UPDATE CustomerCost c
    JOIN TempCustomerTotal tct ON c.cid = tct.cid
    SET c.total_cost = tct.total_add;

    DROP TABLE TempCustomerTotal;

    
    INSERT INTO BigCustomer (cname, total_cost)
    SELECT c.cname, FLOOR(c.total_cost)
    FROM CustomerCost c
    JOIN CustomerTotalBefore ctb ON c.cid = ctb.cid
    WHERE ctb.is_big_customer = TRUE;

    INSERT INTO NormalCustomer (cname, total_cost)
    SELECT c.cname, FLOOR(c.total_cost)
    FROM CustomerCost c
    JOIN CustomerTotalBefore ctb ON c.cid = ctb.cid
    WHERE ctb.is_big_customer = FALSE;

    
    DROP TABLE IF EXISTS CustomersDiscount, CustomerTotalBefore, CustomerCost, RankedCustomers;
-- -------------------------------操作结束--------------------------------------------------------------

END//
DELIMITER ;