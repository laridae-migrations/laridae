require 'json'
require_relative '../components/Migration'
require_relative '../components/MigrationRecord'
require_relative '../components/DatabaseConnection'

script = {
  "name": "phone_change_column_type",
  "operation": "change_column_type",
  "info": {
    "schema": "public",
    "table": "employees",
    "column": "phone",
    "type": "char(14)"
  },
  "functions": {
    "up": "\"1-\" || phone",
    "down": "SUBSTRING(phone, 3)"
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
