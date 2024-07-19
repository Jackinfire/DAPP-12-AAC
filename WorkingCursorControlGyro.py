import asyncio
import websockets
import json
from pynput.mouse import Controller
from screeninfo import get_monitors

# Initialize mouse controller
mouse = Controller()

# Get screen dimensions
screen_width = get_monitors()[0].width
screen_height = get_monitors()[0].height

# Sensitivity for mouse movement (adjust based on screen size)
roll_range = 180  # Expected range of roll in degrees (for a full 180-degree turn)
pitch_range = 120  # Expected range of yaw in degrees (for a full 180-degree turn)

# Calculate sensitivity based on screen dimensions and IMU range
sensitivity_x = screen_width / roll_range
sensitivity_y = screen_height / pitch_range

print(f"Sensitivity X: {sensitivity_x}, Sensitivity Y: {sensitivity_y}")

# Variables for zero calibration
vertZero = 0
horzZero = 0

async def process_message(message):
    global vertZero, horzZero
    print("try1")
    try:
        # Parse JSON data
        data = json.loads(message)
        accel_x = data.get('accel_x', 0)
        accel_y = data.get('accel_y', 0)
        accel_z = data.get('accel_z', 0)
        gyro_x = data.get('gyro_x', 0)
        gyro_y = data.get('gyro_y', 0)
        gyro_z = data.get('gyro_z', 0)
        attitude_roll = data.get('attitude_roll', 0)
        attitude_pitch = data.get('attitude_pitch', 0)
        attitude_yaw = data.get('attitude_yaw', 0)
        
        # Here you can use additional data as needed
        # For example, let's use pitch and roll to move the mouse
        pitch = attitude_pitch * (180 / 3.14159)  # Convert from radians to degrees
        roll = attitude_roll * (180 / 3.14159)  # Convert from radians to degrees
        
        # Calculate the vertical and horizontal values
        vertValue = pitch - vertZero
        horzValue = roll - horzZero
        
        # Update the zero calibration values
        vertZero = pitch
        horzZero = roll

        # Debug prints
        print(f"Roll: {roll}, Pitch: {pitch}")
        print(f"Horizontal Move: {horzValue}, Vertical Move: {vertValue}")
        
        # Move the mouse cursor based on sensor values. 
        if vertValue != 0:
            print(f"Moving vertically by {int(vertValue * sensitivity_y)} pixels")
            mouse.move(0, -int(vertValue * sensitivity_y))  # Move mouse on y axis based on pitch
        if horzValue != 0:
            print(f"Moving horizontally by {int(horzValue * sensitivity_x)} pixels")
            mouse.move(int(horzValue * sensitivity_x), 0)  # Move mouse on x axis based on roll

    except json.JSONDecodeError:
        print("Invalid JSON data received")

async def handler(websocket, path):
    async for message in websocket:
        await process_message(message)

start_server = websockets.serve(handler, "0.0.0.0",12345)

asyncio.get_event_loop().run_until_complete(start_server)
print("Listening on 0.0.0.0:12345...")
asyncio.get_event_loop().run_forever()
