require_relative '../components/TableManipulator'
class CreateIndex
  def initialize(database, script)
    schema = script["info"]["schema"]
    @table = script["info"]["table"]
    @column = script["info"]["column"]
    @new_column = "laridae_new_#{@column}"
    @index = "laridae_index_#{@table}_#{@column}"
    @method = script["info"]["method"]
    @table_manipulator = TableManipulator.new(database, schema, @table)
  end

  def rollback
    @table_manipulator.cleanup
    @table_manipulator.drop_index(@index)
    @table_manipulator.drop_column(@new_column)
  end

  def expand
    before_view = {@new_column => nil}
    after_view = {@column => nil, @new_column => @column}
    @table_manipulator.create_new_version_of_column(@column)
    @table_manipulator.create_index(@index, @method, @new_column)
    @table_manipulator.create_view("laridae_before", before_view)
    @table_manipulator.create_view("laridae_after", after_view)
    @table_manipulator.create_trigger(@column, @new_column, @column, @column)
    @table_manipulator.backfill(@new_column, @column)
  end

  def contract
    @table_manipulator.cleanup
    @table_manipulator.drop_column(@column)
    @table_manipulator.rename_column(@new_column, @column)
    new_index_name = "index_#{@table}_#{@column}"
    @table_manipulator.rename_index(@index, new_index_name)
  end
end