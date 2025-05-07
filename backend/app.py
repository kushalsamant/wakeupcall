from flask import Flask, request, render_template
from supabase import create_client
from twilio.rest import Client
from dotenv import load_dotenv
import os
import schedule
import time
import threading
from datetime import datetime

app = Flask(__name__)
load_dotenv()

# Initialize Supabase
supabase_url = os.getenv("SUPABASE_URL")
supabase_key = os.getenv("SUPABASE_KEY")
supabase = create_client(supabase_url, supabase_key)

# Initialize Twilio
twilio_client = Client(os.getenv("TWILIO_ACCOUNT_SID"), os.getenv("TWILIO_AUTH_TOKEN"))
twilio_phone = os.getenv("TWILIO_PHONE_NUMBER")

@app.route("/")
def index():
    return render_template("index.html", status="No wake-up time set.")

@app.route("/set-wakeup", methods=["POST"])
def set_wakeup():
    phone_number = request.form["phone_number"]
    wakeup_time = request.form["wakeup_time"]
    
    try:
        supabase.table("wakeups").insert({
            "phone_number": phone_number,
            "wakeup_time": wakeup_time
        }).execute()
        return render_template("index.html", status=f"Wake-up call set for {wakeup_time} to {phone_number}")
    except Exception as e:
        return render_template("index.html", status=f"Error: {str(e)}")

def check_wakeups():
    while True:
        current_time = datetime.now().strftime("%H:%M")
        try:
            wakeups = supabase.table("wakeups").select("*").eq("wakeup_time", current_time).execute()
            
            for wakeup in wakeups.data:
                phone_number = wakeup["phone_number"]
                twilio_client.calls.create(
                    to=phone_number,
                    from_=twilio_phone,
                    twiml="<Response><Say>Wake up! It's time to start your day!</Say></Response>"
                )
                supabase.table("wakeups").delete().eq("id", wakeup["id"]).execute()
        except Exception as e:
            print(f"Error checking wakeups: {e}")
        
        time.sleep(60)  # Check every minute

threading.Thread(target=check_wakeups, daemon=True).start()

if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=5000)