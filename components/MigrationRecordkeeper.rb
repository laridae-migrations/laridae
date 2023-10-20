class MigrationRecordkeeper
  def initialize(database_connection)
    @database = database_connection
    @database.turn_off_notices
  end

  def create_open_migration_table
    sql = <<~SQL
      CREATE SCHEMA IF NOT EXISTS laridae;
      CREATE TABLE IF NOT EXISTS laridae.open_migration (script jsonb);
    SQL
    @database.query(sql)
  end

  def open_migration?
    sql = <<~SQL
      SELECT * FROM laridae.open_migration;
    SQL
    result = @database.query(sql)
    result.ntuples > 0
  end

  def open_migration
    sql = <<~SQL
      SELECT * FROM laridae.open_migration;
    SQL
    result = @database.query(sql)
    result[0]["script"]
  end

  def record_new_migration(script)
    sql = <<~SQL
    INSERT INTO laridae.open_migration (script) VALUES ($1);
    SQL
    @database.query(sql, [script])
  end
  
  def remove_current_migration
    sql = <<~SQL
    DELETE FROM laridae.open_migration;
    SQL
    @database.query(sql)
  end
end