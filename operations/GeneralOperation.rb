# frozen_string_literal: true
require_relative '../components/Table'
require_relative '../components/Database'

# superclass for all operations
class GeneralOperation
  def initialize(db_conn, script)
    @script = script
    @database = Database.new(db_conn, script)

    schema = script['info']['schema']
    table = script['info']['table']
    @table = Table.new(db_conn, schema, table)

    @column = script['info']['column']
  end

  def create_before_view(before_view)
    @database.create_view('laridae_before', @table.schema, @table.name, @table.columns_in_view(before_view))
  end

  def create_after_view(after_view)
    @database.create_view("laridae_#{@script['name']}", @table.schema, @table.name, @table.columns_in_view(after_view))
  end

  def rollback
    @database.teardown_created_schemas
  end

  def contract
    @database.teardown_created_schemas
  end

  def rename_propagated_constraints(constraints_to_be_renamed)
    unless constraints_to_be_renamed.empty?
      constraints_to_be_renamed.each do |pair|
        @table.rename_constraint(pair[0], pair[1])
      end
    end
  end
end
