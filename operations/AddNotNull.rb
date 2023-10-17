require 'json'
require_relative '../components/Utils'

# add not null
class AddNotNull
  # database_hash can contain: host, port, options, tty, dbname, login, password
  def initialize(db_connection, script_json)
    @database = db_connection
    @migration_json = script_json

    script_hash = JSON.parse(script_json)
    info = script_hash['info']

    @schema = info['schema']
    @table = info['table']
    @column = info['column']
    @column_not_null = "laridae_new_#{@column}"

    @up_function = script_hash['functions']['up']
    @down_function = script_hash['functions']['down']
  end

  def run
    puts 'Should clean up be done on the database? (Y/N) '
    choice = gets.chomp.upcase
    rollback if choice == 'Y' 
    
    expand
    
    puts 'Is it safe to contract? (Y/N) '
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
    create_views
    create_laridae_schema
    create_triggers
    # backfill
    # validate_not_null_constraint
  end

  #=============================================================
  # ALL METHODS FOR CLEANING UP
  def rollback
    cleanup
    sql = <<~SQL
      ALTER TABLE #{@schema}.#{@table} 
        DROP COLUMN IF EXISTS #{@column_not_null} CASCADE;
      ALTER TABLE #{@schema}.#{@table} 
        DROP CONSTRAINT IF EXISTS laridae_constraint_#{@column}_not_null CASCADE;
    SQL
    @database.query(sql)
  end

  def cleanup
    sql = <<~SQL
      DROP SCHEMA IF EXISTS before CASCADE;
      DROP SCHEMA IF EXISTS after CASCADE;
      DROP SCHEMA IF EXISTS laridae CASCADE;
      DROP FUNCTION IF EXISTS #{@schema}.laridae_triggerfn_#{@table}_#{@column_not_null} CASCADE;

      DROP FUNCTION IF EXISTS propagate_#{@column}_update() CASCADE;
      DROP FUNCTION IF EXISTS propagate_#{@column_not_null}_update() CASCADE;
      DROP FUNCTION IF EXISTS laridae_triggerfn_insert_up_#{@table}_#{@column} CASCADE;
      DROP FUNCTION IF EXISTS laridae_triggerfn_insert_down_#{@table}_#{@column} CASCADE;
    SQL
    @database.query(sql)
  end

  def contract
    cleanup
    sql = <<~SQL
      ALTER TABLE #{@table}  
        DROP COLUMN IF EXISTS #{@column} CASCADE;
      ALTER TABLE #{@table} 
        RENAME COLUMN #{@column_not_null} TO #{@column};
      ALTER TABLE #{@schema}.#{@table} 
        RENAME CONSTRAINT laridae_constraint_#{@column}_not_null 
        TO constraint_#{@column}_not_null;
    SQL
    @database.query(sql)
  end

  #=============================================================
  # Create not_null column and before/after views
  def create_views
    create_not_null_column
    create_before_view
    create_after_view
  end

  def create_not_null_column
    sql = <<~SQL
      ALTER TABLE #{@schema}.#{@table}
      ADD #{@column_not_null} #{Utils.get_column_type(@database, @schema, @table, @column)},
      ADD CONSTRAINT laridae_constraint_#{@column}_not_null CHECK (#{@column_not_null} IS NOT NULL) NOT VALID;
    SQL
    @database.query(sql)
  end

  def create_before_view
    old_columns = Utils.get_all_before_columns_names(@database, @schema, @table)
    sql = <<~SQL
      CREATE SCHEMA before;
      CREATE VIEW before.#{@table} AS 
      SELECT #{old_columns.join(', ')} from #{@schema}.#{@table};
    SQL
    @database.query(sql)
  end

  def create_after_view
    non_involved_columns = Utils.get_all_non_involved_columns_names(@database, @schema, @table, @column)
    sql = <<~SQL
      CREATE SCHEMA after;
      CREATE VIEW after.employees AS
      SELECT #{non_involved_columns.join(', ')}, #{"laridae_new_#{@column}"} AS #{@column} from public.employees;
    SQL
    @database.query(sql)
  end

  #=============================================================
  # Create laridate schema and insert this current migration script
  def create_laridae_schema()
    Utils.create_laridae_schema(@database)
    Utils.insert_into_laridae(@schema, "employees_phone_not_null", @migration_json)
  end

  #=============================================================
  # create the backward and forward triggers
  def create_triggers
    create_down_trigger_function
    create_down_trigger
  end
  
  def sql_to_assign_variables(down_operation = true)
    sql = ''
    old_columns = Utils.get_all_non_involved_columns_names(@database, @schema, @table, @column)
    old_columns.each do |column|
      sql += "#{column} #{@schema}.#{@table}.#{column}%TYPE := NEW.#{column}; \n"
    end
    working_column = down_operation ? @column_not_null : @column
    sql += "#{@column} #{@schema}.#{@table}.#{working_column}%TYPE := NEW.#{working_column};"
  end

  def create_down_trigger_function 
    sql = <<~SQL
      CREATE OR REPLACE FUNCTION #{@schema}.laridae_triggerfn_#{@table}_#{@column_not_null}()
        RETURNS trigger
        LANGUAGE plpgsql
      AS $$
        DECLARE
          #{sql_to_assign_variables(true)}
          latest_schema text;
          search_path text;
        BEGIN
          SELECT '#{@schema}' || '_' || latest_version
            INTO latest_schema
            FROM "laridae".latest_version('public');
          SELECT current_setting
            INTO search_path
            FROM current_setting('search_path');
          IF search_path = latest_schema THEN
            NEW."#{@column}" = #{@down_function};
          END IF;
          RETURN NEW;
        END;
      $$
    SQL
    @database.query(sql)
  end

  def create_down_trigger
    sql = <<~SQL
      CREATE OR REPLACE TRIGGER laridae_trigger_#{@table}_#{@column_not_null}
      BEFORE INSERT OR UPDATE ON #{@table}
      FOR EACH ROW EXECUTE FUNCTION laridae_triggerfn_#{@table}_#{@column_not_null}();
    SQL
    @database.query(sql)
  end

  #=============================================================
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

  #=============================================================
  # create up and down functions based on supplied functions from migration script
  # def create_transformative_functions
  #   create_up_function
  #   create_down_function
  # end

  # def create_up_function
  #   sql = <<~SQL
  #     CREATE FUNCTION laridae_supplied_up_#{@table}_#{@column}(#{Utils.get_column_type(@database, @schema, @table, @column)}) 
  #     RETURNS #{Utils.get_column_type(@database, @schema, @table, @column)}
  #     AS '#{@functions['up']}'
  #     LANGUAGE SQL;
  #   SQL
  #   @database.query(sql)
  # end

  # def create_down_function
  #   sql = <<~SQL
  #     CREATE FUNCTION laridae_supplied_down_#{@table}_#{@column}(#{Utils.get_column_type(@database, @schema, @table, @column)}) 
  #     RETURNS #{Utils.get_column_type(@database, @schema, @table, @column)}
  #     AS '#{@functions['down']}'
  #     LANGUAGE SQL;
  #   SQL
  #   @database.query(sql)
  # end

  # def create_up_insert_trigger
  #   columns = Utils.get_all_columns_names(@database, @schema, @table)
  #   new_dot_columns = columns.select{ |col| col != @column_not_null}
  #                               .map{ |col| "NEW.#{col}" }
  #                               .join(', ')

  #   sql_create_fn = <<~SQL
  #     CREATE OR REPLACE FUNCTION laridae_triggerfn_insert_up_#{@table}_#{@column}() 
  #       RETURNS TRIGGER
  #     AS $$
  #     BEGIN
  #       INSERT INTO #{@schema}.#{@table} (#{columns.join(', ')})
  #       VALUES (#{new_dot_columns}, laridae_supplied_up_#{@table}_#{@column}(NEW.#{@column}));
  #       RETURN NEW;
  #     END
  #     $$ LANGUAGE plpgsql;
  #   SQL
  #   @database.query(sql_create_fn)
    
  #   sql_create_trigger = <<~SQL
  #     CREATE OR REPLACE TRIGGER laridae_trigger_insert_up_#{@table}_#{@column}
  #     INSTEAD OF INSERT 
  #     ON before.#{@table}
  #     FOR EACH ROW
  #     EXECUTE FUNCTION laridae_triggerfn_insert_up_#{@table}_#{@column}();
  #   SQL
  #   @database.query(sql_create_trigger)
  # end

  # def create_down_insert_trigger
  #   columns = Utils.get_all_columns_names(@database, @schema, @table)
  #   new_dot_columns = columns.select{ |col| col != @column_not_null}
  #                               .map{ |col| "NEW.#{col}" }
  #                               .join(', ')

  #   sql_create_fn = <<~SQL
  #     CREATE OR REPLACE FUNCTION laridae_triggerfn_insert_down_#{@table}_#{@column}() 
  #       RETURNS TRIGGER
  #     AS $$
  #     BEGIN
  #       INSERT INTO #{@schema}.#{@table} (#{columns.join(', ')})
  #       VALUES (#{new_dot_columns}, laridae_supplied_down_#{@table}_#{@column}(NEW.#{@column}));
  #       RETURN NEW;
  #     END
  #     $$ LANGUAGE plpgsql;
  #   SQL
  #   @database.query(sql_create_fn)
    
  #   sql_create_trigger = <<~SQL
  #     CREATE OR REPLACE TRIGGER laridae_trigger_insert_down_#{@table}_#{@column}
  #     INSTEAD OF INSERT 
  #     ON after.#{@table}
  #     FOR EACH ROW
  #     EXECUTE FUNCTION laridae_triggerfn_insert_down_#{@table}_#{@column}();
  #   SQL
  #   @database.query(sql_create_trigger)
  # end

  # def create_up_update_trigger
  #   sql_create_fn = <<~SQL
  #     CREATE OR REPLACE FUNCTION propagate_#{@column}_update()
  #       RETURNS TRIGGER 
  #       LANGUAGE plpgsql
  #     AS $$
  #     BEGIN
  #       NEW.#{@column_not_null} := laridae_supplied_up_#{@table}_#{@column}(NEW.#{@column});
  #       RETURN NEW;
  #     END;
  #     $$
  #   SQL
  #   @database.query(sql_create_fn)
  
  #   sql_create_trigger = <<~SQL
  #     CREATE OR REPLACE TRIGGER trigger_propagate_#{@column}_update
  #     BEFORE UPDATE OF #{@column} 
  #     ON #{@schema}.#{@table}
  #     FOR EACH ROW EXECUTE FUNCTION propagate_#{@column}_update();
  #   SQL
  #   @database.query(sql_create_trigger)
  # end

  # def create_down_update_trigger
  #   sql_create_fn = <<~SQL
  #     CREATE OR REPLACE FUNCTION propagate_#{@column_not_null}_update()
  #       RETURNS TRIGGER 
  #       LANGUAGE plpgsql
  #     AS $$
  #     BEGIN
  #       NEW.#{@column} := laridae_supplied_down_#{@table}_#{@column}(NEW.#{@column_not_null});
  #       RETURN NEW;
  #     END;
  #     $$
  #   SQL
  #   @database.query(sql_create_fn)
  
  #   sql_create_trigger = <<~SQL
  #     CREATE TRIGGER trigger_propagate_#{@column_not_null}_update
  #     BEFORE UPDATE OF #{@column_not_null} 
  #     ON #{@schema}.#{@table}
  #     FOR EACH ROW EXECUTE FUNCTION propagate_#{@column_not_null}_update();
  #   SQL
  #   @database.query(sql_create_trigger)
  # end
