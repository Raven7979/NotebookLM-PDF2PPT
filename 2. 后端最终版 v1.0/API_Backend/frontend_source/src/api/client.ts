import axios from 'axios';

const client = axios.create({
  baseURL: '/api',
  timeout: 300000, // 5 minutes for large file uploads
  headers: {
    'Content-Type': 'application/json',
  },
});

export default client;
