# Mac App API 契约文档 v1

> **重要**：本文档定义了 Mac App 与后端服务器之间的 API 接口规范。
> 后端保证 v1 版本的 API 向后兼容，不会因更新而破坏现有 App 功能。

## 基础信息

- **Base URL**: `https://your-server.com/api/v1/mac`
- **认证方式**: 通过 `phone_number` 参数识别用户

---

## 1. 图片修复 (Inpaint)

**端点**: `POST /api/v1/mac/inpaint`

**功能**: 代理调用 Nano API 进行图片修复，擦除文字

**请求** (multipart/form-data):
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| image | File | ✅ | 原始图片 |
| mask | File | ✅ | Mask 图片（白色=擦除区域） |
| phone_number | String | ✅ | 用户手机号 |

**响应** (JSON):
```json
{
    "success": true,
    "image_base64": "...",        // Base64 编码的结果图片
    "credits_used": 1,            // 消耗的积分
    "remaining_credits": 99       // 剩余积分
}
```

**错误码**:
| 状态码 | 说明 |
|--------|------|
| 402 | 积分不足 |
| 404 | 用户不存在 |
| 500 | 修图失败 |

---

## 2. 查询积分

**端点**: `GET /api/v1/mac/credits`

**请求参数**:
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| phone_number | String | ✅ | 用户手机号 |

**响应**:
```json
{
    "phone_number": "13800138000",
    "credits": 100
}
```

---

## 3. 验证用户

**端点**: `POST /api/v1/mac/verify-token`

**请求参数**:
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| phone_number | String | ✅ | 用户手机号 |

**响应**:
```json
{
    "valid": true,
    "phone_number": "13800138000",
    "credits": 100
}
```

---

## 版本兼容性承诺

- **v1 版本保证向后兼容**
- 新增字段不会破坏现有解析逻辑
- 如有重大变更，将发布 v2 版本
