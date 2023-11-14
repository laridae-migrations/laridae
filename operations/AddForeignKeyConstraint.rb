# frozen_string_literal: true

require_relative './GeneralOperation'

class AddForeignKeyConstraint < GeneralOperation
  def initialize(db_conn, script)
    # @script_hash = script
    # schema = script["info"]["schema"]
    # @table = script["info"]["table"]
    # @column = script["info"]["column"]
    # @table_manipulator = TableManipulator.new(database, schema, @table)
    super
    @new_column = "laridae_new_#{@column['name']}"
    @constraint_name = @column['references']['name']
    @functions = script['functions']
  end

  def rollback
    super
    @table.drop_column(@new_column)
    @table.remove_constraint(@constraint_name)
  end

  def expand
    constraint = "FOREIGN KEY (#{@new_column}) REFERENCES #{@column['references']['table']} (#{@column['references']['column']}) NOT VALID"

    before_view = { @new_column => nil }
    after_view = { @column['name'] => nil, @new_column => @column['name'] }

    data_type = @table.column_type(@column['name'])
    default_value = @table.get_column_default_value(@column['name'])
    is_unique = false

    @table.add_column(@new_column, data_type, default_value, is_unique)
    super(before_view, after_view)

    @table.add_constraint(@constraint_name, constraint)
    @database.create_trigger(@table, @column['name'], @new_column, @functions['up'], @functions['down'])
    @table.backfill(@new_column, @functions['up'])
    @database.validate_constraint(@table.name, @constraint_name)
  end

  def contract
    super
    @table.drop_column(@column['name'])
    @table.rename_column(@new_column, @column['name'])
    # don't need to rename constraint cuz provided by client
  end
end
