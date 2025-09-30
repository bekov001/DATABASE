DROP DATABASE IF EXISTS advanced_Lab;

-- Task 1: Create database called 'advanced_Lab'
CREATE DATABASE advanced_Lab;

-- Connect to the newly created database
\c advanced_Lab;

-- Task 1: Create table 'employees'
CREATE TABLE employees (
    emp_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    department VARCHAR(50) DEFAULT 'Unassigned',
    salary NUMERIC(10, 2) DEFAULT 40000.00,
    hire_date DATE,
    status VARCHAR(20) DEFAULT 'Active'
);

-- Task 1: Create table 'departments'
CREATE TABLE departments (
    dept_id SERIAL PRIMARY KEY,
    dept_name VARCHAR(50) UNIQUE NOT NULL,
    budget NUMERIC(12, 2),
    manager_id INT
);

-- Task 1: Create table 'projects'
CREATE TABLE projects (
    project_id SERIAL PRIMARY KEY,
    project_name VARCHAR(100) NOT NULL,
    dept_id INT REFERENCES departments(dept_id),
    start_date DATE,
    end_date DATE,
    budget NUMERIC(12, 2)
);

-- Insert Sample Data for Testing

INSERT INTO departments (dept_name, budget, manager_id) VALUES
('IT', 150000, 1),
('Sales', 120000, 2),
('HR', 80000, 3),
('Finance', 200000, NULL),
('Marketing', 95000, NULL);

INSERT INTO employees (first_name, last_name, department, salary, hire_date, status) VALUES
('John', 'Smith', 'IT', 75000, '2019-08-01', 'Active'),
('Jane', 'Doe', 'Sales', 85000, '2018-05-15', 'Active'),
('Peter', 'Jones', 'IT', 95000, '2017-03-12', 'Senior'),
('Mary', 'Williams', 'HR', 60000, '2021-11-20', 'Active'),
('David', 'Brown', 'Sales', 62000, '2022-01-10', 'Active'),
('Emily', 'Davis', 'IT', 58000, '2023-06-05', 'Active'),
('Michael', 'Miller', 'Finance', 120000, '2016-02-28', 'Senior'),
('Sarah', 'Wilson', 'HR', 38000, '2023-08-14', 'Terminated'),
('Chris', 'Taylor', 'Sales', 55000, '2021-09-01', 'Promoted'),
('Jessica', 'Moore', 'Finance', 110000, '2019-07-22', 'Active'),
('Robert', 'White', 'Marketing', 39000, '2024-01-05', 'Active');

INSERT INTO projects (project_name, dept_id, start_date, end_date, budget) VALUES
('Alpha System Upgrade', 1, '2022-06-01', '2022-12-31', 75000),
('Beta CRM Rollout', 2, '2023-02-01', '2023-08-31', 60000),
('Gamma HR Portal', 3, '2023-03-15', '2023-09-30', 40000);

-- Part B: Advanced INSERT Operations

-- Task 2: INSERT with column specification
INSERT INTO employees (first_name, last_name, department)
VALUES ('Kevin', 'Harris', 'IT');

-- Task 3: INSERT with DEFAULT values
-- This insert relies on the DEFAULT values for 'salary' and 'status'
INSERT INTO employees (first_name, last_name, department, hire_date)
VALUES ('Laura', 'Clark', 'HR', '2024-02-15');

-- Task 4: INSERT multiple rows in single statement
INSERT INTO departments (dept_name, budget) VALUES
('Legal', 70000),
('Support', 65000),
('Research', 180000);

-- Task 5: INSERT with expressions
INSERT INTO employees (first_name, last_name, hire_date, salary)
VALUES ('Brian', 'Lewis', CURRENT_DATE, 50000 * 1.1);

-- Task 6: INSERT from SELECT (subquery)
-- Create a temporary table and insert IT employees into it
CREATE TABLE temp_employees AS
SELECT * FROM employees WHERE 1=0; -- Creates the table structure without data

INSERT INTO temp_employees
SELECT * FROM employees WHERE department = 'IT';

-- Part C: Complex UPDATE Operations

-- Task 7: UPDATE with arithmetic expressions
-- Increase all employee salaries by 10%
UPDATE employees
SET salary = salary * 1.10;

-- Task 8: UPDATE with WHERE clause and multiple conditions
-- Update status for high-earning, long-term employees
UPDATE employees
SET status = 'Senior'
WHERE salary > 60000 AND hire_date < '2020-01-01';

-- Task 9: UPDATE using CASE expression
-- Re-categorize department based on salary tiers
UPDATE employees
SET department = CASE
    WHEN salary > 80000 THEN 'Management'
    WHEN salary BETWEEN 50000 AND 80000 THEN 'Senior'
    ELSE 'Junior'
END;

-- Task 10
-- Set department to its default value for employees with status 'Inactive'
-- First, let's create an 'Inactive' employee to test this
INSERT INTO employees (first_name, last_name, status) VALUES ('Inactive', 'User', 'Inactive');
UPDATE employees
SET department = DEFAULT
WHERE status = 'Inactive';

