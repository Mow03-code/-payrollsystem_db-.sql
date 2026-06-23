
DELETE FROM dbo.Payroll_Benefits;
DELETE FROM dbo.PayrollDeduction;
DELETE FROM dbo.Deductions;
DELETE FROM dbo.Payroll;
DELETE FROM dbo.Attendance;
DELETE FROM dbo.Overtime;
DELETE FROM dbo.Leave_Request;
DELETE FROM dbo.User_Account;
DELETE FROM dbo.Pay_Period;
DELETE FROM dbo.Employee;
GO

DBCC CHECKIDENT ('dbo.Pay_Period', RESEED, 0);
DBCC CHECKIDENT ('dbo.Attendance', RESEED, 0);
DBCC CHECKIDENT ('dbo.Payroll', RESEED, 0);
DBCC CHECKIDENT ('dbo.Payroll_Benefits', RESEED, 0);
GO

-- 2. Reload Employee data
INSERT INTO dbo.Employee (employee_id, last_name, first_name, birthday, basic_salary, hourly_rate)
SELECT Employee_ID, Last_Name, First_Name, Birthday, Basic_Salary, Hourly_Rate
FROM dbo.Employees;
GO

UPDATE dbo.Employee SET position_id = 1, department_id = 1 WHERE employee_id = 10001;
UPDATE dbo.Employee SET position_id = 2, department_id = 1 WHERE employee_id <> 10001;
GO

-- 3. Reload Attendance
INSERT INTO dbo.Attendance (employee_id, [date], time_in, time_out)
SELECT [Employee], [Date], [Log_In], [Log_Out]
FROM dbo.[MotorPH Employee Attendance Records]
WHERE [Date] IS NOT NULL;
GO

-- 4. Generate Pay Periods covering actual data range:
--    June 2024 - Dec 2024, and Jan 2026 - June 2026
DECLARE @Year INT, @Month INT, @StartDate DATE, @EndDate DATE;

SET @Year = 2024;
SET @Month = 6;
WHILE @Month <= 12
BEGIN
    SET @StartDate = DATEFROMPARTS(@Year, @Month, 1);
    SET @EndDate = DATEFROMPARTS(@Year, @Month, 15);
    INSERT INTO dbo.Pay_Period (start_date, end_date) VALUES (@StartDate, @EndDate);

    SET @StartDate = DATEFROMPARTS(@Year, @Month, 16);
    SET @EndDate = EOMONTH(@StartDate);
    INSERT INTO dbo.Pay_Period (start_date, end_date) VALUES (@StartDate, @EndDate);

    SET @Month = @Month + 1;
END;

SET @Year = 2026;
SET @Month = 1;
WHILE @Month <= 6
BEGIN
    SET @StartDate = DATEFROMPARTS(@Year, @Month, 1);
    SET @EndDate = DATEFROMPARTS(@Year, @Month, 15);
    INSERT INTO dbo.Pay_Period (start_date, end_date) VALUES (@StartDate, @EndDate);

    SET @StartDate = DATEFROMPARTS(@Year, @Month, 16);
    SET @EndDate = EOMONTH(@StartDate);
    INSERT INTO dbo.Pay_Period (start_date, end_date) VALUES (@StartDate, @EndDate);

    SET @Month = @Month + 1;
END;
GO

-- 5. Ensure Benefit_Type / Benefits are seeded
IF NOT EXISTS (SELECT 1 FROM dbo.Benefit_Type)
BEGIN
    INSERT INTO dbo.Benefit_Type (benefit_name, description, isTaxable, calculation_type, rateValue)
    VALUES
    ('Rice Subsidy', 'Monthly rice allowance', 0, 'Fixed', 0.00),
    ('Phone Allowance', 'Monthly phone/communication allowance', 0, 'Fixed', 0.00),
    ('Clothing Allowance', 'Annual clothing allowance, prorated monthly', 0, 'Fixed', 0.00);
END;

IF NOT EXISTS (SELECT 1 FROM dbo.Benefits)
BEGIN
    INSERT INTO dbo.Benefits (benefitType_id, remarks)
    SELECT benefitType_id, NULL FROM dbo.Benefit_Type;
END;
GO

