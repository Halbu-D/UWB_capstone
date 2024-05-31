import socket
import mysql.connector
from datetime import datetime

import RPi.GPIO as GPIO
import time

#motor_pin = 18 #나중에 연결하면 추가

# GPIO 핀번호 설정
GPIO.setmode(GPIO.BCM)
GPIO.setup(motor_pin, GPIO.OUT)

# UDP 서버
UDP_IP = "0.0.0.0" # 모든 ip허용
UDP_PORT = 8080  # 사용할 포트

# MySQL 연결
mydb = mysql.connector.connect(
    host="localhost",
    user="halbu",
    password="##",#비밀번호
    database="university"
)

# UDP 소켓 생성
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

# 소켓 IP, PORT 바인딩
sock.bind((UDP_IP, UDP_PORT))
print(f"Listening on {UDP_IP}:{UDP_PORT}")

# 모타 동작 함수
def run_motor():
    try:
        #GPIO.output(motor_pin, GPIO.HIGH)
        print("Motor is running...")
        time.sleep(5);
        
        #GPIO.output(motor_pin, GPIO.LOW)
        print("Motor stopped.")
        
    except KeyboardInterrupt:
        #GPIO.cleanup()
        print("Keyboard Interrupt. GPIO cleaned up.")

# db에 학번 일치시 로그 남김
def log_to_database(student_id):
    cursor = mydb.cursor()

    cursor.execute("SELECT * FROM student_info WHERE student_id = %s", (student_id,))
    result = cursor.fetchone()

    if result:
        # motor_control 테이블에 저장
        now = datetime.now()
        current_time = now.strftime("%Y-%m-%d %H:%M:%S")
        sql = "INSERT INTO motor_control (student_id, received_time) VALUES (%s, %s)"
        val = (student_id, current_time)
        cursor.execute(sql, val)
        mydb.commit()
        print("Received student ID:", student_id, "and logged to motor_control table.")
    
    
    else:
        print("Student ID:", student_id, "not found in student_info table.")

# UDP 데이터 수신 및 처리
while True:
    data, addr = sock.recvfrom(1024)
    student_id = data.decode()  # 문자열로 디코딩
    print("Received student ID:", student_id)
    log_to_database(student_id)
    #run_motor() #모터 연결시 

# 종료
mydb.close()
