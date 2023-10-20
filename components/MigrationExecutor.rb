<<<<<<< HEAD
require_relative './DatabaseConnection'
require_relative './MigrationRecordkeeper'
require_relative '../operations/AddNotNull'
require_relative '../operations/RenameColumn'
require_relative '../operations/AddCheckConstraint'
require_relative '../operations/DropColumn'
require_relative '../operations/CreateIndex'
require 'json'

class MigrationExecutor
  DB_URL_FILENAME = "#{__dir__}/.laridae_database_url.txt"
  HANDLERS_BY_OPERATION = {
    "add_not_null" => AddNotNull,
    'rename_column' => RenameColumn,
    'add_check_constraint' => AddCheckConstraint,
    'drop_column' => DropColumn,
    'create_index' => CreateIndex
  }
  def initialize
    @database = nil
  end

  def run_command(command_line_arguments)
    arguments_per_command = {"init" => 2, "expand" => 2, "contract" => 1, "rollback" => 1}
    command = command_line_arguments[0]
    if !arguments_per_command.key?(command)
      puts "Invalid command."
      return
    end
    if arguments_per_command[command] > command_line_arguments.length
      puts "Missing required argument."
      return
    elsif arguments_per_command[command] < command_line_arguments.length
      puts "Extra arguments supplied."
      return
    end
    send(*command_line_arguments)
  end

  def database_connection_from_file
    # add handling for if file does not exist
    # todo: close files
    database_url = File.open(DB_URL_FILENAME).read
    database = DatabaseConnection.new(database_url)
    database.turn_off_notices
    database
  end

  def new_schema_search_path
    db_url = File.open(DB_URL_FILENAME).read
    if db_url.include?("?")
      "#{db_url}&currentSchema=laridae_after,public"
    else
      "#{db_url}?currentSchema=laridae_after,public"
    end
  end

  # not to be confused with initialize; handles init command
  def init(db_url)
    # todo: handle this situation better
    if File.exists?(DB_URL_FILENAME)
      puts "Note: previously initialized; overwriting."
    end
    db_url_file = File.open(DB_URL_FILENAME, 'w')
    db_url_file.write(db_url)
    db_url_file.close
    # todo: add error handling if URL is invalid
    @database = DatabaseConnection.new(db_url)
    MigrationRecordkeeper.new(@database).create_open_migration_table
    @database.close
=======
# rubocop:disable allcops
BATCH_SIZE = 400

class TableManipulator
  def initialize(database, schema, table)
    @database = database
    @schema = schema
    @table = table
  end

  def cleanup
    sql = <<~SQL
    DROP SCHEMA IF EXISTS laridae_before CASCADE;
    DROP SCHEMA IF EXISTS laridae_after CASCADE;
    DROP SCHEMA IF EXISTS laridae_temp CASCADE;
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
>>>>>>> main
  end

  def operation_handler_for_script(script)
    operation_name = script["operation"]
    HANDLERS_BY_OPERATION[operation_name].new(@database, script)
  end

  def expand(filename)
    @database = database_connection_from_file
    migration_recordkeeper = MigrationRecordkeeper.new(@database)
    if !filename.end_with?(".json")
      puts "Migration script #{filename} must be JSON."
      return
    end
    begin
      migration_script_file = File.open(filename)
    rescue Errno::ENOENT
      puts "Migration script \"#{filename}\" not found."
      return
    end
    if migration_recordkeeper.open_migration?
      puts "Another migration is currently running; cannot continue."
      return
    end
    migration_script = migration_script_file.read
    script_hash = JSON.parse(migration_script)
    operation_handler = operation_handler_for_script(script_hash)
    puts "Should clean up be done on the database (Y/N)"
    choice = STDIN.gets.chomp.upcase
    operation_handler.rollback if choice == 'Y' 
    operation_handler.expand
    migration_recordkeeper.record_new_migration(migration_script)
    puts "Expand complete: new schema available at #{new_schema_search_path}"
  end

  def contract
    @database = database_connection_from_file
    migration_recordkeeper = MigrationRecordkeeper.new(@database)
    if !migration_recordkeeper.open_migration?
      puts "No open migration; cannot contract."
    end
    migration_script = migration_recordkeeper.open_migration
    script_hash = JSON.parse(migration_script)
    operation_handler = operation_handler_for_script(script_hash)
    operation_handler.contract
    migration_recordkeeper.remove_current_migration
    puts "Contract complete"
  end

  def rollback
    @database = database_connection_from_file
    migration_recordkeeper = MigrationRecordkeeper.new(@database)
    if !migration_recordkeeper.open_migration?
      puts "No open migration; cannot rollback."
    end
    migration_script = migration_recordkeeper.open_migration
    script_hash = JSON.parse(migration_script)
    operation_handler = operation_handler_for_script(script_hash)
    operation_handler.rollback
    migration_recordkeeper.remove_current_migration
    puts "Rollback complete"
  end
end