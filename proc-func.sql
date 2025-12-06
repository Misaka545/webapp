USE shopee;

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_getShopProductStatistics $$

-- Get product statistics for a specific shop
CREATE PROCEDURE sp_getShopProductStatistics(
    IN input_shopId INT,
    IN input_min_target INT
)
BEGIN
    -- Default logic for input_min_target
    IF input_min_target IS NULL THEN
        SET input_min_target = 0;
    END IF;

    -- Main query to get product statistics
    SELECT
        p.productID,
        p.name AS ProductName,
        AVG(p.product_Rating) as Rating,
        -- Use COALESCE to display 0 instead of NULL for unsold products
        COALESCE(SUM(oi.quantity), 0) AS TotalUnitsSold,
        COALESCE(SUM(oi.quantity * oi.unit_Price), 0) AS TotalRevenue -- total before comission calculation
    FROM PRODUCT p
    LEFT JOIN ORDER_ITEM oi 
    ON p.productID = oi.productID 
    AND oi.status = 'DELIVERED' -- Only valid sales
    WHERE p.shopID = input_shopId
    GROUP BY p.productID, p.name
    -- Filter based on target
    HAVING TotalUnitsSold >= input_min_target
    ORDER BY TotalRevenue DESC;
END $$

DROP PROCEDURE IF EXISTS sp_searchProducts $$

-- Search products base on price range and category keyword
-- display product details along with the shop name, sorted by price ascending
CREATE PROCEDURE sp_searchProducts(
    IN input_category_keyword VARCHAR(100),
    IN input_min_price DECIMAL(15,2),
    IN input_max_price DECIMAL(15,2)
)
BEGIN
    -- Default logic for price range
    IF input_min_price IS NULL THEN
        SET input_min_price = 0;
    END IF;
    IF input_max_price IS NULL THEN
        SET input_max_price = 999999999; -- Arbitrary high value
    END IF;
    -- Main query to search products
    SELECT
        p.productID,
        p.name AS ProductName,
        s.shopName AS ShopName,
        c.categoryName AS Category,
        p.base_Price AS Price,
        p.product_Rating AS Rating,
        p.description
    FROM PRODUCT p
    JOIN SHOP s ON p.shopID = s.shopID
    JOIN BELONGS_TO_CATEGORY btc ON p.productID = btc.productID
    JOIN CATEGORY c ON btc.categoryID = c.categoryID
    WHERE c.categoryName LIKE CONCAT('%', input_category_keyword, '%')
      AND p.base_Price BETWEEN input_min_price AND input_max_price
    ORDER BY p.base_Price ASC;
END $$

DROP FUNCTION IF EXISTS fn_calculateShopNetRevenue $$

-- Calculate the total net revenue for a specific shop in a given month and year
-- The platform takes different commission rates based on product categories:
-- ELECTRONICS: 2%
-- FASHION: 5%
-- OTHERS: 3%
-- Only consider orders with status 'DELIVERED'
CREATE FUNCTION fn_calculateShopNetRevenue(
    input_shopId INT,
    input_month INT,
    input_year INT
)
RETURNS DECIMAL(15,2)
DETERMINISTIC
BEGIN
    -- Variables declaration
    DECLARE done INT DEFAULT FALSE;
    DECLARE total_revenue DECIMAL(15,2) DEFAULT 0.00;
    DECLARE item_price INT;
    DECLARE item_quantity INT;
    DECLARE cat_name VARCHAR(100);
    DECLARE commission_rate DECIMAL(3,2);
    DECLARE net_amount DECIMAL(15,2);

    -- Declare cursor
    -- Join order_item -> product -> belongs_to_category -> category
    -- Filter by shop, date, status = 'DELIVERED'
    DECLARE cur_items CURSOR FOR
        SELECT oi.unit_Price, oi.quantity, CATEGORY.categoryName
        FROM ORDER_ITEM oi
        JOIN PRODUCT ON oi.productID = PRODUCT.productID
        JOIN BELONGS_TO_CATEGORY btc ON PRODUCT.productID = btc.productID
        JOIN CATEGORY ON btc.categoryID = CATEGORY.categoryID
        WHERE PRODUCT.shopID = input_shopId
          AND MONTH(oi.delivered_date) = input_month
          AND YEAR(oi.delivered_date) = input_year
          AND oi.status = 'DELIVERED';

    -- Reach the end flag
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    -- Validate input
    IF NOT EXISTS (SELECT 1 FROM SHOP WHERE shopID = input_shopId) THEN
        RETURN -1; -- Shop does not exist
    END IF;

    OPEN cur_items;

    read_loops: LOOP
        FETCH cur_items INTO item_price, item_quantity, cat_name;
        IF done THEN
            LEAVE read_loops;
        END IF;

        -- Logic to determine fee
        IF cat_name = 'ELECTRONICS' THEN
            SET commission_rate = 0.02;
        ELSEIF cat_name = 'FASHION' THEN
            SET commission_rate = 0.05;
        ELSE
            SET commission_rate = 0.03; -- standard rate
        END IF;

        -- Calculate net amount for the item
        SET net_amount = (item_price * item_quantity) * (1 - commission_rate);

        -- Accumulate to total revenue
        SET total_revenue = total_revenue + net_amount;

    END LOOP;

    CLOSE cur_items;

    RETURN total_revenue;
