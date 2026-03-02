import client from './client';

export interface FileRecord {
    id: string;
    filename: string;
    page_count: number;
    cost: number;
    status: string;
    created_at: string;
}

export const userApi = {
    async getFiles(phone_number: string) {
        const response = await client.get<FileRecord[]>('/users/files', {
            params: { phone_number }
        })
        return response.data
    },

    async bindInviteCode(phone_number: string, invite_code: string) {
        const response = await client.post('/users/bind-invite', {
            phone_number,
            invite_code
        })
        return response.data;
    },

    getMe: async (phoneNumber: string) => {
        const response = await client.get('/users/me', {
            params: { phone_number: phoneNumber }
        });
        return response.data;
    }
};
