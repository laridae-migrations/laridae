require_relative './MigrationExecutor'
require 'json'

class EnvironmentVariablesInterface
  def initialize
    @database_url = ENV['DATABASE_URL']
  end

  def run_command
    if !ENV.key?('ACTION')
      puts "Missing required environment variable ACTION."
      return
    end
    action = ENV['ACTION']
    arguments = []
    if ENV.key?('SCRIPT')
      arguments.push(ENV['SCRIPT'])
    end
    # todo: verify action is in expected list to avoid weird errors
    send(action, *arguments)
  end

  def init
    MigrationExecutor.new(@database_url).init
    puts "Initialization successful."
  end

  def expand(migration_script)
    # todo: add error handling
    script_hash = JSON.parse(migration_script)
    migration_executor = MigrationExecutor.new(@database_url)
    new_schema_search_path = migration_executor.expand(script_hash)
    if new_schema_search_path
      puts "Expand complete: new schema available at #{new_schema_search_path}"
    end
  end

  def contract
    MigrationExecutor.new(@database_url).contract
  end

  def rollback
    MigrationExecutor.new(@database_url).rollback
  end
end