END $$

DROP FUNCTION IF EXISTS fn_classifyBuyerRank $$

-- Classify buyer rank (VIP scoring)
-- A buyer is classified as 'Standard', 'Silver', 'Gold', or 'Platinum' based on their total spending and cancellation rate
-- If the buyer has not met the spending threshold for at least6 months, downgrade their rank by one level
-- If the buyer has cancellation rate > 30%, downgrade their rank by one level
CREATE FUNCTION fn_classifyBuyerRank(
    input_buyerId INT
)
RETURNS VARCHAR(20)
DETERMINISTIC
BEGIN
    -- Variables declaration
    DECLARE done INT DEFAULT FALSE;
    DECLARE total_spending DECIMAL(15,2) DEFAULT 0.00;
    DECLARE recent_spending DECIMAL(15,2) DEFAULT 0.00;
    DECLARE cancel_count INT DEFAULT 0;
    DECLARE total_orders INT DEFAULT 0;

    DECLARE current_status VARCHAR(20);
    DECLARE current_amount DECIMAL(15,2);
    DECLARE order_date DATETIME;

    DECLARE result_rank VARCHAR(20);
    DECLARE rank_score INT DEFAULT 1; -- 1: Standard, 2: Silver, 3: Gold, 4: Platinum
    DECLARE cancel_rate DECIMAL(5,2) DEFAULT 0.00;

    -- Declare cursor
    DECLARE cur_orders CURSOR FOR
        SELECT oi.status, oi.quantity * oi.unit_Price AS total_amount, oi.delivered_date
        FROM ORDER_ITEM oi
        JOIN ORDERS o ON oi.orderID = o.orderID
        WHERE o.buyerID = input_buyerId;

    -- Reach the end flag
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    IF NOT EXISTS (SELECT 1 FROM BUYER WHERE userID = input_buyerId) THEN
        RETURN 'Invalid User'; -- Buyer does not exist
    END IF;

    OPEN cur_orders;

    read_loops: LOOP
        FETCH cur_orders INTO current_status, current_amount, order_date;
        IF done THEN
            LEAVE read_loops;
        END IF;

        -- Always increase total orders count
        SET total_orders = total_orders + 1;

        -- Aggreagate data
        IF current_status = 'DELIVERED' THEN
            -- Add to lifetime spending
            SET total_spending = total_spending + current_amount;

            -- Add to recent spending if within 6 months
            IF order_date >= DATE_SUB(NOW(), INTERVAL 6 MONTH) THEN
                SET recent_spending = recent_spending + current_amount;
            END IF;

        ELSEIF current_status = 'CANCELED' THEN
            SET cancel_count = cancel_count + 1;
        END IF;

    END LOOP;

    CLOSE cur_orders;

    -- Determine initial rank based on total spending
    IF total_spending >= 10000000 THEN -- >=10M VND
        SET rank_score = 4; -- Platinum
    ELSEIF total_spending >= 5000000 THEN -- >=5M VND
        SET rank_score = 3; -- Gold
    ELSEIF total_spending >= 2000000 THEN -- >=2M VND
        SET rank_score = 2; -- Silver
    ELSE
        SET rank_score = 1; -- Standard
    END IF;

    -- Downgrade rank if cancellation rate > 30%
    IF total_orders > 0 THEN -- Avoid division by zero
        SET cancel_rate = cancel_count / total_orders;
        IF cancel_rate > 0.3 THEN
            SET rank_score = GREATEST(rank_score - 1, 1);
        END IF;
    END IF;

    -- Downgrade rank if recent spending < threshold (40% of required spending for current rank)
    IF (rank_score = 4 AND recent_spending < 4000000) OR
       (rank_score = 3 AND recent_spending < 2000000) OR
       (rank_score = 2 AND recent_spending < 800000) THEN
        SET rank_score = GREATEST(rank_score - 1, 1);
    END IF;

    -- Map rank score to rank name
    IF rank_score = 4 THEN
        SET result_rank = 'Platinum';
    ELSEIF rank_score = 3 THEN
        SET result_rank = 'Gold';
    ELSEIF rank_score = 2 THEN
        SET result_rank = 'Silver';
    ELSE
        SET result_rank = 'Standard';
    END IF;

    RETURN result_rank;
