import client from './client';

export interface User {
  id: string;
  phone_number: string;
  credits: number;
  invite_code?: string;
  invited_by_code?: string;
  is_active: boolean;
  is_superuser: boolean;
  created_at: string;
  total_converted_pages?: number;
  total_payment_amount?: number;
  total_redeemed_points?: number;
}

export const sendVerificationCode = async (phone_number: string) => {
  const response = await client.post('/auth/send-code', { phone_number });
  return response.data;
};

export interface LoginResponse {
  user: User;
  token: string;
}

export const loginOrRegister = async (phone_number: string, code?: string, password?: string, invite_code?: string) => {
  const response = await client.post<LoginResponse>('/auth/login', {
    phone_number,
    code,
    password,
    invite_code
  });
  return response.data;
};

export interface UploadResponse {
  file_id: string;
  filename: string;
  page_count: number;
  cost: number;
  message: string;
}

export const uploadFile = async (file: File, phone_number: string) => {
  const formData = new FormData();
  formData.append('file', file);
  formData.append('phone_number', phone_number);

  const response = await client.post('/upload', formData, {
    headers: {
      'Content-Type': 'multipart/form-data',
    },
  });
  return response.data;
};

export const convertFile = async (file_id: string, phone_number: string) => {
  const response = await client.post('/convert', {
    file_id,
    phone_number
  });
  return response.data;
};
