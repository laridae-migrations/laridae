require_relative './MigrationExecutor'

class CommandLineInterface
  DB_URL_FILENAME = "#{__dir__}/.laridae_database_url.txt"

  def initialize(command_line_arguments)
    @command_line_arguments = command_line_arguments
  end
  
  def run_command
    arguments_per_command = {"init" => 2, "expand" => 2, "contract" => 1, "rollback" => 1}
    command = @command_line_arguments[0]
    if !arguments_per_command.key?(command)
      puts "Invalid command."
      return
    end
    if arguments_per_command[command] > @command_line_arguments.length
      puts "Missing required argument."
      return
    elsif arguments_per_command[command] < @command_line_arguments.length
      puts "Extra arguments supplied."
      return
    end
    send(*@command_line_arguments)
  end

  def database_url_from_file
    db_url_file = File.open(DB_URL_FILENAME)
    db_url = db_url_file.read
    db_url_file.close
    db_url
  end

  def init(db_url)
    # todo: handle this situation better
    if File.exist?(DB_URL_FILENAME)
      puts "Note: previously initialized; overwriting."
    end
    db_url_file = File.open(DB_URL_FILENAME, 'w')
    db_url_file.write(db_url)
    db_url_file.close
    MigrationExecutor.new(db_url).init
    puts "Initialization successful."
  end

  def expand(filename)
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
    database_url = database_url_from_file
    migration_script = migration_script_file.read
    script_hash = JSON.parse(migration_script)
    migration_executor = MigrationExecutor.new(database_url)
    puts "Should clean up be done on the database (Y/N)"
    choice = STDIN.gets.chomp.upcase
    if choice == 'Y'
      migration_executor.cleanup(script_hash)
    end
    new_schema_search_path = migration_executor.expand(script_hash)
    if new_schema_search_path
      puts "Expand complete: new schema available at #{new_schema_search_path}"
    end
  end

  def contract
    database_url = database_url_from_file
    MigrationExecutor.new(database_url).contract
  end

  def rollback
    database_url = database_url_from_file
    MigrationExecutor.new(database_url).rollback
  end
end