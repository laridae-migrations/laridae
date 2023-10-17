class Utils
  # return an array of strings of all column names
  def self.get_all_columns_names(db, schema, table)
    sql = <<~SQL
      SELECT column_name
      FROM information_schema.columns
      WHERE table_schema = $1 and table_name = $2;
    SQL
    result = db.query(sql, [schema, table])
    result.map { |line| line['column_name'] }
  end

  # return an array of strings of all before column names
  def self.get_all_before_columns_names(db, schema, table)
    columns = self.get_all_columns_names(db, schema, table)
    columns.select { |col| col != "laridae_new_#{@column}" }
  end

  # return an array of strings of all column names that are not involved in the operation
  def self.get_all_non_involved_columns_names(db, schema, table, changing_column)
    columns = self.get_all_columns_names(db, schema, table)
    columns.select do |col| 
      col != changing_column && 
      col != "laridae_new_#{changing_column}"
    end
  end

  # return a string of type of the column
  def self.get_column_type(db, schema, table, column_name)
    sql = <<~SQL
      SELECT data_type 
      FROM information_schema.columns
      WHERE table_schema = $1 
        AND table_name = $2
        AND column_name = $3
      LIMIT 1;
    SQL
    db.query(sql, [schema, table, column_name])
      .map { |tuple| tuple['data_type'] }
      .first
  end

  

  #============================================================
  # Create laridae schema to store trigger data
  def self.create_laridae_schema(db)
    sql = <<~SQL
      DROP SCHEMA IF EXISTS laridae CASCADE;
      CREATE SCHEMA laridae;
    SQL
    db.query(sql)
    self.create_laridae_migration_table(db)
    self.create_get_latest_version_name_function(db)
  end

  # Create migrations table in laridae schema with unique index
  def self.create_laridae_migration_table(db)
    sql = <<~SQL
      CREATE TABLE IF NOT EXISTS laridae.migrations (
        schema NAME NOT NULL,
        name TEXT NOT NULL,
        migration JSONB NOT NULL,
        previous TEXT,
        PRIMARY KEY (schema, name),
        FOREIGN KEY	(schema, previous) REFERENCES laridae.migrations(schema, name)
      );
    SQL
    db.query(sql)

    # Only first migration can exist without parent
    sql = "CREATE UNIQUE INDEX IF NOT EXISTS only_first_migration_without_parent ON laridae.migrations (schema) WHERE previous IS NULL;"
    db.query(sql)
  end

  # Get the latest version name (this is the one with child migrations)
  def self.create_get_latest_version_name_function(db)
    sql = <<~SQL
      CREATE OR REPLACE FUNCTION laridae.latest_version(schema_name NAME) RETURNS text
      AS $$ 
        SELECT l.name FROM laridae.migrations l 
        WHERE NOT EXISTS (
          SELECT 1 FROM laridae.migrations c WHERE schema=schema_name AND c.previous=l.name
        ) 
        AND schema=schema_name $$
      LANGUAGE SQL STABLE;
    SQL
    db.query(sql)
  end

  def self.insert_into_laridae(schema, migration_name, migration_script_json)
    sql = <<~SQL
      INSERT INTO laridae.migrations (schema, name, migration)
      VALUES ('public', '#{migration_name}', #{migration_script_json};
    SQL
  end

end