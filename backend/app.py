from flask import Flask, request, render_template
from supabase import create_client
from dotenv import load_dotenv
import os

app = Flask(__name__)
load_dotenv()

# Initialize Supabase
supabase_url = os.getenv("SUPABASE_URL")
supabase_key = os.getenv("SUPABASE_KEY")
supabase = create_client(supabase_url, supabase_key)

@app.route("/")
def index():
    return render_template("index.html", status="No wake-up time set.")

@app.route("/set-wakeup", methods=["POST"])
def set_wakeup():
    device_id = request.form["device_id"]
    wakeup_time = request.form["wakeup_time"]
    
    # Store in Supabase
    supabase.table("wakeups").insert({
        "device_id": device_id,
        "wakeup_time": wakeup_time
    }).execute()
    
    return render_template("index.html", status=f"Wake-up set for {wakeup_time}")

@app.route("/get-wakeup/<device_id>", methods=["GET"])
def get_wakeup(device_id):
    result = supabase.table("wakeups").select("*").eq("device_id", device_id).execute()
    return {"wakeups": result.data}

if __name__ == "__main__":
    app.run(debug=True)