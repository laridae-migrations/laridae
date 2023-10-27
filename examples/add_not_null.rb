require 'json'
require_relative '../components/MigrationExecutor'
require_relative '../components/DatabaseConnection'

script = [
  {
    operation: "add_not_null",
    info: {
      schema: "public",
      table: "employees",
      column: "phone"
    },
    functions: {
      up: "CASE WHEN phone IS NULL THEN '0000000000' ELSE phone END",
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