-- 6. Calculate Payroll for ALL employees x ALL pay periods
INSERT INTO dbo.Payroll (
    employee_id, payPeriod_id, basic_salary, overtime_pay, holiday_pay, other_earnings,
    sss_contribution, philhealth, pagibig, tax_withheld,
    absences_deduction, loans_deduction, other_deductions
)
SELECT 
    e.employee_id,
    pp.payPeriod_id,
    ROUND(e.basic_salary, 2),
    ISNULL(ot.total_ot_pay, 0.00),
    ROUND(
        ISNULL(att.regular_holiday_hours, 0.00) * e.hourly_rate * 1.00
        + ISNULL(att.special_holiday_hours, 0.00) * e.hourly_rate * 0.30,
    2),
    0.00,
    ROUND(dbo.fn_GetSSSContribution(e.basic_salary), 2),
    ROUND(dbo.fn_GetPhilHealthContribution(e.basic_salary), 2),
    ROUND(dbo.fn_GetPagibigContribution(e.basic_salary), 2),
    dbo.fn_ComputeWithholdingTax(
        (ROUND(ISNULL(att.total_hours_worked, 0.00) * e.hourly_rate, 2)
            + ISNULL(ot.total_ot_pay, 0.00)
            + ROUND(ISNULL(att.regular_holiday_hours, 0.00) * e.hourly_rate * 1.00 + ISNULL(att.special_holiday_hours, 0.00) * e.hourly_rate * 0.30, 2))
        - (ROUND(dbo.fn_GetSSSContribution(e.basic_salary), 2) + ROUND(dbo.fn_GetPhilHealthContribution(e.basic_salary), 2) + ROUND(dbo.fn_GetPagibigContribution(e.basic_salary), 2))
    ),
    0.00, 0.00, 0.00
FROM dbo.Employee e
CROSS JOIN dbo.Pay_Period pp
LEFT JOIN (
    SELECT 
        pp_sub.payPeriod_id,
        CAST(raw_att.Employee AS INT) AS employee_id,
        COUNT(DISTINCT raw_att.[Date]) AS days_worked,
        SUM(ISNULL(DATEDIFF(MINUTE, raw_att.Log_In, raw_att.Log_Out) / 60.0 - 1.0, 0)) AS total_hours_worked,
        SUM(CASE WHEN h_sub.holiday_type = 'Regular Holiday' THEN (DATEDIFF(MINUTE, raw_att.Log_In, raw_att.Log_Out) / 60.0 - 1.0) ELSE 0.0 END) AS regular_holiday_hours,
        SUM(CASE WHEN h_sub.holiday_type = 'Special Non-Working' THEN (DATEDIFF(MINUTE, raw_att.Log_In, raw_att.Log_Out) / 60.0 - 1.0) ELSE 0.0 END) AS special_holiday_hours
    FROM dbo.[MotorPH Employee Attendance Records] raw_att
    JOIN dbo.Pay_Period pp_sub ON raw_att.[Date] BETWEEN pp_sub.start_date AND pp_sub.end_date
    LEFT JOIN dbo.HolidayLookup h_sub ON raw_att.[Date] = h_sub.holiday_date
    GROUP BY pp_sub.payPeriod_id, raw_att.Employee
) att ON e.employee_id = att.employee_id AND pp.payPeriod_id = att.payPeriod_id
LEFT JOIN (
    SELECT o.employee_id, pp_ot.payPeriod_id, SUM(o.overtime_pay) AS total_ot_pay
    FROM dbo.Overtime o
    JOIN dbo.Pay_Period pp_ot ON o.[date] BETWEEN pp_ot.start_date AND pp_ot.end_date
    WHERE o.approval_status = 'Approved'
    GROUP BY o.employee_id, pp_ot.payPeriod_id
) ot ON e.employee_id = ot.employee_id AND pp.payPeriod_id = ot.payPeriod_id;
GO

-- 7. Populate Payroll_Benefits using real per-employee values
INSERT INTO dbo.Payroll_Benefits (benefit_id, payroll_id, amount, remarks)
SELECT 
    b.benefit_id,
    pr.payroll_id,
    CASE bt.benefit_name
        WHEN 'Rice Subsidy' THEN emp.Rice_Subsidy / 2.0
        WHEN 'Phone Allowance' THEN emp.Phone_Allowance / 2.0
        WHEN 'Clothing Allowance' THEN emp.Clothing_Allowance / 2.0
    END,
    NULL
FROM dbo.Payroll pr
JOIN dbo.Employees emp ON pr.employee_id = emp.Employee_ID
CROSS JOIN dbo.Benefits b
JOIN dbo.Benefit_Type bt ON b.benefitType_id = bt.benefitType_id;
GO

