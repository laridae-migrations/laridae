require_relative './DatabaseConnection'
require_relative './MigrationRecordkeeper'
require_relative './DatabaseManipulator'

require_relative '../operations/AddColumn'
require_relative '../operations/AddUniqueConstraint'
require_relative '../operations/AddForeignKeyConstraint'
require_relative '../operations/AddNotNull'
require_relative '../operations/RenameColumn'
require_relative '../operations/AddCheckConstraint'
require_relative '../operations/DropColumn'
require_relative '../operations/CreateIndex'
require 'json'

class MigrationExecutor
  BEFORE_SCHEMA = "laridae_before"
  AFTER_SCHEMA = "laridae_after"
  TEMP_SCHEMA = "laridae_temp"
  DB_URL_FILENAME = "#{__dir__}/.laridae_database_url.txt"
  HANDLERS_BY_OPERATION = {
    "add_not_null" => AddNotNull,
    'rename_column' => RenameColumn,
    'add_check_constraint' => AddCheckConstraint,
    'drop_column' => DropColumn,
    'create_index' => CreateIndex,
    "add_column" => AddColumn,
    "add_unique_constraint" => AddUniqueConstraint,
    "add_foreign_key_constraint" => AddForeignKeyConstraint
  }
  def initialize
    @database = nil
    @migration_recordkeeper = nil
    @database_manipulator = nil
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
      "#{db_url}&currentSchema=#{AFTER_SCHEMA},public"
    else
      "#{db_url}?currentSchema=#{AFTER_SCHEMA},public"
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
    puts "Initialization complete."
  end

  def operation_handler_for_script(script)
    operation_name = script["operation"]
    HANDLERS_BY_OPERATION[operation_name].new(@database, script)
  end

  def migration_script_from_file(filename)
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
    if @migration_recordkeeper.open_migration?
      puts "Another migration is currently running; cannot continue."
      return
    end
    migration_script = migration_script_file.read
    JSON.parse(migration_script)
  end

  def expand(filename)
    @database = database_connection_from_file
    @database_manipulator = DatabaseManipulator.new(@database)
    @migration_recordkeeper = MigrationRecordkeeper.new(@database)
    script_object = migration_script_from_file(filename)
    puts "Should clean up be done on the database (Y/N)"
    choice = STDIN.gets.chomp.upcase
    if choice == 'Y'
      @database_manipulator.cleanup
    end
    before_snapshot = Snapshot.new(@database, BEFORE_SCHEMA)
    after_snapshot = Snapshot.new(@database, AFTER_SCHEMA)
    script_object.each do |operation|
      operation_handler = operation_handler_for_script(operation)
      operation_handler.expand_step(before_snapshot, after_snapshot)
    end
    before_snapshot.create
    after_snapshot.create
    @migration_recordkeeper.record_new_migration(script_object)
    puts "Expand complete: new schema available at #{new_schema_search_path}"
  end

  def contract
    @database = database_connection_from_file
    @database_manipulator = DatabaseManipulator.new(@database)
    @migration_recordkeeper = MigrationRecordkeeper.new(@database)
    if !@migration_recordkeeper.open_migration?
      puts "No open migration; cannot contract."
    end
    migration_script = @migration_recordkeeper.open_migration
    script_object = JSON.parse(migration_script)
    @database_manipulator.cleanup
    script_object.reverse.each do |operation|
      operation_handler = operation_handler_for_script(operation)
      operation_handler.contract_step
    end
    @migration_recordkeeper.remove_current_migration
    puts "Contract complete"
  end

  def rollback
    @database = database_connection_from_file
    @database_manipulator = DatabaseManipulator.new(@database)
    @migration_recordkeeper = MigrationRecordkeeper.new(@database)
    if !@migration_recordkeeper.open_migration?
      puts "No open migration; cannot rollback."
    end
    migration_script = @migration_recordkeeper.open_migration
    script_object = JSON.parse(migration_script)
    @database_manipulator.cleanup
    script_object.reverse.each do |operation|
      operation_handler = operation_handler_for_script(operation)
      operation_handler.rollback_step
    end
    @migration_recordkeeper.remove_current_migration
    puts "Rollback complete"
  end
end