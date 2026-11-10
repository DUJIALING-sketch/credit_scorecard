
--CREATE TABLE loans AS
--SELECT *
--FROM read_csv(
--    'D:/credit_scorecard/data/cs-training.csv',
--    header  = true,
--    nullstr = 'NA',
--    names   = ['id', 'y', 'util', 'age', 'dpd30', 'debt_ratio', 'income',
--               'open_lines', 'dpd90', 're_loans', 'dpd60', 'dependents']
--);
-- 因为表已经建好了，如果再执行一次 CREATE TABLE，会报错「表已存在」。建议把它变成注释：选中整段建表代码，按 Ctrl + /，每行前面会加上 --。

SELECT COUNT(*) FROM loans;

--第 6 步：看看表的结构
DESCRIBE loans;

--写一句 SQL，选出 id、dpd30、dpd60、dpd90 这 4 列，只要前 10 行。
SELECT id, dpd30,dpd60,dpd90 FROM loans LIMIT 10;
--脚本里有多句 SQL 时，分号用来告诉数据库「这一句结束了」，养成每句都加分号的习惯

--第 8 步：WHERE 筛选行
--为什么：前面学的 SELECT 是选列，WHERE 是选行，也就是只要满足条件的客户。风控里几乎每句 SQL 都会用到它，比如「只看有过 90 天逾期的人」「只看年龄小于 25 岁的人」。
--第 1 题：找出 util 大于 1 的客户，显示 id、util、y 三列，取前 10 行。
SELECT id,util,y FROM loans WHERE util>1 LIMIT 10;
--第 2 题：用 COUNT(*) 算出 util 大于 1 的客户一共有多少人。
SELECT COUNT(*) FROM loans WHERE util>1;

--第 9 步：用 AVG(y) 算坏账率
--为什么：知道超限的有 3,321 人还不够，风控真正关心的是：这些人风险高不高？
--SELECT 后面可以同时放多个计算，用逗号隔开。
SELECT COUNT(*), AVG(y) FROM loans WHERE util > 1;
--自己改写一句，算 util <= 1 的人数和坏账率
SELECT COUNT(*), AVG(y) FROM loans WHERE util <= 1;
--去掉 WHERE，算全部客户的人数和坏账率。
SELECT COUNT(*), AVG(y) FROM loans ;

--第 10 步：AND 和 OR，组合多个条件
--把超限客户拆成两组，分别算人数和坏账率：
--第 1 题：真实超限组，util > 1 并且 util <= 1.1
SELECT COUNT(*), AVG(y) FROM loans WHERE util <= 1.1 and util>1;
--第 2 题：疑似数据错误组，util > 1.1
SELECT COUNT(*), AVG(y) FROM loans WHERE util>1.1;
--分析：很多人会以为「数据错误」组是随机乱码，坏账率应该接近平均水平。但实际上它的坏账率不仅没降，还比真实超限组略高。
--这说明：这些极端值不是随机错误，背后很可能也是高风险客户，比如额度被冻结、降到很低，导致比值暴涨。所以它们仍然带有风险信息。
--这也说明你评分卡里的处理方式是对的：截断到 1.1，而不是删除或置空。
--极端值本身就带有风险信号，不是噪声。删掉会让模型低估风险，而且上线后同样的数据还会出现，模型必须能处理。

--第 11 步：ORDER BY 排序
--之前说过，只写 LIMIT 时，返回哪几行是不确定的。要看「util 最大的 10 个人」这类结果，必须先排序。
--书写顺序：SELECT → FROM → WHERE → ORDER BY → LIMIT
--第 1 题：找出 util 最大的 10 个人，显示 id、util、y。
SELECT id,util,y FROM loans ORDER BY util DESC LIMIT 10;
--该结果现实util最大的那几个1，y是0，合理的解释是：util > 1.1 这一组其实混在一起了。
--1.1 到几倍之间的，可能是真实的严重超限，风险很高
--几千、几万倍的，更像真正的数据错误，风险反而不高
--第 2 题：找出年龄最小的 10 个人，显示 id、age、y。预测会出现年龄0
SELECT id, age,y FROM loans ORDER BY age LIMIT 10;
--第 1 题：验证发现 1。把 util > 1.1 的客户再拆成两组，分别算人数和坏账率：util > 1.1 AND util <= 10，util > 10
SELECT COUNT(*), AVG(y) FROM loans WHERE util>1.1 and util <=10;
SELECT COUNT(*), AVG(y) FROM loans WHERE util >10;
--发现：可以把阈值设为10而非1.1
--第 2 题：把年龄那题改成 ORDER BY age, id，看看结果的 id 顺序有什么变化。预测id也从小到大排
SELECT id, age, y FROM loans ORDER BY age, id LIMIT 10;


--第 12 步：GROUP BY 分组统计
--刚才为了比较 4 组客户，你写了 4 句 SQL，每次手动改 WHERE。如果要比 20 组呢？GROUP BY 可以一句话按某列把人分组，每组分别算 COUNT 和 AVG。
--顺序;SELECT(要什么) → FROM（从哪要） → WHERE（行条件） → GROUP BY （分组）→ ORDER BY （顺序）→ LIMIT（几行）
--预测十几行，会出现96，98，且坏账率高
SELECT dpd90, COUNT(*), AVG(y)
FROM loans    --每组显示：组的值、人数、坏账率
GROUP BY dpd90  --按 dpd90 的取值分组：0 次一组、1 次一组、2 次一组……
ORDER BY dpd90;  --结果按组的值排序


--第 13 步：用 AS 起名，用 ROUND 保留小数
--第 1 题：运行 SELECT COUNT(DISTINCT dpd90) FROM loans;，验证你的行数预测。
SELECT COUNT(DISTINCT dpd90) FROM loans;
--第 2 题：改写 GROUP BY 那句，让结果的 3 列分别叫 dpd90、n、bad_rate，坏账率保留 4 位小数。然后拉到结果最下面，看 96 和 98 两行的人数和坏账率。
SELECT dpd90, COUNT(*) AS n, ROUND(AVG(y),4)AS bad_rate
FROM loans   
GROUP BY dpd90  
ORDER BY dpd90; 



--第 14 步：HAVING，筛选分组后的结果
--上次说过，dpd90 = 6 那组只有 80 人，坏账率不稳定。如果只想看人数 ≥ 100 的组，该怎么写？
--注意WHERE → GROUP BY → HAVING，所以只能用having
--第 1 题：运行上面倒序排列那句，看 96、98 的人数和坏账率。
SELECT dpd90, COUNT(*) AS n, ROUND(AVG(y),4)AS bad_rate
FROM loans   
GROUP BY dpd90  
ORDER BY dpd90 DESC
LIMIT 3; 
--第 2 题：在 dpd90 分组那句里加上 HAVING COUNT(*) >= 100，只保留人数 ≥ 100 的组。
SELECT dpd90, COUNT(*) AS n, ROUND(AVG(y),4)AS bad_rate
FROM loans   
GROUP BY dpd90  
HAVING COUNT(*)>=100
ORDER BY dpd90 ; 

--第 15 步：IS NULL，找出空值
--为什么：income 有缺失。风控里经常要问：缺失多少？缺失的人风险高不高？
--关键规则：判断空值只能用 IS NULL（不是空值用 IS NOT NULL），不能用 = NULL。
--第 1 题：用 = NULL 数一下收入缺失的人数（故意写错，看看结果）
SELECT COUNT(*) FROM loans WHERE income=NULL;
--第 2 题：改成正确的 IS NULL，再数一次，同时算这群人的坏账率。
SELECT COUNT(*), AVG(y) FROM loans WHERE income IS NULL;
--第 3 题：运行下面这句，比较两个数
SELECT COUNT(*), COUNT(income) FROM loans;
--知识点：COUNT(*)	所有行，不管有没有空值；COUNT(income)	income 不是 NULL 的行；COUNT(DISTINCT income)	income 不是 NULL 的不同取值个数
--COUNT(列名) 只统计该列不为空的行数。所以 COUNT(*) − COUNT(列名) 就是该列的缺失数
--结果分析：收入缺失组的坏账率是 5.61%，比全体的 6.68% 还低。
--很多人的直觉是「不填收入的人更可疑」，但数据说的正好相反。这也和你评分卡里的发现对得上：income、debt_ratio、monthly_debt 三个变量的 Missing 箱合计加了 24 分，也就是被模型判断为更安全。
--为什么会这样？ 没有数据能直接证明，只能提出假设：
--这批客户可能来自不要求填写收入的渠道或产品
--可能是年龄偏大、已退休的人群，收入字段不适用
--重要的结论是：缺失不是随机的。 「谁的数据缺失」本身就带有信息，所以评分卡里把缺失单独作为一箱，而不是用中位数填补。



