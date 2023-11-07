# frozen_string_literal: true

require_relative './Migration'
require_relative './MigrationRecord'
require_relative './DatabaseConnection'
require_relative './Validator'
require 'json'

class CommandLineInterface
  def initialize(command_line_arguments)
    @command_line_arguments = command_line_arguments
    @db_url = @command_line_arguments[1]
  end

  def run_command
    arguments_per_command = { 'init' => 2, 'expand' => 3, 'contract' => 2, 'rollback' => 2 }
    command = @command_line_arguments.first

    if !arguments_per_command.key?(command)
      puts 'Invalid command.'
    elsif arguments_per_command[command] > @command_line_arguments.length
      puts 'Missing required argument.'
    else
      arguments_to_take = arguments_per_command[command] - 1
      send(*@command_line_arguments[0..arguments_to_take])
    end
  end

  def init(_)
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

  def script_validated(db_conn, migration_file_location)
    validation_result = Validator.run_with_location(db_conn, migration_file_location)
    puts "#{validation_result['message']}. Expand did not start" unless validation_result['valid']
    validation_result['valid']
  end

  # rubocop:disable Metrics/MethodLength
  def expand(_, migration_file_location)
    db_conn = DatabaseConnection.new(@db_url)
    record = MigrationRecord.new(db_conn)
    if script_validated(db_conn, migration_file_location)
      migration_script_json = JSON.parse(File.read(migration_file_location))
      Migration.new(db_conn, record, migration_script_json).expand
    end
  rescue StandardError => e
    puts "Error occured: #{e.message}"
    puts 'Expand terminated.'
  ensure
    db_conn&.close
  end
  # rubocop:enable Metrics/MethodLength

  def contract(_)
    db_conn = DatabaseConnection.new(@db_url)
    record = MigrationRecord.new(db_conn)
    Migration.new(db_conn, record, record.last_migration['script']).contract
  rescue StandardError => e
    puts "Error occured: #{e.message}"
    puts 'Contract terminated.'
  ensure
    db_conn&.close
  end

  def rollback(_)
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
