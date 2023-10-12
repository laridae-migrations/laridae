require 'pg'

# delete all schemas
def rollback
  sql = <<~SQL
    DROP SCHEMA IF EXISTS before CASCADE;
    DROP SCHEMA IF EXISTS after CASCADE;
    DROP FUNCTION IF EXISTS up CASCADE;
    DROP FUNCTION IF EXISTS down CASCADE;
    ALTER TABLE employees DROP COLUMN IF EXISTS phone_not_null CASCADE;
    DELETE FROM employees WHERE id>100; /* remove this */
  SQL
  $database.exec_params(sql)
end

# create before view from physical table
def create_before_view
  sql = <<~SQL
    CREATE SCHEMA before;
    CREATE VIEW before.employees AS 
    SELECT id, name, age, phone from public.employees;
  SQL
  $database.exec_params(sql)
end

# add not null column, add table not null column constraint, add after view
def create_not_null_column
  sql = <<~SQL
    ALTER TABLE public.employees 
      ADD phone_not_null text,
      ADD CONSTRAINT check_phone_not_null CHECK (phone_not_null IS NOT NULL) NOT VALID;
  SQL
  $database.exec_params(sql)
end

# Create the after view, extracting "phone_not_null" from physical schema to "phone"
def create_after_view
  sql = <<~SQL
    CREATE SCHEMA after;
    CREATE VIEW after.employees AS
    SELECT id, name, age, phone_not_null AS phone from public.employees;
  SQL
  $database.exec_params(sql)
end

def create_up_function
  sql = <<~SQL
    CREATE FUNCTION up(text) RETURNS text
    AS '(SELECT CASE WHEN $1 IS NULL THEN ''0000000000'' ELSE $1 END)'
    LANGUAGE SQL;
  SQL
  $database.exec_params(sql)
end

def create_down_function
  sql = <<~SQL
    CREATE FUNCTION down(text) RETURNS text
    AS 'SELECT $1'
    LANGUAGE SQL;
  SQL
  $database.exec_params(sql)
end

def create_insert_trigger
  sql = <<~SQL
    CREATE OR REPLACE FUNCTION propagate_either_phone_insert()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    AS $$
      BEGIN
        IF NEW.phone IS NOT NULL AND NEW.phone_not_null IS NULL THEN
          NEW.phone_not_null := up(NEW.phone);
        ELSIF NEW.phone_not_null IS NOT NULL AND NEW.phone IS NULL THEN
          NEW.phone := down(NEW.phone_not_null);
        END IF;
        RETURN NEW;
      END;
    $$
  SQL
  $database.exec_params(sql)
  
  sql = <<~SQL
    CREATE OR REPLACE TRIGGER trigger_propagate_either_phone_insert
    BEFORE INSERT ON public.employees
    FOR EACH ROW EXECUTE FUNCTION propagate_either_phone_insert();
  SQL
  $database.exec_params(sql)
end

def create_up_update_trigger
  sql = <<~SQL
    CREATE OR REPLACE FUNCTION propagate_phone_update()
      RETURNS TRIGGER 
      LANGUAGE plpgsql
    AS $$
    BEGIN
      NEW.phone_not_null := up(NEW.phone);
      RETURN NEW;
    END;
    $$
  SQL
  $database.exec_params(sql)

  sql = <<~SQL
    CREATE OR REPLACE TRIGGER trigger_propagate_phone_update
    BEFORE UPDATE OF phone ON public.employees
    FOR EACH ROW EXECUTE FUNCTION propagate_phone_update();
  SQL
  $database.exec_params(sql)
end

def create_down_update_trigger
  sql = <<~SQL
    CREATE OR REPLACE FUNCTION propagate_phone_not_null_update()
    RETURNS TRIGGER 
    LANGUAGE plpgsql
  AS $$
  BEGIN
    NEW.phone := down(NEW.phone_not_null);
    RETURN NEW;
  END;
  $$
  SQL
  $database.exec_params(sql)

  sql = <<~SQL
    CREATE TRIGGER trigger_propagate_phone_not_null_update
    BEFORE UPDATE OF phone_not_null ON public.employees
    FOR EACH ROW EXECUTE FUNCTION propagate_phone_not_null_update();
  SQL
  $database.exec_params(sql)
end

def backfill
  sql = <<~SQL
    UPDATE public.employees
    SET phone_not_null = up(phone);
  SQL
  $database.exec_params(sql)
end

def validate_not_null_constraint
  sql = <<~SQL
    ALTER TABLE employees VALIDATE CONSTRAINT check_phone_not_null;
  SQL
  $database.exec_params(sql)
end

def contract
  sql = <<~SQL
    DROP SCHEMA IF EXISTS before CASCADE;
    DROP SCHEMA IF EXISTS after CASCADE;
    DROP FUNCTION IF EXISTS up CASCADE;
    DROP FUNCTION IF EXISTS down CASCADE;
    ALTER TABLE employees DROP COLUMN IF EXISTS phone CASCADE;
    ALTER TABLE employees RENAME COLUMN phone_not_null TO phone;
  SQL
  $database.exec_params(sql)
end

def run_tests
  sql = <<~SQL
    INSERT INTO before.employees (name, age, phone)
    VALUES ('inserted into before', 20, '1231231231');
    INSERT INTO after.employees (name, age, phone)
    VALUES ('inserted into after', 40, '1231231231');
    UPDATE before.employees 
      SET phone = '9999999999'
      WHERE name = 'inserted into before';
    UPDATE after.employees 
      SET phone = '8888888888'
      WHERE name = 'inserted into after';
  SQL
  $database.exec_params(sql)
end

# connect to database
$database = PG.connect(dbname: "postgres")

# main
rollback
create_before_view
create_not_null_column
create_after_view
create_up_function
create_down_function
create_insert_trigger
create_up_update_trigger
create_down_update_trigger
backfill
validate_not_null_constraint

puts "Is it safe to contract? (Y/N) "
choice = gets.chomp.upcase
contract if choice == 'Y' 