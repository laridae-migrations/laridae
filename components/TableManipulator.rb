class TableManipulator
  def initialize(database, schema, table)
    @database = database
    @schema = schema
    @table = table
  end

  def cleanup
    sql = <<~SQL
    DROP SCHEMA IF EXISTS before CASCADE;
    DROP SCHEMA IF EXISTS after CASCADE;
    DROP SCHEMA IF EXISTS laridae CASCADE;
    SQL
    @database.query(sql)
  end

  def get_all_columns_names
    sql = <<~SQL
      SELECT column_name
      FROM information_schema.columns
      WHERE table_schema = $1 and table_name = $2;
    SQL
    result = @database.query(sql, [@schema, @table])
    result.map { |line| line["column_name"] }
  end

  def get_column_type(column_name)
    sql = <<~SQL
      SELECT data_type 
      FROM information_schema.columns
      WHERE table_schema = $1 
        AND table_name = $2
        AND column_name = $3;
    SQL
    @database.query(sql, [@schema, @table, column_name])
      .map { |tuple| tuple['data_type'] }
      .first
  end

  def create_trigger_function(old_column, new_column, up, down)
    sql = <<~SQL
      CREATE SCHEMA IF NOT EXISTS laridae;
      CREATE OR REPLACE FUNCTION laridae.triggerfn_#{@table}_#{old_column}()
        RETURNS trigger
        LANGUAGE plpgsql
      AS $$
        DECLARE
          #{old_column} #{@schema}.#{@table}.#{old_column}%TYPE := NEW.#{old_column};
          #{new_column} #{@schema}.#{@table}.#{new_column}%TYPE := NEW.#{new_column};
          search_path text;
        BEGIN
          SELECT current_setting
            INTO search_path
            FROM current_setting('search_path');
          IF search_path = 'after' THEN
            NEW.#{old_column} := #{down};
          ELSE
            NEW.#{new_column} := #{up};
          END IF;
          RETURN NEW;
        END;
      $$
    SQL
    @database.query(sql)
  end

  def create_trigger(old_column, new_column, up, down)
    create_trigger_function(old_column, new_column, up, down)
    sql_create_trigger = <<~SQL
      CREATE TRIGGER trigger_propagate_#{old_column}
      BEFORE INSERT OR UPDATE
      ON #{@schema}.#{@table}
      FOR EACH ROW EXECUTE FUNCTION laridae.triggerfn_#{@table}_#{old_column}();
    SQL
    @database.query(sql_create_trigger)
  end

  def backfill(new_column, up)
    sql = <<~SQL
      UPDATE #{@schema}.#{@table}
      SET #{new_column} = #{up};
    SQL
    @database.query(sql)
  end

  def create_view(schema, view)
    columns_in_view = []
    get_all_columns_names.each do |name|
      if view.key?(name)
        if view[name] != nil
          columns_in_view.push("#{name} AS #{view[name]}")
        end
      else
        columns_in_view.push(name)
      end
    end
    sql = <<~SQL
      CREATE SCHEMA #{schema}
      CREATE VIEW #{schema}.#{@table} AS 
      SELECT #{columns_in_view.join(", ")} from #{@schema}.#{@table};
    SQL
    @database.query(sql)
  end

  def rename_column(old_name, new_name)
    sql = <<~SQL
      ALTER TABLE #{@schema}.#{@table}
      RENAME COLUMN #{old_name} TO #{new_name};
    SQL
    @database.query(sql)
  end

  def drop_column(column_name)
    sql = <<~SQL
      ALTER TABLE #{@schema}.#{@table}
      DROP COLUMN IF EXISTS #{column_name};
    SQL
    @database.query(sql)
  end

  def create_new_version_of_column(old_column)
    sql = <<~SQL
      ALTER TABLE #{@schema}.#{@table}
      ADD laridae_new_#{old_column} #{get_column_type(old_column)}
    SQL
    @database.query(sql)
  end

  def add_constraint(name, constraint)
    sql = <<~SQL
      ALTER TABLE #{@schema}.#{@table}
      ADD CONSTRAINT #{name} #{constraint};
    SQL
    @database.query(sql)
  end

  def remove_constraint(name)
    sql = <<~SQL
      ALTER TABLE #{@schema}.#{@table}
      DROP CONSTRAINT IF EXISTS #{name};
    SQL
    @database.query(sql)
  end

  def rename_constraint(old_name, new_name)
    sql = <<~SQL
      ALTER TABLE #{@schema}.#{@table}
      RENAME CONSTRAINT #{old_name} TO #{new_name};
    SQL
    @database.query(sql)
  end

  def validate_constraint(constraint_name)
    sql = <<~SQL
      ALTER TABLE #{@table} 
      VALIDATE CONSTRAINT #{constraint_name}
    SQL
    @database.query(sql)
  end
end