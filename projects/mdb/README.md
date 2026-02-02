# Requirements (in projects)

mysql
nginx
php-fpm


## Updating

DB:
```bash
mysqldump --no-data --add-drop-table --databases movies_db > movies_db.sql
zip movies_db_defaut.zip movies_db.sql
```

DATA:
```bash
cd /your_docroot/..
cp -a mdb /home/ubuntu/
cd /home/ubuntu/
```
**NOTE:** remove DB creds in ```mdb/includes/mysql_config.php``` and continue:
```bash
zip -r mdb.local_2026-02-22.zip mdb
```
