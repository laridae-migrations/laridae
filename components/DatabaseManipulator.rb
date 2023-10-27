require_relative "./MigrationExecutor"

class DatabaseManipulator
  def initialize(database_connection)
    @database = database_connection
  end

  def cleanup
    sql = <<~SQL
    DROP SCHEMA IF EXISTS #{MigrationExecutor.AFTER_SCHEMA} CASCADE;
    DROP SCHEMA IF EXISTS #{MigrationExecutor.TEMP_SCHEMA} CASCADE;
    SQL
    @database.query(sql)
  end
end