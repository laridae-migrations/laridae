class DropColumnHandler
  def initialize(database, script)
    schema = script["info"]["schema"]
    table = script["info"]["table"]
    @column = script["info"]["column"]
    @table_manipulator = TableManipulator.new(database, schema, table)
  end

  def rollback
    @table_manipulator.cleanup
  end

  def expand
    before_view = {}
    after_view = {@column => nil}
    @table_manipulator.create_view("laridae_before", before_view)
    @table_manipulator.create_view("laridae_after", after_view)
  end

  def contract
    @table_manipulator.cleanup
    @table_manipulator.drop_column(@column)
  end
end