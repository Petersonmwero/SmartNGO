# Use PyMySQL as a drop-in replacement for mysqlclient (MySQLdb).
# Django 4.2 enforces a minimum mysqlclient version, so we advertise a
# compatible version number for the pure-Python PyMySQL driver.
import pymysql

pymysql.version_info = (1, 4, 6, "final", 0)
pymysql.install_as_MySQLdb()
