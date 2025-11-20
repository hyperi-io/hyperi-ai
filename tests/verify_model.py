#!/usr/bin/env python3
#
# verify_model.py - Test if a model in a settings file is available via the API.
#
# Usage:
#   1. Install the Google AI library:
#      pip install -q -U google-generativeai
#
#   2. Set your API key:
#      export GOOGLE_API_KEY="YOUR_API_KEY"
#
#   3. Run the script against a settings file:
#      python3 tests/verify_model.py .gemini/settings.json
#
import os
import sys
import json
import google.generativeai as genai

def verify_model(settings_file):
    """Reads a model from a settings file and checks its availability."""
    if not os.path.exists(settings_file):
        print(f"❌ Error: Settings file not found at '{settings_file}'")
        sys.exit(1)

    try:
        with open(settings_file, 'r') as f:
            settings = json.load(f)
        model_name = settings.get("model")
        if not model_name:
            print(f"❌ Error: 'model' key not found in '{settings_file}'")
            sys.exit(1)

        print(f"Verifying model '{model_name}' from '{settings_file}'...")
        genai.configure(api_key=os.environ["GOOGLE_API_KEY"])
        genai.GenerativeModel(model_name)
        print(f"✅ Success! Model '{model_name}' is available and ready to use.")

    except KeyError:
        print("❌ Error: GOOGLE_API_KEY environment variable not set.")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Failed to verify model '{model_name}'.")
        print(f"   Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(f"Usage: python3 {sys.argv[0]} <path_to_settings.json>")
        sys.exit(1)
    verify_model(sys.argv[1])