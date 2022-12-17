--creating the products dimension
CREATE TABLE PRODUCTS_DIM (
ProductID NUMBER,
ProductName VARCHAR2(40) NOT NULL,
QuantityPerUnit VARCHAR2(20), 
UnitPrice NUMBER,
constraint products_pk PRIMARY KEY (ProductID) );
INSERT INTO PRODUCTS_DIM (ProductID, ProductName, QuantityPerUnit, 
UnitPrice)
SELECT ProductID, ProductName, QuantityPerUnit, UnitPrice 
FROM NW_PRODUCTS;

--creating the customers dimension
CREATE TABLE CUSTOMERS_DIM (
CustomerID CHAR(5),
CustomerName VARCHAR2(100) NOT NULL,
CustomerCity VARCHAR2(60), 
OldcustomerCity VARCHAR2(60),
constraint customer_pk PRIMARY KEY (CustomerID) );
UPDATE CUSTOMERS_DIM SET OldcustomerCity = CustomerCity;
INSERT INTO CUSTOMERS_DIM (CustomerID, CustomerName, CustomerCity)
SELECT CustomerID, CompanyName, City
FROM NW_CUSTOMERS; 

--creating shippers dimension
CREATE TABLE SHIPPERS_DIM (
ShipperID NUMBER,
CompanyName VARCHAR2(50) NOT NULL,
Phone VARCHAR2(24), 
constraint shippers_pk PRIMARY KEY (ShipperID) );
INSERT INTO SHIPPERS_DIM (ShipperID, CompanyName, Phone)
SELECT ShipperID, CompanyName, Phone
FROM NW_SHIPPERS; 

--creating junk dimesion table
CREATE TABLE JUNK_DIM (
Junk_SK NUMBER GENERATED ALWAYS as IDENTITY(START with 1 INCREMENT by 1),
Discount_IND VARCHAR2(1) DEFAULT 'N',
constraint junk_pk PRIMARY KEY (Junk_SK)
);
ALTER TABLE JUNK_DIM
ADD ( OrderID NUMBER ,
ProductID NUMBER ) ; 
INSERT INTO JUNK_DIM (OrderID, ProductID, Discount_IND)
SELECT od.OrderID, od.ProductID, CASE WHEN od.Discount <> 0 THEN 'Y' ELSE 'N' 
END AS Discount_IND
FROM NW_ORDERDETAILS od; 

--creating the emloyee dimension table
CREATE TABLE EMPLOYEES_DIM (
EmployeeID NUMBER,
EmployeeName VARCHAR2(100),
EmployeeTitle VARCHAR2(30),
EmployeeCity VARCHAR2(15),
constraint employee_pk PRIMARY KEY (EmployeeID)
);
INSERT INTO EMPLOYEES_DIM (EmployeeID, EmployeeName, 
EmployeeTitle, EmployeeCity)
SELECT e.EmployeeID, e.FirstName || ' ' || e.LastName, e.Title, e.City
FROM NW_EMPLOYEES e;

--role-playing dimension
CREATE TABLE TEMP_DATE_DIM (
SDate Date
);
INSERT INTO TEMP_DATE_DIM (SDate)
SELECT OrderDate 
FROM NW_ORDERS;
INSERT INTO TEMP_DATE_DIM (SDate)
SELECT ShippedDate
FROM NW_ORDERS;

CREATE TABLE DATE_DIM (
Date_SK NUMBER GENERATED ALWAYS as IDENTITY(START with 1 
INCREMENT by 1),
SDate Date,
Day_of_week VARCHAR2(15),
Month VARCHAR2(15),
Year INTEGER,
constraint date_pk PRIMARY KEY (date_SK)
);
INSERT INTO DATE_DIM (SDate, Day_of_week, Month, Year)
SELECT DISTINCT SDate, TO_CHAR(SDate,'Dy') as "Day", EXTRACT(month 
FROM SDate) as "Month",EXTRACT(year FROM SDate) as "Year"
FROM TEMP_DATE_DIM 
WHERE SDate is NOT NULL
ORDER BY SDate DESC;

CREATE TABLE TEMP_SALES_FACT as 
SELECT DISTINCT od.ProductID as ProductID, c.CustomerID as 
CustomerID, e.EmployeeID as EmployeeID, s.ShipperID as ShipperID, 
od.OrderID as OrderID, od.Quantity as Quantity, od.Discount as 
Discount,
(od.Quantity*od.UnitPrice - od.Discount) as Billing_amount, 
o.OrderDate as OrderDate, o.ShippedDate as ShippedDate
FROM NW_ORDERDETAILS od JOIN NW_ORDERS o ON 
od.OrderID = o.OrderID
JOIN NW_SHIPPERS s ON s.ShipperID = o.ShipVia
JOIN NW_PRODUCTS p ON od.ProductID = p.ProductID
JOIN NW_CUSTOMERS c ON o.CustomerID = c.CustomerID
JOIN NW_EMPLOYEES e ON e.EmployeeID = o.EmployeeID
ORDER BY OrderDate, ShippedDate, OrderID, ProductID
;

CREATE TABLE PRODUCT_SALES_FACT as 
SELECT pd.ProductID as ProductID, cd.CustomerID as CustomerID, 
ed.EmployeeID as EmployeeID, 
sd.ShipperID as ShipperID, 
td1.Date_SK as Shipping_date_SK, td2.Date_SK as Order_date_SK,
jd.Junk_SK as Junk_SK, 
tsf.OrderID as Order_DD, tsf.Quantity as Quantity, 
tsf.Billing_amount as Billing_amount
FROM TEMP_SALES_FACT tsf JOIN PRODUCTS_DIM pd ON 
tsf.ProductID = pd.ProductID
JOIN CUSTOMERS_DIM cd ON tsf.CustomerID = cd.CustomerID
JOIN EMPLOYEES_DIM ed ON tsf.EmployeeID = ed.EmployeeID
JOIN SHIPPERS_DIM sd ON tsf.ShipperID = sd.ShipperID
LEFT OUTER JOIN JUNK_DIM jd ON (tsf.OrderID = jd.OrderID AND 
tsf.ProductID = jd.ProductID)
LEFT OUTER JOIN DATE_DIM td1 ON tsf.ShippedDate = td1.sdate
LEFT OUTER JOIN DATE_DIM td2 ON tsf.OrderDate = td2.sdate
;

ALTER TABLE PRODUCT_SALES_FACT 
ADD (
Constraint product_fk FOREIGN KEY (ProductID) references PRODUCTS_DIM,
Constraint customer_fk FOREIGN KEY (CustomerID) references CUSTOMERS_DIM,
Constraint shipper_fk FOREIGN KEY (ShipperID) references SHIPPERS_DIM,
Constraint employee_fk FOREIGN KEY (EmployeeID) references EMPLOYEES_DIM,
Constraint junk_fk FOREIGN KEY (Junk_SK) references JUNK_DIM,
Constraint Shipping_date_SK_fk FOREIGN KEY (Shipping_date_SK) references 
DATE_DIM,
Constraint Order_date_SK_fk FOREIGN KEY (Order_date_SK) references DATE_DIM
) ;
ALTER TABLE JUNK_DIM
DROP ( OrderID , ProductID) ;