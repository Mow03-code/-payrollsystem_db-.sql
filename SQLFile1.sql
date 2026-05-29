--Create a table  for Role Permmissions

CREATE TABLE Permissions (
    permission_id           INT PRIMARY KEY,
    permission_name         VARCHAR(100),
    view_payroll            VARCHAR(50),
    edit_payroll            VARCHAR(50),
    process_payroll         VARCHAR(50),
    manage_deduction        VARCHAR(50),
    manage_leave            VARCHAR(50),
    manage_benefits         VARCHAR(50),
    calculate_benefits      VARCHAR(50),
    generate_financial_report VARCHAR(50),
    view_own_payroll        VARCHAR(50)
);

--UserRole Table 
CREATE TABLE Role (
    role_id INT PRIMARY KEY,
    role_name VARCHAR(50)
);

-- Optional: Insert the sample roles
INSERT INTO Role (role_id, role_name)
VALUES
(1, 'admin'),
(2, 'HR'),
(3, 'finance_manager'),
(4, 'employee'),
(5, 'finance_staff');

CREATE TABLE User_Account (
    user_id INT PRIMARY KEY,
    password VARCHAR(255),
    employee_id INT,
    role_id INT,
    FOREIGN KEY (role_id) REFERENCES Role(role_id)

);CREATE TABLE Role_Permissions (
    rolePermissions_id INT PRIMARY KEY,
    role_id INT,
    permissions_id INT,
    FOREIGN KEY (role_id) REFERENCES Role(role_id)
    
);





