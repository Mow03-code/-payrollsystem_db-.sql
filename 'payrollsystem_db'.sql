USE payrollsystem_db;

-- Department Table
CREATE TABLE Department (
    department_id INT IDENTITY(1,1) PRIMARY KEY,
    department_name VARCHAR(50) NOT NULL,
    departmentType_id INT
);

-- Payroll Table
CREATE TABLE Payroll (
    payroll_id INT,
    employee_id INT,
    payPeriod_id INT,
    basic_salary DECIMAL(10,2),
    overtime_pay DECIMAL(10,2),
    holiday_pay DECIMAL(10,2),
    other_earnings DECIMAL(10,2),
    sss_contribution DECIMAL(10,2),
    philhealth DECIMAL(10,2),
    pagibig DECIMAL(10,2),
    tax_withheld DECIMAL(10,2),
    absenses_deduction DECIMAL(10,2),
    loans_deduction DECIMAL(10,2),
    other_deductions DECIMAL(10,2)
);

-- Payroll Benefits
CREATE TABLE Payroll_Benefits (
    payroll_benefit_id INT,
    benefit_id INT,
    payroll_id INT,
    amount DECIMAL(10,2),
    remarks VARCHAR(50)
);

-- Pay period Table
CREATE TABLE Pay_Period (
    payroll_id INT,
    start_date DATE,
    end_date DATE
);

-- Earnings Table
CREATE TABLE Earnings (
    compensation_id INT,
    net_earnings DECIMAL(10,2),
    gross_earnings DECIMAL(10,2)
);

-- Benefits Table
CREATE TABLE Benefits (
    benefit_id INT,
    benefitType_id INT,
    remarks VARCHAR(50)
);

-- Benefit Type Table
CREATE TABLE Benefit_Type (
    benefitType_id INT,
    benefit_name VARCHAR(50),
    description VARCHAR(100),
    isTaxable BOOLEAN,
    calculation_type VARCHAR(30),
    rateValue DECIMAL(10,2)
);

--  Position Table
CREATE TABLE Position (
    position_id INT IDENTITY(1,1) PRIMARY KEY,
    position_name VARCHAR(50) NOT NULL,
    supervisor_id INT,
    manager_id INT,
    assistant_manager_id INT,
    team_lead_id INT
);

--  Status Table (if Full-time, Part-time, Probational)
CREATE TABLE Status (
    status_id INT IDENTITY(1,1) PRIMARY KEY,
    contractual INT,
    preliminary INT,
    regular INT,
    employee_id INT,
    department_id INT,
    position_id INT,
    attendance_id INT,
    status_approval INT
);

-- Employee Details Table
CREATE TABLE Employee (
    employee_id INT PRIMARY KEY,
    last_name VARCHAR(20) NOT NULL,
    first_name VARCHAR(20) NOT NULL,
    birthday DATE NOT NULL,
    gender VARCHAR(10),
    phone_number INT,
    date_hired DATE,
    employment_status VARCHAR(50),
    basic_salary DECIMAL(10,2) NOT NULL CHECK (basic_salary >= 0),
    hourly_rate DECIMAL(10,2) NOT NULL CHECK (hourly_rate >= 0),
    grossSemimonthly_salary DECIMAL(10,2) CHECK (grossSemimonthly_salary >= 0),
    supervisor_id INT,
    
    -- Foreign Key links and relationships
    department_id INT FOREIGN KEY REFERENCES Department(department_id),
    position_id INT FOREIGN KEY REFERENCES Position(position_id),
    status_id INT FOREIGN KEY REFERENCES Status(status_id)
);

-- Attendace Table
CREATE TABLE Attendance (
    attendance_id INT IDENTITY(1,1) PRIMARY KEY,
    employee_id INT NOT NULL FOREIGN KEY REFERENCES Employee(employee_id),
    date DATE NOT NULL,
    time_in TIME NOT NULL,
    time_out TIME NOT NULL,
    shiftType_id INT,
    status_id INT,
    overtime_id INT,
    leave_id INT
);

-- Role Permission Table
CREATE TABLE Role_Permissions (
    rolePermissions_id INT NOT NULL,
    role_id INT,
    permissions_id INT
);

-- User Account Table
CREATE TABLE User_Account (
    user_id INT,
    employee_id INT,
    password VARCHAR(255),
    role_id INT
);

-- Overtime table
CREATE TABLE Overtime (
    overtime_id INT IDENTITY(1,1) PRIMARY KEY,
    employee_id INT NOT NULL FOREIGN KEY REFERENCES Employee(employee_id),
    date DATE NOT NULL,
    hours_worked DECIMAl (10,2) NOT NULL,
    rate_multiplier DECIMAl (10,2) NOT NULL,
    overtime_pay DECIMAl (10,2) NOT NULL,
    reason VARCHAR(100),
    earnings_id INT,
    approval_status VARCHAR(50)
)

-- testing tables
Use payrollsystem_db;
Go

INSERT INTO Employee (employee_id, last_name, first_name, birthday, basic_salary, hourly_rate)
SELECT [Employee], Last_Name, First_Name, Birthday, Basic_Salary, Hourly_Rate
From [MotorPH Employee Data v2];

-- testing attendance table

Use payrollsystem_db;
Go

INSERT INTO Attendance (employee_id, date, time_in, time_out)
SELECT
    [Employee],
    CONVERT(DATE, [Date]),
    CONVERT(TIME, [Log_In]),
    CONVERT(TIME, [Log_Out])
FROM [MotorPH Employee Attendance Records];
Go

SELECT * FROM Attendance;

-- testing Overtime computation
INSERT INTO Attendance (employee_id, date, time_in, time_out)
SELECT
    [Employee],
    