-- Task 11: UPDATE with subquery
-- Update department budget to be 20% higher than the average salary of its employees
UPDATE departments d
SET budget = (
    SELECT AVG(e.salary) * 1.20
    FROM employees e
    WHERE e.department = d.dept_name
)
WHERE d.dept_name IN (SELECT DISTINCT department FROM employees);

-- Task 12: UPDATE multiple columns
-- Promote employees in the 'Sales' department
UPDATE employees
SET salary = salary * 1.15, status = 'Promoted'
WHERE department = 'Sales';

-- Part D: Advanced DELETE Operations

-- Task 13: DELETE with simple WHERE condition
DELETE FROM employees
WHERE status = 'Terminated';

-- Task 14: DELETE with complex WHERE clause
-- First, add a record that matches this condition to demonstrate the DELETE
INSERT INTO employees (first_name, last_name, salary, hire_date, department)
VALUES ('Temp', 'Worker', 35000, '2023-02-01', NULL);
DELETE FROM employees
WHERE salary < 40000 AND hire_date > '2023-01-01' AND department IS NULL;

-- Task 15: DELETE with subquery
-- Delete departments that have no employees
DELETE FROM departments
WHERE dept_name NOT IN (SELECT DISTINCT department FROM employees WHERE department IS NOT NULL);

-- Task 16: DELETE with RETURNING clause
-- Delete old projects and return the data of the deleted rows
DELETE FROM projects
WHERE end_date < '2023-01-01'
RETURNING *;

-- Part E: Operations with NULL Values

-- Task 17: INSERT with NULL values
INSERT INTO employees (first_name, last_name, salary, department)
VALUES ('Unknown', 'Employee', NULL, NULL);

-- Task 18: UPDATE NULL handling
UPDATE employees
SET department = 'Unassigned'
WHERE department IS NULL;

-- Task 19: DELETE with NULL conditions
DELETE FROM employees
WHERE salary IS NULL OR department IS NULL;

-- Part F: RETURNING Clause Operations

-- Task 20: INSERT with RETURNING
INSERT INTO employees (first_name, last_name, department, salary, hire_date)
VALUES ('Nancy', 'Green', 'Marketing', 68000, '2022-08-08')
RETURNING emp_id, first_name || ' ' || last_name AS full_name;

-- Task 21: UPDATE with RETURNING
UPDATE employees
SET salary = salary + 5000
WHERE department = 'IT'
RETURNING emp_id, salary - 5000 AS old_salary, salary AS new_salary;

-- Task 22: DELETE with RETURNING all columns
DELETE FROM employees
WHERE hire_date < '2020-01-01'
RETURNING *;

-- Part G: Advanced DML Patterns

-- Task 23: Conditional INSERT
-- This query will only insert 'Paul' 'Allen' if he doesn't already exist.
INSERT INTO employees (first_name, last_name, department, salary)
SELECT 'Paul', 'Allen', 'IT', 250000
WHERE NOT EXISTS (
    SELECT 1 FROM employees WHERE first_name = 'Paul' AND last_name = 'Allen'
);

-- Task 24: UPDATE with JOIN logic using subqueries
-- Increase salary based on the budget of the employee's department
UPDATE employees e
SET salary = salary * CASE
    WHEN (SELECT budget FROM departments d WHERE d.dept_name = e.department) > 100000 THEN 1.10
    ELSE 1.05
END
WHERE e.department IN (SELECT dept_name FROM departments);

-- Task 25: Bulk operations
-- Step 1: Insert 5 employees in a single statement
INSERT INTO employees (first_name, last_name, department, salary) VALUES
('Bulk', 'One', 'Support', 45000),
('Bulk', 'Two', 'Support', 45000),
('Bulk', 'Three', 'Support', 45000),
('Bulk', 'Four', 'Support', 45000),
('Bulk', 'Five', 'Support', 45000);

-- Step 2: Update all their salaries in a single statement
UPDATE employees
SET salary = salary * 1.10
WHERE first_name = 'Bulk';

-- Task 26: Data migration simulation
-- Step 1: Create the archive table
CREATE TABLE employee_archive (
    emp_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    department VARCHAR(50),
    salary NUMERIC(10, 2),
    hire_date DATE,
    status VARCHAR(20),
    archived_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Let's make a few employees 'Inactive' for the migration
UPDATE employees SET status = 'Inactive' WHERE first_name = 'Bulk';

-- Step 2: Move data and then delete, using a transaction for safety
BEGIN;

-- Insert inactive employees into the archive table
INSERT INTO employee_archive (emp_id, first_name, last_name, department, salary, hire_date, status)
SELECT emp_id, first_name, last_name, department, salary, hire_date, status
FROM employees
WHERE status = 'Inactive';

-- Delete the moved employees from the original table
DELETE FROM employees
WHERE status = 'Inactive';

COMMIT;

-- Task 27: Complex business logic
-- Extend project end dates for well-staffed, high-budget projects
UPDATE projects p
SET end_date = end_date + INTERVAL '30 days'
WHERE p.budget > 50000 AND (
    SELECT COUNT(e.emp_id)
    FROM employees e
    JOIN departments d ON e.department = d.dept_name
    WHERE d.dept_id = p.dept_id
) > 3;


