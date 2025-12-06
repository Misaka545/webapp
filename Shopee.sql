drop database if exists Shopeedb;
create database Shopeedb;
use Shopeedb;
-- USERS 
CREATE TABLE USERS (
    userID INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    fullname VARCHAR(50),
    password VARCHAR(255) NOT NULL,
    phone VARCHAR(15) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    status ENUM('ACTIVE', 'INACTIVE') DEFAULT 'ACTIVE'   
);

-- ADMINISTRATOR 
CREATE TABLE ADMINISTRATOR (
    userID INT PRIMARY KEY,
    admin_level VARCHAR(50) NOT NULL,
    FOREIGN KEY (userID) REFERENCES USERS(userID)
        ON UPDATE CASCADE
);

-- SELLER
CREATE TABLE SELLER (
    userID INT PRIMARY KEY,
    FOREIGN KEY (userID) REFERENCES USERS(userID)
        ON UPDATE CASCADE
);

-- BUYER
CREATE TABLE BUYER (
    userID INT PRIMARY KEY,
    birthDate DATE,
    loyaltyPoints INT DEFAULT 0,
    FOREIGN KEY (userID) REFERENCES USERS(userID)
        ON UPDATE CASCADE
);

-- BANK
CREATE TABLE BANK (
    bankID INT AUTO_INCREMENT PRIMARY KEY,
    bankName VARCHAR(100) NOT NULL,
    branch VARCHAR(100),
    accountName VARCHAR(50) NOT NULL,
    number_card VARCHAR(30) UNIQUE NOT NULL,
    userID INT NOT NULL,
    FOREIGN KEY (userID) REFERENCES USERS(userID)
        ON UPDATE CASCADE ON DELETE CASCADE
);

-- BUYER_ADDRESS
CREATE TABLE BUYER_ADDRESS (
    addressID INT AUTO_INCREMENT PRIMARY KEY,
    buyerID INT NOT NULL,
    phone VARCHAR(15) NOT NULL,
    recipientName VARCHAR(100),
    description TEXT NOT NULL,
    ward VARCHAR(100) NOT NULL,
    district VARCHAR(100) NOT NULL,
    province VARCHAR(100) NOT NULL,
    isDefault BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (buyerID) REFERENCES BUYER(userID)
        ON UPDATE CASCADE ON DELETE CASCADE
);

-- SHOP
CREATE TABLE SHOP (
    shopID INT AUTO_INCREMENT PRIMARY KEY,
    sellerID INT NOT NULL,
    shopName VARCHAR(100) NOT NULL,
    description TEXT,
    shopType VARCHAR(50),
    date_Open DATE,
    shop_Status ENUM('ACTIVE', 'INACTIVE') DEFAULT 'ACTIVE',
    shop_Rating DECIMAL(3,2) DEFAULT 0.00,
    FOREIGN KEY (sellerID) REFERENCES SELLER(userID)
        ON UPDATE CASCADE
);

-- CATEGORY
CREATE TABLE CATEGORY (
    categoryID INT AUTO_INCREMENT PRIMARY KEY,
    categoryName VARCHAR(100) NOT NULL,
    parentID INT,
    FOREIGN KEY (parentID) REFERENCES CATEGORY(categoryID)
        ON UPDATE CASCADE ON DELETE SET NULL
);

-- PRODUCT
CREATE TABLE PRODUCT (
    productID INT AUTO_INCREMENT PRIMARY KEY,
    shopID INT NOT NULL,
    name VARCHAR(150) NOT NULL,
    description TEXT,
    product_Rating DECIMAL(3,2) DEFAULT 0.00,
    base_Price INT NOT NULL CHECK(base_Price > 0),
    FOREIGN KEY (shopID) REFERENCES SHOP(shopID)
        ON UPDATE CASCADE
);

-- PRODUCT_OPTIONS
CREATE TABLE PRODUCT_OPTIONS(
    optionID INT NOT NULL, 
    productID INT NOT NULL,
    size VARCHAR(50),
    color VARCHAR(50),
    dimensions VARCHAR(100),
    weight DECIMAL(6,2),
    current_Stock INT DEFAULT 0,
    PRIMARY KEY (productID, optionID),
    FOREIGN KEY (productID) REFERENCES PRODUCT(productID)
        ON UPDATE CASCADE
);

