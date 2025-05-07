# WakeUpCall

WakeUpCall is a robust application designed to help users manage their daily schedules with timely reminders and notifications. Built with a Python Flask backend and a JavaScript frontend, it provides a seamless experience for setting up personalized wake-up calls and alerts. This project is in active development and will soon be available as a premium Android app.

## Features

- Customizable Reminders: Set wake-up calls and reminders tailored to your schedule.
- Cross-Platform Notifications: Receive alerts via web or mobile (Android app coming soon).
- Secure Backend: Powered by Flask with a modular Python architecture for reliability and scalability.
- User-Friendly Interface: Intuitive frontend built with JavaScript for easy interaction.
- Extensible Design: Ready for future integrations, including Android app features.

## Installation

### Prerequisites

- Python 3.10 or higher
- Node.js 16 or higher
- npm (Node Package Manager)
- A virtual environment tool (e.g., `venv`)

### Backend Setup

1. Clone the repository:

   ```bash
   git clone <repository-url>
   cd WakeUpCall
   ```

2. Navigate to the backend directory:

   ```bash
   cd backend
   ```

3. Create and activate a virtual environment:

   ```bash
   python -m venv venv
   .\venv\Scripts\activate  # On Windows
   source venv/bin/activate  # On macOS/Linux
   ```

4. Install Python dependencies:

   ```bash
   pip install -r requirements.txt
   ```

5. Configure environment variables:
   - Create a `.env` file in the `backend` directory.
   - Add necessary configurations (e.g., API keys, database URLs).

   ```bash
   # Example .env
   FLASK_ENV=development
   SECRET_KEY=your-secret-key
   ```

6. Run the Flask server:

   ```bash
   python app.py
   ```

### Frontend Setup

1. From the project root, install Node.js dependencies:

   ```bash
   npm install
   ```

2. Start the frontend server:

   ```bash
   node server.js
   ```

3. Access the app at `http://localhost:3000` (or the port specified in `server.js`).

## Usage

1. Open the app in your browser at `http://localhost:3000`.
2. Sign up or log in to create your profile.
3. Set wake-up calls or reminders via the intuitive interface.
4. Receive notifications based on your configured schedule.
5. Stay tuned for the Android app release for on-the-go access!

## License

**Proprietary License**

All rights reserved. The WakeUpCall software, including its source code, documentation, and associated assets, is proprietary and owned by the project author. Unauthorized copying, modification, distribution, or use of this software, in whole or in part, is strictly prohibited without explicit written permission from the author.

For licensing inquiries or to request permission for use, please contact the author at the email provided below.

## Contact

For support, feedback, or licensing inquiries, please reach out to:

- Email: kushaldsamant@gmail.com
- Project Repository: [https://github.com/kushalsamant/wakeupcall/](https://github.com/kushalsamant/wakeupcall/)

*Note*: This project is under active development for commercial release as an Android app. Stay tuned for updates!