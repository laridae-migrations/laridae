require 'json'
require_relative '../components/Migration'
require_relative '../components/MigrationRecord'
require_relative '../components/DatabaseConnection'

script = {
  "name": "11072023_phone_add_not_unique",
  "operation": "add_unique_constraint",
  "info": {
    "schema": "public",
    "table": "employees",
    "column": "phone"
  },
  "functions": {
    "up": "'phone-' || id",
    "down": "phone"
  }
}

db_conn = DatabaseConnection.new(
  {
    dbname: 'human_resources',
    host: 'localhost',
    port: 5432,
    user: 'postgres'
  }
)

record = MigrationRecord.new(db_conn)

Migration.new(db_conn, record, script.to_json).run