END $$

DELIMITER ;

-- Test
CALL sp_searchProducts('Electronics', 100000, 5000000);
CALL sp_getShopProductStatistics(1, NULL);
SELECT shopID, fn_calculateShopNetRevenue(shopID, 9, 2025) AS total_revenue
FROM SHOP;
SELECT userID, fn_classifyBuyerRank(userID) AS buyer_rank
FROM BUYER;

-- ==============================================================
-- SCENARIO 1: TESTING REVENUE & STATISTICS (Shop 1 - TechZone)
-- Current State: Shop 1 sells 'Tai nghe Bluetooth' (Prod 1).
-- Goal: 
--   1. Add a new expensive product to Shop 1.
--   2. Create orders in Dec 2025 to test 2% Commission (Electronics).
--   3. Leave one product unsold to test NULL/0 handling in Statistics.
-- ==============================================================

-- 1.1 Add a new High-Value Product to Shop 1
INSERT INTO PRODUCT (productID, shopID, name, description, base_Price) 
VALUES (100, 1, 'Gaming Laptop Pro', 'High-end gaming laptop', 20000000); -- 20 Million

INSERT INTO PRODUCT_OPTIONS (productID, optionID, current_Stock) 
VALUES (100, 1, 50);

INSERT INTO BELONGS_TO_CATEGORY (productID, categoryID) 
VALUES (100, 1);

-- 1.2 Add Valid Orders for Dec 2025 (Target for Revenue Function)
-- Buyer 14 buys 2 Laptops (Total 40M). 
-- Commission Logic: 40M * 2% = 800k Fee. Net Revenue = 39.2M.
INSERT INTO ORDERS (buyerID, addressID, total_Amount, order_Date) 
VALUES (14, 4, 40000000, '2025-12-01 10:00:00');

SET @orderID_Rev = LAST_INSERT_ID();

INSERT INTO ORDER_ITEM (orderID, optionID, productID, carrierID, status, quantity, unit_Price, delivered_date) 
VALUES (@orderID_Rev, 1, 100, 1, 'DELIVERED', 2, 20000000, '2025-12-05');

INSERT INTO REVIEW (buyerID, productID, rating, comment, date_Posted) VALUES 
(14, 100, 5, 'Excellent performance!', '2025-12-10');


-- Add Product 101 that is NEVER sold to test 'sp_getShopProductStatistics'
INSERT INTO PRODUCT (productID, shopID, name, description, base_Price) 
VALUES (101, 1, 'Old VGA Cable', 'Nobody wants this', 50000);
INSERT INTO PRODUCT_OPTIONS (productID, optionID, current_Stock) VALUES (101, 1, 100);
INSERT INTO BELONGS_TO_CATEGORY (productID, categoryID) VALUES (101, 1);

-- TEST QUERY FOR SCENARIO 1:
-- CALL sp_getShopProductStatistics(1, NULL); 
-- ^ Should show Laptop (2 sold), Tai nghe (2 sold), and VGA Cable (0 sold).


-- ==============================================================
-- SCENARIO 2: TESTING BUYER RANK - PLATINUM (Buyer 11)
-- Current State: Buyer 11 has 1 order of 550k.
-- Goal: Push total spend > 10M to reach Platinum.
-- ==============================================================

INSERT INTO ORDERS (buyerID, addressID, total_Amount, order_Date) 
VALUES (11, 1, 15000000, NOW());

SET @orderID_VIP = LAST_INSERT_ID();

INSERT INTO ORDER_ITEM (orderID, optionID, productID, carrierID, status, quantity, unit_Price, delivered_date) 
VALUES (@orderID_VIP, 1, 100, 1, 'DELIVERED', 1, 15000000, NOW());

INSERT INTO REVIEW (buyerID, productID, rating, comment, date_Posted) VALUES 
(11, 100, 4, 'Good value for money.', NOW());

-- TEST QUERY FOR SCENARIO 2:
SELECT fn_classifyBuyerRank(11); 
-- ^ Should return 'Platinum'.


