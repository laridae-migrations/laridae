require_relative '../operations/AddNotNullHandler'
require_relative '../operations/add_column'
require_relative '../operations/set_unique'
require_relative '../operations/set_fk'
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
    'create_index' => CreateIndex,
    "add_column" => AddColumnHandler,
    "set_unique" => SetUniqueHandler,
    "set_foreign_key" => SetForeignKeyHandler
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


