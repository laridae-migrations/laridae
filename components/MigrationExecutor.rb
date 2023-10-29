require_relative './DatabaseConnection'
require_relative './MigrationRecordkeeper'

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

  def initialize(db_url)
    @db_url = db_url
    # todo: handle invalid db url
    @database = DatabaseConnection.new(@db_url)
    @database.turn_off_notices
  end

  def new_schema_search_path
    if @db_url.include?("?")
      "#{@db_url}&currentSchema=laridae_after,public"
    else
      "#{@db_url}?currentSchema=laridae_after,public"
    end
  end

  def operation_handler_for_script(script)
    operation_name = script["operation"]
    HANDLERS_BY_OPERATION[operation_name].new(@database, script)
  end

  def init
    MigrationRecordkeeper.new(@database).create_open_migration_table
    @database.close
  end

  def cleanup(script_hash)
    operation_handler = operation_handler_for_script(script_hash)
    operation_handler.rollback
  end

  def expand(script_hash)
    migration_recordkeeper = MigrationRecordkeeper.new(@database)
    if migration_recordkeeper.open_migration?
      puts "Another migration is currently running; cannot continue."
      return
    end
    operation_handler = operation_handler_for_script(script_hash)
    operation_handler.expand
    migration_recordkeeper.record_new_migration(JSON.generate(script_hash))
    @database.close
    new_schema_search_path
  end

  def contract
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
    @database.close
  end

  def rollback
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
    @database.close
  end
end