-- ==============================================================
-- SCENARIO 3: TESTING INACTIVITY DOWNGRADE (Buyer 12)
-- Current State: Buyer 12 has 1 order of 2.3M.
-- Goal: Add huge spend (20M) but date it back to 2024.
-- Expectation: Spend > 10M (Platinum Base), but Inactive > 6mo -> Downgrade to Gold.
-- ==============================================================

INSERT INTO ORDERS (buyerID, addressID, total_Amount, order_Date) 
VALUES (12, 2, 20000000, '2024-01-01 00:00:00');

SET @orderID_Inactive = LAST_INSERT_ID();

INSERT INTO ORDER_ITEM (orderID, optionID, productID, carrierID, status, quantity, unit_Price, delivered_date) 
VALUES (@orderID_Inactive, 1, 100, 1, 'DELIVERED', 1, 20000000, '2024-01-05');

INSERT INTO REVIEW (buyerID, productID, rating, comment, date_Posted) VALUES 
(12, 100, 5, 'Great product!', '2024-01-10');

-- TEST QUERY FOR SCENARIO 3:
SELECT fn_classifyBuyerRank(12); 
-- ^ Should return 'Gold' (Downgraded from Platinum).


-- ==============================================================
-- SCENARIO 4: TESTING CANCELLATION DOWNGRADE (Buyer 13)
-- Current State: Buyer 13 has 1 order of 320k.
-- Goal: Add spend to reach Gold (>5M), but spam CANCELED orders.
-- Expectation: Base Gold, but Cancel Rate > 30% -> Downgrade to Silver.
-- ==============================================================

-- 4.1 Add Valid Spend (6M)
INSERT INTO ORDERS (buyerID, addressID, total_Amount, order_Date) 
VALUES (13, 3, 6000000, NOW());
SET @orderID_Valid = LAST_INSERT_ID();
INSERT INTO ORDER_ITEM (orderID, optionID, productID, carrierID, status, quantity, unit_Price, delivered_date) 
VALUES (@orderID_Valid, 1, 100, 1, 'DELIVERED', 1, 6000000, NOW());

INSERT INTO REVIEW (buyerID, productID, rating, comment, date_Posted) VALUES 
(13, 100, 5, 'Great product!', NOW());

-- 4.2 Add Canceled Orders (3 Orders)
-- Total Orders = 1 (Initial) + 1 (Valid) + 3 (Cancel) = 5.
-- Cancel Count = 3. Rate = 3/5 = 60% (>30%).
INSERT INTO ORDERS (buyerID, addressID, total_Amount, order_Date) VALUES (13, 3, 500000, NOW());
INSERT INTO ORDER_ITEM (orderID, optionID, productID, carrierID, status, quantity, unit_Price, delivered_date) 
VALUES (LAST_INSERT_ID(), 1, 100, 1, 'CANCELED', 1, 500000, NULL);

INSERT INTO ORDERS (buyerID, addressID, total_Amount, order_Date) VALUES (13, 3, 500000, NOW());
INSERT INTO ORDER_ITEM (orderID, optionID, productID, carrierID, status, quantity, unit_Price, delivered_date) 
VALUES (LAST_INSERT_ID(), 1, 100, 1, 'CANCELED', 1, 500000, NULL);

INSERT INTO ORDERS (buyerID, addressID, total_Amount, order_Date) VALUES (13, 3, 500000, NOW());
INSERT INTO ORDER_ITEM (orderID, optionID, productID, carrierID, status, quantity, unit_Price, delivered_date) 
VALUES (LAST_INSERT_ID(), 1, 100, 1, 'CANCELED', 1, 500000, NULL);

-- TEST QUERY FOR SCENARIO 4:
SELECT fn_classifyBuyerRank(13); 
-- ^ Should return 'Silver' (Downgraded from Gold).

-- 1. Check Revenue for Shop 1 (TechZone) in Dec 2025
-- Should include the 40M order. (40M * 0.98 = 39.2M)
SELECT fn_calculateShopNetRevenue(1, 12, 2025) AS TechZone_Dec_Revenue;

-- 2. Check Statistics for Shop 1
-- Look for 'Old VGA Cable' with 0 Sales.
CALL sp_getShopProductStatistics(1, NULL);
-- should show 5 laptop sold, 2 tai nghe sold, 0 vga cable sold.

-- 3. Check Buyer Ranks
SELECT 
    userID, 
    username, 
    fn_classifyBuyerRank(userID) AS Rank_Calculated
FROM USERS 
WHERE userID IN (11, 12, 13);



