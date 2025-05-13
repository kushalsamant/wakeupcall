import React, { useState } from 'react';
import { LocalNotifications } from '@capacitor/local-notifications';
import './App.css';

function App() {
  const [callTime, setCallTime] = useState('');
  const [message, setMessage] = useState('');

  const scheduleNotification = async (callTime) => {
    const scheduleTime = new Date(callTime).getTime();
    const now = new Date().getTime();
    if (scheduleTime <= now) {
      alert('Please select a future time');
      return false;
    }

    await LocalNotifications.requestPermissions();
    await LocalNotifications.schedule({
      notifications: [
        {
          id: Math.floor(Math.random() * 1000000),
          title: 'WakeUpCall',
          body: 'Incoming wake-up call',
          schedule: { at: new Date(scheduleTime) },
          actionTypeId: 'CALL_ACTION',
          extra: { activity: 'com.kushal.wakeupcall.CallActivity' }
        }
      ]
    });
    return true;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setMessage('');
    try {
      const scheduled = await scheduleNotification(callTime);
      if (scheduled) {
        setMessage('Wake-up call scheduled successfully!');
      } else {
        setMessage('Error: Please select a future time');
      }
    } catch (error) {
      setMessage('Error: Failed to schedule call');
    }
  };

  return (
    <div className="App">
      <header className="App-header">
        <h1>WakeUpCall</h1>
        <p>Schedule your wake-up call</p>
        <form onSubmit={handleSubmit}>
          <div>
            <label>Call Time: </label>
            <input
              type="datetime-local"
              value={callTime}
              onChange={(e) => setCallTime(e.target.value)}
              required
            />
          </div>
          <button type="submit">Schedule Call</button>
        </form>
        {message && <p>{message}</p>}
      </header>
    </div>
  );
}

export default App;