--第 16 步：CASE WHEN，自己定义分组
--今天你为了比较 util 的 4 组客户，写了 4 句 SQL。CASE WHEN 可以在一句 SQL 里给每个客户打上组别标签，再配合 GROUP BY，一次算出所有组。
--打标签（CASE WHEN ... END）
--它挨个检查每个人的 util 值，给他们贴个标签，并把结果命名为 util_group 列
SELECT
    CASE
        WHEN util <= 1   THEN '1_正常'
        WHEN util <= 1.1 THEN '2_真实超限'
        WHEN util <= 10  THEN '3_严重超限'
        ELSE                  '4_极端值'
    END AS util_group,
    COUNT(*) AS n,               --看看被贴上同一个标签的人有几个；有groupby的时候，count会自动算组而非全部
    ROUND(AVG(y), 4) AS bad_rate  --算该组坏账率
FROM loans
GROUP BY util_group     --按刚刚的分组打包  
ORDER BY util_group;    --按组名从小到大1排

--练习：按「收入是否缺失」分成两组，每组算人数、坏账率、MEDIAN(debt_ratio)。
SELECT 
    CASE   
    	WHEN income IS NULL THEN '收入缺失'
    	ELSE '有收入'
    END AS income_group,
    COUNT(*)AS n,
    AVG(Y)AS bad_rate,
    MEDIAN(debt_ratio)
FROM loans
GROUP BY income_group;
--结果解释：收入缺失时，没有分母可以除，数据里存的很可能直接是负债金额。也就是说，同一个字段，在两群人身上含义完全不同。
--这就是你评分卡第 3 步「收入缺失时 debt_ratio 置空」的依据。如果不处理，直接分箱，1,159 这种值会被当成「负债极高」，结论会完全错。
--用中位数而不是平均数也值得一提：这列有极端值，平均数会被拉偏，中位数更能代表典型水平。



--第 17 步：CASE WHEN 生成「清洗后的新列」
--先学一个新写法：IN。dpd30 IN (96, 98) 等价于 dpd30 = 96 OR dpd30 = 98，值多的时候更简洁。
--例子：清洗 dpd30。规则：96 和 98 是特殊编码，置为空值；其他保持原样
SELECT
    id,
    dpd30,--我要看三个东西：id，原始dpd30，清洗后的30
    CASE
        WHEN dpd30 IN (96, 98) THEN NULL
        ELSE dpd30
    END AS dpd30_clean
FROM loans
WHERE dpd30 IN (96, 98, 0, 1)  --我只关心这四种人：逾期 96 次的、98 次的、0 次的（从来不逾期的好人）、1 次的（逾期过一次的）。
ORDER BY dpd30 DESC
LIMIT 8;--从大到小排，前8行

--练习：写 age_clean。规则：age = 0 置空，其他保持原样，显示 id、age、age_clean，用 ORDER BY age LIMIT 3 检查
SELECT 
    id,
    age,
    CASE 
    	WHEN age=0 THEN NULL 
    	ELSE age
    END AS age_clean
FROM loans
order by age 
LIMIT 3;

--练习：写 util_clean，用今天发现的改进版规则：
--util > 10 → 置空（当作数据错误）
--util > 1.1 → 截断为 1.1
--其他 → 保持原样
--id、util、util_clean，用 ORDER BY util DESC LIMIT 5 检查。
SELECT 
    id,
    util,
    CASE 
    	WHEN util>10 THEN NULL 
    	WHEN util>1.1 THEN 1.1
    	ELSE util
    END AS util_clean
FROM loans
ORDER BY util DESC 
LIMIT 5;

--如果交换util的顺序：预测不是null而是1.1
--原因：CASE WHEN 从上往下判断，满足一个就停下。
SELECT 
    id,
    util,
    CASE 
	    WHEN util>1.1 THEN 1.1
    	WHEN util>10 THEN NULL 
    	ELSE util
    END AS util_clean
FROM loans
ORDER BY util DESC 
LIMIT 5;
   
    
--第 18 步：把所有清洗规则合成一张新表
--刚才每次只清洗一列，而且结果只是显示出来，没有保存。实际工作中，会把清洗好的数据存成一张新表，后面的分析和建模都从这张表开始。
--鲜先学两个新东西;
--1. CREATE OR REPLACE TABLE
--和之前的 CREATE TABLE 一样，但如果表已经存在，就替换掉。这样你写错了可以直接改了再运行，不会报「表已存在」。
--2. 标记变量也用 CASE WHEN 生成，满足条件为 1，否则为 0：CASE WHEN dpd90 IN (96, 98) THEN 1 ELSE 0 END AS dpd_special
-------------------------------------------------------------------------------
--清洗规则汇总（和你评分卡第 3 步一致，util 用今天的改进版）
--列	                                      规则
--dpd30、dpd60、dpd90	                 96 / 98 → 置空
--dpd_special	                    新增标记：dpd90 是 96 / 98 → 1，否则 0
--age	                               0 → 置空
--util	                          > 10 → 置空；> 1.1 → 1.1；其他不变
--util_abnormal	                     新增标记：util > 10 → 1，否则 0
--income_missing	                 新增标记：income 为空 → 1，否则 0
--debt_ratio	                   income 为空 → 置空；> 5 → 5；其他不变
--id、y、income、open_lines、re_loans、dependents	  保持原样
--------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE loans_clean AS
SELECT
    id,
    y,
    -- 逾期字段
    CASE WHEN dpd30 IN (96, 98) THEN NULL ELSE dpd30 END AS dpd30,
    CASE WHEN dpd60 IN (96, 98) THEN NULL ELSE dpd60 END AS dpd60,
    CASE WHEN dpd90 IN (96, 98) THEN NULL ELSE dpd90 END AS dpd90,
    CASE WHEN dpd90 IN (96, 98) THEN 1 ELSE 0 END AS dpd_special,
    -- 年龄
    CASE WHEN age=0 then NULL ELSE age END AS age,
    -- 额度使用率
    CASE WHEN util>10 THEN NULL
         WHEN util>1.1 THEN 1.1
    ELSE util
    END AS util,
    CASE WHEN util>10 THEN 1 ELSE 0 END AS util_abnormal,
    -- 收入和负债比
    income,
    CASE WHEN income IS NULL THEN 1 ELSE 0 END AS income_missing,
    CASE WHEN income IS NULL THEN NULL 
         WHEN debt_ratio >5 THEN 5
    ELSE debt_ratio
    END AS debt_ratio,
    -- 其他保持原样
    open_lines,
    re_loans,
    dependents
FROM loans;

--建表成功后，运行这句检查：
SELECT
    COUNT(*)              AS n,
    COUNT(*) - COUNT(util)       AS util_null,
    COUNT(*) - COUNT(dpd30)      AS dpd30_null,
    COUNT(*) - COUNT(age)        AS age_null,
    COUNT(*) - COUNT(debt_ratio) AS dr_null,
    MAX(util)             AS util_max,
    MAX(debt_ratio)       AS dr_max
FROM loans_clean;

--这次把所有清洗过的列都检查一遍：
SELECT
    COUNT(*)                     AS n,
    COUNT(*) - COUNT(dpd30)      AS dpd30_null,
    COUNT(*) - COUNT(dpd60)      AS dpd60_null,
    COUNT(*) - COUNT(dpd90)      AS dpd90_null,
    COUNT(*) - COUNT(age)        AS age_null,
    COUNT(*) - COUNT(util)       AS util_null,
    COUNT(*) - COUNT(debt_ratio) AS dr_null,
    SUM(dpd_special)             AS dpd_special_n,
    SUM(util_abnormal)           AS util_abnormal_n,
    SUM(income_missing)          AS income_missing_n,
    MAX(util)                    AS util_max,
    MAX(debt_ratio)              AS dr_max
FROM loans_clean;


