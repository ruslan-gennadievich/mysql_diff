DELIMITER $$

CREATE PROCEDURE compare_databases_to_report(
    IN db1 VARCHAR(64),
    IN db2 VARCHAR(64)
)
BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE tbl VARCHAR(64);
    DECLARE col VARCHAR(64);

    DECLARE pk_join TEXT;
    DECLARE pk_select TEXT;
    DECLARE sql_text LONGTEXT;

    DECLARE tbl_cur CURSOR FOR
        SELECT TABLE_NAME
        FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA = db1;

    DECLARE col_cur CURSOR FOR
        SELECT COLUMN_NAME
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = db1
          AND TABLE_NAME = tbl
          AND COLUMN_NAME NOT IN (
              SELECT COLUMN_NAME
              FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
              WHERE TABLE_SCHEMA = db1
                AND TABLE_NAME = tbl
                AND CONSTRAINT_NAME = 'PRIMARY'
          );

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    TRUNCATE diff_report;

    OPEN tbl_cur;

    table_loop: LOOP
        FETCH tbl_cur INTO tbl;
        IF done THEN LEAVE table_loop; END IF;

        -- Формируем JOIN по составному PK
        SELECT GROUP_CONCAT(CONCAT('a.', COLUMN_NAME, ' = b.', COLUMN_NAME) ORDER BY ORDINAL_POSITION SEPARATOR ' AND ')
        INTO pk_join
        FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
        WHERE TABLE_SCHEMA = db1
          AND TABLE_NAME = tbl
          AND CONSTRAINT_NAME = 'PRIMARY';

        -- Формируем вывод значения PK
        SELECT GROUP_CONCAT(CONCAT('a.', COLUMN_NAME) ORDER BY ORDINAL_POSITION SEPARATOR ', ')
        INTO pk_select
        FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
        WHERE TABLE_SCHEMA = db1
          AND TABLE_NAME = tbl
          AND CONSTRAINT_NAME = 'PRIMARY';

        IF pk_join IS NULL THEN
            ITERATE table_loop; -- нет PK, пропускаем
        END IF;

        SET done = 0;
        OPEN col_cur;

        column_loop: LOOP
            FETCH col_cur INTO col;
            IF done THEN
                SET done = 0;
                LEAVE column_loop;
            END IF;

            SET @sql_text = CONCAT(
                'INSERT INTO diff_report(table_name, pk_value, column_name, value_db1, value_db2)
                 SELECT ''', tbl, ''',
                        CONCAT_WS('':'', ', pk_select, '),
                        ''', col, ''',
                        a.', col, ',
                        b.', col, '
                 FROM ', db1, '.', tbl, ' a
                 JOIN ', db2, '.', tbl, ' b ON ', pk_join, '
                 WHERE NOT (a.', col, ' <=> b.', col, ')'
            );

            PREPARE stmt FROM @sql_text;
            EXECUTE stmt;
            DEALLOCATE PREPARE stmt;

        END LOOP;

        CLOSE col_cur;

    END LOOP;

    CLOSE tbl_cur;
END$$

DELIMITER ;
