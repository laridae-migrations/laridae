require 'json'
require_relative '../components/MigrationExecutor'
require_relative '../components/DatabaseConnection'

script = {
  operation: "add_column",
  info: {
    schema: "public",
    table: "employees",
    column: {
      name: "computer_id",
      type: "integer",
      unique: true,
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
