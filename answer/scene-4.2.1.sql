-- 1 条语句：创建 SalesManager 用户
	CREATE USER 'SalesManager'@'localhost' IDENTIFIED BY '123456';
-- 1 条语句：授予权限
	GRANT ALL PRIVILEGES 
	ON TABLE homework3_4_5_db.OrderAudit
	TO 'SalesManager'@'localhost'
	WITH GRANT OPTION;