-- IMAGE_PRODUCT
CREATE TABLE IMAGE_URL (
    imageID INT AUTO_INCREMENT PRIMARY KEY,
    productID INT NOT NULL,
    optionID INT NOT NULL,
    imageURL VARCHAR(255) NOT NULL,
    FOREIGN KEY (productID, optionID) REFERENCES PRODUCT_OPTIONS(productID, optionID)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

-- BELONGS_TO_CATEGORY
CREATE TABLE BELONGS_TO_CATEGORY (
    productID INT,
    categoryID INT,
    PRIMARY KEY (productID, categoryID),
    FOREIGN KEY (productID) REFERENCES PRODUCT(productID)
        ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (categoryID) REFERENCES CATEGORY(categoryID)
        ON UPDATE CASCADE ON DELETE CASCADE
);

-- VOUCHER
CREATE TABLE VOUCHER (
    voucherID INT AUTO_INCREMENT PRIMARY KEY,
    voucher_Code VARCHAR(50) UNIQUE NOT NULL,
    discount_value INT,
    min_Applicable_Price INT DEFAULT 0,
    max_Discount_Amount INT,
    expiration_Date DATE
);

-- OWN_VOUCHER
CREATE TABLE OWN_VOUCHER (
    buyerID INT NOT NULL,
    voucherID INT NOT NULL,
    used BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (buyerID, voucherID),
    FOREIGN KEY (buyerID) REFERENCES BUYER(userID)
        ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (voucherID) REFERENCES VOUCHER(voucherID)
        ON UPDATE CASCADE ON DELETE CASCADE
);

-- SHOP_REVIEW
CREATE TABLE SHOP_REVIEW (
    buyerID INT NOT NULL,
    shopID INT NOT NULL,
    rating INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment TEXT NOT NULL,
    date_Posted DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (buyerID, shopID),
    FOREIGN KEY (buyerID) REFERENCES BUYER(userID)
        ON UPDATE CASCADE ,
    FOREIGN KEY (shopID) REFERENCES SHOP(shopID)
        ON UPDATE CASCADE 
);

-- ORDERS
CREATE TABLE ORDERS (
    orderID INT AUTO_INCREMENT PRIMARY KEY,
    buyerID INT NOT NULL,
    order_Date DATETIME DEFAULT CURRENT_TIMESTAMP,
    addressID INT NOT NULL,
    total_Amount INT NOT NULL CHECK (total_Amount >= 0),
    FOREIGN KEY (buyerID) REFERENCES BUYER(userID)
        ON UPDATE CASCADE,
    FOREIGN KEY (addressID) REFERENCES BUYER_ADDRESS(addressID)
        ON UPDATE CASCADE
);

-- REVIEW
CREATE TABLE REVIEW (
    buyerID INT NOT NULL,
    orderID INT NOT NULL,
    productID INT NOT NULL,
    rating INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment TEXT NOT NULL,
    date_Posted DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (buyerID, orderID),
    FOREIGN KEY (orderID) REFERENCES ORDERS(orderID)
        ON UPDATE CASCADE ,
    FOREIGN KEY (buyerID) REFERENCES BUYER(userID)
        ON UPDATE CASCADE ,
    FOREIGN KEY (productID) REFERENCES PRODUCT(productID)
        ON UPDATE CASCADE 
);

-- PAYMENT
CREATE TABLE PAYMENT(
    orderID INT,
    method VARCHAR(50) NOT NULL,
    trackingCode VARCHAR(50),
    statusPayment ENUM('FAIL','SUCCESS'),
    PRIMARY KEY (orderID),
    FOREIGN KEY (orderID) REFERENCES ORDERS(orderID)
        ON UPDATE CASCADE ON DELETE CASCADE 
);

-- SHIPPING_CARRIER
CREATE TABLE SHIPPING_CARRIER (
    carrierID INT AUTO_INCREMENT PRIMARY KEY,
    carrier_Name VARCHAR(100),
    contact_Info VARCHAR(255)
);

-- ORDER_ITEM
CREATE TABLE ORDER_ITEM (
    orderItemID INT AUTO_INCREMENT,
    orderID INT NOT NULL,
    optionID INT NOT NULL,
    productID INT NOT NULL,
    carrierID INT NOT NULL,
    status ENUM('PENDING', 'SHIPPING', 'DELIVERED', 'COMPLETED', 'CANCELED') DEFAULT 'PENDING',
    quantity INT DEFAULT 1 CHECK (quantity > 0),
    unit_Price INT CHECK (unit_Price >= 0),
    delivered_date DATE,
    expected_delivered_date DATE,
    statusPaid ENUM('PAID', 'UNPAID') NOT NULL DEFAULT 'UNPAID',
    PRIMARY KEY(orderItemID),
    FOREIGN KEY (orderID) REFERENCES ORDERS(orderID)
        ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (carrierID) REFERENCES SHIPPING_CARRIER(carrierID)
        ON UPDATE CASCADE,
    FOREIGN KEY (productID, optionID) REFERENCES PRODUCT_OPTIONS(productID, optionID)
        ON UPDATE CASCADE
);

-- ORDER_VOUCHER
CREATE TABLE ORDER_VOUCHER (
    orderID INT,
    voucherID INT,
    date_Applied DATE,
    PRIMARY KEY (orderID, voucherID),
    FOREIGN KEY (orderID) REFERENCES ORDERS(orderID)
        ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (voucherID) REFERENCES VOUCHER(voucherID)
        ON UPDATE CASCADE ON DELETE CASCADE
);

DELIMITER $$
-- Kiểm tra định dạng mật khẩu khi tạo người dùng
CREATE TRIGGER trg_user_password_check_insert
BEFORE INSERT ON USERS
FOR EACH ROW
BEGIN
    IF NEW.password NOT REGEXP '^(?=.*[A-Z])(?=.*[0-9]).{8,}$' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Password must be >= 8 chars, include at least 1 uppercase letter and 1 digit';
    END IF;
END$$
-- Kiểm tra định dạng mật khẩu khi cập nhật người dùng
CREATE TRIGGER trg_user_password_check_update
BEFORE UPDATE ON USERS
FOR EACH ROW
BEGIN
    IF NEW.password NOT REGEXP '^(?=.*[A-Z])(?=.*[0-9]).{8,}$' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Password must be >= 8 chars, include at least 1 uppercase letter and 1 digit';
    END IF;
END$$

-- Kiểm tra định dạng email khi tạo người dùng
CREATE TRIGGER trg_user_email_check_insert
BEFORE INSERT ON USERS
FOR EACH ROW
BEGIN
    IF NEW.email NOT REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Email format is invalid';
    END IF;
END$$
-- Cập nhật trạng thái voucher khi sử dụng
CREATE TRIGGER trg_after_insert_order_voucher
AFTER INSERT ON ORDER_VOUCHER
FOR EACH ROW
BEGIN
    UPDATE OWN_VOUCHER
    SET used = TRUE
    WHERE buyerID = NEW.buyerID
      AND voucherID = NEW.voucherID;
END$$
-- Kiểm tra voucher đã sử dụng trước khi áp dụng
CREATE TRIGGER trg_check_used_voucher_before_insert
BEFORE INSERT ON ORDER_VOUCHER
FOR EACH ROW
BEGIN
    DECLARE is_used BOOLEAN;

    SELECT used INTO is_used
    FROM OWN_VOUCHER
    WHERE buyerID = NEW.buyerID
      AND voucherID = NEW.voucherID;

    -- Nếu voucher không tồn tại hoặc đã dùng
    IF is_used IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Voucher does not belong to this buyer';
    END IF;

    IF is_used = TRUE THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Voucher has already been used and cannot be applied again';
    END IF;

END$$

-- TRIGGER Tạo optionID tự động
CREATE TRIGGER before_insert_product_option
BEFORE INSERT ON PRODUCT_OPTIONS
FOR EACH ROW
BEGIN
    DECLARE next_option_id INT;
    SELECT IFNULL(MAX(optionID), 0) + 1
    INTO next_option_id
    FROM PRODUCT_OPTIONS
    WHERE productID = NEW.productID;

    SET NEW.optionID = next_option_id;
END $$

-- Kiểm tra Người dùng có tài khoản ngân hàng trước khi tạo seller
CREATE TRIGGER check_seller_has_bank
BEFORE INSERT ON SELLER
FOR EACH ROW
BEGIN
    DECLARE bank_count INT;
    SELECT COUNT(*) INTO bank_count
    FROM BANK
    WHERE userID = NEW.userID;
    IF bank_count = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot register as Seller without a Bank account';
    END IF;
END $$

-- Gán voucher hiện có cho ng dùng mới đăng ký
CREATE TRIGGER auto_assign_voucher_to_new_buyer
AFTER INSERT ON BUYER
FOR EACH ROW
BEGIN
    INSERT INTO OWN_VOUCHER (buyerID, voucherID)
    SELECT NEW.userID, voucherID
    FROM VOUCHER;
END$$

-- Tự động gán voucher cho ng dùng
CREATE TRIGGER auto_assign_voucher
AFTER INSERT ON VOUCHER
FOR EACH ROW
BEGIN
    IF NEW.voucherID <> 1 THEN
        INSERT INTO OWN_VOUCHER (buyerID, voucherID)
        SELECT userID, NEW.voucherID
        FROM BUYER;
    END IF;
END$$


-- Kiểm tra ngày giao hàng
CREATE TRIGGER check_order_item_dates_before_insert
BEFORE INSERT ON ORDER_ITEM
FOR EACH ROW
BEGIN
    DECLARE order_date DATETIME;

    -- Lấy ngày đặt hàng
    SELECT order_date INTO order_date
    FROM ORDERS
    WHERE orderID = NEW.orderID;

    -- Kiểm tra ngày giao thực tế
    IF NEW.delivered_date IS NOT NULL 
       AND NEW.delivered_date < order_date THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Delivered date must be after order date';
    END IF;

    -- Kiểm tra ngày giao dự kiến
    IF NEW.expected_delivered_date IS NOT NULL
       AND NEW.expected_delivered_date < order_date THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Expected delivered date must be after order date';
    END IF;
END$$


-- Trigger kiểm tra khi UPDATE ORDER_ITEM
CREATE TRIGGER check_order_item_dates_before_update
BEFORE UPDATE ON ORDER_ITEM
FOR EACH ROW
BEGIN
    DECLARE order_date DATETIME;

    -- Lấy ngày đặt hàng
    SELECT order_date INTO order_date
    FROM ORDERS
    WHERE orderID = NEW.orderID;

    -- Kiểm tra ngày giao dự kiến
    IF NEW.expected_delivered_date IS NOT NULL
       AND NEW.expected_delivered_date < order_date THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Expected delivered date must be after order date';
    END IF;

    -- Kiểm tra ngày giao thực tế
    IF NEW.delivered_date IS NOT NULL
       AND NEW.delivered_date < order_date THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Delivered date must be after order date';
    END IF;
END$$

-- Gán isDefault cho địa chỉ đầu tiên của người mua
CREATE TRIGGER set_first_address_default
BEFORE INSERT ON BUYER_ADDRESS
FOR EACH ROW
BEGIN
    DECLARE addr_count INT;
    SELECT COUNT(*) INTO addr_count
    FROM BUYER_ADDRESS
    WHERE buyerID = NEW.buyerID;
    IF addr_count = 0 THEN
        SET NEW.isDefault = TRUE;
    END IF;
END $$


-- Cập nhật điểm đánh giá Shop
CREATE TRIGGER update_shop_rating_after_insert
AFTER INSERT ON SHOP_REVIEW
FOR EACH ROW
BEGIN
    DECLARE avg_rating DECIMAL(3,2);
    SELECT ROUND(AVG(rating), 2)
    INTO avg_rating
    FROM SHOP_REVIEW
    WHERE shopID = NEW.shopID;

    UPDATE SHOP
    SET shop_Rating = IFNULL(avg_rating, 0)
    WHERE shopID = NEW.shopID;
END $$

-- Cập nhật điểm đánh giá sản phẩm
CREATE TRIGGER update_product_rating_after_insert
AFTER INSERT ON REVIEW
FOR EACH ROW
BEGIN
    DECLARE avg_rating DECIMAL(3,2);
    SELECT ROUND(AVG(rating), 2)
    INTO avg_rating
    FROM REVIEW
    WHERE productID = NEW.productID;

    UPDATE PRODUCT
    SET product_Rating = IFNULL(avg_rating, 0)
    WHERE productID = NEW.productID;
END $$

DELIMITER ;

-- Tạo data mẫu

-- USERS 
INSERT INTO USERS (username, fullname, password, phone, email, status) VALUES
-- Admins
('admin1', 'ADMIN1', 'Pass12345', '0901000001', 'admin1@gmail.com', 'ACTIVE'),
('admin2', 'ADMIN2', 'Pass12345', '0901000002', 'admin2@gmail.com', 'ACTIVE'),
('admin3', 'ADMIN3', 'Pass12345', '0901000003', 'admin3@gmail.com', 'ACTIVE'),
('admin4', 'ADMIN4', 'Pass12345', '0901000004', 'admin4@gmail.com', 'ACTIVE'),
('admin5', 'ADMIN5', 'Pass12345', '0901000005', 'admin5@gmail.com', 'ACTIVE'),
-- Sellers
('seller1', 'SELLER1', 'Pass12345', '0902000001', 'seller1@gmail.com', 'ACTIVE'),
('seller2', 'SELLER2', 'Pass12345', '0902000002', 'seller2@gmail.com', 'ACTIVE'),
('seller3', 'SELLER3', 'Pass12345', '0902000003', 'seller3@gmail.com', 'ACTIVE'),
('seller4', 'SELLER4', 'Pass12345', '0902000004', 'seller4@gmail.com', 'ACTIVE'),
('seller5', 'SELLER5', 'Pass12345', '0902000005', 'seller5@gmail.com', 'ACTIVE'),
-- Buyers
('buyer1', 'BUYER1', 'Pass12345', '0903000001', 'buyer1@gmail.com', 'ACTIVE'),
('buyer2', 'BUYER2', 'Pass12345', '0903000002', 'buyer2@gmail.com', 'ACTIVE'),
('buyer3', 'BUYER3', 'Pass12345', '0903000003', 'buyer3@gmail.com', 'ACTIVE'),
('buyer4', 'BUYER4', 'Pass12345', '0903000004', 'buyer4@gmail.com', 'ACTIVE'),
('buyer5', 'BUYER5', 'Pass12345', '0903000005', 'buyer5@gmail.com', 'ACTIVE');

-- ADMINISTRATOR 
INSERT INTO ADMINISTRATOR (userID, admin_level) VALUES
(1, 'SUPER ADMIN'),
(2, 'MODERATOR'),
(3, 'MANAGER'),
(4, 'SYSTEM ADMIN'),
(5, 'SUPPORT LEAD');

-- BUYER 
INSERT INTO BUYER (userID, birthDate, loyaltyPoints) VALUES
(11, '1999-05-12', 0),
(12, '2001-10-20', 0),
(13, '2000-07-22', 0),
(14, '1998-11-15', 0),
(15, '2002-02-02', 0);

-- BANK 
INSERT INTO BANK (bankName, branch, accountName, number_card, userID) VALUES
('Vietcombank', 'HCM', 'Seller One', '1111111111111', 6),
('Techcombank', 'HN', 'Seller Two', '2222222222222', 7),
('ACB', 'HCM', 'Buyer One', '3333333333333', 11),
('VPBank', 'DN', 'Seller Three', '4444444444444', 8),
('MB Bank', 'HN', 'Buyer Two', '5555555555555', 12),
('BIDV', 'CT', 'Seller Four', '6666666666666', 9),
('Sacombank', 'HP', 'Buyer Three', '7777777777777', 13),
('TPBank', 'HCM', 'Seller Five', '8888888888888', 10),
('Eximbank', 'HN', 'Buyer Four', '9999999999999', 14),
('SHB', 'DN', 'Buyer Five', '1010101010101', 15);

-- SELLER 
INSERT INTO SELLER (userID) VALUES
(6), (7), (8), (9), (10);

-- BUYER_ADDRESS
INSERT INTO BUYER_ADDRESS (buyerID, phone, recipientName, description, ward, district, province, isDefault) VALUES
(11, '0903000001', 'Buyer 1', '123 Street', 'Ward 1', 'District 1', 'HCM', TRUE),
(11, '0903000001', 'Buyer 1', '555 Street', 'Ward 5', 'District 9', 'HCM', FALSE),
(12, '0903000002', 'Buyer 2', '456 Street', 'Ward 2', 'District 2', 'HN', TRUE),
(13, '0903000003', 'Buyer 3', '789 Street', 'Ward 3', 'District 3', 'DN', TRUE),
(14, '0903000004', 'Buyer 4', '321 Street', 'Ward 4', 'District 4', 'CT', TRUE),
(15, '0903000005', 'Buyer 5', '654 Street', 'Ward 5', 'District 5', 'HP', TRUE);

-- SHOP 
INSERT INTO SHOP (sellerID, shopName, description, shopType, date_Open, shop_Status, shop_Rating) VALUES
(6, 'TechZone', 'Shop chuyên đồ điện tử', 'Electronics', '2023-01-01', 'ACTIVE', 4.5),
(7, 'HomeStore', 'Đồ gia dụng cao cấp', 'Home', '2024-01-10', 'ACTIVE', 4.0),
(8, 'FashionHub', 'Quần áo nam nữ', 'Fashion', '2023-05-05', 'ACTIVE', 4.2),
(9, 'SportLife', 'Đồ thể thao', 'Sport', '2024-02-02', 'ACTIVE', 4.1),
(10, 'BookHeaven', 'Sách và văn phòng phẩm', 'Books', '2022-11-11', 'ACTIVE', 4.8);

-- CATEGORY
INSERT INTO CATEGORY (categoryName, parentID) VALUES
('Electronics', NULL),
('Home Appliances', NULL),
('Fashion', NULL),
('Sports', NULL),
('Books', NULL);

-- PRODUCT
INSERT INTO PRODUCT (shopID, name, description, base_Price) VALUES
(1, 'Tai nghe Bluetooth', 'Tai nghe không dây', 300000),
(2, 'Nồi chiên không dầu', 'Dung tích 5L', 1200000),
(3, 'Áo thun nam', 'Chất liệu cotton', 200000),
(4, 'Giày thể thao', 'Giày chạy bộ', 600000),
(5, 'Sách học SQL', 'Cẩm nang học SQL cơ bản', 150000);

-- PRODUCT_OPTIONS 
INSERT INTO PRODUCT_OPTIONS (productID, size, color, dimensions, weight, current_Stock) VALUES
(1, NULL, 'Black', NULL, 0.2, 50),
(1, NULL, 'White', NULL, 0.2, 40),

(2, NULL, 'Silver', NULL, 3.5, 20),
(2, NULL, 'Black', NULL, 3.5, 15),

(3, 'M', 'Blue', NULL, 0.3, 100),
(3, 'L', 'Red', NULL, 0.3, 80),

(4, '42', 'Red', NULL, 0.5, 70),
(4, '43', 'Black', NULL, 0.5, 65),

(5, NULL, 'White', NULL, 0.2, 40),
(5, NULL, 'Yellow', NULL, 0.2, 35);

-- IMAGE_URL
INSERT INTO IMAGE_URL (productID, optionID, imageURL) VALUES
-- Product 1 (Tai nghe Bluetooth)
(1, 1, 'https://example.com/images/product1_black_1.jpg'),
(1, 2, 'https://example.com/images/product1_white_1.jpg'),
-- Product 2 (Nồi chiên không dầu)
(2, 1, 'https://example.com/images/product2_silver_1.jpg'),
(2, 2, 'https://example.com/images/product2_black_1.jpg'),
-- Product 3 (Áo thun nam)
(3, 1, 'https://example.com/images/product3_m_blue_1.jpg'),
(3, 2, 'https://example.com/images/product3_l_red_1.jpg'),
-- Product 4 (Giày thể thao)
(4, 1, 'https://example.com/images/product4_42_red_1.jpg'),
(4, 2, 'https://example.com/images/product4_43_black_1.jpg');

INSERT INTO IMAGE_URL (productID, optionID, imageURL) VALUES
-- Product 5 (Sách học SQL)
(5, 1, 'https://images.pexels.com/photos/1130980/pexels-photo-1130980.jpeg?cs=srgb&dl=assortment-book-bindings-books-1130980.jpg&fm=jpg'),
(5, 2, 'https://example.com/images/product5_yellow_1.jpg');

-- BELONGS_TO_CATEGORY
INSERT INTO BELONGS_TO_CATEGORY (productID, categoryID) VALUES
(1, 1),
(2, 2),
(3, 3),
(4, 4),
(5, 5);

-- VOUCHER
INSERT INTO VOUCHER (voucher_Code, discount_value, min_Applicable_Price, max_Discount_Amount, expiration_Date) VALUES
('NEWBUYER', 30, 0, 50000, NULL),
('SALE10', 10, 100000, 50000, '2025-12-31'),
('SALE20', 20, 200000, 100000, '2025-12-31'),
('10-10', 30, 0, 30000, '2025-12-31'),
('12-12', 20, 100000, 50000, '2026-01-01');

-- SHOP_REVIEW
INSERT INTO SHOP_REVIEW (buyerID, shopID, rating, comment) VALUES
(11, 1, 5, 'Rất hài lòng!'),
(12, 2, 4, 'Tốt'),
(13, 3, 5, 'Shop đẹp'),
(14, 4, 4, 'Giao hàng nhanh'),
(15, 5, 5, 'Sách chất lượng cao');

-- ORDERS
INSERT INTO ORDERS (buyerID, addressID, total_Amount, order_Date) VALUES
(11, 1,  550000,  '2025-11-15 08:00:00'),
(12, 2, 2300000,  '2025-11-16 09:30:00'),
(13, 3,  320000,  '2025-11-17 10:15:00'),
(14, 4,  1170000,  '2025-11-18 14:00:00'),
(15, 5,  250000,  '2025-11-19 16:45:00');

-- REVIEW
INSERT INTO REVIEW (buyerID, orderID, productID, rating, comment) VALUES
(11, 1, 1, 5, 'Nghe rất hay'),
(12, 2, 2, 4, 'Dễ dùng'),
(13, 3, 3, 5, 'Áo thoải mái'),
(14, 4, 4, 4, 'Giày êm'),
(15, 5, 5, 5, 'Nội dung hữu ích');

-- PAYMENT
INSERT INTO PAYMENT (orderID, method, trackingCode, statusPayment) VALUES
(1, 'Bank Transfer', 'TRK111', 'SUCCESS'),
(2, 'COD',           'TRK222', 'SUCCESS'),
(3, 'E-Wallet',      'TRK333', 'FAIL'),
(4, 'Bank Transfer', 'TRK444', 'SUCCESS'),
(5, 'COD',           'TRK555', 'FAIL');

-- SHIPPING_CARRIER
INSERT INTO SHIPPING_CARRIER (carrier_Name, contact_Info) VALUES
('GHN', 'hotline@ghn.vn'),
('GHTK', 'cs@ghtk.vn'),
('VNPost', 'support@vnpost.vn'),
('J&T Express', 'cs@jtexpress.vn'),
('Shopee Express', 'help@spx.vn');

-- ORDER_ITEM 

-- ORDER 1
INSERT INTO ORDER_ITEM (orderID, productID, quantity, optionID, status, carrierID, unit_Price, delivered_date, expected_delivered_date, statusPaid) VALUES
(1, 1, 1, 1, 'DELIVERED', 1, 275000, '2025-11-20', '2025-11-20', 'PAID'),
(1, 2, 1, 1, 'DELIVERED', 1, 275000, '2025-11-20', '2025-11-20', 'PAID');

-- ORDER 2
INSERT INTO ORDER_ITEM (orderID, productID, quantity, optionID, status, carrierID, unit_Price, delivered_date, expected_delivered_date, statusPaid) VALUES
(2, 1, 2, 2, 'PENDING', 1, 1150000, NULL, '2025-11-23', 'PAID'),
(2, 2, 2, 2, 'PENDING', 1, 1150000, NULL, '2025-11-23', 'PAID');

-- ORDER 3
INSERT INTO ORDER_ITEM (orderID, productID, quantity, optionID, status, carrierID, unit_Price, delivered_date, expected_delivered_date, statusPaid) VALUES
(3, 1, 3, 1, 'PENDING', 1, 160000, NULL, '2025-11-24', 'UNPAID'),
(3, 2, 3, 1, 'PENDING', 2, 160000, NULL, '2025-11-24', 'UNPAID');

-- ORDER 4
INSERT INTO ORDER_ITEM (orderID, productID, quantity, optionID, status, carrierID, unit_Price, delivered_date, expected_delivered_date, statusPaid) VALUES
(4, 1, 4, 2, 'DELIVERED', 1, 585000, '2025-11-25', '2025-11-26', 'PAID'),
(4, 2, 4, 2, 'DELIVERED', 1, 585000, '2025-11-25', '2025-11-26', 'PAID');

-- ORDER 5
INSERT INTO ORDER_ITEM (orderID, productID, quantity, optionID, status, carrierID, unit_Price, delivered_date, expected_delivered_date, statusPaid) VALUES
(5, 1, 5, 1, 'PENDING', 1, 125000, NULL, '2025-11-27', 'UNPAID'),
(5, 2, 5, 1, 'PENDING', 1, 125000, NULL, '2025-11-27', 'UNPAID');

-- ORDER_VOUCHER (Đầy đủ buyerID)

INSERT INTO ORDER_VOUCHER (orderID, voucherID, date_Applied) VALUES
(1, 2, '2025-09-01'),
(2, 3, '2025-09-05'),
(3, 3, '2025-09-07'),
(4, 4, '2025-09-09'),
(5, 5, '2025-09-10');