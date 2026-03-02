import client from './client';

export interface CreditCode {
    code: string;
    points: number;
    status: string;
    created_at: string;
    used_at?: string;
    used_by?: string;
}

export interface Transaction {
    id: string;
    user_id: string;
    type: string;
    amount: number;
    description: string;
    created_at: string;
}

export interface RedemptionResponse {
    code: CreditCode;
    message: string;
}

export const codesApi = {
    // User: Redeem code
    redeem: async (code: string, phoneNumber: string) => {
        const response = await client.post<RedemptionResponse>('/codes/redeem', { code, phone_number: phoneNumber });
        return response.data;
    },

    // User: Get history
    // User: Get history
    getHistory: async (userId: string) => {
        // Backend expects phone_number as query param
        const response = await client.get<Transaction[]>('/users/history', {
            params: { phone_number: userId }
        });
        return response.data;
    },

    // Admin: Generate codes
    generate: async (points: number, count: number, phoneNumber: string) => {
        const response = await client.post<CreditCode[]>('/admin/codes/generate', { points, count }, {
            params: { phone_number: phoneNumber }
        });
        return response.data;
    }
};