-- ==============================================================-- PROCEDURE: INSERT_PRODUCT
-- Mục đích: Thêm sản phẩm mới vào cửa hàng với các kiểm tra hợp lệ.
--Sử dụng bảng PRODUCT
-- Câu lệnh:
CREATE PROCEDURE INSERT_PRODUCT(
    IN P_SHOPID INT,
    IN P_NAME VARCHAR(150),
    IN P_DESCRIPTION TEXT,
    IN P_BASE_PRICE INT,
    IN P_CATEGORYID INT      
)
BEGIN
    DECLARE shop_exists INT DEFAULT 0;
    DECLARE shop_active INT DEFAULT 0;
    DECLARE category_exists INT DEFAULT 0;
    DECLARE new_product_id INT;

    -- KIỂM TRA SHOP CÓ TỒN TẠI
    SELECT COUNT(*) INTO shop_exists FROM SHOP WHERE shopID = P_SHOPID;
    IF shop_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'SHOP KHÔNG TỒN TẠI!';
    END IF;

    -- KIỂM TRA SHOP ACTIVE
    SELECT COUNT(*) INTO shop_active 
    FROM SHOP WHERE shopID = P_SHOPID AND shop_Status = 'ACTIVE';
    IF shop_active = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'SHOP ĐÃ NGỪNG HOẠT ĐỘNG!';
    END IF;

    -- KIỂM TRA CATEGORY
    SELECT COUNT(*) INTO category_exists 
    FROM CATEGORY 
    WHERE categoryID = P_CATEGORYID;

    IF category_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'CATEGORY KHÔNG TỒN TẠI!';
    END IF;

    -- KIỂM TRA TÊN
    IF P_NAME IS NULL OR TRIM(P_NAME) = '' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'TÊN SẢN PHẨM KHÔNG ĐƯỢC ĐỂ TRỐNG!';
    END IF;

    -- KIỂM TRA GIÁ > 0
    IF P_BASE_PRICE <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'GIÁ SẢN PHẨM PHẢI LỚN HƠN 0!';
    END IF;

    -- THÊM PRODUCT
    INSERT INTO PRODUCT(shopID, name, description, base_Price)
    VALUES(P_SHOPID, P_NAME, P_DESCRIPTION, P_BASE_PRICE);

    SET new_product_id = LAST_INSERT_ID();

    -- THÊM QUAN HỆ CATEGORY
    INSERT INTO BELONGS_TO_CATEGORY(productID, categoryID)
    VALUES (new_product_id, P_CATEGORYID);

    SELECT 'THÀNH CÔNG: SẢN PHẨM "', P_NAME, '" ĐÃ ĐƯỢC THÊM VÀ GÁN CATEGORY!' AS MESSAGE;

END;
-- Testcase:
-- Test 1: Thêm sản phẩm thành công
CALL INSERT_PRODUCT(1, 'Bàn phím cơ RGB', 'Bàn phím cơ full RGB switch blue', 650000, 1);

-- Test 2: Thêm sản phẩm thành công khác
CALL INSERT_PRODUCT(2, 'Nồi chiên không dầu 7L', 'Nồi chiên không dầu dung tích lớn', 1500000, 1);

-- Test 3: Lỗi - Shop không tồn tại
CALL INSERT_PRODUCT(999, 'Sản phẩm test', 'Mô tả', 100000, 1);
 

-- Test 4: Lỗi - Shop không active
INSERT INTO SHOP (sellerID, shopName, description, shopType, date_Open, shop_Status) 
VALUES (6, 'Shop Inactive', 'Shop ngừng hoạt động', 'Other','2019-3-4' , 'INACTIVE');

CALL INSERT_PRODUCT(6, 'Sản phẩm test', 'Mô tả', 100000);
 
-- Test 5: Lỗi - Tên sản phẩm rỗng
CALL INSERT_PRODUCT(1, '', 'Mô tả', 100000);
 

-- Test 6: Lỗi - Giá sản phẩm < 0
CALL INSERT_PRODUCT(1, 'Sản phẩm giá âm', 'Mô tả', -50000);
 

-- Test 7: Lỗi - Giá sản phẩm = 0
CALL INSERT_PRODUCT(1, 'Sản phẩm giá 0', 'Mô tả', 0);

