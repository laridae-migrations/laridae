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
    @down_function = script_hash['functions']['down'].gsub(@column, @column_not_null)
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
    create_triggers
    backfill
    validate_not_null_constraint
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
    DROP FUNCTION IF EXISTS laridae_triggerfn_#{@table}_#{@column_not_null} CASCADE;
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
      CREATE VIEW after.#{@table} AS
      SELECT #{non_involved_columns.join(', ')}, laridae_new_#{@column} AS #{@column} from #{@schema}.#{@table};
    SQL
    puts sql
    @database.query(sql)
  end

  def sql_to_declare_variables(down_operation = true)
    sql = ''
    columns = Utils.get_all_columns_names(@database, @schema, @table)
    columns.each do |column|
      sql += "#{column} #{@schema}.#{@table}.#{column}%TYPE := NEW.#{column};\n"
    end
    sql
  end

  # create the backward and forward triggers
  # todo: search_path could be neither before nor after
  def create_trigger_function
    sql = <<~SQL
      CREATE OR REPLACE FUNCTION #{@schema}.laridae_triggerfn_#{@table}_#{@column_not_null}()
        RETURNS trigger
        LANGUAGE plpgsql
      AS $$
        DECLARE
          #{@column} #{@schema}.#{@table}.#{@column}%TYPE := NEW.#{@column};
          #{@column_not_null} #{@schema}.#{@table}.#{@column_not_null}%TYPE := NEW.#{@column_not_null};
          search_path text;
        BEGIN
          SELECT current_setting
            INTO search_path
            FROM current_setting('search_path');
          IF search_path = 'after' THEN
            NEW.#{@column} := #{@down_function};
          ELSE
            NEW.#{@column_not_null} := #{@up_function};
          END IF;
          RETURN NEW;
        END;
      $$
    SQL
    @database.query(sql)
  end

  def create_triggers
    create_trigger_function
    sql_create_trigger = <<~SQL
      CREATE TRIGGER trigger_propagate_#{@column_not_null}
      BEFORE INSERT OR UPDATE
      ON #{@schema}.#{@table}
      FOR EACH ROW EXECUTE FUNCTION #{@schema}.laridae_triggerfn_#{@table}_#{@column_not_null}();
    SQL
    @database.query(sql_create_trigger)
  end

  def backfill
    sql = <<~SQL
      UPDATE #{@schema}.#{@table}
      SET #{@column_not_null} = #{@up_function};
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