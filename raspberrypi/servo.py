import RPi.GPIO as GPIO
from time import sleep

servoPin = 12
SERVO_MAX = 12
SERVO_MIN = 3

GPIO.setmode(GPIO.BOARD)
GPIO.setup(servoPin, GPIO.OUT)

servo = GPIO.PWM(servoPin, 50)
servo.start(0)

def servoPos(degree):
	if degree > 180:
		degree = 180
		
	duty = SERVO_MIN + (degree * (SERVO_MAX - SERVO_MIN) / 180.0)
	servo.ChangeDutyCycle(duty)
	
if __name__ == "__main__":
	servoPos(90)
	sleep(3)
	
	servoPos(0)
	sleep(3)
	
	servo.stop()
	
	GPIO.cleanup()
	
	