--又发现一个数据问题
--debt_ratio = 负债 ÷ 收入。收入是 0 时，这个除法根本没法算，可数据里还是有值，而且是几万这样的数。
--合理的推测是：数据方在收入为 0 时，把分母当成 1 来算，所以 debt_ratio 其实又是负债金额本身。
--这和你之前发现的「收入缺失时 debt_ratio 存的是金额」是同一个问题，只是这次出现在 income = 0 或 1 的人身上。
--目前的清洗规则会怎么处理他们？ 他们的收入不是空值，所以 debt_ratio 被截断为 5，落进「负债比最高」的那一箱。但他们的 debt_ratio 其实不是比例，这样处理含义就不对了。这和今天早上 util > 10 的问题是一回事。
--不过先别急着下结论。 要不要改，得先看两件事：这群人有多少？风险高不高？
--练习：用 CASE WHEN 量化这个问题
--用原始表 loans，按收入分成 3 组，每组算人数、坏账率、debt_ratio 中位数：
--组别	条件
--1_缺失	income 为空
--2_零或一	income <= 1
--3_正常	   其他
SELECT 
    CASE WHEN income IS NULL THEN '1_缺失' 
         WHEN income <=1 THEN '2_0或1'
         ELSE '3_正常'
     END AS income_group,
    COUNT(*),
    AVG(y),
    MEDIAN(debt_ratio)
FROM loans--用原始表 loans，因为 loans_clean 里的 debt_ratio 已经被截断，看不到原始的中位数了
GROUP BY income_group;
--饥结果解读：这群人（收入为0或1）是全表风险最低的客群，坏账率 3.71%，只有平均水平的一半多一点。
--但现在的清洗规则会把他们的 debt_ratio 截断为 5，放进「负债比最高」的那一箱，给他们扣分。 也就是说，风险最低的 2,239 人被当成了高负债客户。
--和早上的 util > 10 对比：
--问题	        影响人数	     他们的真实风险	        被错误放进
--util > 10	      241	    7.05%（接近平均）	   util 最高风险箱
--income ≤ 1	2,239	     3.71%（低风险）	        debt_ratio 最高风险箱

--怎么改？有取舍
--方案	            做法	                             好处	                                    代价
--A：不改	        截断为 5	                              简单	                             2,239 个低风险客户被扣分
--B：和缺失合并	  income ≤ 1 时 debt_ratio 也置空	 进入 Missing 箱。缺失组坏账率 5.6%，和这组 3.7% 都低于平均，合并后方向一致	           两组风险仍有差距，信息被平均掉一部分
--C：B + 加标记 再加一个 income_low（income ≤ 1 为 1）	模型可以单独学到这组风险更低	              多一个变量；而且只有 1.5% 的人，IV 可能不高，进不了模型
--建议用 C：先做，能不能进模型交给第 7 步的 IV 筛选决定。
--练习：更新清洗规则：修改 loans_clean 的建表代码：
--debt_ratio：income IS NULL 或 income <= 1 → 置空；其余规则不变
--新增 income_low：income <= 1 → 1，否则 0
CREATE OR REPLACE TABLE loans_clean AS
SELECT
    id,
    y,
    -- 逾期字段
    CASE WHEN dpd30 IN (96, 98) THEN NULL ELSE dpd30 END AS dpd30,
    CASE WHEN dpd60 IN (96, 98) THEN NULL ELSE dpd60 END AS dpd60,
    CASE WHEN dpd90 IN (96, 98) THEN NULL ELSE dpd90 END AS dpd90,
    CASE WHEN dpd90 IN (96, 98) THEN 1 ELSE 0 END AS dpd_special,
    -- 年龄
    CASE WHEN age=0 then NULL ELSE age END AS age,
    -- 额度使用率
    CASE WHEN util>10 THEN NULL
         WHEN util>1.1 THEN 1.1
    ELSE util
    END AS util,
    CASE WHEN util>10 THEN 1 ELSE 0 END AS util_abnormal,
    -- 收入和负债比
    income,
    CASE WHEN income IS NULL THEN 1 ELSE 0 END AS income_missing,
    CASE WHEN income IS NULL OR income<=1 THEN NULL 
         WHEN debt_ratio >5 THEN 5
    ELSE debt_ratio
    END AS debt_ratio,
    --新增income_low：income <= 1 → 1，否则 0
    CASE WHEN income<=1 THEN 1
         ELSE 0
         END AS income_low,
    -- 其他保持原样
    open_lines,
    re_loans,
    dependents
FROM loans;
--把所有清洗过的列都检查一遍：
SELECT
    COUNT(*)                     AS n,
    COUNT(*) - COUNT(dpd30)      AS dpd30_null,
    COUNT(*) - COUNT(dpd60)      AS dpd60_null,
    COUNT(*) - COUNT(dpd90)      AS dpd90_null,
    COUNT(*) - COUNT(age)        AS age_null,
    COUNT(*) - COUNT(util)       AS util_null,
    COUNT(*) - COUNT(debt_ratio) AS dr_null,
    SUM(dpd_special)             AS dpd_special_n,
    SUM(util_abnormal)           AS util_abnormal_n,
    SUM(income_missing)          AS income_missing_n,
    MAX(util)                    AS util_max,
    MAX(debt_ratio)              AS dr_max,
    SUM(income_low) AS income_low_n
FROM loans_clean;


--第 19 步：子查询，在一句 SQL 里用另一句 SQL 的结果
--：你之前比较各组坏账率时，都是心算「这一组是全体的几倍」。这个倍数就是你评分卡 Lift 表里的 Lift。能不能让 SQL 直接算出来？
SELECT
    CASE WHEN income IS NULL THEN '1_缺失'
         WHEN income <= 1    THEN '2_零或一'
         ELSE                     '3_正常'
    END AS income_group,
    COUNT(*)                                     AS n,
    ROUND(AVG(y), 4)                             AS bad_rate,
    ROUND(AVG(y) / (SELECT AVG(y) FROM loans), 2) AS lift,--这里用了子查询：先单独算出全体坏账率 0.06684，返回一个数
    ROUND(COUNT(*)/(SELECT COUNT(*)FROM loans),2) AS share
FROM loans
GROUP BY income_group
ORDER BY income_group;


--第 20 步：WITH（CTE），给中间结果起个名字
--子查询写在 SELECT 中间，一行太长，不好读
--如果要在多个地方用「全体坏账率」，就得把同一个子查询复制好几遍
WITH
total AS (
    SELECT COUNT(*) AS n_all, AVG(y) AS bad_all
    FROM loans
),
base AS (
    SELECT
        y,
        CASE WHEN income IS NULL THEN '1_缺失'
             WHEN income <= 1    THEN '2_零或一'
             ELSE                     '3_正常'
        END AS income_group
    FROM loans
)
SELECT
    income_group,
    COUNT(*)                          AS n,
    ROUND(COUNT(*) * 1.0 / MAX(n_all), 4) AS share,
    ROUND(AVG(y), 4)                  AS bad_rate,
    ROUND(AVG(y) / MAX(bad_all), 2)   AS lift
FROM base, total
GROUP BY income_group
ORDER BY income_group;

--练习：仿照这个结构，用 WITH 重写今天早上的 util 4 组分析（正常 / 真实超限 / 严重超限 / 极端值），算出 n、share、bad_rate、lift。
WITH 
total AS (
    SELECT COUNT(1) AS n_all,AVG(y) AS bad_all---算总量方便引用
    FROM loans
),
base AS(
    SELECT
        y,
        CASE WHEN util<=1 THEN '正常'
             WHEN util<=1.1 THEN '真实超限'---分组
             WHEN util <=10 THEN '严重超限'
             ELSE '极端值'
        END AS util_group
    FROM loans
)
SELECT 
     util_group,--直接用
     COUNT(1)  AS n,
     ROUND(COUNT(1)*1.0/MAX(n_all),4) AS share,
     ROUND(AVG(y),4) AS bad_rate,
     ROUND(AVG(y)/MAX(bad_all),2) AS lift
FROM base, total
GROUP BY util_group
ORDER BY util_group;
--结果解读：策略视角：严重超限只占 0.81% 的人，坏账率却是平均水平的 6.77 倍。这种「占比小、lift 高」的客群，正是硬拒绝规则最适合的对象：拒绝的人少，误伤小，拦截效果集中。
    

--第 21 步：JOIN，把两张表连起来
--在公司里，数据不会都放在一张表里。建模时要把它们按客户 id 拼起来，这就是 JOIN。通常是：
--表      	内容	                来源
--申请表	年龄、收入、供养人数	      客户申请时填写
--征信表	额度使用率、逾期次数、负债	从人行征信或第三方查询
--表现表	是否逾期（y）	            放款后观察

--我们把 loans 拆成两张。为了模拟真实情况，让 10% 的客户查不到征信，比如征信白户
-- 申请表：所有客户
CREATE OR REPLACE TABLE app AS
SELECT id, y, age, income, dependents
FROM loans;

-- 征信表：id 是 10 的倍数的客户查不到征信
CREATE OR REPLACE TABLE bureau AS
SELECT id, util, dpd30, dpd60, dpd90, open_lines, re_loans, debt_ratio
FROM loans
WHERE id % 10 <> 0;--%表示除后的余数
--分别用 COUNT(*) 数一下 app 和 bureau 各有多少行。
SELECT 
     COUNT(1)