--2.1.2 Update
-- Bảng PRODUCT
-- Câu lệnh: 
CREATE PROCEDURE UPDATE_PRODUCT(
    IN P_PRODUCTID INT,
    IN P_NAME VARCHAR(150),
    IN P_DESCRIPTION TEXT,
    IN P_BASE_PRICE INT,
    IN P_CATEGORY_ID INT      
)
BEGIN
    DECLARE product_exists INT DEFAULT 0;
    DECLARE category_exists INT DEFAULT 0;

    -- KIỂM TRA SẢN PHẨM
    SELECT COUNT(*) INTO product_exists 
    FROM PRODUCT 
    WHERE productID = P_PRODUCTID;

    IF product_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'SẢN PHẨM KHÔNG TỒN TẠI!';
    END IF;

    -- KIỂM TRA CATEGORY
    SELECT COUNT(*) INTO category_exists 
    FROM CATEGORY 
    WHERE categoryID = P_CATEGORY_ID;

    IF category_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'CATEGORY KHÔNG TỒN TẠI!';
    END IF;

    -- KIỂM TRA TÊN
    IF P_NAME IS NULL OR TRIM(P_NAME) = '' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'TÊN SẢN PHẨM KHÔNG ĐƯỢC ĐỂ TRỐNG!';
    END IF;

    -- KIỂM TRA GIÁ
    IF P_BASE_PRICE <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'GIÁ SẢN PHẨM PHẢI LỚN HƠN 0!';
    END IF;

    -- UPDATE PRODUCT
    UPDATE PRODUCT 
    SET name = P_NAME,
        description = P_DESCRIPTION,
        base_Price = P_BASE_PRICE
    WHERE productID = P_PRODUCTID;

    -- XÓA CATEGORY CŨ (nếu có)
    DELETE FROM BELONGS_TO_CATEGORY 
    WHERE productID = P_PRODUCTID;

    -- THÊM CATEGORY MỚI
    INSERT INTO BELONGS_TO_CATEGORY(productID, categoryID)
    VALUES(P_PRODUCTID, P_CATEGORY_ID);

    SELECT 'CẬP NHẬT THÀNH CÔNG: SẢN PHẨM #', P_PRODUCTID AS MESSAGE;
END;

-- Testcase:
-- Test 8: Cập nhật sản phẩm thành công
CALL UPDATE_PRODUCT(1, 'Tai nghe Bluetooth cao cấp', 'Chất lượng âm thanh tuyệt vời', 350000, 1);
-- Test 9: Lỗi - Sản phẩm không tồn tại
CALL UPDATE_PRODUCT(999, 'Tên mới', 'Mô tả mới', 200000, 1);
 
-- Test 10: Lỗi - Tên sản phẩm rỗng
CALL UPDATE_PRODUCT(6, '', 'Mô tả mới', 200000, 1);
 

-- Test 11: Lỗi - Giá sản phẩm <= 0
CALL UPDATE_PRODUCT(6, 'Tên mới', 'Mô tả mới', -100000, 1);
--2.1.3. Delete 
-- Sản phẩm được xóa khi :
-- Sản phẩm thông tin không đúng, vi phạm quy định của sàn thương mại điện tử
-- Sản phẩm test trong quá trình phát triển
-- Sản phẩm chưa có khách hàng đạt mua
-- Sản phẩm không được xóa khi: Sản phẩm đã có đơn hàng
-- Mục đích, lý do cần xóa sản phẩm:
-- Tránh tồn tại các sản phẩm sai phạm, sai thông tin ảnh hưởng đến uy tín sàn thương mại điện tử
-- Dọn dẹp Database, loại bỏ các dữ liệu test
-- Giảm thiểu các dữ liệu không cần thiết giúp tối ưu hiệu suất
-- Bảng: PRODUCT
-- Câu lệnh:
CREATE PROCEDURE DELETE_PRODUCT(
    IN P_PRODUCTID INT
)
BEGIN
    DECLARE product_exists INT DEFAULT 0;
    DECLARE has_orders INT DEFAULT 0;
    DECLARE product_name VARCHAR(150);

    -- kiểm tra sản phẩm có tồn tại
    SELECT COUNT(*) INTO product_exists 
    FROM PRODUCT 
    WHERE productID = P_PRODUCTID;

    IF product_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'SẢN PHẨM KHÔNG TỒN TẠI!';
    END IF;

    -- LẤY TÊN SẢN PHẨM
    SELECT name INTO product_name
    FROM PRODUCT
    WHERE productID = P_PRODUCTID
    LIMIT 1;


    -- kiểm tra sản phẩm có trong đơn hàng không
    SELECT COUNT(*) INTO has_orders
    FROM ORDER_ITEM 
    WHERE productID = P_PRODUCTID;
    
    IF has_orders > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'KHÔNG THỂ XÓA SẢN PHẨM ĐÃ TỪNG ĐƯỢC ĐẶT HÀNG!';
    END IF;

    -- thực hiện xóa
    DELETE FROM PRODUCT WHERE productID = P_PRODUCTID;

    SELECT CONCAT('THÀNH CÔNG: SẢN PHẨM "', product_name, '" ĐÃ ĐƯỢC XÓA!') AS MESSAGE;

