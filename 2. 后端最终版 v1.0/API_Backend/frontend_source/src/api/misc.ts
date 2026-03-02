import client from './client';

export interface AppVersion {
    id: number;
    version: string;
    build: number;
    download_url: string;
    local_file_path?: string;
    release_notes?: string;
    force_update: boolean;
    created_at: string;
}

export const getLatestAppVersion = async () => {
    const response = await client.get<AppVersion>('/v1/misc/app/latest');
    return response.data;
};

export const getAppVersions = async (skip = 0, limit = 100) => {
    const response = await client.get<AppVersion[]>('/v1/misc/app/versions', {
        params: { skip, limit }
    });
    return response.data;
};

export const createAppVersion = async (formData: FormData, onUploadProgress?: (progressEvent: any) => void) => {
    const response = await client.post<AppVersion>('/v1/misc/app/versions', formData, {
        headers: {
            'Content-Type': 'multipart/form-data',
        },
        onUploadProgress,
    });
    return response.data;
};

export const deleteAppVersion = async (versionId: number) => {
    const response = await client.delete(`/v1/misc/app/versions/${versionId}`);
    return response.data;
};