FROM app;--15万

SELECT 
     COUNT(1)
FROM bureau;--13.5万


--两种joint
-- 内连接：只保留两张表里都有的客户
SELECT COUNT(*)--算，表a，内连接b
FROM app a
INNER JOIN bureau b ON a.id = b.id;

-- 左连接：保留左表（app）的所有客户，右表没有的填空值
SELECT COUNT(*), COUNT(b.util)--算总行数，算b有效util行数；表a，左连接
FROM app a
LEFT JOIN bureau b ON a.id = b.id;--如果不写条件where，自动填充null



--第 22 步：找出「没匹配上」的人
--知道有 15,000 人查不到征信还不够，风控还要问：这些人风险怎么样？
SELECT COUNT(*), AVG(a.y)
FROM app a
LEFT JOIN bureau b ON a.id = b.id
WHERE b.id IS NULL;--筛选出在a表但不在b表的
--练习：算出匹配上征信的客户的人数和坏账率。
SELECT COUNT(*), AVG(a.y)
FROM app a
LEFT JOIN bureau b ON a.id=b.id
WHERE b.id IS NOT NULL;--等同于内连接，找交集
--这里表的avg和整体差不多，因为我们是用 id % 10 = 0 挑出这 15,000 人的。id 只是行号，和客户风险毫无关系，所以这等于随机抽样。随机抽出来的人，风险自然和全体差不多。


--第 23 步：JOIN 最大的坑，重复键导致行数膨胀
--真实场景：征信表里，一个客户可能被查询过多次，每次查询一条记录。如果直接拿申请表去 JOIN，这个客户就会被复制成好几行。即b表行数变多被左连接到a表
--先模拟一张有重复的表
CREATE OR REPLACE TABLE bureau_dup AS--我要建一张新表，名字叫 bureau_dup，若重复就替代
SELECT * FROM bureau---- 第 1 部分：原封不动把所有数据拿过来
UNION ALL--UNION ALL 的意思是：直接拼，允许重复，不去重。（如果用 UNION，它会把一模一样的行自动删掉一个，那就达不到制造重复数据的目的了）。
SELECT * FROM bureau WHERE id % 7 = 0;--把 id 是 7 的倍数的客户再复制一份，模拟「被查询了两次」
--运行建表语句，数一下 bureau_dup 有多少行。
SELECT COUNT(*) FROM bureau_dup;--154286行
--用 LEFT JOIN 把 app 和 bureau_dup 连起来，数 COUNT(*)，并算 AVG(a.y)。
SELECT COUNT(*),AVG(a.y)
FROM app a
LEFT JOIN bureau_dup d ON a.id=d.id;--这里合并了a和一个有重复的表，因此行数更多了
--第 3 题：找出重复的 id
SELECT id, COUNT(*) AS cnt
FROM bureau_dup
GROUP BY id
HAVING COUNT(*) > 1
ORDER BY id
LIMIT 10;
-------------------------怎么找出表里的重复数据？
--按要检查的键分组，用 HAVING 筛出出现次数大于 1 的组：
--SELECT id, COUNT(*) FROM 表 GROUP BY id HAVING COUNT(*) > 1;
--数出一共有多少个 id 重复
--思路：把它当成一张中间表，用昨天学的 WITH 起个名字，再对它 COUNT(*)。
WITH dup AS (
    SELECT id,COUNT(1) FROM bureau_dup GROUP BY id HAVING COUNT(1)>1               -- 这里放刚才找重复 id 的查询（去掉 ORDER BY 和 LIMIT）
)
SELECT COUNT(*) FROM dup;

--还有一种更快的方法，你也可以试试：
SELECT COUNT(*) - COUNT(DISTINCT id) FROM bureau_dup;
--但注意：它代表多出来的行数，不一定等于重复的 id 个数，比如假如有的id重复了3次，算出来是2代表行数，并非该id个数。
--只有每个重复的 id 都正好出现 2 次时，两者才相等。
--真实工作中，找到重复只是第一步，还要决定每个客户保留哪一条。比如征信表通常保留最近一次查询的记录。


--第 24 步：窗口函数 ROW_NUMBER，每个客户只保留一条
--先重建一张带「查询次序」的表
--现在的 bureau_dup 里，两条重复记录一模一样，分不出先后。我们加一列 query_no 表示第几次查询：
CREATE OR REPLACE TABLE bureau_dup AS
SELECT *, 1 AS query_no FROM bureau--*表示全选，硬塞1，作为新列
UNION ALL
SELECT *, 2 AS query_no FROM bureau WHERE id % 7 = 0;--全选，选出余数为零的，塞入2作为新列。最后拼接这两张表
--1 AS query_no 的意思是：给每一行加一列 query_no，值都是 1

--窗口函数是什么？保留原表，加一列rn，表示在同一个 id 内部，按 query_no 从大到小排的名次。即不压缩表的排序
SELECT
    id,
    query_no,
    ROW_NUMBER() OVER (PARTITION BY id ORDER BY query_no DESC) AS rn
    --ROW_NUMBER()	给每行编号：1、2、3……。分组就组内排序，没有分组就全体排序
    --OVER (...)	说明编号的规则，有 OVER 的就是窗口函数
    --PARTITION BY id	按 id 分组，每个 id 内部各自从 1 开始编号。作用像 GROUP BY，但不压缩行
    --ORDER BY query_no DESC	组内按 query_no 从大到小排，最新的排第一
FROM bureau_dup
WHERE id IN (7, 8, 14)
ORDER BY id, rn;

--第 25 步：只保留 rn = 1 的行
--这里不能用where rn=1，原因：FROM → WHERE → GROUP BY → HAVING → SELECT → ORDER BY → LIMIT
SELECT
    id,
    query_no,
    ROW_NUMBER() OVER (PARTITION BY id ORDER BY query_no DESC) AS rn
FROM bureau_dup
WHERE rn = 1;
--正确写法：先用 WITH 算好 rn，再筛选
CREATE OR REPLACE TABLE bureau_dedup AS
WITH ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY id ORDER BY query_no DESC) AS rn
    FROM bureau_dup--dup是之前新建的带标记的表，但还没有rn标记！
)
--第一回合，我先排个号存起来（ranked）；
--第二回合，我从刚才存好的结果里，挑出 rn=1 的，并把临时列扔掉。
SELECT * EXCLUDE (rn, query_no)--除了这两列都挑出来
FROM ranked
WHERE rn = 1;--只要rn=1的1列。现在dedup是最新的表

--验证去重是否成功：
SELECT COUNT(*), COUNT(DISTINCT id) FROM bureau_dedup;
--用 app LEFT JOIN bureau_dedup，数 COUNT(*)
SELECT COUNT(*)
FROM app a
LEFT JOIN bureau_dedup b ON a.id=b.id;
--结果等于a的总行数是因为b 表里每个 id 只有一行，也就是连接键唯一。 所以 a 的每个客户最多匹配到 b 的 1 行，不会被复制，结果行数就等于左表行数 150,000。


--------------------------------------一张表里每个客户有多条记录，怎么取每个客户最新的一条？
--WITH t AS (
--    SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY query_time DESC) AS rn
--    FROM 表 
--)
--SELECT * FROM t WHERE rn = 1;



--第 26 步：三种排名函数的区别ROW_NUMBER、RANK、DENSE_RANK 有什么区别。它们只在出现并列时表现不同。
SELECT
    id,
    dpd30,
    ROW_NUMBER() OVER (ORDER BY dpd30 DESC) AS row_num,--没有分组，全体排序。不管并列
    RANK()       OVER (ORDER BY dpd30 DESC) AS rnk,--并列时序号一样，排名不连续
    DENSE_RANK() OVER (ORDER BY dpd30 DESC) AS dense_rnk--并列时序号一样，排名连续
FROM loans_clean
WHERE id <= 20
ORDER BY dpd30 DESC, id;
--总结：ROW_NUMBER 不管是否并列，都给出连续不重复的编号；
--RANK 并列的取相同名次，后面的名次会跳过，比如 1、2、2、4；
--DENSE_RANK 并列的取相同名次，后面的名次不跳，比如 1、2、2、3。
--去重时用 ROW_NUMBER，取前 N 名或第 N 高时，根据是否需要保留并列，选择 RANK 或 DENSE_RANK。


