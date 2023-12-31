# frozen_string_literal: true

require_relative './GeneralOperation'

class AddColumn < GeneralOperation
  def initialize(db_conn, script)
    super
    @constraints = []
    @functions = script['functions']
  end

  def rollback
    super
    @constraints.each do |constraint|
      @table.remove_constraint(constraint)
    end
    @table.drop_column(@column['name'])
  end

  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  def expand

    before_view = { @column => nil }
    after_view = { @column => @column }

    create_before_view(before_view)

    data_type = @column['type']
    default_value = @column['default']
    is_unique = @column['unique']
    @table.add_column(@column['name'], data_type, default_value, is_unique)

    if @column['nullable'] == false
      not_null_constraint = "CHECK (#{@column['name']} IS NOT NULL) NOT VALID"
      constraint_name = "#{@column['name']}_not_null"
      @table.add_constraint(constraint_name, not_null_constraint)
      @constraints.push(constraint_name)
    end

    if @column['check']
      # if check constraint, add constraint
      check_constraint = "CHECK (#{@column['check']['constraint']}) NOT VALID"
      constraint_name = @column['check']['name']
      @table.add_constraint(constraint_name, check_constraint)
      @constraints.push(constraint_name)
    end

    create_after_view(after_view)

    @table.create_trigger(@table, @column, @new_column, @functions['up'], @functions['down']) if @functions

    @constraints.each do |constraint|
      @table.validate_constraint(constraint)
    end
  end

  # contract: super
end
