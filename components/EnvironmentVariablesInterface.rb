# frozen_string_literal: true

require_relative './Migration'
require_relative './MigrationRecord'
require_relative './DatabaseConnection'
require_relative './Validator'
require 'json'

class EnvironmentVariablesInterface
  def initialize
    @db_url = ENV['DATABASE_URL']
  end

  def run_command
    unless ENV.key?('ACTION')
      puts 'Missing required environment variable ACTION.'
      return
    end
    action = ENV['ACTION']
    arguments = []
    arguments.push(ENV['SCRIPT']) if ENV.key?('SCRIPT')
    # TODO: verify action is in expected list to avoid weird errors
    send(action, *arguments)
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

  def script_validated(db_conn, script)
    validation_result = Validator.run_with_script(db_conn, script)
    puts "#{validation_result['message']}. Expand did not start" unless validation_result['valid']
    validation_result['valid']
  end

  def expand(migration_script)
    db_conn = DatabaseConnection.new(@db_url)
    record = MigrationRecord.new(db_conn)
    Migration.new(db_conn, record, migration_script).expand if script_validated(db_conn, migration_script)
  rescue StandardError => e
    puts "Error occured: #{e.message}"
    puts 'Expand terminated.'
  ensure
    db_conn&.close
  end

  def contract
    db_conn = DatabaseConnection.new(@db_url)
    record = MigrationRecord.new(db_conn)
    Migration.new(db_conn, record, record.last_migration['script']).contract
  rescue StandardError => e
    puts "Error occured: #{e.message}"
    puts 'Contract terminated.'
  ensure
    db_conn&.close
  end

  def rollback
    db_conn = DatabaseConnection.new(@db_url)
    record = MigrationRecord.new(db_conn)
    Migration.new(db_conn, record, record.last_migration['script']).rollback
  rescue StandardError => e
    puts "Error occured: #{e.message}"
    puts 'Rollback terminated.'
  ensure
    db_conn&.close
  end
  end
end
