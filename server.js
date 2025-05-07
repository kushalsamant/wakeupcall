require('dotenv').config();
     const express = require('express');
     const twilio = require('twilio');
     const schedule = require('node-schedule');
     const { createClient } = require('@supabase/supabase-js');
     const cors = require('cors');

     const app = express();
     app.use(cors());
     app.use(express.json());

     const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_KEY);
     const twilioClient = new twilio(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN);

     // Register user
     app.post('/api/register', async (req, res) => {
       const { email, password, phone_number } = req.body;
       const { data, error } = await supabase.auth.signUp({
         email,
         password,
         options: { data: { phone_number } }
       });
       if (error) return res.status(400).json({ error: error.message });
       const { error: insertError } = await supabase.from('users').insert([
         { id: data.user.id, email, phone_number }
       ]);
       if (insertError) return res.status(400).json({ error: insertError.message });
       res.json({ user: data.user });
     });

     // Login user
     app.post('/api/login', async (req, res) => {
       const { email, password } = req.body;
       const { data, error } = await supabase.auth.signInWithPassword({ email, password });
       if (error) return res.status(401).json({ error: error.message });
       res.json({ user: data.user });
     });

     // Set wake-up schedule
     app.post('/api/schedule', async (req, res) => {
       const { user_id, wake_up_time } = req.body;
       const { data, error } = await supabase.from('schedules').insert([{ user_id, wake_up_time }]).select();
       if (error) return res.status(400).json({ error: error.message });

       const [hours, minutes] = wake_up_time.split(':');
       schedule.scheduleJob(`${minutes} ${hours} * * *`, async () => {
         const { data: user } = await supabase.from('users').select('phone_number').eq('id', user_id).single();
         twilioClient.calls.create({
           to: user.phone_number,
           from: process.env.TWILIO_PHONE_NUMBER,
           url: process.env.TWIML_URL
         }).catch(err => console.error('Twilio error:', err));
       });

       res.json({ schedule: data[0] });
     });

     // Get user schedules
     app.get('/api/schedules/:user_id', async (req, res) => {
       const { user_id } = req.params;
       const { data, error } = await supabase.from('schedules').select().eq('user_id', user_id);
       if (error) return res.status(400).json({ error: error.message });
       res.json({ schedules: data });
     });

     app.listen(process.env.PORT, () => console.log(`Server running on port ${process.env.PORT}`));