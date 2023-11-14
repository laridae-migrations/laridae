# frozen_string_literal: true

require_relative './Migration'
require_relative './MigrationRecord'
require_relative './DatabaseConnection'
require_relative './Validator'
require 'json'

# rubocop:disable Metrics/MethodLength
class CommandLineInterface
  ARGUMENTS_PER_COMMAND = {
    'init' => 2,
    'expand' => 3,
    'contract' => 2,
    'rollback' => 2,
    'restore' => 2
  }.freeze

  def initialize(command_line_arguments)
    @command_line_arguments = command_line_arguments
    @db_url = @command_line_arguments[1]
  end

  def run_command
    command = @command_line_arguments.first.downcase
    if !ARGUMENTS_PER_COMMAND.key?(command)
      puts 'Invalid command.'
    elsif ARGUMENTS_PER_COMMAND[command] > @command_line_arguments.length
      puts 'Missing required argument.'
    else
      arguments_to_take = ARGUMENTS_PER_COMMAND[command] - 1
      send(*@command_line_arguments[0..arguments_to_take])
    end
  rescue StandardError => e
    puts "Error occured: #{e.message}"
    puts 'Command cannot be executed.'
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

  def expand(_, migration_file_location)
    db_conn = DatabaseConnection.new(@db_url)
    record = MigrationRecord.new(db_conn)
    validate_script(db_conn, migration_file_location)
    migration_script_json = JSON.parse(File.read(migration_file_location))
    Migration.new(db_conn, record, migration_script_json).expand
    puts "New schema can be accessed using the search_path: #{new_schema_search_path(migration_script_json['name'])}"
  rescue StandardError => e
    puts "Error occured: #{e.message}"
    puts 'Expand terminated.'
  ensure
    db_conn&.close
  end

  def contract(_)
    db_conn = DatabaseConnection.new(@db_url)
    record = MigrationRecord.new(db_conn)
    raise 'There is no active migration to contract' unless record.last_migration_expanded?

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

  def restore(_)
    db_conn = DatabaseConnection.new(@db_url)
    record = MigrationRecord.new(db_conn)
    raise 'There is no migration eligible to restore' unless record.last_migration_aborted?

    Migration.new(db_conn, record, record.last_migration['script']).restore
    # rescue StandardError => e
    puts "Error occured: #{e.message}"
    puts 'Restore terminated.'
  ensure
    db_conn&.close
  end

  def validate_script(db_conn, migration_file_location)
    validation_result = Validator.run_with_location(db_conn, migration_file_location)
    raise "#{validation_result['message']}." unless validation_result['valid']

    validation_result['valid']
  end

  def new_schema_search_path(migration_name)
    if @db_url.include?('?')
      "#{@db_url}&options=-csearch_path%3Dlaridae_#{migration_name},public"
    else
      "#{@db_url}?options=-csearch_path%3Dlaridae_#{migration_name},public"
    end
  end
end
# rubocop:enable Metrics/MethodLength
