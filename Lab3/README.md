# Lab 3 – Ghi nhật ký ưu tiên bảo mật (SecureLogger)

Thực hành: Ghi nhật ký ưu tiên bảo mật

Họ và tên: Đoàn Xuân Hướng

Lớp: 23DATA1

MSSV: 2387700025

---

## 1. Mục tiêu

Xây dựng hệ thống ghi nhật ký `SecureLogger` và tích hợp với thư viện `SecureValidator` ở Lab 1 để
ghi lại mọi lần kiểm tra validation.

| Yêu cầu | Thực hiện trong `securelogger/logger.py` |
|---|---|
| Hỗ trợ đa cấp độ log (DEBUG, INFO, WARNING, ERROR, CRITICAL) | logger `secure_logger` đặt mức `DEBUG` |
| Tự động phát hiện và che thông tin định danh cá nhân (PII) | `mask_pii()`: email → `<email_masked>`; `token`/`apikey`/`key`/`password` kèm giá trị → `<token_masked>` |
| Luân phiên log (rotation) kèm nén dữ liệu | `SecureRotatingFileHandler` (kế thừa `RotatingFileHandler`): quá 1 MB thì xoay vòng, `GZipRotator` nén file cũ thành `.gz`, giữ 2 bản |
| Phát hiện thay đổi trái phép (tamper detection) | mỗi dòng log sau khi ghi được băm SHA-256, hash lưu vào `secure.log.sig` |
| Ghi log theo cấu trúc JSON | `JSONFormatter`: `timestamp`, `level`, `message`, thêm `data` và `results` nếu có |

`app.py` là API Flask `POST /validate`: nhận JSON, gọi các hàm của `securevalidator`, ghi log mức
INFO cho mỗi lần kiểm tra (kèm dữ liệu vào và kết quả). JSON không hợp lệ thì ghi log mức WARNING
và trả về 400.

## 2. Cấu trúc

```
Lab3/
├── README.md
└── secure_logger_lab/
    ├── app.py                    
    ├── requirements.txt          
    ├── securelogger/
    │   ├── __init__.py
    │   └── logger.py             
    └── securevalidator/        
        ├── __init__.py
        └── core.py
```

Khi chạy, trong `secure_logger_lab/` sẽ có thêm `secure.log` (log JSON) và `secure.log.sig` (hash
của từng dòng log).

## 3. Chạy ứng dụng

```bash
cd Lab3/secure_logger_lab
pip install -r requirements.txt
python app.py
```

Ứng dụng chạy tại `http://127.0.0.1:5000`.

## 4. Kiểm tra bằng Postman

Request **POST** `http://localhost:5000/validate`, Body → raw → JSON:

```json
{
  "email": "huong@example.com",
  "url": "https://secure.com",
  "filename": "report.pdf",
  "sql": "' OR 1=1 --",
  "html": "<script>alert(1)</script>"
}
```

Response:

```json
{
  "email": true,
  "filename": true,
  "html": "&lt;script&gt;alert(1)&lt;/script&gt;",
  "sql": "1=1",
  "url": true
}
```

Gửi body không phải JSON sẽ nhận `400 {"error": "Invalid JSON format"}`.

`secure.log` sau request trên – email đã bị che, mỗi dòng là một JSON:

```json
{"timestamp": "2026-09-23T06:02:46.162299Z", "level": "INFO", "message": "Validation check performed", "data": "{'email': '<email_masked>', 'url': 'https://secure.com', 'filename': 'report.pdf', 'sql': \"' OR 1=1 --\", 'html': '<script>alert(1)</script>'}", "results": "{'email': True, 'url': True, 'filename': True, 'sql': '1=1', 'html': '&lt;script&gt;alert(1)&lt;/script&gt;'}"}
```

`secure.log.sig` – SHA-256 của dòng log tương ứng:

```
94c721d61def156ed4855d5a31ae154b622492f69a7fa3581c8a693bbb38a938
```

## 5. Kiểm tra tamper detection

Băm lại từng dòng trong `secure.log` và so với `secure.log.sig` (chạy trong `secure_logger_lab/`):

```python
import hashlib

lines = open("secure.log", encoding="utf-8").read().splitlines()
sigs = open("secure.log.sig", encoding="utf-8").read().split()[-len(lines):]
for i, (line, sig) in enumerate(zip(lines, sigs), 1):
    ok = hashlib.sha256(line.encode("utf-8")).hexdigest() == sig
    print(i, "OK" if ok else "DA BI SUA")
```
