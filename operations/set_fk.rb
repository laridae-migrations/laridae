class SetForeignKeyHandler
  def initialize(database, script)
    schema = script["info"]["schema"]
    @table = script["info"]["table"]
    @column = script["info"]["column"]
    @table_manipulator = TableManipulator.new(database, schema, @table)
    @new_column = "laridae_new_#{@column["name"]}"
    @constraint_name = @column["references"]["name"]
    @functions = script["functions"]
  end

  def rollback
    @table_manipulator.cleanup
    @table_manipulator.drop_column(@new_column)
    @table_manipulator.remove_constraint(@constraint_name)
  end

  def expand
    constraint = "FOREIGN KEY (#{@new_column}) REFERENCES #{@column["references"]["table"]} (#{@column["references"]["column"]}) NOT VALID"
    before_view = {@new_column => nil}
    after_view = {@column["name"] => nil, @new_column => @column["name"]}
    data_type = @table_manipulator.get_column_type(@column["name"])
    default_value = @table_manipulator.get_column_default_value(@column["name"])
    is_unique = false

    @table_manipulator.add_column(@table, @new_column, data_type, default_value, is_unique)
    @table_manipulator.add_constraint(@constraint_name, constraint)
    @table_manipulator.create_view("laridae_before", before_view)
    @table_manipulator.create_view("laridae_after", after_view)
    p @functions
    @table_manipulator.create_trigger(@column["name"], @new_column, @functions["up"], @functions["down"])
    @table_manipulator.backfill(@new_column, @functions["up"])
    @table_manipulator.validate_constraint(@constraint_name)
  end

  def contract
    @table_manipulator.cleanup
    @table_manipulator.drop_column(@column)
    @table_manipulator.rename_column(@new_column, @column)
    # don't need to rename constraint cuz provided by client
  end
end

# script = {
#   operation: "add_new_column",
#   info: {
#     schema: "public",
#     table: "employees",
#     column: {
#       name: "phone_number",
#       type: varchar(15),
#       default: "1-XXX-XXX-XXXX",
#       nullable: true,
#       unique: false,
#       pk: false,
#       check: {
#         name: "",
#         constraint: "",
#       },
#       references: {
#         name: "fk_employees_id",
#         table: "employees",
#         column: "id"
#       },
#     },
#   },
#   functions: {
#     up: "CASE WHEN phone IS NULL THEN '0000000000' ELSE phone END",
#     down: "phone"
#   }
# }
# need to update 