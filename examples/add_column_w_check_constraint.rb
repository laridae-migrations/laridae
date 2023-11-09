require 'json'
require_relative '../components/MigrationExecutor'
require_relative '../components/DatabaseConnection'

script = {
  operation: "add_column",
  info: {
    schema: "public",
    table: "employees",
    column: {
      name: "age_insert_ex",
      type: "integer",
      check: {
        name: "age_check",
        constraint: "age >= 18"
      }
    },
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
