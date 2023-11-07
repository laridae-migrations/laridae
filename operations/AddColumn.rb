require_relative '../components/TableManipulator'
class AddColumn
  def initialize(database, script)
    schema = script["info"]["schema"]
    @table = script["info"]["table"]
    @column = script["info"]["column"]
    @table_manipulator = TableManipulator.new(database, schema, @table)
    @constraints = []
    @functions = script["functions"]
  end

  def rollback
    @table_manipulator.cleanup
    @constraints.each do |constraint|
      @table_manipulator.remove_constraint(constraint)
    end
  end

  def expand
    # p @column
    data_type = @column["type"]
    default_value = @column["default"]
    # add column
    is_unique = @column["unique"]
    p is_unique
    @table_manipulator.add_column(@table, @column["name"], data_type, default_value, is_unique)

    if !@column["nullable"].nil?
      # if nullable is true, than we allow null values
      if !@column["nullable"]
        not_null_constraint = "CHECK (#{@column["name"]} IS NOT NULL) NOT VALID"
        constraint_name = "#{@column["name"]}_not_null"
        @table_manipulator.add_constraint(constraint_name, not_null_constraint)
        @constraints.push(constraint_name)
      end
    end

    if @column["check"]
      # if check constraint, add constraint
      check_constraint = "CHECK (#{@column["check"]["constraint"]}) NOT VALID"
      constraint_name = @column["check"]["name"]
      @table_manipulator.add_constraint(constraint_name, check_constraint)
      @constraints.push(constraint_name)
    end 

    before_view = {@column => nil}
    after_view = {@column => @column}
    @table_manipulator.create_view("laridae_before", before_view)
    @table_manipulator.create_view("laridae_after", after_view)

    # do we support having one of functions but not both?
    if @functions
      @table_manipulator.create_trigger(@column, @new_column, @functions["up"], @functions["down"])
    end

    # should we validate our constraints when contracting???
    # validate multiple constraints
    @constraints.each do |constraint|
      @table_manipulator.validate_constraint(constraint)
    end
    
  end

  def contract
    @table_manipulator.cleanup
  end
end

# script = {
#   operation: "add_column",
#   info: {
#     schema: "public",
#     table: "employees",
#     column: {
#       name: "phone_number",
#       type: varchar(15),
#       default: "1-XXX-XXX-XXXX",
#       nullable: true,
#       unique: true,
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