import { Router } from 'express';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { User } from '../models/User';
import { authenticateToken, AuthRequest } from '../middleware/auth';

const router = Router();

router.post('/register', async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ message: 'Email and password are required' });
    }

    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({ message: 'User already exists' });
    }

    const passwordHash = await bcrypt.hash(password, 10);
    const newUser = new User({ email, passwordHash });
    await newUser.save();

    res.status(201).json({ message: 'User registered successfully' });
  } catch (error) {
    console.error('Register error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ message: 'Email and password are required' });
    }

    const user = await User.findOne({ email });
    if (!user) {
      return res.status(400).json({ message: 'Invalid credentials' });
    }

    const isMatch = await bcrypt.compare(password, user.passwordHash);
    if (!isMatch) {
      return res.status(400).json({ message: 'Invalid credentials' });
    }

    const token = jwt.sign(
      { id: user._id, email: user.email },
      process.env.JWT_SECRET || 'fallback_secret',
      { expiresIn: '7d' }
    );

    res.json({ token, user: { id: user._id, email: user.email } });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

router.get('/me', authenticateToken, async (req: AuthRequest, res) => {
  try {
    const user = await User.findById(req.user?.id);
    if (!user) return res.status(404).json({ message: 'User not found' });
    res.json({ user: req.user, recentlyPlayed: user.recentlyPlayed || [] });
  } catch (error) {
    res.status(500).json({ message: 'Server error' });
  }
});

router.post('/recent', authenticateToken, async (req: AuthRequest, res) => {
  try {
    const { track } = req.body;
    if (!track) return res.status(400).json({ message: 'Track is required' });

    const user = await User.findById(req.user?.id);
    if (!user) return res.status(404).json({ message: 'User not found' });

    // Ensure recentlyPlayed is initialized
    let recent = user.recentlyPlayed || [];
    
    // Filter out if already exists
    recent = recent.filter((t: any) => t.id !== track.id);
    
    // Add to beginning and limit to 20
    recent.unshift(track);
    user.recentlyPlayed = recent.slice(0, 20);

    await user.save();
    res.json({ recentlyPlayed: user.recentlyPlayed });
  } catch (error) {
    console.error('Save recent error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

export default router;
