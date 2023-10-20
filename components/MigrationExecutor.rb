# rubocop:disable allcops
BATCH_SIZE = 400

class MigrationExecutor
  def initialize
    @database = nil
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