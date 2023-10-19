class AddCheckConstraintHandler
  def initialize(database, script)
    schema = script["info"]["schema"]
    table = script["info"]["table"]
    @column = script["info"]["column"]
    @table_manipulator = TableManipulator.new(database, schema, table)
    @new_column = "laridae_new_#{@column}"
    @constraint_name = "laridae_constraint_#{@column}_check"
    # ideally we want to check to make sure they don't reference any other columns
    # in the check constraint
    @condition = script["info"]["condition"].gsub(@column, @new_column)
    @functions = script["functions"]
  end

  def rollback
    @table_manipulator.cleanup
    @table_manipulator.drop_column(@new_column)
    @table_manipulator.remove_constraint(@constraint_name)
  end

  def expand
    constraint = "CHECK (#{@condition}) NOT VALID"
    before_view = {@new_column => nil}
    after_view = {@column => nil, @new_column => @column}
    @table_manipulator.create_new_version_of_column(@column)
    @table_manipulator.add_constraint(@constraint_name, constraint)
    @table_manipulator.create_view("laridae_before", before_view)
    @table_manipulator.create_view("laridae_after", after_view)
    @table_manipulator.create_trigger(@column, @new_column, @functions["up"], @functions["down"])
    @table_manipulator.backfill(@new_column, @functions["up"])
    @table_manipulator.validate_constraint(@constraint_name)
  end

  def contract
    @table_manipulator.cleanup
    @table_manipulator.drop_column(@column)
    @table_manipulator.rename_column(@new_column, @column)
    new_constraint_name = "constraint_#{@column}_check"
    @table_manipulator.rename_constraint(@constraint_name, new_constraint_name)
  end
end