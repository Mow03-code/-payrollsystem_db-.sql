-- Deduction Type Table
CREATE TABLE DeductionType (
    deductionType_id    INT             IDENTITY(1,1) PRIMARY KEY,
    type_name           VARCHAR(50)     NOT NULL,
    isMandatory         BOOLEAN         NOT NULL DEFAULT FALSE,
    calculation_type    VARCHAR(30)     NOT NULL,
    rate_or_formula     DECIMAL(10,2)   NULL
);

-- TaxBracket Table
CREATE TABLE TaxBracket (
    bracket_id          INT             IDENTITY(1,1) PRIMARY KEY,
    taxable_income_min  DECIMAL(10,2)   NOT NULL,
    taxable_income_max  DECIMAL(10,2)   NOT NULL,
    base_tax            DECIMAL(10,2)   NOT NULL,
    excess_rate         DECIMAL(10,2)   NOT NULL,
    is_active           BOOLEAN         NOT NULL DEFAULT TRUE
);

-- Deductions Table
CREATE TABLE Deductions (
    deduction_id        INT             IDENTITY(1,1) PRIMARY KEY,
    payroll_id          INT             NOT NULL,
    deductionType_id    INT             NOT NULL,
    pagbig              DECIMAL(10,2)   NOT NULL DEFAULT 0.00,
    amount              DECIMAL(10,2)   NOT NULL,
    remarks             VARCHAR(100)    NULL
);

-- PayrollDeduction Table
CREATE TABLE PayrollDeduction (
    payroll_deduction_id    INT             IDENTITY(1,1) PRIMARY KEY,
    payroll_id              INT             NOT NULL,
    deduction_id            INT             NOT NULL,
    amount                  DECIMAL(10,2)   NOT NULL,
    remarks                 VARCHAR(100)    NULL
);
