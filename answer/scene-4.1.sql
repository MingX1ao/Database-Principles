DROP TRIGGER IF EXISTS LogOrderChange;
DELIMITER //
CREATE TRIGGER LogOrderChange
AFTER UPDATE ON ProductOrder
FOR EACH ROW
BEGIN
 
    INSERT INTO OrderAudit(
        change_time,
        operator,
        old_order_id,
        old_create_date,
        old_customer_id,
        old_product_id,
        old_quantity,
        old_is_filled,
        new_order_id,
        new_create_date,
        new_customer_id,
        new_product_id,
        new_quantity,
        new_is_filled
    )
    VALUES(
        CURRENT_TIMESTAMP(),
        (SELECT USER()),
        OLD.id,
        OLD.create_date,
        OLD.customer_id,
        OLD.product_id,
        OLD.quantity,
        OLD.is_filled,
        NEW.id,
        NEW.create_date,
        NEW.customer_id,
        NEW.product_id,
        NEW.quantity,
        NEW.is_filled
    );
END;
//
DELIMITER ;
