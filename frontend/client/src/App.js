import React, { useState, useEffect } from 'react';
     import axios from 'axios';
     import { createClient } from '@supabase/supabase-js';

     const supabase = createClient('https://vbzmercnilwfrgdwynet.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZiem1lcmNuaWx3ZnJnZHd5bmV0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDYxNjQwNzQsImV4cCI6MjA2MTc0MDA3NH0.uH79jYh-aEdFsfK9h2Qbbgp6zj_8JkSwmUrBIOF1fo0');

     function App() {
       const [user, setUser] = useState(null);
       const [email, setEmail] = useState('');
       const [password, setPassword] = useState('');
       const [phoneNumber, setPhoneNumber] = useState('');
       const [wakeUpTime, setWakeUpTime] = useState('');
       const [schedules, setSchedules] = useState([]);
       const [message, setMessage] = useState('');

       const handleRegister = async () => {
         try {
           const { data } = await axios.post('https://your-app.vercel.app/api/register', { email, password, phone_number: phoneNumber });
           setUser(data.user);
           setMessage('Registered successfully!');
         } catch (err) { setMessage('Registration failed: ' + err.response.data.error); }
       };

       const handleLogin = async () => {
         try {
           const { data } = await axios.post('https://your-app.vercel.app/api/login', { email, password });
           setUser(data.user);
           setMessage('Logged in successfully!');
         } catch (err) { setMessage('Login failed: ' + err.response.data.error); }
       };

       const handleSchedule = async () => {
         try {
           const { data } = await axios.post('https://your-app.vercel.app/api/schedule', { user_id: user.id, wake_up_time: wakeUpTime });
           setSchedules([...schedules, data.schedule]);
           setMessage('Schedule set!');
         } catch (err) { setMessage('Scheduling failed: ' + err.response.data.error); }
       };

       const fetchSchedules = async () => {
         if (user) {
           const { data } = await axios.get(`https://your-app.vercel.app/api/schedules/${user.id}`);
           setSchedules(data.schedules);
         }
       };

       useEffect(() => { fetchSchedules(); }, [user]);

       return (
         <div className="min-h-screen bg-gray-100 flex flex-col items-center justify-center p-4">
           <h1 className="text-3xl font-bold mb-6">Wake-Up Call SaaS</h1>
           {!user ? (
             <div className="w-full max-w-md bg-white p-6 rounded-lg shadow-md">
               <input type="email" placeholder="Email" value={email} onChange={(e) => setEmail(e.target.value)} className="w-full p-2 mb-4 border rounded" />
               <input type="password" placeholder="Password" value={password} onChange={(e) => setPassword(e.target.value)} className="w-full p-2 mb-4 border rounded" />
               <input type="text" placeholder="Phone (+918779632310)" value={phoneNumber} onChange={(e) => setPhoneNumber(e.target.value)} className="w-full p-2 mb-4 border rounded" />
               <button onClick={handleRegister} className="w-full bg-blue-500 text-white p-2 rounded mb-2">Register</button>
               <button onClick={handleLogin} className="w-full bg-green-500 text-white p-2 rounded">Login</button>
             </div>
           ) : (
             <div className="w-full max-w-md bg-white p-6 rounded-lg shadow-md">
               <h2 className="text-xl mb-4">Welcome, {user.email}</h2>
               <input type="time" value={wakeUpTime} onChange={(e) => setWakeUpTime(e.target.value)} className="w-full p-2 mb-4 border rounded" />
               <button onClick={handleSchedule} className="w-full bg-blue-500 text-white p-2 rounded mb-4">Set Wake-Up Time</button>
               <h3 className="text-lg mb-2">Your Schedules</h3>
               <ul>{schedules.map((s) => <li key={s.id}>{s.wake_up_time}</li>)}</ul>
               <button onClick={() => setUser(null)} className="w-full bg-red-500 text-white p-2 rounded">Logout</button>
             </div>
           )}
           {message && <p className="mt-4 text-red-500">{message}</p>}
         </div>
       );
     }

     export default App;