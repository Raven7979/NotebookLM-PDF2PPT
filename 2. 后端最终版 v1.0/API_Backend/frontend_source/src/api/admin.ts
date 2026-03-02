import client from './client';
import type { User } from './auth';

export interface AdminStats {
  user_count: number;
  file_count: number;
  revenue: number;
}

export interface FileRecord {
  id: string;
  filename: string;
  page_count: number;
  cost: number;
  status: string;
  created_at: string;
}

export interface Order {
  id: string;
  user_id: string;
  amount: number;
  credits: number;
  status: string;
  created_at: string;
}

export interface UserDetail extends User {
  file_records: FileRecord[];
  orders: Order[];
  total_converted_pages?: number;
}

export const getUsers = async (phoneNumber: string) => {
  const response = await client.get<User[]>('/admin/users', {
    params: { phone_number: phoneNumber }
  });
  return response.data;
};

export const getUserDetails = async (phoneNumber: string, targetUserId: string) => {
  const response = await client.get<UserDetail>(`/admin/users/${targetUserId}`, {
    params: { phone_number: phoneNumber }
  });
  return response.data;
};

export const getStats = async (phoneNumber: string) => {
  const response = await client.get<AdminStats>('/admin/stats', {
    params: { phone_number: phoneNumber }
  });
  return response.data;
};

export const updateCredits = async (adminPhone: string, userId: string, credits: number) => {
  const response = await client.put<User>(`/admin/users/${userId}/credits`, null, {
    params: { credits, phone_number: adminPhone }
  });
  return response.data;
};

export const getCodes = async (adminPhone: string) => {
  const response = await client.get('/admin/codes', {
    params: { phone_number: adminPhone }
  });
  return response.data;
}

export interface Order {
  id: string;
  user_id: string;
  amount: number;
  credits: number;
  status: string;
  created_at: string;
}

export const getOrders = async (phoneNumber: string) => {
  const response = await client.get<Order[]>('/admin/orders', {
    params: { phone_number: phoneNumber }
  });
  return response.data;
};
