# LARIDAE

### `add_not_null.rb`

A prototype of our functionality in a simple set use-case:

Adding the `NOT NULL` constraint to the `phone` column by:

- Create a column `phone_not_null` with the `NOT NULL` as a table constraint
- Create 2 views: `before` and `after`
- Add triggers to propagate data between `phone` and `phone_not_null` on inserts and updates
- Backfilling `phone_not_null` with `'0000000000'`
- Validate the table `NOT NULL` constraint
- Prompt the user whether or not to contract: delete all views, triggers, functions, delete `phone`, rename `phone_not_null` to `phone`
