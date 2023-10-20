# frozen_string_literal: true

# rubocop:disable Metrics/MethodLength
# rubocop:disable Metrics/ClassLength
require_relative './DatabaseConnection'

# This class is meant to be run as class method
# such as Validator.new(db, script).run
# which will return an object validating the
# migration script is valid or not
class Validator
  def self.run(db_connection, script_hash)
    operation_name = script_hash['operation']

    checks = send(operation_name, db_connection, script_hash) if respond_to?(operation_name)

    checks.each do |check_result|
      return check_result unless check_result['valid']
    end
    { 'valid' => true }
  end

  #=======================================================
  # VALIDATOR METHODS CORRESPONDING TO OPERATIONS
  def self.add_not_null(db, script_hash)
    [check_schema_table_column_exist(db, script_hash),
     check_column_does_not_contain_unsupported_constraints(db, script_hash)]
  end

  def self.add_check_constraint(db, script_hash)
    [check_schema_table_column_exist(db, script_hash),
     check_column_does_not_contain_unsupported_constraints(db, script_hash)]
  end

  def self.drop_column(db, script_hash)
    [check_schema_table_column_exist(db, script_hash),
     check_column_does_not_contain_unsupported_constraints(db, script_hash)]
  end

  def self.rename_column(db, script_hash)
    schema = script_hash['info']['schema']
    table = script_hash['info']['table']
    new_name = script_hash['info']['new_name']

    [check_schema_table_column_exist(db, script_hash),
     check_name_valid(new_name),
     check_name_not_taken(db, schema, table, new_name)]
  end

  def self.create_index(db, script_hash)
    [check_schema_table_column_exist(db, script_hash)]
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
      return check_result unless check_result['valid']
    end
    { 'valid' => true }
  end

  def self.check_schema_exists(db, schema)
    sql = <<~SQL
      SELECT schema_name FROM information_schema.schemata#{' '}
       WHERE schema_name = '#{schema}';
    SQL

    result = db.query(sql)
    if result.num_tuples.zero?
      { 'valid' => false, 'message' => 'Schema does not exist' }
    else
      { 'valid' => true }
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
      { 'valid' => false, 'message' => 'Table does not exist' }

    else
      { 'valid' => true }
    end
  end

  def self.check_column_exists(db, schema, table, column)
    sql = <<~SQL
      SELECT column_name FROM information_schema.columns
        WHERE table_schema = '#{schema}'
        AND table_name = '#{table}'
        AND column_name = '#{column}';
    SQL

    result = db.query(sql)
    if result.num_tuples.zero?
      { 'valid' => false, 'message' => 'Column does not exist' }
    else
      { 'valid' => true }
    end
  end

  #=======================================================
  # Check that the specified column is not a PRIMARY KEY 
  # or is a reference to a FOREIGN KEY
  def self.check_column_does_not_contain_unsupported_constraints(db, script_hash)
    schema = script_hash['info']['schema']
    table = script_hash['info']['table']
    column = script_hash['info']['column']

    checks = [check_column_is_not_primary_key(db, schema, table, column),
              check_column_is_not_fkey_reference(db, schema, table, column)]

    checks.each do |check_result|
      return check_result unless check_result['valid']
    end
    { 'valid' => true }
  end

  def self.check_column_is_not_primary_key(db, schema, table, column)
    sql = <<~SQL
      SELECT *
      FROM information_schema.key_column_usage AS c
        JOIN information_schema.table_constraints AS t
        ON t.constraint_name = c.constraint_name
      WHERE c.constraint_schema = '#{schema}'
        AND t.table_name = '#{table}'#{' '}
        AND c.column_name = '#{column}'
        AND t.constraint_type = 'PRIMARY KEY';
    SQL

    result = db.query(sql)

    if result.num_tuples.zero?
      { 'valid' => true }
    else
      { 'valid' => false, 'message' => 'Column has a Primary Key constraint' }
    end
  end

  def self.check_column_is_not_fkey_reference(db, schema, table, column)
    sql = <<~SQL
      SELECT *#{' '}
      FROM pg_constraint c#{' '}
      WHERE c.confrelid = (SELECT oid FROM pg_class#{' '}
                            WHERE relnamespace = (SELECT oid FROM pg_namespace#{' '}
                                                    WHERE nspname = '#{schema}')#{' '}
                            AND relname = '#{table}')
            AND c.confkey @> (SELECT array_agg(attnum) FROM pg_attribute#{' '}
                              WHERE attname = '#{column}'#{' '}
                              AND attrelid = c.confrelid);
    SQL

    result = db.query(sql)

    if result.num_tuples.zero?
      { 'valid' => true }
    else
      { 'valid' => false, 'message' => 'Column is referenced in a Foreign Key constraint' }
    end
  end

  #=======================================================
  # PostgreSQL column names only contains a-zA-Z0-9 and underscores(_), and cannot start with numbers
  def self.check_name_valid(name)
    if name.match(/[^0-9a-z_]/i)
      { 'valid' => false, 'message' => 'Name contain invalid character(s)' }
    elsif !name.match(/^[_a-z]/i)
      { 'valid' => false, 'message' => 'Name can only starts with alphabetical characters or underscore' }
    else
      { 'valid' => true }
    end
  end

  # check that there isn't already another column with the same name
  def self.check_name_not_taken(db, schema, table, new_column_name)
    sql = <<~SQL
      SELECT column_name FROM information_schema.columns
        WHERE table_schema = '#{schema}'
        AND table_name = '#{table}'
        AND column_name = '#{new_column_name}';
    SQL

    result = db.query(sql)

    if result.num_tuples.zero?
      { 'valid' => true }
    else
      { 'valid' => false, 'message' => 'New column name already exists' }
    end
  end
end
# rubocop:enable Metrics/MethodLength
# rubocop:enable Metrics/ClassLength
