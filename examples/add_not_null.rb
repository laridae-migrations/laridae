require 'json'
require_relative '../components/Migration'
require_relative '../components/MigrationRecord'
require_relative '../components/DatabaseConnection'

script = {
  "name": "11072023_phone_add_not_null_per_mai",
  "operation": "add_not_null",
  "info": {
    "schema": "public",
    "table": "employees",
    "column": "phone"
  },
  "functions": {
    "up": "CASE WHEN phone IS NULL THEN '0000000000' ELSE phone END",
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
