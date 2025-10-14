-- PART A
-- 1
CREATE DATABASE advanced_Lab;
\c advanced_Lab;

CREATE TABLE employees (
    emp_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    department VARCHAR(50),
    salary INT DEFAULT 40000,
    hire_date DATE,
    status VARCHAR(20) DEFAULT 'Active'
);

CREATE TABLE departments (
    dept_id SERIAL PRIMARY KEY,
    dept_name VARCHAR(50) UNIQUE,
    budget INT,
    manager_id INT
);

CREATE TABLE projects (
    project_id SERIAL PRIMARY KEY,
    project_name VARCHAR(100),
    dept_id INT,
    start_date DATE,
    end_date DATE,
    budget INT
);

-- Sample Data Insertion for testing
INSERT INTO departments (dept_name, budget, manager_id) VALUES
('IT', 150000, 1), ('Sales', 120000, 2), ('HR', 80000, 3), ('Management', 250000, 4);

INSERT INTO employees (first_name, last_name, department, salary, hire_date, status) VALUES
('John', 'Doe', 'IT', 90000, '2019-06-15', 'Active'),
('Jane', 'Smith', 'IT', 65000, '2021-08-22', 'Active'),
('Peter', 'Jones', 'Sales', 75000, '2019-11-30', 'Promoted'),
('Mary', 'Williams', 'Sales', 62000, '2023-02-10', 'Active'),
('David', 'Brown', 'HR', 55000, '2022-05-18', 'Active'),
('Sue', 'Storm', 'HR', 38000, '2025-01-05', 'Active'),
('Tom', 'Thumb', 'IT', 45000, '2023-09-01', 'Inactive'),
('Clark', 'Kent', 'Management', 120000, '2018-01-01', 'Senior'),
('Bruce', 'Wayne', 'Management', 200000, '2017-05-20', 'Senior'),
('Diana', 'Prince', 'HR', null, '2025-03-01', 'Active'),
('Barry', 'Allen', null, 50000, '2025-04-10', 'Active'),
('Hal', 'Jordan', 'HR', 35000, '2022-03-03', 'Terminated');

INSERT INTO projects (project_name, dept_id, start_date, end_date, budget) VALUES
('Project Alpha', 1, '2022-01-10', '2022-12-15', 80000),
('Project Beta', 2, '2023-03-01', '2023-09-30', 60000),
('Project Gamma', 1, '2025-02-20', '2025-08-20', 120000);


-- PART B
-- 2
INSERT INTO employees (first_name, last_name, department)
VALUES ('Alice', 'Wonder', 'IT');

-- 3
INSERT INTO employees (first_name, last_name, hire_date)
VALUES ('Bob', 'Builder', '2025-10-15');

-- 4
INSERT INTO departments (dept_name, budget, manager_id) VALUES
('Marketing', 95000, 5),
('Finance', 200000, 6),
('Operations', 180000, 7);

-- 5
INSERT INTO employees (first_name, last_name, hire_date, salary)
VALUES ('Charlie', 'Chaplin', CURRENT_DATE, 50000 * 1.1);

-- 6
CREATE TABLE temp_employees AS
TABLE employees
WITH NO DATA;

INSERT INTO temp_employees
SELECT * FROM employees WHERE department = 'IT';


-- PART C
-- 7
UPDATE employees SET salary = salary * 1.10;

-- 8
UPDATE employees
SET status = 'Senior'
WHERE salary > 60000 AND hire_date < '2020-01-01';

-- 9
UPDATE employees
SET department = CASE
    WHEN salary > 80000 THEN 'Management'
    WHEN salary BETWEEN 50000 AND 80000 THEN 'Senior Staff'
    ELSE 'Junior Staff'
END;

-- 10
ALTER TABLE employees ALTER COLUMN department SET DEFAULT 'Unassigned';
UPDATE employees
SET department = DEFAULT
WHERE status = 'Inactive';

-- 11
UPDATE departments d
SET budget = (SELECT AVG(e.salary) * 1.2 FROM employees e WHERE e.department = d.dept_name)
WHERE EXISTS (SELECT 1 FROM employees e WHERE e.department = d.dept_name);

-- 12
UPDATE employees
SET salary = salary * 1.15, status = 'Promoted'
WHERE department = 'Sales';


-- PART D
-- 13
DELETE FROM employees WHERE status = 'Terminated';

-- 14
DELETE FROM employees
WHERE salary < 40000 AND hire_date > '2023-01-01' AND department IS NULL;

-- 15
DELETE FROM departments
WHERE dept_name NOT IN (SELECT DISTINCT department FROM employees WHERE department IS NOT NULL);

-- 16
DELETE FROM projects
WHERE end_date < '2023-01-01'
RETURNING *;


-- PART E
-- 17
INSERT INTO employees (first_name, last_name, salary, department, hire_date)
VALUES ('Mystery', 'Man', NULL, NULL, '2025-01-01');

-- 18
UPDATE employees
SET department = 'Unassigned'
WHERE department IS NULL;

-- 19
DELETE FROM employees
WHERE salary IS NULL OR department IS NULL;


-- PART F
-- 20
INSERT INTO employees (first_name, last_name, department, salary, hire_date)
VALUES ('Will', 'Turner', 'Sales', 58000, '2025-05-05')
RETURNING emp_id, first_name || ' ' || last_name AS full_name;

-- 21
UPDATE employees
SET salary = salary + 5000
WHERE department = 'IT'
RETURNING emp_id, salary - 5000 AS old_salary, salary AS new_salary;

-- 22
DELETE FROM employees
WHERE hire_date < '2020-01-01'
RETURNING *;


-- PART G
-- 23
INSERT INTO employees (first_name, last_name, department, salary, hire_date)
SELECT 'John', 'Doe', 'IT', 70000, '2025-10-15'
WHERE NOT EXISTS (
    SELECT 1 FROM employees WHERE first_name = 'John' AND last_name = 'Doe'
);

-- 24
UPDATE employees e
SET salary =
    CASE
        WHEN (SELECT d.budget FROM departments d WHERE d.dept_name = e.department) > 100000 THEN salary * 1.10
        ELSE salary * 1.05
    END
WHERE e.department IN (SELECT d.dept_name FROM departments d);

-- 25
INSERT INTO employees (first_name, last_name, department) VALUES
('Bulk', 'One', 'Operations'),
('Bulk', 'Two', 'Operations'),
('Bulk', 'Three', 'Operations'),
('Bulk', 'Four', 'Operations'),
('Bulk', 'Five', 'Operations');

UPDATE employees
SET salary = salary * 1.10
WHERE first_name = 'Bulk';

-- 26
CREATE TABLE employee_archive (LIKE employees INCLUDING ALL);

INSERT INTO employee_archive
SELECT * FROM employees WHERE status = 'Inactive';

DELETE FROM employees
WHERE status = 'Inactive';

-- 27
UPDATE projects
SET end_date = end_date + INTERVAL '30 day'
WHERE budget > 50000 AND (
    SELECT COUNT(*)
    FROM employees e
    JOIN departments d ON e.department = d.dept_name
    WHERE d.dept_id = projects.dept_id
) > 3;
