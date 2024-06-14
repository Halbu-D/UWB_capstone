import socket
import pymysql
import sys

connection = pymysql.connect(host='localhost',
                             user='halbu',
                             password='#',  # 암호
                             db='userdb',
                             charset='utf8mb4',
                             cursorclass=pymysql.cursors.DictCursor)

arg = sys.argv[1]

try:
    with connection.cursor() as cursor:
        sql = "INSERT INTO accessLog (user_id, access_time) values (%s, now())"
        cursor.execute(sql, (arg, ))

        connection.commit()

finally:
    connection.close()