class RenameColumnHandler
  def initialize(database, script)
    schema = script["info"]["schema"]
    table = script["info"]["table"]
    @column = script["info"]["column"]
    @new_name = script["info"]["new_name"]
    @table_manipulator = TableManipulator.new(database, schema, table)
  end

  def rollback
    @table_manipulator.cleanup
  end

  def expand
    constraint = "CHECK (#{@new_column} IS NOT NULL) NOT VALID"
    before_view = {}
    after_view = {@column => @new_name}
    @table_manipulator.create_view("laridae_before", before_view)
    @table_manipulator.create_view("laridae_after", after_view)
  end

  def contract
    @table_manipulator.cleanup
    @table_manipulator.rename_column(@column, @new_name)
  end
end