# super class for all operation
class GeneralOperation
  def initialize(db_conn, script)
    @script = script
    @database = Database.new(db_conn, script)

    schema = script['info']['schema']
    table = script['info']['table']
    @table = Table.new(db_conn, schema, table)

    @column = script['info']['column']
  end

  def expand(before_view, after_view)
    @database.create_view('laridae_before', @table.schema, @table.name, @table.columns_in_view(before_view))
    @database.create_view("laridae_#{@script['name']}", @table.schema, @table.name, @table.columns_in_view(after_view))
  end

  def rollback
    @database.teardown_created_schemas
  end

  def contract
    @database.teardown_created_schemas
  end
end