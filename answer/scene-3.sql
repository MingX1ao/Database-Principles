DROP TRIGGER IF EXISTS RefundAtCancel;
DELIMITER //
CREATE TRIGGER RefundAtCancel
AFTER DELETE ON ProductOrder
FOR EACH ROW
BEGIN
    DECLARE t_price INT UNSIGNED;
    -- 只处理已交付的订单
    IF OLD.is_filled = TRUE THEN
        
        SELECT price INTO t_price 
        FROM Product 
        WHERE id = OLD.product_id;
        
        UPDATE Product 
        SET stock = stock + OLD.quantity 
        WHERE id = OLD.product_id;
        
        UPDATE Customer 
        SET balance = balance + (t_price * OLD.quantity)
        WHERE id = OLD.customer_id;

    END IF;
END;
//
DELIMITER ;
