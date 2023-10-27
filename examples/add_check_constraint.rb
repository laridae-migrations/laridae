require 'json'
require_relative '../components/MigrationExecutor'
require_relative '../components/DatabaseConnection'

script = [
  {
    operation: "add_check_constraint",
    info: {
      schema: "public",
      table: "employees",
      column: "phone",
      condition: "phone ~* '\\d\\d\\d-\\d\\d\\d-\\d\\d\\d\\d'"
    },
    functions: {
      up: "CASE WHEN (NOT phone ~* '\\d\\d\\d-\\d\\d\\d-\\d\\d\\d\\d') THEN '000-000-0000' ELSE phone END",
      down: "phone"
    }
  }
]

db = DatabaseConnection.new(
  {
    dbname: 'human_resources',
    host: 'localhost',
    port: 5432,
    user: 'postgres'
  }
)
MigrationExecutor.new(db, script.to_json).run
