import asyncio
import json
import websockets
import sys
import ssl
import uuid
import os

# Set TrueNAS WebSocket API URL
TRUENAS_WS_URL = "wss://bwees-nas/websocket"
API_KEY = os.getenv("TRUENAS_API_KEY")
if not API_KEY:
    print("TRUENAS_API_KEY environment variable not set")
    sys.exit(1)

async def upload_compose():
    ssl_context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    ssl_context.check_hostname = False
    ssl_context.verify_mode = ssl.CERT_NONE

    async with websockets.connect(TRUENAS_WS_URL, ssl=ssl_context) as ws:
        # Send initial message to establish connection
        initial_payload = {
            "msg": "connect",
            "version": "1",
            "support": ["1"]
        }
        await ws.send(json.dumps(initial_payload))
        initial_response = await ws.recv()
        initial_data = json.loads(initial_response)

        # Authenticate
        auth_payload = {
            "id": str(uuid.uuid4()),
            "msg": "method",
            "method": "auth.login_with_api_key",
            "params": [API_KEY]
        }
        await ws.send(json.dumps(auth_payload))
        auth_response = await ws.recv()
        auth_data = json.loads(auth_response)

        if not auth_data.get("result"):
            print("Authentication failed")
            print(f"Error: {auth_data.get('error')}")
            sys.exit(1)
        print("Authenticated successfully")

        # Upload the compose file from args
        filename = sys.argv[1]
        app_name = filename.split('/')[-1].split('.')[0]
        with open(filename, 'r') as file:
            compose_content = file.read()

            upload_payload = {
                "id": str(uuid.uuid4()),
                "msg": "method",
                "method": "app.update",
                "params": [app_name, 
                    {
                        "custom_compose_config_string": compose_content,
                    }
                ]
            }

            await ws.send(json.dumps(upload_payload))
            upload_response = await ws.recv()
            upload_data = json.loads(upload_response)
            job_id = upload_data.get("result")

            # subscribe to get_jobs events
            subscribe_payload = {
                "id": str(uuid.uuid4()),
                "msg": "sub",
                "name": "core.get_jobs"
            }
            await ws.send(json.dumps(subscribe_payload))
            await ws.recv()

            # read from websocket until a core.get_jobs response is received with ID job_id and state "SUCCESS"
            while True:
                response = await ws.recv()
                response_data = json.loads(response)

                if response_data.get("msg") == "changed" and response_data.get("id") == job_id:
                    job_result = response_data.get("fields", {})
                    if job_result.get("state") == "SUCCESS":
                        print(f"Compose file {filename} uploaded successfully")
                        break
                    elif job_result.get("state") == "FAILED":
                        print(f"Compose file {filename} upload failed: {job_result.get("error").strip()}")
                        sys.exit(1)


asyncio.run(upload_compose())