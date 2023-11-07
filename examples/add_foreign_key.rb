require 'json'
require_relative '../components/MigrationExecutor'
require_relative '../components/DatabaseConnection'

script = {
  operation: "add_foreign_key_constraint",
  info: {
    schema: "public",
    table: "phones_ex",
    column: {
      name: "employee_id",
      references: {
        name: "fk_employee_id",
        table: "employees",
        column: "id",
      },
    },
  },
  functions: {
    up: "(SELECT CASE WHEN EXISTS (SELECT 1 FROM employees WHERE employees.id = employee_id) THEN employee_id ELSE NULL END)",
    down: "employee_id"
  }
}


db = DatabaseConnection.new(
  {
    dbname: 'human_resources',
    host: 'localhost',
    port: 5432,
    user: 'postgres'
  }
)
MigrationExecutor.new(db, script.to_json).run