-- 8. Rebuild the payslip view
CREATE OR ALTER VIEW dbo.v_EmployeePayslipReport AS
SELECT
    pr.payroll_id,
    e.employee_id,
    CONCAT(e.last_name, ', ', e.first_name) AS employee_full_name,
    p.position_name,
    d.department_name,
    pp.payPeriod_id,
    pp.start_date AS period_start_date,
    pp.end_date AS period_end_date,
    FORMAT(pr.basic_salary, 'C', 'en-PH') AS MonthlyBasic_Rate, 
    FORMAT(e.hourly_rate, 'C', 'en-PH') AS hourly_rate,
    CAST(ROUND(ISNULL(att.total_hours_worked, 0.00), 2) AS DECIMAL(10,2)) AS hours_worked,
    ISNULL(att.days_worked, 0) AS days_worked, 
    FORMAT(ROUND(ISNULL(att.total_hours_worked, 0.00) * e.hourly_rate, 2), 'C', 'en-PH') AS basic_earned_pay,
    FORMAT(pr.overtime_pay, 'C', 'en-PH') AS overtime_pay,
    FORMAT(pr.holiday_pay, 'C', 'en-PH') AS holiday_pay,
    FORMAT(pr.other_earnings, 'C', 'en-PH') AS other_earnings,
    FORMAT((ROUND(ISNULL(att.total_hours_worked, 0.00) * e.hourly_rate, 2) + pr.overtime_pay + pr.holiday_pay + pr.other_earnings), 'C', 'en-PH') AS total_gross_earnings,
    FORMAT(ISNULL(pb.rice_subsidy, 0.00), 'C', 'en-PH') AS rice_subsidy,
    FORMAT(ISNULL(pb.phone_allowance, 0.00), 'C', 'en-PH') AS phone_allowance,
    FORMAT(ISNULL(pb.clothing_allowance, 0.00), 'C', 'en-PH') AS clothing_allowance,
    FORMAT(ISNULL(pb.total_benefits, 0.00), 'C', 'en-PH') AS total_benefits,
    FORMAT(pr.sss_contribution, 'C', 'en-PH') AS sss_deduction,
    FORMAT(pr.philhealth, 'C', 'en-PH') AS philhealth_deduction,
    FORMAT(pr.pagibig, 'C', 'en-PH') AS pagibig_deduction,
    FORMAT(pr.absences_deduction, 'C', 'en-PH') AS absences_deduction,
    FORMAT(pr.loans_deduction, 'C', 'en-PH') AS loans_deduction,
    FORMAT(pr.other_deductions, 'C', 'en-PH') AS other_deductions,
    FORMAT((pr.sss_contribution + pr.philhealth + pr.pagibig + pr.absences_deduction + pr.loans_deduction + pr.other_deductions), 'C', 'en-PH') AS total_deductions,
    FORMAT(pr.tax_withheld, 'C', 'en-PH') AS withholding_tax,
    FORMAT(
        ((ROUND(ISNULL(att.total_hours_worked, 0.00) * e.hourly_rate, 2) + pr.overtime_pay + pr.holiday_pay + pr.other_earnings)
        + ISNULL(pb.total_benefits, 0.00)
        - (pr.sss_contribution + pr.philhealth + pr.pagibig + pr.absences_deduction + pr.loans_deduction + pr.other_deductions + pr.tax_withheld)),
    'C', 'en-PH') AS net_pay
FROM dbo.Payroll pr
JOIN dbo.Employee e ON pr.employee_id = e.employee_id
JOIN dbo.Pay_Period pp ON pr.payPeriod_id = pp.payPeriod_id
LEFT JOIN dbo.Position p ON e.position_id = p.position_id
LEFT JOIN dbo.Department d ON e.department_id = d.department_id
LEFT JOIN (
    SELECT 
        pp_sub.payPeriod_id,
        CAST(raw_att.Employee AS INT) AS employee_id,
        COUNT(DISTINCT raw_att.[Date]) AS days_worked,
        SUM(ISNULL(DATEDIFF(MINUTE, raw_att.Log_In, raw_att.Log_Out) / 60.0 - 1.0, 0)) AS total_hours_worked
    FROM dbo.[MotorPH Employee Attendance Records] raw_att
    JOIN dbo.Pay_Period pp_sub ON raw_att.[Date] BETWEEN pp_sub.start_date AND pp_sub.end_date
    GROUP BY pp_sub.payPeriod_id, raw_att.Employee
) att ON e.employee_id = att.employee_id AND pp.payPeriod_id = att.payPeriod_id
LEFT JOIN (
    SELECT 
        pb.payroll_id,
        SUM(CASE WHEN bt.benefit_name = 'Rice Subsidy' THEN pb.amount ELSE 0 END) AS rice_subsidy,
        SUM(CASE WHEN bt.benefit_name = 'Phone Allowance' THEN pb.amount ELSE 0 END) AS phone_allowance,
        SUM(CASE WHEN bt.benefit_name = 'Clothing Allowance' THEN pb.amount ELSE 0 END) AS clothing_allowance,
        SUM(pb.amount) AS total_benefits
    FROM dbo.Payroll_Benefits pb
    JOIN dbo.Benefits b ON pb.benefit_id = b.benefit_id
    JOIN dbo.Benefit_Type bt ON b.benefitType_id = bt.benefitType_id
    GROUP BY pb.payroll_id
) pb ON pr.payroll_id = pb.payroll_id;
GO

-- 9. May 2026 payslips
SELECT * FROM dbo.v_EmployeePayslipReport
WHERE period_start_date >= '2026-05-01' AND period_end_date <= '2026-05-31'
ORDER BY employee_id, period_start_date;