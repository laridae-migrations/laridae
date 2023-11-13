require 'json'
require_relative '../components/Migration'
require_relative '../components/MigrationRecord'
require_relative '../components/DatabaseConnection'

script = {
  operation: "add_column",
  info: {
    schema: "public",
    table: "employees",
    column: {
      name: "important",
      type: "boolean",
      nullable: false,
      default: false,
    },
  }
}

db_conn = DatabaseConnection.new(
  {
    dbname: 'script_test',
    host: 'localhost',
    port: 5432,
    user: 'stephanie'
  }
)
record = MigrationRecord.new(db_conn)

Migration.new(db_conn, record, script.to_json).expand
