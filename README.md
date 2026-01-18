# mysql_diff
MySQL Data Diff by one storage procedure. Simple and fast :)

Sometimes you want to see what data will be changed in the database.


For example:
```
table_name | pk_value | column_name | value_db1 | value_db2
-----------+----------+-------------+-----------+-----------
users      | 15       | status      | active    | blocked
products   | 77       | price       | 500       | 520
orders     | 2031     | total       | 100       | 120
```

This repository contains a stored procedure that generates such a report.

# Usage:
1) Prepare two DB for compare (for example: db1 and db2)

2) In db1 create table diff_report (temporary table for compare), just run in mysql cli:
   `SOURCE ./diff_report_table.sql`

3) In db1 create procedure for compare, just run:
   `SOURCE ./diff_procedure.sql`

4) And call this procedure:
  `CALL compare_databases_to_report('db1', 'db2');`

That it, next see diff_report table in your db1.