--第 27 步：分组 Top N（笔试最经典的窗口函数题）
--在 loans_clean 里，把客户分成 4 个年龄段，找出每个年龄段收入最高的 3 个人。
--思路（3 步，用 WITH 一步步写）：
--第一个 CTE：用 CASE WHEN 给每个人打上年龄段标签
--第二个 CTE：用窗口函数，在每个年龄段内部按收入从高到低排名
--主查询：筛出排名 ≤ 3 的人
WITH
labeled AS (
    SELECT
        id, age, income,
        CASE WHEN age<30 THEN '1_30以下'
             WHEN age>=30 AND age<45 THEN '2_30-44'
             WHEN age>=45 AND age<60 THEN '3_45-59'
             WHEN age>=60 THEN '4_60以上'
             ELSE '5_缺失'
	    END AS age_group
    FROM loans_clean
),
ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY age_group ORDER BY income DESC NULLS LAST) AS rn--income为null时排到最后
    FROM labeled
)
SELECT *
FROM ranked
WHERE rn<=3
ORDER BY age_group, rn;


--第 28 步：SUM() OVER，累计求和
--「如果把风险最高的一批人拒掉，能拦住多少坏客户？拒绝率是多少？」这需要从风险最高的组开始，一组一组往下累加人数和坏客户数。
--SUM(列) OVER (ORDER BY 列) 表示按顺序累加到当前行为止。
--例子：用 dpd90 分组，从逾期次数最多的组开始累计。
WITH grp AS (
    SELECT
        dpd90,
        COUNT(*) AS n,
        SUM(y)   AS bad
    FROM loans_clean
    WHERE dpd90 IS NOT NULL
    GROUP BY dpd90--既然分组了，这里的count也是组内计数
)
SELECT
    dpd90,
    n,
    bad,
    SUM(n)   OVER (ORDER BY dpd90 DESC) AS cum_n,--把组内计数累加
    SUM(bad) OVER (ORDER BY dpd90 DESC) AS cum_bad,
    SUM(n)   OVER (ORDER BY dpd90 DESC)/SUM(n) OVER() AS 'reject_rate',
    SUM(bad) OVER (ORDER BY dpd90 DESC)/SUM(bad) OVER() AS 'capture_rate'
    --：总人数和总坏客户数，可以用 SUM(n) OVER () 和 SUM(bad) OVER ()。OVER 括号里什么都不写，表示对整张表求和，每一行都得到同一个总数。
FROM grp
ORDER BY dpd90 DESC;
--拒绝率：被拒人数/总人数
--坏客户拦截率：被拒的坏人/总坏人
--被拒客群坏账率：被拒的坏人/被拒的总人数
--误伤好客户：被拒总人数-被拒的坏人
--通过客群坏账率：通过的坏人/通过的总人数


--第 29 步：LAG，和上一行比较
--评分卡分箱时，你要求坏账率单调。怎么用 SQL 快速检查各组坏账率有没有「倒挂」？需要每一行和上一行比。
WITH grp AS (
    SELECT
        dpd90,
        COUNT(*)         AS n,
        ROUND(AVG(y), 4) AS bad_rate
    FROM loans_clean
    WHERE dpd90 IS NOT NULL
    GROUP BY dpd90
    HAVING COUNT(*) >= 100--只看人数够多的组，避免样本太少的干扰
),
-------------以上第一步，先分组，且只要人数大于100的组，定义人数和坏人率
-----------------------------------第三步，再套一层with，注意不需要再写with。然后要取第二步的表中diff<0的
 grpn AS(
 ---------------第二步，取列：人数，坏人率，前一期坏人率，作差
SELECT
    dpd90,
    n,
    bad_rate,--按 dpd90 从小到大排，取上一组的坏账率
    LAG(bad_rate) OVER (ORDER BY dpd90 )            AS prev_rate,
    bad_rate - LAG(bad_rate) OVER (ORDER BY dpd90 ) AS diff
FROM grp)
-----------------------------------第三步，取grpn中的特定行
SELECT dpd90,
       n,
       bad_rate,
       prev_rate,
       diff
FROM grpn
WHERE diff<0;





------------下一阶段：风控笔试题实战
--我们手动造一张小小的还款表，模拟笔试时题目给的数据，开始练这类题。
--新语法：用 VALUES 直接写数据建表
--VALUES (...)：这就是你在纸上画一个表格。每一行括号里就是一条记录。
CREATE OR REPLACE TABLE repay AS
SELECT * FROM (VALUES
    (101, 1, DATE '2026-01-15', DATE '2026-01-14'),--DATE表示转日期，而非数字
    (101, 2, DATE '2026-02-15', DATE '2026-02-20'),
    (101, 3, DATE '2026-03-15', NULL),--NULL表示还没还
    (102, 1, DATE '2026-01-20', DATE '2026-01-20'),
    (102, 2, DATE '2026-02-20', DATE '2026-02-19'),
    (102, 3, DATE '2026-03-20', DATE '2026-03-25'),
    (103, 1, DATE '2026-02-05', NULL),
    (103, 2, DATE '2026-03-05', NULL),
    (104, 1, DATE '2026-02-10', DATE '2026-02-12'),
    (104, 2, DATE '2026-03-10', DATE '2026-03-10')
) AS t(loan_id, term, due_date, repay_date);--新建表格命名为t，并命名四列名称
--看一下这张表：
SELECT * FROM repay

--题目1：查询每一期的还款情况，新增一列 is_overdue：逾期为 1，否则为 0。
SELECT *,---只要加个*就能显示全部列！注意逗号
      CASE WHEN due_date<repay_date OR repay_date IS NULL THEN 1
      ELSE 0
      END AS is_overdue
FROM repay
ORDER BY loan_id, term;

--笔试题 2：计算逾期天数
--题目：新增一列 overdue_days，表示每期逾期了多少天。观察日设为 2026-04-01。提前还或当天还：逾期天数记为 0，不能是负数
--需要 2 个新函数
   ----  1. COALESCE(a, b)：如果 a 是空值，就用 b 代替
   ----  2. 日期相减：不同数据库写法不一样（笔试重点）
          --------数据库              	写法	                            注意
               -----DuckDB	   date_diff('day', 开始日期, 结束日期)        我们现在用这个
               -----MySQL	  DATEDIFF(结束日期, 开始日期)	              参数顺序相反！
               -----Hive	   datediff(结束日期, 开始日期)	               和 MySQL 一样
SELECT
    *,
    date_diff('day', due_date, COALESCE(repay_date, DATE '2026-04-01')) AS raw_days,
    CASE WHEN raw_days>=0 THEN raw_days ELSE 0 END AS overdue_days--注意这里有时候直接写rawdays出错，因为各行是同时计算的。稳健的是copy上一行或者新建with表
FROM repay
ORDER BY loan_id, term;
                       --方法 3：用 GREATEST 函数，更简洁：GREATEST(date_diff('day', due_date, COALESCE(repay_date, DATE '2026-04-01')), 0) AS overdue_days

----笔试题 3：首期逾期率（FPD）
--借款人第一期就不还，往往说明他从一开始就没打算还，很可能是欺诈。
--指标	定义
--FPD0	首期逾期天数 > 0 的借款占比，晚一天就算
--FPD7	首期逾期天数 > 7 的借款占比
--FPD30	首期逾期天数 > 30 的借款占比
-----第一步：用 WITH 算出每期的 overdue_days
-----第二步：只看第 1 期（WHERE term = 1）
-----第三步：FPD0 = AVG(CASE WHEN overdue_days > 0 THEN 1 ELSE 0 END)注意算rate是一个数字，无法同时导入所有列*
WITH fpd AS(
     SELECT *,
     date_diff('day',due_date,COALESCE(repay_date, DATE'2026-04-01'))AS row_days,
     GREATEST(date_diff('day',due_date,COALESCE(repay_date, DATE'2026-04-01')),0)AS overdue_days
     FROM repay
     WHERE term=1
     ORDER BY loan_id,term
)
SELECT 
     AVG(CASE WHEN overdue_days > 0 THEN 1 ELSE 0 END) AS fpd0,--第一期逾期就记1，算平均就是首期逾期率
     AVG(CASE WHEN overdue_days > 3 THEN 1 ELSE 0 END) AS fpd3,
     AVG(CASE WHEN overdue_days > 7 THEN 1 ELSE 0 END) AS fpd7
     FROM fpd;


-------笔试题 4：每笔借款的逾期状态（风控最常用的分组）
--前面都在看「每一期」，但风控日常汇报一般看「每一笔借款」现在处于什么状态。行业里用 M0、M1、M2…… 来表示逾期阶段：
--阶段	逾期天数	  含义
--M0	  0	     正常
--M1	1 – 30	逾期 1 个月以内
--M2	31 – 60	逾期 1 到 2 个月
--M3	61 – 90	逾期 2 到 3 个月
--M3+	> 90	一般视为坏账
---历史最大逾期天数	这笔借款曾经最严重逾期过多少天  历史最大逾期反映客户信用好坏
---当前逾期天数	截至观察日，最早一期没还的欠了多少天   当前逾期决定催收

       -- 第 1 题：历史最大逾期天数
