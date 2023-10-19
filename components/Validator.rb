# frozen_string_literal: true

# rubocop:disable Metrics/MethodLength
require_relative './DatabaseConnection'

# This class is meant to be run as class method
# such as Validator.new(db, script).run
# which will return an object validating the
# migration script is valid or not
class Validator
  def self.run(db_connection, script_hash)
    operation_name = script_hash['operation']
    send(operation_name, db_connection, script_hash) if respond_to?(operation_name)
  end

  #=======================================================
  # VALIDATOR METHODS CORRESPONDING TO OPERATIONS
  def self.add_not_null(db, script_hash)
    check_schema_table_column_exist(db, script_hash)
  end

  def self.add_check_constraint(db, script_hash)
    check_schema_table_column_exist(db, script_hash)
  end

  def self.drop_column(db, script_hash)
    check_schema_table_column_exist(db, script_hash)
  end

  def self.rename_column(db, script_hash)
    check = check_schema_table_column_exist(db, script_hash)
    return check unless check[:valid]

    new_name = script_hash['info']['new_name']
    check_name_valid(new_name)
  end

  #=======================================================
  # Check if table, schema, column given in script_hash are valid
  def self.check_schema_table_column_exist(db, script_hash)
    schema = script_hash['info']['schema']
    table = script_hash['info']['table']
    column = script_hash['info']['column']

    schema_check = check_schema_exists(db, schema)
    table_check = check_table_exists(db, schema, table)
    column_check = check_column_exists(db, schema, table, column)

    checks = [schema_check, table_check, column_check]
    checks.each do |check_result|
      return check_result unless check_result[:valid]
    end
    { valid: true }
  end

  def self.check_schema_exists(db, schema)
    sql = <<~SQL
      SELECT schema_name FROM information_schema.schemata#{' '}
       WHERE schema_name = '#{schema}';
    SQL

    result = db.query(sql)
    if result.num_tuples.zero?
      { valid: false, error: 'Schema does not exist' }
    else
      { valid: true }
    end
  end

  def self.check_table_exists(db, schema, table)
    sql = <<~SQL
      SELECT table_name FROM information_schema.tables
        WHERE table_schema = '#{schema}'
        AND table_name = '#{table}';
    SQL

    result = db.query(sql)
    if result.num_tuples.zero?
      { valid: false, error: 'Table does not exist' }

    else
      { valid: true }
    end
  end

  def self.check_column_exists(db, schema, table, column)
    sql = <<~SQL
      SELECT column_name FROM information_schema.columns#{' '}
        WHERE table_schema = '#{schema}'
        AND table_name = '#{table}'#{' '}
        AND column_name = '#{column}';
    SQL

    result = db.query(sql)
    if result.num_tuples.zero?
      { valid: false, error: 'Column does not exist' }
    else
      { valid: true }
    end
  end

  #=======================================================
  def self.check_name_valid(name)
    if name.match(/[^0-9a-z_]/i)
      { valid: false, message: 'Name contain invalid character(s)' }
    elsif !name.match(/^[_a-z]/i)
      { valid: false, message: 'Name can only starts with alphabetical characters or underscore' }
    else
      { valid: true }
    end
  end
end
# rubocop:enable Metrics/MethodLength
