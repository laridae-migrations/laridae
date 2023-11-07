require 'json'
require_relative '../components/Migration'
require_relative '../components/MigrationRecord'
require_relative '../components/DatabaseConnection'

script = {
  "name": "11062023_add_phone_check_constraint_per_mai",
  "operation": "add_check_constraint",
  "info": {
    "schema": "public",
    "table": "employees",
    "column": "phone",
    "condition": "phone ~* '\\d\\d\\d-\\d\\d\\d-\\d\\d\\d\\d'"
  },
  "functions": {
    "up": "CASE WHEN (NOT phone ~* '\\d\\d\\d-\\d\\d\\d-\\d\\d\\d\\d') THEN '000-000-0000' ELSE phone END",
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
