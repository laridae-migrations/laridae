# frozen_string_literal: true

require_relative '../components/Table'
require_relative '../components/Database'

class AddNotNull
  def initialize(db_conn, script)
    @script = script
    @database = Database.new(db_conn, script)

    schema = script['info']['schema']
    table = script['info']['table']
    @table = Table.new(db_conn, schema, table)

    @column = script['info']['column']
    @new_column = "laridae_new_#{@column}"
    @constraint_name = "laridae_constraint_#{@column}_not_null"
    @functions = script['functions']
  end

  def rollback
    @database.teardown_created_schemas
    @table.drop_column(@new_column)
    @table.remove_constraint(@constraint_name)
  end

  # rubocop:disable Metrics/AbcSize
  def expand
    constraint = "CHECK (#{@new_column} IS NOT NULL) NOT VALID"
    before_view = { @new_column => nil }
    after_view = { @column => nil, @new_column => @column }

    @table.create_new_version_of_column(@column)
    @table.add_constraint(@constraint_name, constraint)
    @database.create_view('laridae_before', @table.schema, @table.name, @table.columns_in_view(before_view))
    @database.create_view("laridae_#{@script['name']}", @table.schema, @table.name, @table.columns_in_view(after_view))
    @database.create_trigger(@table, @column, @new_column, @functions['up'], @functions['down'])
    @table.backfill(@new_column, @functions['up'])
    @database.validate_constraint(@table.name, @constraint_name)
  end
  # rubocop:enable Metrics/AbcSize

  def contract
    @database.teardown_created_schemas
    @table.drop_column(@column)
    @table.rename_column(@new_column, @column)
    new_constraint_name = "constraint_#{@column}_not_null"
    @table.rename_constraint(@constraint_name, new_constraint_name)
  end
end
