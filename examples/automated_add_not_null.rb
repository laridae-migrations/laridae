require_relative '../operations/AddNotNull'
require_relative '../components/DatabaseConnection'

test_insert_sql = <<~SQL
  INSERT INTO before.employees (id, name, age, phone)
  VALUES (101, 'inserted into before', 20, '1231231231');
  INSERT INTO after.employees (id, name, age, phone)
  VALUES (102 'inserted into after', 40, '1231231231');
SQL

test_update_sql = <<~SQL
  UPDATE before.employees 
    SET phone = '9999999999'
    WHERE name = 'inserted into before';
  UPDATE after.employees 
    SET phone = '8888888888'
    WHERE name = 'inserted into after';
SQL

db = DatabaseConnection.new(
  {
    dbname: 'human_resources',
    host: 'localhost',
    port: 5432,
    user: 'postgres'
  }
)

script = {
  operation: "add_not_null",
  info: {
    schema: "public",
    table: "employees",
    column: "phone"
  },
  functions: {
    up: "SELECT CASE WHEN $1 IS NULL THEN ''0000000000'' ELSE $1 END",
    down: 'SELECT $1'
  }
}

AddNotNull.new(db, script).run
