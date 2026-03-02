
import os
import json
from typing import Optional
from alibabacloud_dysmsapi20170525.client import Client as Dysmsapi20170525Client
from alibabacloud_tea_openapi import models as open_api_models
from alibabacloud_dysmsapi20170525 import models as dysmsapi_20170525_models
from alibabacloud_tea_util import models as util_models

class AliyunSMSService:
    def __init__(self):
        self.access_key_id = os.getenv("ALIYUN_ACCESS_KEY_ID")
        self.access_key_secret = os.getenv("ALIYUN_ACCESS_KEY_SECRET")
        self.sign_name = os.getenv("ALIYUN_SMS_SIGN_NAME")
        self.template_code = os.getenv("ALIYUN_SMS_TEMPLATE_CODE")
        self.client = self._create_client()

    def _create_client(self) -> Dysmsapi20170525Client:
        """
        使用AK&SK初始化账号Client
        """
        if not self.access_key_id or not self.access_key_secret:
            # 如果没有配置 key，返回 None，避免初始化错误
            # 在这种情况下，send_verify_code 应该处理 None client
            print("Warning: Aliyun AccessKey ID or Secret not configured.")
            return None

        config = open_api_models.Config(
            access_key_id=self.access_key_id,
            access_key_secret=self.access_key_secret
        )
        # 访问的域名
        config.endpoint = 'dysmsapi.aliyuncs.com'
        return Dysmsapi20170525Client(config)

    def send_verify_code(self, phone_number: str, code: str) -> bool:
        if not self.client:
            print("Error: Aliyun SMS Client not initialized.")
            return False

        send_sms_request = dysmsapi_20170525_models.SendSmsRequest(
            sign_name=self.sign_name,
            template_code=self.template_code,
            phone_numbers=phone_number,
            template_param=json.dumps({"code": code})
        )
        
        runtime = util_models.RuntimeOptions()
        
        try:
            # 复制代码运行请自行打印 API 的返回值
            response = self.client.send_sms_with_options(send_sms_request, runtime)
            
            if response.body.code == 'OK':
                print(f"SMS sent successfully to {phone_number}")
                return True
            else:
                print(f"Failed to send SMS: {response.body.message}")
                return False
                
        except Exception as error:
            # 打印 error
            print(f"Aliyun SMS Exception: {error}")
            return False