END;
-- TestCase:
-- Test 12: Xóa sản phẩm không có đơn hàng (thành công)
CALL INSERT_PRODUCT(1, 'Sản phẩm test xóa', 'Sản phẩm để test xóa', 100000);
CALL DELETE_PRODUCT(107);

-- Test 13: Lỗi - Xóa sản phẩm có đơn hàng
CALL DELETE_PRODUCT(6);  -- Sản phẩm có trong ORDER_ITEM
 
-- Test 14: Lỗi - Sản phẩm không tồn tại
CALL DELETE_PRODUCT(999);

--2.2 Trigger
--2.2.1. Trigger kiểm tra ràng buộc nghiệp vụ
-- Ràng buộc: Chỉ người mua đã hoàn tất đơn hàng mới có thể đánh giá sản phẩm
-- Các thao tác DML có thể vi phạm ràng buộc: 
-- Thêm đánh giá mới: INSERT INTO REVIEW
-- Câu lệnh:
CREATE TRIGGER trg_before_insert_review
BEFORE INSERT ON REVIEW
FOR EACH ROW
BEGIN
    DECLARE order_status VARCHAR(20);
    DECLARE order_exists INT DEFAULT 0;
    DECLARE product_exists INT DEFAULT 0;
    DECLARE buyer_exists INT DEFAULT 0;
    DECLARE review_exists INT DEFAULT 0;
    
    -- kiểm tra sản phẩm có tồn tại không
    SELECT COUNT(*) INTO product_exists
    FROM PRODUCT 
    WHERE productID = NEW.productID;
    IF product_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'SAN PHAM KHONG TON TAI!';
    END IF;
    
    -- kiểm tra buyer có tồn tại không
    SELECT COUNT(*) INTO buyer_exists
    FROM BUYER 
    WHERE userID = NEW.buyerID;
    IF buyer_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'BUYER KHONG TON TAI!';
    END IF;
    
    -- kiểm tra buyer đã review sản phẩm này chưa
    SELECT COUNT(*) INTO review_exists
    FROM REVIEW 
    WHERE buyerID = NEW.buyerID AND productID = NEW.productID;
    IF review_exists > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'BAN CHI DUOC DANH GIA SAN PHAM NAY 1 LAN!';
    END IF;
    
    -- kiểm tra đơn hàng có tồn tại và thuộc về người mua này không
    SELECT COUNT(*) INTO order_exists
    FROM ORDER_ITEM oi
    JOIN ORDERS o ON oi.orderID = o.orderID
    WHERE oi.productID = NEW.productID 
      AND o.buyerID = NEW.buyerID;
    
    -- Nếu có đơn hàng, lấy status của nó
    IF order_exists > 0 THEN
        SELECT oi.status INTO order_status
        FROM ORDER_ITEM oi
        JOIN ORDERS o ON oi.orderID = o.orderID
        WHERE oi.productID = NEW.productID 
          AND o.buyerID = NEW.buyerID
    ELSE
        SET order_status = NULL;
    END IF;
    IF order_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'KHONG TIM THAY DON HANG TUONG UNG VOI SAN PHAM NAY!';
    END IF;
    
    -- Kiểm tra đơn hàng đã hoàn thành chưa
    IF order_status != 'COMPLETED' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'CHI DUOC DANH GIA SAN PHAM SAU KHI DON HANG DA HOAN THANH!';
    END IF;
END;
 
-- Test Case:
-- Test case 1: Thêm đánh giá hợp lệ
INSERT INTO REVIEW (buyerID, productID, rating, comment) 
VALUES (11, 6, 5, 'Sản phẩm tuyệt vời!');

-- Test case 2: Sản phẩm không tồn tại
INSERT INTO REVIEW (buyerID, productID, rating, comment) 
VALUES (11, 99, 5, 'Sản phẩm tuyệt vời!');
 

-- Test case 3: Buyer không tồn tại
INSERT INTO REVIEW (buyerID, productID, rating, comment) 
VALUES (99, 6, 5, 'Sản phẩm tuyệt vời!');
 

-- Test case 4: Chỉ được đánh giá 1 lần
INSERT INTO REVIEW (buyerID, productID, rating, comment) 
VALUES (11, 6, 5, 'Sản phẩm tuyệt vời!');
 

-- Test case 5: Không tìm thấy đơn hàng
INSERT INTO REVIEW (buyerID, productID, rating, comment) 
VALUES (11, 15, 5, 'Sản phẩm tuyệt vời!');

