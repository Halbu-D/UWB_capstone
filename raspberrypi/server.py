import socket
import pymysql
from subprocess import run

connection = pymysql.connect(host='localhost',
                             user='halbu',
                             password='#',  # 암호
                             db='userdb',
                             charset='utf8mb4',
                             cursorclass=pymysql.cursors.DictCursor)

def udp_server(host: str, port: int):
    # 소켓 생성
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind((host, port))

    print(f"Listening on {host}:{port}")

    try:
        while True:
            # 데이터 수신
            data, addr = sock.recvfrom(1024)  # 버퍼 크기는 1024 바이트로 설정 
            if log_to_database(data):
                run(["python3", "acessLog.py", data], check=True)
                run(["python3", "servo.py"], check=True)  # 데이터베이스 조회 결과가 있으면 servo.py 실행
            # print(f"Received message from {addr}: {data.decode()}")
    except KeyboardInterrupt:
        print("Server is shutting down.")
    finally:
        sock.close()

def log_to_database(id):
    cursor = connection.cursor()

    cursor.execute("SELECT * FROM userdata WHERE id = %s", (id,))
    result = cursor.fetchone()

    if result:
        print('ID found in database')
        return True
    else:
        print("Student ID:", id, "not found in userdata table.")
        return False

if __name__ == "__main__":
    udp_server("0.0.0.0", 8080)
