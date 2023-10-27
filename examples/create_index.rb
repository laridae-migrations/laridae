require 'json'
require_relative '../components/MigrationExecutor'
require_relative '../components/DatabaseConnection'

script = [
  {
    operation: "create_index",
    info: {
      schema: "public",
      table: "employees",
      column: "phone",
      method: "btree"
    },
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