-- Test case 6: Chỉ đánh giá khi đã hoàn thành đơn hàng
INSERT INTO REVIEW (buyerID, productID, rating, comment) 
VALUES (12, 7, 5, 'Sản phẩm tuyệt vời!');

--2.2.2 Trigger cho thuộc tính dẫn xuất
-- Thuộc tính: giá trị total_Amount trong ORDERS
-- Cách tính: total_Amount = quantity * unit_Price
-- Các theo tác DML có thể thay đổi giá trị thuộc tính: 
-- Thêm sản phẩm vào đơn hàng: INSERT INTO ORDER_ITEM 
-- Cập nhật số lượng hoặc giá: UPDATE ORDER_ITEM 
-- Câu lệnh:
-- Trigger 1: Sau khi thêm ORDER_ITEM mới
CREATE TRIGGER trg_update_order_total_after_insert
AFTER INSERT ON ORDER_ITEM
FOR EACH ROW
BEGIN
    DECLARE order_total INT;
    
    -- Tính tổng tiền cho order
    SELECT SUM(quantity * unit_Price) 
    INTO order_total
    FROM ORDER_ITEM
    WHERE orderID = NEW.orderID;
    
    -- Cập nhật tổng tiền vào bảng ORDERS
    UPDATE ORDERS 
    SET total_Amount = IFNULL(order_total, 0)
    WHERE orderID = NEW.orderID;
END;

-- Trigger 2: Sau khi cập nhật ORDER_ITEM
CREATE TRIGGER trg_update_order_total_after_update
AFTER UPDATE ON ORDER_ITEM
FOR EACH ROW
BEGIN
    DECLARE order_total INT;
    
    -- Tính tổng tiền cho order
	-- Có thể có nhiều mặt hàng trong 1 đơn
    SELECT SUM(quantity * unit_Price) 
    INTO order_total
    FROM ORDER_ITEM
    WHERE orderID = NEW.orderID;
    
    -- Cập nhật tổng tiền vào bảng ORDERS
    UPDATE ORDERS 
    SET total_Amount = IFNULL(order_total, 0)
    WHERE orderID = NEW.orderID;
END;
-- Test Case:
-- Test INSERT INTO ORDER_ITEM  
INSERT INTO ORDERS (buyerID, addressID, total_Amount, order_Date) VALUES
(15, 5,  0,  '2025-11-15 08:00:00');
 
INSERT INTO ORDER_ITEM VALUES
(13, 1, 20, 1, 'PENDING', 1, 100000, '2025-11-20', '2025-11-20', 'PAID');
 
--> Bảng ORDER đã cập nhật giá trị total_amount : 100000
 
-- Test UPDATE ORDER_ITEM 
-- Upadate unit_price
UPDATE ORDER_ITEM 
SET unit_Price = 200000 
WHERE orderID = 13 AND productID = 20 AND optionID = 1;
--> Bảng ORDER đã cập nhật giá trị total_amount : 200000
  
-- Update quantity
UPDATE ORDER_ITEM 
SET quantity = 0
WHERE orderID = 13 AND productID = 20 AND optionID = 1;
--> Bảng ORDER đã cập nhật giá trị total_amount : 0

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_updateOrderStatus $$

CREATE PROCEDURE sp_updateOrderStatus(
    IN p_shopID INT,
    IN p_orderID INT,
    IN p_productID INT,
    IN p_newStatus VARCHAR(20)
)
BEGIN
    DECLARE v_count INT;

    -- 1. Kiểm tra xem món hàng này có thuộc về Shop này không (Bảo mật)
    SELECT COUNT(*) INTO v_count
    FROM ORDER_ITEM oi
    JOIN PRODUCT p ON oi.productID = p.productID
    WHERE oi.orderID = p_orderID 
      AND oi.productID = p_productID 
      AND p.shopID = p_shopID;

    IF v_count = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Không tìm thấy đơn hàng hoặc sản phẩm không thuộc Shop của bạn!';
    END IF;

    -- 2. Cập nhật trạng thái
    UPDATE ORDER_ITEM
    SET status = p_newStatus,
        -- Nếu giao thành công thì cập nhật ngày giao thực tế
        delivered_date = IF(p_newStatus = 'DELIVERED', NOW(), NULL)
    WHERE orderID = p_orderID AND productID = p_productID;
    
    -- Ghi chú: Hàm fn_calculateShopNetRevenue chỉ tính các đơn có status = 'DELIVERED'.
    -- Do đó, khi status chuyển sang DELIVERED, doanh thu sẽ tự động được tính.

    SELECT 'Cập nhật trạng thái thành công!' AS message;
END $$

DELIMITER ;
