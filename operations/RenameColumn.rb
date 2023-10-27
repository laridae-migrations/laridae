require_relative '../components/TableManipulator'
require_relative './Operation'
class RenameColumn < Operation
  def initialize(database, script)
    super(database)
    schema = script["info"]["schema"]
    table = script["info"]["table"]
    @column = script["info"]["column"]
    @new_name = script["info"]["new_name"]
    @table_manipulator = TableManipulator.new(database, schema, table)
  end

  def rollback_step; end

  def expand_step(after_view)
    constraint = "CHECK (#{@new_column} IS NOT NULL) NOT VALID"
    after_view[@column] = @new_name
    @table_manipulator.create_view("laridae_after", after_view)
  end

  def contract_step
    @table_manipulator.rename_column(@column, @new_name)
  end
end