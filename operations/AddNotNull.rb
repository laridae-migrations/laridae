require_relative '../components/TableManipulator'
require_relative './Operation'
class AddNotNull < Operation
  def initialize(database, script)
    super(database)
    schema = script["info"]["schema"]
    table = script["info"]["table"]
    @column = script["info"]["column"]
    @table_manipulator = TableManipulator.new(database, schema, table)
    @new_column = "laridae_new_#{@column}"
    @constraint_name = "laridae_constraint_#{@column}_not_null"
    @functions = script["functions"]
  end

  def rollback
    @table_manipulator.cleanup
    @table_manipulator.drop_column(@new_column)
    @table_manipulator.remove_constraint(@constraint_name)
  end

  def expand_step(after_view)
    constraint = "CHECK (#{@new_column} IS NOT NULL) NOT VALID"
    after_view[@column] = nil
    after_view[@new_column] = @column
    @table_manipulator.create_new_version_of_column(@column)
    @table_manipulator.add_constraint(@constraint_name, constraint)
    @table_manipulator.create_view("laridae_after", after_view)
    @table_manipulator.create_trigger(@column, @new_column, @functions["up"], @functions["down"])
    @table_manipulator.backfill(@new_column, @functions["up"])
    @table_manipulator.validate_constraint(@constraint_name)
  end

  def contract
    @table_manipulator.cleanup
    @table_manipulator.drop_column(@column)
    @table_manipulator.rename_column(@new_column, @column)
    new_constraint_name = "constraint_#{@column}_not_null"
    @table_manipulator.rename_constraint(@constraint_name, new_constraint_name)
  end
end