--按 loan_id 分组，算出每笔借款的 max_overdue_days，并用 CASE WHEN 分出 M 阶段。
WITH fpd AS(
     SELECT *,
     date_diff('day',due_date,COALESCE(repay_date, DATE'2026-04-01'))AS row_days,
     GREATEST(date_diff('day',due_date,COALESCE(repay_date, DATE'2026-04-01')),0)AS overdue_days
     FROM repay
     ORDER BY loan_id,term
),--------------------------------------------------先给出表：包含逾期天数和修正逾期天数1
loan_max AS(
     SELECT loan_id,
            MAX(overdue_days) AS max_overdue_days,
            MIN(CASE WHEN repay_date IS NULL THEN due_date END) AS early_date,-----due有值才逾期否则为null
            COALESCE(date_diff('day', MIN(CASE WHEN repay_date IS NULL THEN due_date END),DATE'2026-04-01'),0) AS "当前逾期天数"---为null的返回为0
     FROM fpd
     GROUP BY loan_id----------------------------------------由于要给id打包取里面的逾期最大，先建一个id分组的表。注意group可以自动先打包再计算max，正合我意
)
SELECT-------------------------------------------------------------然后给这个表加一列表示逾期程度
     loan_id,
     max_overdue_days,
     early_date,
     "当前逾期天数",
     CASE WHEN max_overdue_days =0 THEN 'M0'
          WHEN max_overdue_days>0 AND max_overdue_days<=30 THEN 'M1'
          WHEN max_overdue_days<=60 THEN 'M2'
          WHEN max_overdue_days<=90 THEN 'M3'
          ELSE 'M3+'
          END AS "M阶段"
FROM loan_max
ORDER BY loan_id;

           ----第 2 题（挑战）：当前逾期天数
           --思路：先找到每笔借款最早一期没还的应还日，再算它到观察日的天数。
--只看没还的期，取其中最早的应还日。还了的期，CASE WHEN 结果是 NULL，MIN 会自动跳过 NULL。如果所有期都还了，结果就是 NULL。
--MIN(CASE WHEN repay_date IS NULL THEN due_date END)加到上文里去
---一个值得想的问题：M 阶段按哪个算？看催收（用early——date）还是信用（用maxover）。


------------------------------前面每道题我都给了骨架和提示。真实笔试没有提示，所以接下来做 5 道综合题，我只给题目，你自己从头写。用的都是已经建好的表。
--1.loans_clean	把 open_lines 分成 4 段：0–3、4–8、9–15、16 以上。算出每段的人数、占比、坏账率、Lift，按段的顺序排列
SELECT 
CASE WHEN open_lines >=0 AND open_lines <=3 THEN '1_0-3'
            WHEN open_lines <=8 THEN '2_4-8'
            WHEN open_lines <=15 THEN '3_9-15'
            ELSE '4_16以上'
       END AS openlines_group, 
       COUNT(*) AS n,
       ROUND(COUNT(*)/(SELECT COUNT(*) FROM loans_clean),4) AS share,
       ROUND(AVG(y) ,4)        AS bad_rate,
       ROUND(AVG(y)/(SELECT AVG(y) from loans_clean),4) AS lift
FROM loans_clean 
GROUP BY openlines_group
ORDER BY openlines_group;
---结果解读：两头高、中间低，这就是你评分卡 EDA 里发现的 U 型：
--0–3 个账户：薄信用客户，信用记录少，风险最高
--16 个以上：多头借贷，到处借钱，风险回升
--4–8 个：最安全

-------------------------------------------------------------------------------------------------
--------先整理一下各表内容：
--loans	150,000	csv 原样读进来，没清洗，有 96/98、年龄 0、util 5 万这些问题	想看原始数据的时候，比如查数据问题
--loans_clean	150,000	清洗后的版本，还多了 4 个标记列	做分析默认用这张
--loans 的 12 列：id、y、util、age、dpd30、dpd60、dpd90、debt_ratio、income、open_lines、re_loans、dependents
--loans_clean多的四列：dpd_special	dpd 是 96/98 特殊编码为 1；util_abnormal	util > 10 为 1；income_missing	收入缺失为 1；income_low	收入 ≤ 1 为 1
--app	150,000	   id、y、age、income、dependents	申请表：客户自己填的信息 + 是否逾期
--bureau 135,000	id、util、dpd30、dpd60、dpd90、open_lines、re_loans、debt_ratio	征信表：去掉了 id 是 10 的倍数的人，模拟「查不到征信」
--bureau_dup 154,286	bureau 的列 + query_no	出错版征信表：id 是 7 的倍数的人出现两次，用来演示 JOIN 重复的坑
--bureau_dedup	135,000	和 bureau 一样	用 ROW_NUMBER 把 bureau_dup 去重后的版本，内容等同于 bureau
--以上这 4 张表都是从原始的 loans 拆出来的，没有清洗过。比如 app 里那个年龄 0 的人还在

--2. 找出查不到征信的客户中，年龄最小的 5 个人，显示 id 和 age。用app（谁申请了）和 bureau_dedup（谁有征信）
SELECT a.id,age
FROM app a
LEFT JOIN bureau_dedup b ON a.id=b.id
WHERE b.id IS NULL 
order by a.age ,a.id
LIMIT 5;

--3.只看人数 ≥ 1,000 的 dependents 取值(不是说dependents=1000，是说取某个值的dependent有1000人)。在每个取值内部，找出 util 最高的 2 个人，显示 id、dependents、util。
WITH table1 AS(
SELECT id,dependents,util,
ROW_NUMBER() OVER(PARTITION BY dependents ORDER BY util DESC,id) AS inner_rank_util,--util可能相等所以要加第二排字段
COUNT(*) OVER (PARTITION BY dependents) AS n_d---------窗口函数的使用！！
FROM loans_clean)
SELECT id,dependents,util
FROM table1
WHERE inner_rank_util <=2 AND n_d>=1000
ORDER BY dependents, inner_rank_util;

--第 4 题：用 repay 表，找出至少有 2 期逾期的借款 loan_id（逾期指逾期天数 > 0，观察日 2026-04-01）。
WITH yuqitable AS(
SELECT loan_id,
      GREATEST(date_diff('day',due_date,COALESCE(repay_date,DATE'2026-04-01')),0) AS days
      FROM repay),
yuqi1 AS(
SELECT loan_id,days
FROM yuqitable 
WHERE days>0),
yuqi2 AS(
SELECT DISTINCT loan_id,
     COUNT(*) OVER (PARTITION BY loan_id) AS n
     FROM yuqi1 )
SELECT loan_id
FROM yuqi2 
WHERE n >=2;
--------------------------------------------------以上更简洁的写法：
WITH yuqitable AS(
SELECT loan_id,
      GREATEST(date_diff('day',due_date,COALESCE(repay_date,DATE'2026-04-01')),0) AS days
      FROM repay)
SELECT loan_id
FROM yuqitable
GROUP BY loan_id---直接分组，组内（同一个人）算违约次数
HAVING SUM(CASE WHEN days > 0 THEN 1 ELSE 0 END) >= 2
ORDER BY loan_id;


----第 5 题（最后一题）
--用 repay 表，按期数（第 1 期、第 2 期、第 3 期）分别算逾期率：每一期逾期的笔数 ÷ 这一期的总笔数。逾期指逾期天数 > 0，观察日 2026-04-01。
WITH yuqitable AS(
SELECT
    term,
    GREATEST(date_diff('day',due_date,COALESCE(repay_date,DATE'2026-04-01')),0) AS days
FROM repay)
SELECT 
term,
     SUM(CASE WHEN days >0 THEN 1 ELSE 0 END)/COUNT(*) AS rate---或者：AVG(CASE WHEN days > 0 THEN 1 ELSE 0 END)
     FROM yuqitable
GROUP BY term
ORDER BY term;
--------------这里结果是term3逾期率100%，但是是因为这一组周有两个人
-------------------------------------引入vintage---------------------------------------------------------------------------------------------
--概念	                意思
--批次（cohort）	同一个月放款的所有借款，比如「2025 年 10 月批次」
--MOB（Month on Book）	放款后的第几个月。放款次月是 MOB 1，再下个月是 MOB 2……
--Vintage 曲线	每个批次在 MOB 1、2、3……时的逾期率
---核心思想：比较不同批次时，只在相同的 MOB 上比。

