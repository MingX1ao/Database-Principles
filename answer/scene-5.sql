DROP PROCEDURE IF EXISTS CreateAndFillOrder;
DELIMITER //
CREATE PROCEDURE CreateAndFillOrder(
    IN p_order_id VARCHAR(15),
    IN p_customer_id VARCHAR(15),
    IN p_product_id VARCHAR(15),
    IN p_quantity INT UNSIGNED
)
CreateAndFillOrder:BEGIN
    DECLARE p_stock INT UNSIGNED;
    DECLARE p_discount DOUBLE;
    DECLARE p_price INT UNSIGNED;
    DECLARE p_cost_off DOUBLE;
    DECLARE p_cost_full DOUBLE;
    DECLARE p_balance INT UNSIGNED;
    DECLARE p_credit INT UNSIGNED;
    DECLARE p_error BOOLEAN DEFAULT FALSE;
    DECLARE CONTINUE HANDLER FOR SQLSTATE '45000' SET p_error = TRUE;

    START TRANSACTION;
    
    -- 1. 创建订单
    INSERT INTO ProductOrder (id, create_date, customer_id, product_id, quantity, is_filled)
    VALUES (p_order_id, CURDATE(), p_customer_id, p_product_id, p_quantity, FALSE);
    
    SAVEPOINT after_create_order;
    
    -- 2. 检查并扣除库存
    SELECT stock, price INTO p_stock, p_price 
    FROM Product WHERE id = p_product_id FOR UPDATE;
    
    IF p_stock >= p_quantity THEN
        UPDATE Product SET stock = stock - p_quantity 
        WHERE id = p_product_id;
        
        IF p_error THEN
            ROLLBACK TO after_create_order;
            COMMIT;
            LEAVE CreateAndFillOrder;
        END IF;
        
        -- 3. 尝试使用优惠券并扣款
        SAVEPOINT after_update_stock;
        
        SELECT MIN(discount) INTO p_discount 
        FROM Coupon 
        WHERE customer_id = p_customer_id;
        
        SET p_cost_off = p_price * p_quantity * IFNULL(p_discount, 1);
        SET p_cost_full = p_price * p_quantity;

        SELECT balance, credit INTO p_balance, p_credit 
        FROM Customer 
        WHERE id = p_customer_id FOR UPDATE;
        
        IF p_discount IS NOT NULL AND p_balance >= p_cost_off THEN
            -- 使用优惠券
            DELETE FROM Coupon 
            WHERE customer_id = p_customer_id AND discount = p_discount;
            
            IF NOT p_error THEN
                UPDATE Customer 
                SET balance = balance - p_cost_off 
                WHERE id = p_customer_id;
                
                IF NOT p_error THEN
                    UPDATE ProductOrder SET is_filled = TRUE 
                    WHERE id = p_order_id;
                    COMMIT;
                    LEAVE CreateAndFillOrder;
                END IF;
            END IF;
            ROLLBACK TO after_update_stock;
        END IF;
        
        -- 尝试全价扣款
        IF p_balance >= p_cost_full THEN
            UPDATE Customer 
            SET balance = balance - p_cost_full 
            WHERE id = p_customer_id;
            
            IF NOT p_error THEN
                UPDATE ProductOrder SET is_filled = TRUE 
                WHERE id = p_order_id;
                COMMIT;
                LEAVE CreateAndFillOrder;
            END IF;
            ROLLBACK TO after_update_stock;
        END IF;
        
        -- 尝试使用信用额度
        IF p_balance + p_credit >= p_cost_full THEN
            UPDATE Customer 
            SET credit = credit - (p_cost_full - balance),
                balance = 0 
            WHERE id = p_customer_id;
            
            IF NOT p_error THEN
                UPDATE ProductOrder SET is_filled = TRUE 
                WHERE id = p_order_id;
                COMMIT;
                LEAVE CreateAndFillOrder;
            END IF;
            ROLLBACK TO after_update_stock;
        END IF;
    END IF;
    
    -- 如果所有尝试都失败，回滚到创建订单后的状态
    ROLLBACK TO after_create_order;
    COMMIT;
END CreateAndFillOrder;
//
DELIMITER ;