require_relative '../components/TableManipulator'
class AddUniqueConstraint
  def initialize(database, script)
    schema = script["info"]["schema"]
    @table = script["info"]["table"]
    @column = script["info"]["column"]
    @table_manipulator = TableManipulator.new(database, schema, @table)
    @new_column = "laridae_new_#{@column["name"]}"
    @unique_constraint_name = "#{@new_column}_unique"
    @functions = script["functions"]
  end

  def rollback
    @table_manipulator.cleanup
    @table_manipulator.drop_column(@new_column)
    @table_manipulator.remove_constraint(@unique_constraint_name)
  end

  def expand
    unique_constraint = "CHECK (UNIQUE) NOT VALID"
    before_view = {@new_column => nil}
    after_view = {@column["name"] => nil, @new_column => @column["name"]}
    data_type = @table_manipulator.get_column_type(@column["name"])
    default_value = @table_manipulator.get_column_default_value(@column["name"])
    is_unique = true
    @table_manipulator.add_column(@table, @new_column, data_type, default_value, is_unique)
    # @table_manipulator.add_constraint(@unique_constraint_name, unique_constraint)
    @table_manipulator.create_view("laridae_before", before_view)
    @table_manipulator.create_view("laridae_after", after_view)


    if @functions
      @table_manipulator.create_trigger(@column, @new_column, @functions["up"], @functions["down"])
      @table_manipulator.backfill(@new_column, @functions["up"])

    end
    # @table_manipulator.validate_constraint(@unique_constraint_name)
  end

  def contract
    @table_manipulator.cleanup
    @table_manipulator.drop_column(@column["name"])
    @table_manipulator.rename_column(@new_column, @column["name"])
    new_constraint_name = "constraint_#{@column["name"]}_unique"
    @table_manipulator.rename_constraint(@unique_constraint_name, new_constraint_name)
  end
end