-- 填写建立索引的语句
-- 最多两个索引， 最后会检查索引数量
CREATE INDEX idx_po_1 ON ProductOrder(create_date);
CREATE INDEX idx_po_2 ON ProductOrder(quantity);


/*
DROP INDEX idx_po_1 ON ProductOrder;
DROP INDEX idx_po_2 ON ProductOrder;

需要注意的是，这这个索引只在建库后不重启且第一次后运行时会将运行时间缩短19倍
之后即使DROP，运行时间仍然与索引存在时一致，不知道为什么，即使重启数据库，重启电脑覆盖Cache，难道是写到主存里去了？

以下都发生在没有任何索引的情况下：
在测试中，不加index且建库后不重启MySql时，无论运行多少次scene-1，时间都是1min左右
然而，在重启MySql后，即使我在上一次建库后只运行了scene-1、没有加索引，此时我再次运行scene-1，时间来到了3s左右
我认为是MySql在运行完非常耗时的操作后会自动记录结果并写入主存，之后直接调用？
然而我DROP这个procedure后，在此手动复制scene-1的程序写入，运行，时间仍然是3s左右，推翻了我的猜测🤡

总结一下，索引能够生效的条件是：
1. 建库，运行scene-1（耗时1min），运行scene-1（耗时1min，无论多少次，前提是不重启MySql）；
2. 添加索引，运行scene-2（耗时3s），时间缩短95%；
除此以外，任何情况下运行scene-1都是3s，索引加了和没加一样

------------------------------添加的理由------------------------------------
根据我的scene-1的代码，在ProductIOrder，Product，Customer这三张表上的索引，只有ProductOrder是最有效的
我的代码最大的时间开销就在ProductOrder上，由于其他三个键有系统自动添加的索引，我只能在余下的三个属性中选择
显然is_filled上的索引没什么意义，因此我选择在上述两个属性上加索引
*/
