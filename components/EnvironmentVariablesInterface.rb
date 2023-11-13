# frozen_string_literal: true

require_relative './Migration'
require_relative './MigrationRecord'
require_relative './DatabaseConnection'
require_relative './Validator'
require_relative './CommandLineInterface'
require 'json'

class EnvironmentVariablesInterface < CommandLineInterface
  ARGUMENTS_PER_COMMAND = {
    'init' => 0,
    'expand' => 1,
    'contract' => 0,
    'rollback' => 0,
    'restore' => 0
  }.freeze

  def initialize
    @db_url = ENV['DATABASE_URL']
  end

  def check_arguments_vs_command(action, arguments)
    if !ARGUMENTS_PER_COMMAND.key?(action)
      raise 'Invalid command action.'
    elsif ARGUMENTS_PER_COMMAND[action.downcase] > arguments.length
      raise 'Missing required argument.'
    end
  end

  def check_env_variables_sufficient
    raise 'Missing required environment variable ACTION.' unless ENV.key?('ACTION')
    raise 'Missing required environment variable DATABASE_URL.' unless ENV.key?('DATABASE_URL')
    if ENV['ACTION'] == 'expand'
      raise 'Missing required environment variable SCRIPT.' unless ENV.key?('SCRIPT')
    end
  end

  def run_command
    check_env_variables_sufficient
    action = ENV['ACTION']
    send(action, ENV['SCRIPT'])
  rescue StandardError => e
    puts "Error occured: #{e.message}"
    puts 'Command cannot be executed.'
  end

  def init
    db_conn = DatabaseConnection.new(@db_url)
    MigrationRecord.new(db_conn).initialize_laridae
    puts 'Initialization successful.'
  rescue PG::Error => e
    puts 'Cannot connect to database. Initializaion terminated.'
  rescue StandardError => e
    puts "Error occured: #{e.message}"
    puts 'Initialization terminated.'
  ensure
    db_conn&.close
  end

  def validate_script(db_conn, script)
    validation_result = Validator.run_with_script(db_conn, script)
    raise "#{validation_result['message']}." unless validation_result['valid']
  end

  def expand(migration_script)
    db_conn = DatabaseConnection.new(@db_url)
    record = MigrationRecord.new(db_conn)
    record.initialize_laridae
    validate_script(db_conn, migration_script)
    migration_script_json = JSON.parse(migration_script)
    Migration.new(db_conn, record, migration_script_json).expand
  rescue StandardError => e
    puts "Error occured: #{e.message}"
    puts 'Expand terminated.'
  ensure
    db_conn&.close
  end

  # contract, rollback, restore inherits from CLI
end
