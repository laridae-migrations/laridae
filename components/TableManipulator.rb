# rubocop:disable allcops
BATCH_SIZE = 400

class TableManipulator
  def initialize(database, schema, table)
    @database = database
    @schema = schema
    @table = table
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

  def get_column_default_value(column_name)
    sql = <<~SQL
      SELECT col.table_schema,
        col.table_name,
        col.column_name,
        col.column_default
      FROM information_schema.columns col
      WHERE col.column_default IS NOT NULL
        AND col.table_schema NOT IN('information_schema', 'pg_catalog')
        AND col.column_name = $1
        AND col.table_name = $2; 
    SQL
    # need to have column name in single quotes?
    
    result = @database.query(sql, [column_name, @table])
    result.field_values('column_default').first
  end

  def sql_to_declare_variables
    sql = ''
    get_all_columns_names.each do |column|
      sql += "#{column} #{@schema}.#{@table}.#{column}%TYPE := NEW.#{column}; \n"
    end
    sql
  end

  def create_trigger_function(old_column, new_column, up, down)
    fixed_down = down.gsub(old_column, new_column)
    sql = <<~SQL
      CREATE SCHEMA IF NOT EXISTS laridae_temp;
      CREATE OR REPLACE FUNCTION laridae_temp.triggerfn_#{@table}_#{old_column}()
        RETURNS trigger
        LANGUAGE plpgsql
      AS $$
        DECLARE
          #{sql_to_declare_variables}
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
    @database.query(sql)
  end

  def create_trigger(old_column, new_column, up, down)
    create_trigger_function(old_column, new_column, up, down)
    sql_create_trigger = <<~SQL
      CREATE TRIGGER trigger_propagate_#{old_column}
      BEFORE INSERT OR UPDATE
      ON #{@schema}.#{@table}
      FOR EACH ROW EXECUTE FUNCTION laridae_temp.triggerfn_#{@table}_#{old_column}();
    SQL
    @database.query(sql_create_trigger)
  end

  def total_rows_count
    sql = "SELECT COUNT(*) FROM #{@schema}.#{@table};"
    @database.query(sql).first['count'].to_i
  end

  def get_primary_key_column
    sql = <<~SQL
      SELECT c.column_name
      FROM information_schema.key_column_usage AS c
        JOIN information_schema.table_constraints AS t
        ON t.constraint_name = c.constraint_name
      WHERE c.constraint_schema = '#{@schema}'
        AND t.table_name = '#{@table}'
        AND t.constraint_type = 'PRIMARY KEY';
    SQL
    @database.query(sql).first['column_name']
  end

  def backfill(new_column, up)
    pkey_column = get_primary_key_column

    (0..total_rows_count).step(BATCH_SIZE) do |offset|
      sql = <<~SQL
        WITH rows AS 
          (SELECT #{pkey_column} FROM #{@table} ORDER BY #{pkey_column} 
           LIMIT #{BATCH_SIZE} OFFSET #{offset})
        UPDATE #{@table} SET #{new_column} = #{up}
        WHERE EXISTS 
          (SELECT * FROM rows WHERE #{@table}.#{pkey_column} = rows.#{pkey_column});
      SQL

      @database.query(sql)
      
      sleep(2)
    end
  end

  def add_column(table, new_column, data_type, default_value, is_unique)
    # faster to split up the two actions
    if is_unique 
      if default_value.nil?
        sql = <<~SQL
          ALTER TABLE #{@schema}.#{@table} ADD COLUMN #{new_column} #{data_type} UNIQUE;
        SQL
      else
        sql = <<~SQL
          ALTER TABLE #{@schema}.#{@table} ADD COLUMN #{new_column} #{data_type} UNIQUE;
          UPDATE #{@schema}.#{@table} SET #{new_column} = '#{default_value}';
        SQL
      end
    else
      if default_value.nil?
        sql = <<~SQL
          ALTER TABLE #{@schema}.#{@table} ADD COLUMN #{new_column} #{data_type};
        SQL
      else
        sql = <<~SQL
          ALTER TABLE #{@schema}.#{@table} ADD COLUMN #{new_column} #{data_type};
          UPDATE #{@schema}.#{@table} SET #{new_column} = '#{default_value}';
        SQL
      end
    end
    p sql
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

  def create_index(name, method, column)
    sql = <<~SQL
      CREATE INDEX CONCURRENTLY IF NOT EXISTS #{name}
      ON #{@schema}.#{@table}
      USING #{method} (#{column})
    SQL
    @database.query(sql)
  end
  
  def drop_index(name)
    sql = <<~SQL
      DROP INDEX CONCURRENTLY IF EXISTS #{name}
    SQL
    @database.query(sql)
  end

  def rename_index(name, new_name)
    sql = <<~SQL
      ALTER INDEX #{name} RENAME TO #{new_name}
    SQL
    @database.query(sql)
  end
end