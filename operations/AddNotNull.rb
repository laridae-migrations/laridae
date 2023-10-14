# add not null
class AddNotNull
  # database_hash can contain: host, port, options, tty, dbname, login, password
  def initialize(db_connection, migration_script)
    @database = db_connection
    info = migration_script[:info]
    @schema = info[:schema]
    @table = info[:table]
    @column = info[:column]
    @column_not_null = "laridae_new_#{@column}"
    @functions = migration_script[:functions]
  end

  def rollback
    sql = <<~SQL
      DROP SCHEMA IF EXISTS before CASCADE;
      DROP SCHEMA IF EXISTS after CASCADE;
      DROP TRIGGER IF EXISTS trigger_propagate_#{@column}_update ON #{@schema}.#{@table} CASCADE;
      DROP TRIGGER IF EXISTS trigger_propagate_#{@column_not_null}_update ON #{@schema}.#{@table} CASCADE;
      DROP FUNCTION IF EXISTS laridae_supplied_up_#{@table}_#{@column} CASCADE;
      DROP FUNCTION IF EXISTS laridae_supplied_down_#{@table}_#{@column} CASCADE;
      ALTER TABLE #{@schema}.#{@table} DROP COLUMN IF EXISTS #{@column_not_null} CASCADE;
      ALTER TABLE #{@schema}.#{@table} DROP CONSTRAINT IF EXISTS laridae_constraint_#{@column}_not_null CASCADE;
    SQL
    @database.query(sql)
  end

  def run
    puts "Should clean up be done on the database? (Y/N) "
    choice = gets.chomp.upcase
    rollback if choice == 'Y' 
    
    expand
    
    puts "Is it safe to contract? (Y/N) "
    choice = gets.chomp.upcase
    if choice == 'Y' 
      contract 
      puts 'Expand and Contract completed'
    else 
      puts 'Expand only'
    end
  end

  private

  def expand
    create_not_null_column
    create_before_view
    create_after_view
    create_up_function
    create_down_function
    create_up_insert_trigger
    create_down_insert_trigger
    create_up_update_trigger
    create_down_update_trigger
    backfill
    validate_not_null_constraint
  end

  def contract
    sql = <<~SQL
      DROP SCHEMA IF EXISTS before CASCADE;
      DROP SCHEMA IF EXISTS after CASCADE;
      DROP FUNCTION IF EXISTS laridae_triggerfn_insert_up_#{@table}_#{@column} CASCADE;
      DROP FUNCTION IF EXISTS laridae_triggerfn_insert_down_#{@table}_#{@column} CASCADE;
      ALTER TABLE #{@table} DROP COLUMN IF EXISTS #{@column} CASCADE;
      ALTER TABLE #{@table} RENAME COLUMN #{@column_not_null} TO #{@column};
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

  def create_not_null_column
    sql = <<~SQL
      ALTER TABLE #{@schema}.#{@table}
        ADD #{@column_not_null} #{get_column_type(@column)},
        ADD CONSTRAINT laridae_constraint_#{@column}_not_null CHECK (#{@column_not_null} IS NOT NULL) NOT VALID;
    SQL
    @database.query(sql)
  end

  def create_before_view
    columns = get_all_columns_names.select do |col| 
      col != "laridae_new_#{@column}"
    end

    sql = <<~SQL
      CREATE SCHEMA before;
      CREATE VIEW before.#{@table} AS 
      SELECT #{columns.join(', ')} from #{@schema}.#{@table};
    SQL
    @database.query(sql)
  end

  def create_after_view
    columns = get_all_columns_names.select do |col| 
      col != @column && col != "laridae_new_#{@column}"
    end

    sql = <<~SQL
      CREATE SCHEMA after;
      CREATE VIEW after.employees AS
      SELECT #{columns.join(', ')}, #{"laridae_new_#{@column}"} AS #{@column} from public.employees;
    SQL
    @database.query(sql)
  end

  def create_up_function
    sql = <<~SQL
      CREATE FUNCTION laridae_supplied_up_#{@table}_#{@column}(#{get_column_type(@column)}) 
      RETURNS #{get_column_type(@column)}
      AS '#{@functions[:up]}'
      LANGUAGE SQL;
    SQL
    @database.query(sql)
  end

  def create_down_function
    sql = <<~SQL
      CREATE FUNCTION laridae_supplied_down_#{@table}_#{@column}(#{get_column_type(@column)}) 
      RETURNS #{get_column_type(@column)}
      AS '#{@functions[:down]}'
      LANGUAGE SQL;
    SQL
    @database.query(sql)
  end

  def create_up_insert_trigger
    columns = get_all_columns_names
    new_dot_columns = columns.select{ |col| col != @column_not_null}
                                .map{ |col| "NEW.#{col}" }
                                .join(', ')

    sql_create_fn = <<~SQL
      CREATE OR REPLACE FUNCTION laridae_triggerfn_insert_up_#{@table}_#{@column}() 
        RETURNS TRIGGER
      AS $$
      BEGIN
        INSERT INTO #{@schema}.#{@table} (#{columns.join(', ')})
        VALUES (#{new_dot_columns}, laridae_supplied_up_#{@table}_#{@column}(NEW.#{@column}));
        RETURN NEW;
      END
      $$ LANGUAGE plpgsql;
    SQL
    @database.query(sql_create_fn)
    
    sql_create_trigger = <<~SQL
      CREATE OR REPLACE TRIGGER laridae_trigger_insert_up_#{@table}_#{@column}
      INSTEAD OF INSERT 
      ON before.#{@table}
      FOR EACH ROW
      EXECUTE FUNCTION laridae_triggerfn_insert_up_#{@table}_#{@column}();
    SQL
    @database.query(sql_create_trigger)
  end

  def create_down_insert_trigger
    columns = get_all_columns_names
    new_dot_columns = columns.select{ |col| col != @column_not_null}
                                .map{ |col| "NEW.#{col}" }
                                .join(', ')

    sql_create_fn = <<~SQL
      CREATE OR REPLACE FUNCTION laridae_triggerfn_insert_down_#{@table}_#{@column}() 
        RETURNS TRIGGER
      AS $$
      BEGIN
        INSERT INTO #{@schema}.#{@table} (#{columns.join(', ')})
        VALUES (#{new_dot_columns}, laridae_supplied_down_#{@table}_#{@column}(NEW.#{@column}));
        RETURN NEW;
      END
      $$ LANGUAGE plpgsql;
    SQL
    @database.query(sql_create_fn)
    
    sql_create_trigger = <<~SQL
      CREATE OR REPLACE TRIGGER laridae_trigger_insert_down_#{@table}_#{@column}
      INSTEAD OF INSERT 
      ON after.#{@table}
      FOR EACH ROW
      EXECUTE FUNCTION laridae_triggerfn_insert_down_#{@table}_#{@column}();
    SQL
    @database.query(sql_create_trigger)
  end

  def create_up_update_trigger
    sql_create_fn = <<~SQL
      CREATE OR REPLACE FUNCTION propagate_#{@column}_update()
        RETURNS TRIGGER 
        LANGUAGE plpgsql
      AS $$
      BEGIN
        NEW.#{@column_not_null} := up(NEW.#{@column});
        RETURN NEW;
      END;
      $$
    SQL
    @database.query(sql_create_fn)
  
    sql_create_trigger = <<~SQL
      CREATE OR REPLACE TRIGGER trigger_propagate_#{@column}_update
      BEFORE UPDATE OF #{@column} 
      ON #{@schema}.#{@table}
      FOR EACH ROW EXECUTE FUNCTION propagate_#{@column}_update();
    SQL
    @database.query(sql_create_trigger)
  end

  def create_down_update_trigger
    sql_create_fn = <<~SQL
      CREATE OR REPLACE FUNCTION propagate_#{@column_not_null}_update()
        RETURNS TRIGGER 
        LANGUAGE plpgsql
      AS $$
      BEGIN
        NEW.#{@column} := down(NEW.#{@column_not_null});
        RETURN NEW;
      END;
      $$
    SQL
    @database.query(sql_create_fn)
  
    sql_create_trigger = <<~SQL
      CREATE TRIGGER trigger_propagate_#{@column_not_null}_update
      BEFORE UPDATE OF #{@column_not_null} 
      ON #{@schema}.#{@table}
      FOR EACH ROW EXECUTE FUNCTION propagate_#{@column_not_null}_update();
    SQL
    @database.query(sql_create_trigger)
  end

  def backfill
    sql = <<~SQL
      UPDATE #{@schema}.#{@table}
      SET #{@column_not_null} = laridae_supplied_up_#{@table}_#{@column}(#{@column});
    SQL
    @database.query(sql)
  end

  def validate_not_null_constraint
    sql = <<~SQL
      ALTER TABLE #{@table} 
      VALIDATE CONSTRAINT laridae_constraint_#{@column}_not_null
    SQL
    @database.query(sql)
  end
end