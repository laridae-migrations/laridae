# frozen_string_literal: true

# handles operations on the entire database
# such as schemas, views, etc.
class Database
  def initialize(database_connection, script_hash)
    @db_conn = database_connection
    @script = script_hash
  end

  def teardown_created_schemas
    sql = <<~SQL
      DROP SCHEMA IF EXISTS laridae_before CASCADE;
      DROP SCHEMA IF EXISTS laridae_#{@script['name']} CASCADE;
      DROP SCHEMA IF EXISTS laridae_temp CASCADE;
    SQL
    @db_conn.query(sql)
  end

  def create_view(new_schema_name, old_schema_name, table_name, columns_in_view)
    # @db_conn.query("CREATE SCHEMA #{new_schema_name}")
    sql = <<~SQL
      CREATE SCHEMA #{new_schema_name};
      CREATE VIEW #{new_schema_name}.#{table_name} AS#{' '}
      SELECT #{columns_in_view.join(', ')} from #{old_schema_name}.#{table_name};
    SQL
    @db_conn.query(sql)
  end

  # rubocop:disable Metrics/MethodLength
  def create_trigger_function(table, old_column, new_column, up, down)
    fixed_down = down.gsub(old_column, new_column)
    sql = <<~SQL
      CREATE SCHEMA IF NOT EXISTS laridae_temp;
      CREATE OR REPLACE FUNCTION laridae_temp.triggerfn_#{table.name}_#{old_column}()
        RETURNS trigger
        LANGUAGE plpgsql
      AS $$
        DECLARE
          #{table.sql_to_declare_variables}
          search_path text;
        BEGIN
          SELECT current_setting
            INTO search_path
            FROM current_setting('search_path');
          IF search_path = 'laridae_after' THEN
            NEW.#{old_column} := #{fixed_down};
          ELSE
            NEW.#{new_column} := #{up};
          END IF;
          RETURN NEW;
        END;
      $$
    SQL
    @db_conn.query(sql)
  end
  # rubocop:enable Metrics/MethodLength

  def create_trigger(table, old_column, new_column, up, down)
    create_trigger_function(table, old_column, new_column, up, down)
    sql = <<~SQL
      CREATE TRIGGER trigger_propagate_#{old_column}
      BEFORE INSERT OR UPDATE
      ON #{table.schema}.#{table.name}
      FOR EACH ROW EXECUTE FUNCTION laridae_temp.triggerfn_#{table.name}_#{old_column}();
    SQL
    @db_conn.query(sql)
  end

  def validate_constraint(table_name, constraint_name)
    sql = <<~SQL
      ALTER TABLE #{table_name}#{' '}
      VALIDATE CONSTRAINT #{constraint_name}
    SQL
    @db_conn.query(sql)
  end
end
