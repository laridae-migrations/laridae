require_relative "../components/DatabaseManipulator"
require_relative "../components/MigrationExecutor"
# maybe put constants in another file to avoid previous import?

class Operation
  def intitialize(database)
    @database = database
    @database_manipulator = DatabaseManipulator.new(@database)
  end

  def expand
    before_snapshot = Snapshot.new(@database, MigrationExecutor.BEFORE_SCHEMA)
    after_snapshot = Snapshot.new(@database, MigrationExecutor.AFTER_SCHEMA)
    expand_step(before_snapshot, after_snapshot)
    before_snapshot.create
    after_snapshot.create
  end

  def contract
    @database_manipulator.cleanup
    contract_step
  end

  def rollback
    @database_manipulator.cleanup
    rollback_step
  end
end