--第 1 步：生成模拟数据
CREATE OR REPLACE TABLE vin_loans AS
WITH base AS (
    SELECT
        i AS loan_id,
        (i - 1) // 1000 AS c,
        (hash(i * 31 + 7) % 10000) / 10000.0 AS r1,
        (hash(i * 17 + 3) % 10000) / 10000.0 AS r2
    FROM range(1, 6001) t(i)
)
SELECT
    loan_id,
    CAST(DATE '2025-07-01' + INTERVAL (c) MONTH AS DATE) AS issue_month,
    CASE WHEN r1 < [0.05, 0.05, 0.055, 0.07, 0.08, 0.09][c + 1]
         THEN CAST(1 + floor(12 * r2 * r2) AS INTEGER)
    END AS bad_mob
FROM base;

CREATE OR REPLACE TABLE vin_perf AS
SELECT
    l.loan_id,
    l.issue_month,
    m.mob,
    CASE WHEN l.bad_mob IS NOT NULL AND m.mob >= l.bad_mob
         THEN (m.mob - l.bad_mob) * 30 + 15 ELSE 0 END AS dpd
FROM vin_loans l
CROSS JOIN range(1, 13) m(mob)
WHERE l.issue_month + INTERVAL (m.mob) MONTH <= DATE '2026-06-01';

ALTER TABLE vin_loans DROP COLUMN bad_mob;
------表	         一行是什么	           列
--vin_loans	      一笔借款	           loan_id、issue_month（放款月份）
--vin_perf	   一笔借款在某个 MOB 的状态	loan_id、issue_month、mob、dpd（当月月末的逾期天数，0 表示正常）
--vin_perf 是 Vintage 分析的核心表。一笔借款有几个 MOB，就有几行。

     --第 1 题：每个放款月份各有多少笔借款？
SELECT COUNT(*),issue_month 
FROM vin_loans
GROUP BY issue_month;
     --第 2 题：每个放款月份，在 vin_perf 里最大的 MOB 是多少？
SELECT MAX(mob),issue_month
FROM vin_perf
GROUP BY issue_month;
     --第 3 题：找一笔出现过逾期的借款，看它每个 MOB 的 dpd 是怎么变化的。
--提示：先用 WHERE dpd > 0 找到一个 loan_id，再查这个 loan_id 的所有行，按 mob 排序。
WITH speid AS(
     SELECT loan_id, mob,dpd
     FROM vin_perf
     WHERE dpd>0 
ORDER BY loan_id
)
SELECT loan_id,mob,dpd FROM speid 
ORDER BY loan_id,mob;

--第 2 步：算 Vintage 逾期率
--指标：行业最常用的是 30+ 逾期率，也就是 dpd > 30（M2 及以上）的借款占比。
--题目：算出每个放款月份、每个 MOB 的 30+ 逾期率。(即每个月的每个mob单独算)
SELECT issue_month,mob,
       ROUND(AVG(CASE WHEN dpd>30 THEN 1 ELSE 0 END),4) AS rate_30p,
       COUNT(1) AS n
FROM vin_perf
GROUP BY issue_month, mob
ORDER BY issue_month;

--第 3 步：转成三角形的 Vintage 表
--现在的结果是长表，51 行，很难一眼比较。业务汇报时，Vintage 一般是宽表：一行一个批次，一列一个 MOB。
--即列名为mob，行名为月份，数据为违约率。写法：条件聚合
WITH v AS (-- 这里放你第 2 步的查询（去掉 ORDER BY）
SELECT issue_month,mob,
       ROUND(AVG(CASE WHEN dpd>30 THEN 1 ELSE 0 END),4) AS rate_30p,
       COUNT(1) AS n
FROM vin_perf
GROUP BY issue_month, mob
)
SELECT
    issue_month,
    MAX(CASE WHEN mob = 1 THEN rate_30p END) AS m1,--用max，因为会自动不要null值
    MAX(CASE WHEN mob = 2 THEN rate_30p END) AS m2,
    MAX(CASE WHEN mob = 3 THEN rate_30p END) AS m3,
    MAX(CASE WHEN mob = 4 THEN rate_30p END) AS m4,
    MAX(CASE WHEN mob = 5 THEN rate_30p END) AS m5,
    MAX(CASE WHEN mob = 6 THEN rate_30p END) AS m6,
    MAX(CASE WHEN mob = 7 THEN rate_30p END) AS m7,
    MAX(CASE WHEN mob = 8 THEN rate_30p END) AS m8,
    MAX(CASE WHEN mob = 9 THEN rate_30p END) AS m9,
    MAX(CASE WHEN mob = 10 THEN rate_30p END) AS m10,
    MAX(CASE WHEN mob = 11 THEN rate_30p END) AS m11
FROM v
GROUP BY issue_month
ORDER BY issue_month;
--Vintage 分析是把借款按放款月份分成批次，比较每个批次在放款后第 N 个月（MOB）的逾期率。
--直接看某个时点的整体逾期率有两个问题：一是新放款的借款还没到会逾期的时候，会把整体逾期率拉低，掩盖风险变化；二是放款规模变化也会影响分母。
--Vintage 让不同批次在相同账龄下比较，能看出某个月的客群或政策有没有让风险变差。
--比如在我的练习里，10 月起的批次在 MOB 3 的 30+ 逾期率比之前高了约 1 个百分点，MOB 6 高了约 2 个百分点，说明 10 月的准入调整带来了风险上升，而且在 MOB 3 就可以发现。

--最后一个练习：写结论
--策略岗的工作，最后一步一定是把数字变成结论，写给业务负责人看。
--题目：假设你是风控分析师，今天是 2026 年 6 月 1 日。请用 3 到 5 句话写一段汇报，说明：
--发现了什么问题（用数字说话）
--问题大概从什么时候开始
---你的建议
--2025 年 10 月起放款的批次风险明显上升。 在相同账龄下比较，10 – 12 月批次 MOB 6 的 30+ 逾期率为 5.1% – 5.4%，比 7 – 9 月批次的 3.1% – 3.5% 高约 2 个百分点，相对上升约 60%；差距在 MOB 3 已经出现，约 1 个百分点。
--风险上升的时间与 10 月准入调整吻合，初步判断两者相关，需要进一步拆分 10 月新增客群的渠道和特征来确认。
--建议：一是复盘 10 月准入调整，评估是否回调；二是对 10 – 12 月批次的在贷客户加强贷后管理；三是把 MOB 2、MOB 3 逾期率纳入日常监控并设置预警线。

---------------------------------模块 A：UNION 和 UNION ALL-------------------------
--GROUP BY 只能出各组的数，合计要另算一次。UNION ALL 可以把两句查询的结果上下拼在一起。
--UNION ALL	2 行	直接拼接，全部保留
--UNION	1 行	拼接后去掉完全重复的行
SELECT 1 AS x
UNION ALL
SELECT 1;
SELECT 1 AS x
UNION
SELECT 1;
--练习：给之前的「收入分组表」加一行合计。income_group,n,bad_rate,用loans表
SELECT
     CASE WHEN income <=1 THEN '2_0或1'
          WHEN income IS NULL THEN '1_缺失'
          ELSE '3_正常'
          END AS income_group,
     COUNT(1) AS n,
     ROUND(AVG(y),4) AS bad_rate
FROM loans
GROUP BY income_group,
UNION ALL
SELECT
    '9_合计'          AS income_group,
    COUNT(*)         AS n,
    ROUND(AVG(y), 4) AS bad_rate
FROM loans
ORDER BY income_group;---对拼好的四行一起排序，可保证9在最后


------------------------------模块 B：迁徙率（Roll Rate）-------------------------------
--催收和贷后部门更关心另一个问题：这个月处在 M1 的客户，下个月有多少会恶化到 M2？有多少会还上钱回到 M0？
--vin_perf 有个简化：一旦逾期就再也不还，所以算不出「还上钱」的情况。我们在它基础上加一些「逾期 1 个月后还上」的客户，生成一张新表 roll_perf。
CREATE OR REPLACE TABLE roll_perf AS
WITH good AS (
    -- 从来没逾期过的借款
    SELECT loan_id
    FROM vin_perf
    GROUP BY loan_id
    HAVING MAX(dpd) = 0------------选出从没逾期的人
),
cure AS (
    -- 从中挑出约 8%，随机选一个月让它逾期（dpd = 15），下个月就还上
    SELECT loan_id, 1 + hash(loan_id * 13 + 5) % 6 AS cure_mob  --让他在cure_mob月逾期
    FROM good
    WHERE hash(loan_id * 7 + 11) % 100 < 8------随机挑人，只在这些人上面建表并设置cure_mob
)
SELECT
    p.loan_id,
    p.issue_month,
    p.mob,
    CASE WHEN c.cure_mob = p.mob THEN 15 ELSE p.dpd END AS dpd--把dpd设为15当cure_mob出现
