
USE payrollsystem_db;
GO


IF OBJECT_ID('dbo.vw_EmployeePayslip', 'V') IS NOT NULL
    DROP VIEW dbo.vw_EmployeePayslip;
GO

CREATE VIEW dbo.vw_EmployeePayslip AS

-- Benefits
WITH BenefitSummary AS (
    SELECT
        pb.payroll_id,
        SUM(CASE WHEN bt.benefit_name = 'Rice Subsidy'       THEN pb.amount ELSE 0 END) AS rice_subsidy,
        SUM(CASE WHEN bt.benefit_name = 'Phone Allowance'    THEN pb.amount ELSE 0 END) AS phone_allowance,
        SUM(CASE WHEN bt.benefit_name = 'Clothing Allowance' THEN pb.amount ELSE 0 END) AS clothing_allowance,
        SUM(pb.amount)                                                                    AS total_benefits
    FROM Payroll_Benefits  pb
    JOIN Benefits          b   ON pb.benefit_id    = b.benefit_id
    JOIN Benefit_Type      bt  ON b.benefitType_id = bt.benefitType_id
    GROUP BY pb.payroll_id
),

-- Attendance
AttendanceSummary AS (
    SELECT
        a.employee_id,
        pp.payPeriod_id,
        COUNT(DISTINCT a.date) AS days_worked
    FROM Attendance a
    JOIN Pay_Period pp ON a.date BETWEEN pp.start_date AND pp.end_date
    GROUP BY a.employee_id, pp.payPeriod_id
),

--Overtime
OvertimeSummary AS (
    SELECT
        o.employee_id,
        pp.payPeriod_id,
        SUM(o.overtime_pay) AS total_overtime_pay
    FROM Overtime   o
    JOIN Pay_Period pp ON o.date BETWEEN pp.start_date AND pp.end_date
    WHERE o.approval_status = 'Approved'
    GROUP BY o.employee_id, pp.payPeriod_id
)

--
SELECT

    -- PAYSLIP HEADER
    CAST(e.employee_id AS VARCHAR(10))
        + '-' + CONVERT(VARCHAR(10), pp.end_date, 120)              AS payslip_no,

    e.employee_id                                                    AS employee_id,
    pp.payPeriod_id                                                  AS payPeriod_id,
    pp.start_date                                                    AS period_start_date,
    pp.end_date                                                      AS period_end_date,

    -- EMPLOYEE INFORMATION
    e.last_name + ', ' + e.first_name                               AS employee_name,
    pos.position_name                                                AS employee_position,
    dept.department_name                                             AS department,

    -- EARNINGS
    e.basic_salary                                                   AS monthly_salary,
    ROUND(e.basic_salary / 20.0, 2)                                 AS daily_rate,
    COALESCE(att.days_worked,        0)                             AS days_worked,
    COALESCE(ot.total_overtime_pay,  0)                             AS overtime_pay,

    ROUND(
        (e.basic_salary / 20.0) * COALESCE(att.days_worked, 0)
        + COALESCE(ot.total_overtime_pay, 0),
    2)                                                               AS gross_income,

    -- BENEFITS
    COALESCE(bs.rice_subsidy,        0)                             AS rice_subsidy,
    COALESCE(bs.phone_allowance,     0)                             AS phone_allowance,
    COALESCE(bs.clothing_allowance,  0)                             AS clothing_allowance,
    COALESCE(bs.total_benefits,      0)                             AS total_benefits,

    -- DEDUCTIONS
    COALESCE(pr.sss_contribution,    0)                             AS sss_contribution,
    COALESCE(pr.philhealth,          0)                             AS philhealth_contribution,
    COALESCE(pr.pagibig,             0)                             AS pagibig_contribution,
    COALESCE(pr.tax_withheld,        0)                             AS withholding_tax,
    COALESCE(pr.absenses_deduction,  0)                             AS absences_deduction,
    COALESCE(pr.loans_deduction,     0)                             AS loans_deduction,
    COALESCE(pr.other_deductions,    0)                             AS other_deductions,

    ROUND(
        COALESCE(pr.sss_contribution,   0)
      + COALESCE(pr.philhealth,         0)
      + COALESCE(pr.pagibig,            0)
      + COALESCE(pr.tax_withheld,       0)
      + COALESCE(pr.absenses_deduction, 0)
      + COALESCE(pr.loans_deduction,    0)
      + COALESCE(pr.other_deductions,   0),
    2)                                                               AS total_deductions,

    -- SUMMARY: TAKE-HOME PAY
    ROUND(
        (
            (e.basic_salary / 20.0) * COALESCE(att.days_worked, 0)
            + COALESCE(ot.total_overtime_pay, 0)
        )
        + COALESCE(bs.total_benefits, 0)
        - (
            COALESCE(pr.sss_contribution,   0)
          + COALESCE(pr.philhealth,         0)
          + COALESCE(pr.pagibig,            0)
          + COALESCE(pr.tax_withheld,       0)
          + COALESCE(pr.absenses_deduction, 0)
          + COALESCE(pr.loans_deduction,    0)
          + COALESCE(pr.other_deductions,   0)
        ),
    2)                                                               AS take_home_pay

FROM Payroll             pr
JOIN Employee            e    ON pr.employee_id   = e.employee_id
JOIN Pay_Period          pp   ON pr.payPeriod_id  = pp.payPeriod_id
LEFT JOIN Position       pos  ON e.position_id    = pos.position_id
LEFT JOIN Department     dept ON e.department_id  = dept.department_id
LEFT JOIN BenefitSummary bs   ON pr.payroll_id    = bs.payroll_id
LEFT JOIN AttendanceSummary att
    ON  att.employee_id  = e.employee_id
    AND att.payPeriod_id = pp.payPeriod_id
LEFT JOIN OvertimeSummary ot
    ON  ot.employee_id   = e.employee_id
    AND ot.payPeriod_id  = pp.payPeriod_id;

GO