FROM vin_perf p
LEFT JOIN cure c ON p.loan_id = c.loan_id;------------先左连接，再case when
--第 1 步：给每行标上「本月阶段」和「上月阶段」
--stage：本月的 M 阶段（M0、M1、M2、M3、M4+）
--prev_stage：同一笔借款上个月的 M 阶段
WITH table1 AS(
SELECT *,
     CASE WHEN dpd=0 THEN 'M0'
          WHEN dpd<=30 THEN 'M1'
          WHEN dpd <=60 THEN 'M2'
          WHEN dpd <=90 THEN 'M3'
          ELSE 'M4+' 
     END AS 'stage'
FROM roll_perf)
SELECT *,
        LAG(stage) OVER (PARTITION BY loan_id ORDER BY mob) AS prev_stage
FROM table1
ORDER BY loan_id, issue_month,mob;

--第 2 步：算迁徙率
--思路：
--把每一行看作「上个月在 A 阶段，这个月在 B 阶段」的一次迁徙
--按 prev_stage, stage 分组，数每种迁徙有多少次
--迁徙率 = 这种迁徙的次数 ÷ 上个月在 A 阶段的总次数
---第 1 层：算本月阶段
WITH table1 AS(
SELECT *,
     CASE WHEN dpd=0 THEN 'M0'
          WHEN dpd<=30 THEN 'M1'
          WHEN dpd <=60 THEN 'M2'
          WHEN dpd <=90 THEN 'M3'
          ELSE 'M4+' 
     END AS 'stage'
FROM roll_perf),----第 2 层：算上月阶段
table2 AS(
SELECT *,
        LAG(stage) OVER (PARTITION BY loan_id ORDER BY mob) AS prev_stage,
FROM table1),--第 3 层：去掉 NULL，按「从哪到哪」分组计数（分子）
table3 AS (
    SELECT
        prev_stage,
        stage,
        COUNT(*) AS n
    FROM table2
    WHERE prev_stage IS NOT NULL
    GROUP BY prev_stage, stage
)--主查询：算分母和迁徙率
SELECT
    prev_stage,
    stage,
    n,-----------从哪到哪的n
    SUM(n) OVER (PARTITION BY prev_stage)                AS n_from,
    ROUND(n * 1.0 / SUM(n) OVER (PARTITION BY prev_stage), 4) AS roll_rate---但n除以总n
FROM table3
ORDER BY prev_stage, stage;
--迁徙率怎么用：链式相乘估算坏账
--一个正常客户，最终走到 M4+ 的概率是多少？ 把每一步的迁徙率乘起来：
--M0 → M1 → M2 → M3 → M4+=1.41% × 41.09% × 100% × 100% ≈ 0.58%
--再看 M1 → M2 的影响有多大：如果催收团队把 M1 → M2 从 41% 降到 30%，最终坏账就从 0.58% 降到 0.42%，减少约 27%。所以 M1 阶段是催收的黄金期，客户越早催回来越好。




-------------------------------模块 C：用 SQL 做分箱和 KS 表---------------------------------------------
--你的评分卡第 10 步做过 Lift 表和 KS，是在 Python 里算的。在公司里，模型上线后，每个月都要用新数据检查模型还有没有效，通常直接用 SQL 在数据库里算。
--模型分数不在数据库里，所以我们用 util 当作一个「单变量分数」：util 越高，风险越高。
--新函数：NTILE(n)
--NTILE(10) OVER (ORDER BY util) 会把所有人按 util 从小到大排序，平均分成 10 组，每人得到一个组号 1 到 10。这就是等频分箱：每组人数大致相等。
SELECT id, util, NTILE(10) OVER (ORDER BY util) AS decile--先看看大致长啥样
FROM loans_clean
LIMIT 5;
--第 1 步：等频分 10 箱，看每箱的情况
--题目：用 loans_clean，按 util 等频分成 10 箱，每箱算出：
--人数 n
--坏客户数 bad
--坏账率 bad_rate（4 位小数）
--这一箱 util 的最小值和最大值
--提示：两层结构。第一层 CTE 用 NTILE 打箱号，第二层按箱号 GROUP BY。
WITH table1 AS(
SELECT y,util, NTILE(10) OVER(ORDER BY util) AS decile
FROM loans_clean
WHERE util IS NOT NULL
order by decile)
SELECT decile,COUNT(1) AS n, SUM(y) AS bad_n,ROUND(AVG(y),4) AS bad_rate,MAX(util) AS max,MIN(util) AS min
FROM table1
GROUP BY decile
order by decile;

---第 2 步：算 KS 表
--KS 的含义（回顾评分卡第 10 步）：把客户从最危险到最安全排好，逐箱累加，看「累计坏客户占比」和「累计好客户占比」的差距。
--差距最大的那一点就是 KS，越大说明模型越能把好坏客户分开。
--题目：在第 1 步结果的基础上，从第 10 箱往第 1 箱累计，每箱算出：
--列	含义
--good	好客户数 = n − bad
--cum_bad_pct	累计坏客户 ÷ 全部坏客户
--cum_good_pct	累计好客户 ÷ 全部好客户
--ks	cum_bad_pct − cum_good_pct
--最后再单独查出 KS = ks 列的最大值。
WITH table1 AS(
SELECT y,util, NTILE(10) OVER(ORDER BY util) AS decile
FROM loans_clean
WHERE util IS NOT NULL
order by decile),
bins AS (
SELECT decile,COUNT(1) AS n, SUM(y) AS bad_n,ROUND(AVG(y),4) AS bad_rate,MAX(util) AS max,MIN(util) AS min,
COUNT(1) - SUM(y) AS good_n
FROM table1
GROUP BY decile
order by decile DESC)
SELECT *, (SUM(bad_n)OVER(ORDER BY decile DESC))/SUM(bad_n)OVER() AS cum_bad_pct,
      (SUM(good_n)OVER(ORDER BY decile DESC))/SUM(good_n)OVER() AS cum_good_pct,
      cum_bad_pct-cum_good_pct AS ks
FROM bins
ORDER BY decile DESC;

---------------------------------------------------------模块 D（SQL 最后一个）：连续逾期------------------------
--风控里，连续逾期比累计逾期更能说明客户出了问题：偶尔忘了还一两次，和连续几个月都不还，性质完全不同。
--准备数据：一张笔试风格的小表
CREATE OR REPLACE TABLE od AS
SELECT * FROM (VALUES
    ('A',1,1),('A',2,1),('A',3,0),('A',4,1),('A',5,1),('A',6,1),
    ('B',1,0),('B',2,1),('B',3,0),('B',4,1),('B',5,0),('B',6,1),
    ('C',1,1),('C',2,1),('C',3,1),('C',4,1),('C',5,0),('C',6,0),
    ('D',1,0),('D',2,0),('D',3,0),('D',4,0),('D',5,0),('D',6,0)
) AS t(user_id, term, is_overdue);
--怎么看连续逾期：核心技巧：「期数 − 排名」
--逾期的期数 term	排名 rn	term − rn
--1   1	    0                           连续的期，term 和 rn 同步加 1，所以差值不变；
--2	  2	    0                term − rn 相同的，就是同一段连续逾期。A 有两段：差值为 0 的 2 期，差值为 1 的 3 期。
--4	  3	    1
--5	  4	    1
--6	  5	    1
--第 1 步：只保留逾期的行，算出每行的 grp = term - ROW_NUMBER() OVER (...)。想一想：PARTITION BY 什么？ORDER BY 什么？
WITH table1 AS(
SELECT *, term-ROW_NUMBER() OVER(PARTITION BY user_id ORDER BY term) AS grp
FROM od
WHERE is_overdue=1
ORDER BY user_id,term),--第 2 步：按 user_id, grp 分组，数出每段连续逾期有几期。
table2 AS(
SELECT user_id, grp,
COUNT(*) AS conti_over
FROM table1 
GROUP BY user_id,grp
ORDER BY user_id,grp)--第 3 步：找出连续逾期 ≥ 3 期的用户。
SELECT * --最后一步如果某个用户有两段都 ≥ 3 期，他会出现两次。题目只要「用户」，稳妥写法是 SELECT DISTINCT user_id
FROM table2 
WHERE conti_over >=3;
