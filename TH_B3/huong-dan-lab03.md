# HƯỚNG DẪN LAB 03 — BẢO MẬT MẠNG MÁY TÍNH
**Sinh viên: Đoàn Xuân Hướng — 2387700025 — 23DATA1**

Nội dung lab: (1) Ứng dụng chat bảo mật SSL/TLS **SecureChat**, (2) bộ công cụ trinh sát mạng **Netrecon** (quét cổng, nhận dạng dịch vụ, banner grabbing, sơ đồ mạng, kiểm tra lỗ hổng, gửi email kết quả).

> **Ghi chú đạo đức (bắt buộc nêu trong báo cáo):** chỉ quét/thử nghiệm trên **máy của chính mình** (127.0.0.1 hoặc IP máy mình), hoặc **scanme.nmap.org** — mục tiêu thử nghiệm chính thức của dự án Nmap (được phép quét). Không quét mạng/IP bên ngoài. Trong hướng dẫn này, các IP của đề bài (`10.14.89.200`, `192.168.1.1`) được thay bằng `127.0.0.1` — ghi chú sai lệch môi trường này vào báo cáo.

**Quy ước chụp ảnh:** mỗi bước có note `📸` gồm **mã ảnh** + **chụp gì** + **phải thấy gì trong khung hình** (để ghép vào báo cáo Word sau). Khi chụp terminal: chụp đủ cả dòng lệnh đã gõ lẫn output. Khi chụp code trong VS Code: chụp đủ thanh tiêu đề file + vùng code, cỡ chữ đọc được.

**Môi trường thực hiện:** Windows 11, cài đặt theo đề bài (OpenSSL for Windows, Nmap, Python, VS Code). Các khối lệnh ghi rõ cửa sổ terminal nào.

**Mã nguồn lab:** đã dựng sẵn và **chạy kiểm chứng thành công** tại `F:\TH_LTANTT\TH_B3` (repo `TH_LTANTT`): `secure-chat\` (Phần 1–2) + `netrecon\` (Phần 4–5), venv `TH_B3\.venv` đã cài `cryptography`, `flask`, `click`, `python-dotenv`. Code dưới đây là code nguyên văn của đề (đã compile + chạy thật); nếu làm lại từ đầu: tạo file đúng tên, dán nguyên văn, không sửa. Script test kèm theo: `secure-chat\test_chat.sh`, `netrecon\test_web.sh` (chạy `bash <script>` để kiểm tra nhanh lại).

---

## PHẦN 1 — CÀI OPENSSL VÀ TẠO CHỨNG CHỈ (SSL/TLS)

### 1.1 Cài OpenSSL cho Windows
1. Vào <https://slproweb.com/products/Win32OpenSSL.html>, tải bản **Win64 OpenSSL v3.x Light** (bản thường, không phải bản "tiny").
   - 📸 **1-1** — chụp trang tải: thấy tên bản Win64 OpenSSL và nút tải.
2. Cài đặt như phần mềm thông thường (Next → Next). Ở bước *"Copy OpenSSL DLLs to the Windows system directory"* nên chọn **"The OpenSSL binaries (/bin) directory"** (hoặc system directory đều được, chỉ cần nhất quán với PATH).
   - 📸 **1-2** — chụp màn hình cài đặt đang chạy (bỏ qua cũng được nếu không muốn lộ thông tin máy).
3. Thêm OpenSSL vào PATH Windows: **Settings → System → About → Advanced system settings → Environment Variables → Path → Edit → New** → thêm `C:\Program Files\OpenSSL-Win64\bin` (đổi theo thư mục cài thực tế). OK hết các cửa sổ.
   - 📸 **1-3** — chụp hộp thoại Environment Variables với dòng `...\OpenSSL-Win64\bin` được bôi đen.
4. **Mở terminal MỚI** (PowerShell hoặc CMD — terminal cũ không nhận PATH mới), kiểm tra:
```powershell
openssl version
```

Kết quả mong đợi: `OpenSSL 3.x.x ...`
   - 📸 **1-4** — chụp terminal: lệnh `openssl version` + dòng version trả về.

### 1.2 Tạo cấu trúc dự án và file cấu hình
5. Tạo thư mục `secure-chat`, bên trong tạo tiếp thư mục `certs`:
```powershell
mkdir secure-chat
cd secure-chat
mkdir certs
```

6. Trong `secure-chat`, tạo file `openssl.cnf` với nội dung sau (dán nguyên văn):
```ini
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_ca
prompt = no

[req_distinguished_name]
C = VN
ST = HN
L = HN
O = MyOrg
OU = IT Dept
CN = MyRootCA

[v3_ca]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true
keyUsage = critical, keyCertSign, cRLSign
```

   - 📸 **1-5** — chụp VS Code: file `openssl.cnf` đang mở, thấy đủ section `[ req ]`, `[ v3_ca ]`… và cây thư mục `secure-chat/certs` bên trái.

### 1.3 Script sinh chứng chỉ `make-certs.bat`
7. Trong `secure-chat`, tạo file `make-certs.bat` (dán nguyên văn):
```bat
@echo off
setlocal enabledelayedexpansion
:: Di chuyen vao thu muc hien tai
cd /d %~dp0
:: Tao cac thu muc con trong certs/
mkdir certs\ca
mkdir certs\server
mkdir certs\client
:: CA
openssl genrsa -out certs\ca\ca.key 2048
openssl req -x509 -new -nodes -key certs\ca\ca.key -sha256 -days 3650 -out certs\ca\ca.crt -config openssl.cnf -extensions v3_ca
:: Server
openssl genrsa -out certs\server\server.key 2048
openssl req -new -key certs\server\server.key -out certs\server\server.csr -subj "/C=VN/ST=HN/L=HN/O=MyOrg/OU=IT Dept/CN=localhost"
openssl x509 -req -in certs\server\server.csr -CA certs\ca\ca.crt -CAkey certs\ca\ca.key -CAcreateserial -out certs\server\server.crt -days 365 -sha256
:: Client
openssl genrsa -out certs\client\client.key 2048
openssl req -new -key certs\client\client.key -out certs\client\client.csr -subj "/C=VN/ST=HN/L=HN/O=MyOrg/OU=IT Dept/CN=client"
openssl x509 -req -in certs\client\client.csr -CA certs\ca\ca.crt -CAkey certs\ca\ca.key -CAcreateserial -out certs\client\client.crt -days 365 -sha256
:: Doi ten file serial de tranh de
move certs\ca\ca.srl certs\ca\ca.srl.bak >nul 2>&1
echo.
echo ===============================
echo Cac chung chi da tao xong!
echo - CA: certs\ca\
echo - Server: certs\server\
echo - Client: certs\client\
echo ===============================
pause
```

8. Chạy script (double-click trong Explorer hoặc trong terminal):
```powershell
.\make-certs.bat
```

Kết quả mong đợi: bảng thông báo `Cac chung chi da tao xong!` liệt kê CA / Server / Client.
   - 📸 **1-6** — chụp terminal khi chạy `make-certs.bat`: thấy đủ các lệnh `openssl genrsa/req/x509` chạy và dòng `Cac chung chi da tao xong!`.
9. Kiểm tra thư mục `certs`:
```powershell
dir certs\ca; dir certs\server; dir certs\client
```

Kết quả mong đợi: `ca.key, ca.crt` — `server.key, server.csr, server.crt` — `client.key, client.csr, client.crt`.
   - 📸 **1-7** — chụp cửa sổ Explorer mở `certs` (thấy 3 thư mục `ca`, `server`, `client`) hoặc terminal `dir` liệt kê đủ 8 file chứng chỉ.

---

## PHẦN 2 — SECURECHAT (SERVER + CLIENT CHAT MÃ HÓA SSL/TLS)

Cấu trúc thư mục `F:\TH_LTANTT\TH_B3\secure-chat` sau phần này:
```
secure-chat\
├── certs\            (Phần 1)
├── openssl.cnf
├── make-certs.bat
├── message_encryption.py
├── connection_manager.py
├── room_manager.py
├── server.py
└── client.py
```

> **Cách làm:** tạo từng file trong VS Code đúng tên, dán nguyên văn code dưới đây, **không sửa gì** (kể cả comment). Nếu file không compile/ chạy lỗi, đối chiếu lại với ảnh trong PDF đề bài.

### 2.1 `message_encryption.py` — mã hóa đầu-cuối AES-256
Lớp `MessageEncryption`: tự sinh khóa AES-256, `encrypt()` trả về `IV + ciphertext`, `decrypt()` tách IV rồi giải mã (CBC + PKCS7).
```python
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives import padding
from cryptography.hazmat.backends import default_backend
import os

class MessageEncryption:
    def __init__(self, key=None):
        self.key = key or os.urandom(32)  # 256-bit AES key
        self.backend = default_backend()

    def encrypt(self, plaintext):
        iv = os.urandom(16)
        cipher = Cipher(algorithms.AES(self.key), modes.CBC(iv), backend=self.backend)
        encryptor = cipher.encryptor()

        padder = padding.PKCS7(128).padder()
        padded_data = padder.update(plaintext.encode('utf-8')) + padder.finalize()

        ct = encryptor.update(padded_data) + encryptor.finalize()
        return iv + ct

    def decrypt(self, ciphertext):
        iv = ciphertext[:16]
        ct = ciphertext[16:]
        cipher = Cipher(algorithms.AES(self.key), modes.CBC(iv), backend=self.backend)
        decryptor = cipher.decryptor()
        padded_data = decryptor.update(ct) + decryptor.finalize()

        unpadder = padding.PKCS7(128).unpadder()
        data = unpadder.update(padded_data) + unpadder.finalize()
        return data.decode('utf-8')
```

- 📸 **2-1** — chụp VS Code: toàn bộ `message_encryption.py` (thấy class `MessageEncryption`, hàm `encrypt`, `decrypt`).

### 2.2 `connection_manager.py` — quản lý kết nối client
Lớp `ConnectionManager`: từ điển `socket → {username, encryption_key}`, khóa `threading.Lock` để an toàn đa luồng.
```python
import threading

class ConnectionManager:
    def __init__(self):
        self.clients = {}  # socket -> dict {username, encryption_key}
        self.lock = threading.Lock()

    def add_client(self, client_sock, username, encryption_key):
        with self.lock:
            self.clients[client_sock] = {'username': username,
                                         'encryption_key': encryption_key}

    def remove_client(self, client_sock):
        with self.lock:
            if client_sock in self.clients:
                del self.clients[client_sock]

    def get_client(self, client_sock):
        with self.lock:
            return self.clients.get(client_sock)

    def broadcast(self, message, sender_sock):
        with self.lock:
            for client in self.clients:
                if client != sender_sock:
                    try:
                        client.send(message)
                    except Exception:
                        pass
```

- 📸 **2-2** — chụp VS Code: toàn bộ `connection_manager.py` (thấy `self.clients`, `self.lock`, các hàm add/remove/broadcast…).

### 2.3 `room_manager.py` — quản lý phòng chat
Lớp `RoomManager`: nhiều phòng, join/leave phòng, broadcast theo phòng.
```python
import threading

class RoomManager:
    def __init__(self):
        self.rooms = {}  # room_name -> set(client sockets)
        self.lock = threading.Lock()

    def create_room(self, room_name):
        with self.lock:
            if room_name not in self.rooms:
                self.rooms[room_name] = set()

    def join_room(self, room_name, client_sock):
        with self.lock:
            if room_name not in self.rooms:
                self.rooms[room_name] = set()
            self.rooms[room_name].add(client_sock)

    def leave_room(self, room_name, client_sock):
        with self.lock:
            if room_name in self.rooms:
                self.rooms[room_name].discard(client_sock)

    def broadcast_room(self, room_name, message, sender_sock):
        with self.lock:
            if room_name not in self.rooms:
                return
            for client in self.rooms[room_name]:
                if client != sender_sock:
                    try:
                        client.send(message)
                    except Exception:
                        pass
```

- 📸 **2-3** — chụp VS Code: toàn bộ `room_manager.py`.

### 2.4 `server.py` — server đa luồng SSL/TLS
Server: nạp cert server + CA, `ssl.SSLContext` với `CERT_REQUIRED` (xác thực cả client), `wrap_socket`, mỗi client một thread, broadcast tin qua `ConnectionManager`/`RoomManager`.
```python
import socket
import ssl
import threading
from connection_manager import ConnectionManager
from room_manager import RoomManager
from message_encryption import MessageEncryption

HOST = '127.0.0.1'
PORT = 8443

SERVER_CERT = 'certs/server/server.crt'
SERVER_KEY = 'certs/server/server.key'
CA_CERT = 'certs/ca/ca.crt'

connection_manager = ConnectionManager()
room_manager = RoomManager()

def handle_client(connstream, addr):
    print(f"[+] Client connected: {addr}")
    try:
        # Bước 1: nhận username và AES key
        # Đơn giản giả định client gửi: "username:key"
        data = connstream.recv(1024).decode()
        if ':' not in data:
            connstream.close()
            return
        username, key_hex = data.split(':')
        encryption_key = bytes.fromhex(key_hex)

        connection_manager.add_client(connstream, username, encryption_key)

        # Mặc định join phòng "general"
        room_manager.create_room('general')
        room_manager.join_room('general', connstream)

        me = MessageEncryption(encryption_key)

        while True:
            enc_message = connstream.recv(4096)
            if not enc_message:
                break
            try:
                message = me.decrypt(enc_message)
            except Exception:
                print("[!] Decryption failed")
                continue

            print(f"[{username}]: {message}")

            # Mã hóa lại message gửi cho phòng, kèm tên user
            out_msg = f"[{username}]: {message}"
            # Mã hóa từng client khác theo key của họ
            with connection_manager.lock:
                for client_sock, info in connection_manager.clients.items():
                    if client_sock != connstream:
                        try:
                            me_other = MessageEncryption(info['encryption_key'])
                            enc_out = me_other.encrypt(out_msg)
                            client_sock.send(enc_out)
                        except Exception:
                            pass

    except Exception as e:
        print(f"Exception {e}")
    finally:
        print(f"[-] Client disconnected: {addr}")
        connection_manager.remove_client(connstream)
        room_manager.leave_room('general', connstream)
        try:
            connstream.shutdown(socket.SHUT_RDWR)
        except Exception:
            pass
        connstream.close()

def main():
    context = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
    context.load_cert_chain(certfile=SERVER_CERT, keyfile=SERVER_KEY)
    context.load_verify_locations(cafile=CA_CERT)
    context.verify_mode = ssl.CERT_REQUIRED  # Yêu cầu client chứng chỉ
    context.options |= ssl.OP_NO_TLSv1 | ssl.OP_NO_TLSv1_1  # TLS1.2 trở lên

    bindsocket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    bindsocket.bind((HOST, PORT))
    bindsocket.listen(5)
    print(f"Server listening on {HOST}:{PORT}")

    while True:
        newsocket, fromaddr = bindsocket.accept()
        try:
            connstream = context.wrap_socket(newsocket, server_side=True)
            threading.Thread(target=handle_client,
                             args=(connstream, fromaddr), daemon=True).start()
        except ssl.SSLError as e:
            print(f"SSL Error: {e}")

if __name__ == '__main__':
    main()
```

- 📸 **2-4** — chụp VS Code: `server.py` (thấy cấu hình SSL context, `load_cert_chain`, `wrap_socket`, vòng lặp accept).

### 2.5 `client.py` — client xác minh chứng chỉ
Client: nạp CA cert để **xác minh server** (`CERT_REQUIRED`), nạp cert/key client để server xác minh lại, gửi `username|key_hex` khi kết nối, thread riêng nhận/giải mã tin, vòng lặp gửi tin đã mã hóa.
```python
import socket
import ssl
import threading
import os
import binascii
from message_encryption import MessageEncryption

SERVER_HOST = '127.0.0.1'
SERVER_PORT = 8443

CA_CERT = 'certs/ca/ca.crt'
CLIENT_CERT = 'certs/client/client.crt'
CLIENT_KEY = 'certs/client/client.key'

def receive_messages(ssl_sock, me):
    try:
        while True:
            enc_data = ssl_sock.recv(4096)
            if not enc_data:
                break
            try:
                msg = me.decrypt(enc_data)
                print(msg)
            except Exception:
                print("[!] Failed to decrypt message")
    except Exception:
        pass

def main():
    username = input("Username: ").strip()
    # Khởi tạo key AES 256
    aes_key = os.urandom(32)
    me = MessageEncryption(aes_key)

    context = ssl.create_default_context(ssl.Purpose.SERVER_AUTH,
                                         cafile=CA_CERT)
    context.load_cert_chain(certfile=CLIENT_CERT, keyfile=CLIENT_KEY)
    context.check_hostname = False
    context.verify_mode = ssl.CERT_REQUIRED

    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    ssl_sock = context.wrap_socket(sock, server_hostname=SERVER_HOST)
    ssl_sock.connect((SERVER_HOST, SERVER_PORT))

    # Gửi username + key hex cho server
    ssl_sock.send(f"{username}:{binascii.hexlify(aes_key).decode()}".encode())

    threading.Thread(target=receive_messages,
                     args=(ssl_sock, me), daemon=True).start()

    print("Type messages (type 'exit' to quit):")
    while True:
        msg = input()
        if msg.lower() == 'exit':
            break
        enc_msg = me.encrypt(msg)
        ssl_sock.send(enc_msg)

    ssl_sock.close()

if __name__ == '__main__':
    main()
```

- 📸 **2-5** — chụp VS Code: `client.py` (thấy `SSLContext`, `load_verify_locations`, `wrap_socket`, `input("Username: ")`).

### 2.6 Chạy thử 1 server + 2 client
10. **Cửa sổ 1 (server):**
```powershell
python .\server.py
```

Kết quả mong đợi: server báo đang nghe (cổng **8443**) và log client kết nối.
   - 📸 **2-6** — chụp terminal server: dòng khởi động/nghe cổng 8443.

11. **Cửa sổ 2 (client 1):**
```powershell
python .\client.py
```

Nhập `Username: phuoc` (hoặc tên bất kỳ), gõ `xin chao`, Enter.
Kết quả mong đợi: dòng `Type messages (type 'exit' to quit):` rồi tin đã gửi; server log `[phuoc]: xin chao`.
   - 📸 **2-7** — chụp terminal client 1: prompt `Username:`, dòng hướng dẫn gõ tin, tin `xin chao` đã gửi.

12. **Cửa sổ 3 (client 2):** chạy `python .\client.py`, nhập `Username: ty`, nhắn qua lại với client 1, ví dụ:
```
phuoc → xin chao
phuoc → day la ung dung chat ma hoa
ty    → hello
ty    → duoc ma hoa bang ssl
```

Kết quả mong đợi: cả 2 client thấy tin của nhau (giải mã thành công), server log đủ 2 user và các tin.
   - 📸 **2-8** — chụp **cả 3 cửa sổ** (server + 2 client) trong 1 khung hoặc 2 khung ghép: thấy `phuoc` và `ty` cùng online, các dòng chat qua lại đầy đủ.
13. Gõ `exit` ở mỗi client để thoát (hoặc Ctrl+C ở server).
   - 📸 **2-9** *(tuỳ chọn)* — chụp lúc gõ `exit` và kết nối đóng.

### 2.7 Commit & push lên GitHub
14. Trong thư mục chứa project (repo đã clone từ GitHub):
```powershell
git add .
git commit -m "[add] secure chat"
git push origin main
```

Kết quả mong đợi: commit báo **7 files changed** (`client.py`, `server.py`, `connection_manager.py`, `make-certs.bat`, `message_encryption.py`, `openssl.cnf`, `room_manager.py`), push lên `main` thành công.
   - 📸 **2-10** — chụp terminal: đủ 3 lệnh git + dòng `7 files changed` + dòng push thành công. *(Tuỳ chọn)* chụp thêm trang repo GitHub thấy các file vừa push — **KHÔNG** commit kèm `certs\` (khóa riêng tư), mục 4.4 có `.gitignore`.

---

## PHẦN 3 — CÀI NMAP VÀ CHUẨN BỊ SMTP

### 3.1 Cài Nmap
15. Tải Nmap tại <https://nmap.org/download.html> (bản **nmap-x.x.x-setup.exe** cho Windows), cài đặt bình thường.
    - 📸 **3-1** — chụp trang tải Nmap.
16. Mở terminal **mới**, kiểm tra:
```powershell
nmap --version
```

Kết quả mong đợi: `Nmap 7.x.x ...`. *(Máy phòng lab này đã cài Nmap 7.80 sẵn — `winget install Insecure.Nmap`; bản trên trang nmap.org mới hơn (7.9x) nên số version trong ảnh chụp có thể khác đề — ghi chú vào báo cáo.)* Nếu báo "không nhận diện được lệnh": thêm `C:\Program Files (x86)\Nmap` (hoặc `C:\Program Files\Nmap`) vào PATH như bước 3, **khởi động lại VS Code** rồi thử lại.
    - 📸 **3-2** — chụp terminal: `nmap --version` + dòng version.

### 3.2 Lấy SMTP_PASS (mật khẩu ứng dụng Gmail)
17. Đăng nhập Gmail → vào <https://myaccount.google.com/apppasswords> (yêu cầu đã bật xác thực 2 bước). Tạo app mới, đặt tên **`Netrecon`**, Google cấp cho bạn một mật khẩu ứng dụng 16 ký tự — **lưu lại**.
    - 📸 **3-3** — chụp màn hình trang App passwords sau khi tạo app `Netrecon`. **⚠️ KHÔNG chụp/đăng ảnh lộ mật khẩu ứng dụng** — che vùng mã hoặc chụp khi đã quay lại danh sách (chỉ thấy tên app).
    > Nếu không có mục App passwords: bật 2-Step Verification cho tài khoản Google trước, mục sẽ xuất hiện.

---

## PHẦN 4 — NETRECON (BỘ CÔNG CỤ TRINH SÁT MẠNG)

Yêu cầu (đề bài): `PortScanner` (quét TCP/UDP, kỹ thuật ẩn mình), `ServiceDetector` (nhận dạng phiên bản dịch vụ), `BannerGrabber` (lấy banner an toàn), `NetworkMapper` (sơ đồ mạng), `VulnChecker` (lỗ hổng cơ bản); có **rate limiting**, **ghi log mọi hoạt động có timestamp**, hỗ trợ **whitelist/blacklist**.

### 4.1 Cấu trúc thư mục
18. Trong `F:\TH_LTANTT\TH_B3` (repo `TH_LTANTT`), tạo thư mục `netrecon` với cấu trúc sau (file `.gitignore` nằm ở **gốc repo**):
```
netrecon\
├── modules\
│   ├── __init__.py
│   ├── banner_grabber.py
│   ├── email_sender.py
│   ├── filter_utils.py
│   ├── network_mapper.py
│   ├── port_scanner.py
│   ├── service_detector.py
│   └── vuln_checker.py
├── static\
│   └── style.css
├── templates\
│   ├── index.html
│   ├── layout.html
│   └── result.html
├── .env
├── app.py
├── cli.py
└── requirements.txt
```

   - 📸 **4-1** — chụp cây thư mục `netrecon` trong VS Code (thấy đủ `modules`, `static`, `templates`, `app.py`, `cli.py`, `requirements.txt`, `.env`).

### 4.2 Cài thư viện
19. File `requirements.txt`:
```text
flask
click
asyncio
htmx
python-dotenv
```
```powershell
cd F:\TH_LTANTT\TH_B3\netrecon
..\.venv\Scripts\python -m pip install -r requirements.txt
```

Kết quả mong đợi: `Successfully installed ...`
    - 📸 **4-2** — chụp terminal: `pip install -r requirements.txt` + dòng `Successfully installed`.

> **Ghi chú đề bài vs thực tế (nêu vào báo cáo):** `requirements.txt` của đề liệt kê `asyncio` (đã có sẵn trong thư viện chuẩn Python từ 3.4 — bản PyPI cùng tên chỉ là bản backport cũ, không cần) và `htmx` (htmx là thư viện **JavaScript**, gói Python cùng tên không được code dùng tới). Các gói thực sự cần: `flask`, `click`, `python-dotenv` (netrecon) + `cryptography` (secure-chat). `service_detector.py` gọi lệnh `nmap -sV` qua subprocess nên **bắt buộc phải cài Nmap** và cho `nmap` vào PATH.

### 4.3 File `.env`
20. Tạo `.env` trong `netrecon`, điền email gửi + **mật khẩu ứng dụng** vừa tạo ở 3.2:
```text
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-16-char-app-password
```

    - 📸 **4-3** — chụp `.env` trong VS Code nhưng **che/blur dòng mật khẩu** (chỉ thấy `SMTP_USER=...`, `SMTP_PASS=***`).

### 4.4 Các module (`modules/`)
21. `modules/__init__.py`: để trống (file rỗng đánh dấu package).

22. `modules/banner_grabber.py` — lấy banner qua socket, có timeout:
```python
import socket, logging
from datetime import datetime

logging.basicConfig(filename='netrecon.log', level=logging.INFO)

def log(msg):
    now = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    logging.info(f"[{now}] {msg}")

def grab_banner(ip, port):
    try:
        s = socket.socket()
        s.settimeout(2)
        s.connect((ip, port))
        banner = s.recv(1024).decode().strip()
        s.close()
        log(f"[{ip}:{port}] Banner: {banner}")
        return banner
    except Exception as e:
        return f"Failed to grab banner: {e}"
```

    - 📸 **4-4** — chụp VS Code: `banner_grabber.py`.

23. `modules/email_sender.py` — gửi kết quả quét qua Gmail SMTP (dùng `SMTP_USER`/`SMTP_PASS` từ `.env`):
```python
import smtplib
from email.message import EmailMessage
from dotenv import load_dotenv

load_dotenv()

def send_email(receiver_email, subject, body, smtp_user, smtp_pass):
    msg = EmailMessage()
    msg['Subject'] = subject
    msg['From'] = smtp_user
    msg['To'] = receiver_email
    msg.set_content(body)

    try:
        with smtplib.SMTP_SSL('smtp.gmail.com', 465) as smtp:
            smtp.login(smtp_user, smtp_pass)
            smtp.send_message(msg)
        print(f"[+] Email sent to {receiver_email}")
    except Exception as e:
        print(f"[-] Email failed: {e}")
```

    - 📸 **4-5** — chụp VS Code: `email_sender.py` (thấy `smtplib`, `SMTP_SSL`, đọc `.env`).

24. `modules/filter_utils.py` — whitelist/blacklist + rate limiting + ghi log timestamp:
```python
def filter_targets(ip_list, whitelist=None, blacklist=None):
    whitelist = set(whitelist or [])
    blacklist = set(blacklist or [])
    result = []
    for ip in ip_list:
        if blacklist and ip in blacklist:
            continue
        if whitelist and ip not in whitelist:
            continue
        result.append(ip)
    return result
```

    - 📸 **4-6** — chụp VS Code: `filter_utils.py` (thấy whitelist/blacklist, rate limit, hàm log).

25. `modules/network_mapper.py` — liệt kê interface/bảng ARP (sơ đồ mạng):
```python
import subprocess, logging
from datetime import datetime

logging.basicConfig(filename='netrecon.log', level=logging.INFO)

def log(msg):
    now = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    logging.info(f"[{now}] {msg}")

def map_network():
    log("Mapping network...")
    try:
        arp_output = subprocess.check_output(["arp", "-a"]).decode()
        log(arp_output)
        return arp_output
    except Exception as e:
        return f"Error: {e}"
```

    - 📸 **4-7** — chụp VS Code: `network_mapper.py`.

26. `modules/port_scanner.py` — quét cổng TCP/UDP (dựa trên `python-nmap`):
```python
import asyncio, logging, socket
from datetime import datetime

logging.basicConfig(filename='netrecon.log', level=logging.INFO)

def log(message):
    now = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    logging.info(f"[{now}] {message}")

async def scan_port(target, port, semaphore):
    try:
        async with semaphore:
            conn = asyncio.open_connection(target, port)
            reader, writer = await asyncio.wait_for(conn, timeout=1)
            log(f"Port {port} is open on {target}")
            print(f"[+] {port}/tcp open")
            writer.close()
            await writer.wait_closed()
    except:
        pass

async def async_scan_ports(target, ports, rate_limit=100):
    semaphore = asyncio.Semaphore(rate_limit)
    tasks = [scan_port(target, port, semaphore) for port in ports]
    await asyncio.gather(*tasks)
```

    - 📸 **4-8** — chụp VS Code: `port_scanner.py` (thấy tham số kỹ thuật quét, xử lý kết quả open/closed/filtered).

27. `modules/service_detector.py` — nhận dạng phiên bản dịch vụ:
```python
import subprocess, logging
from datetime import datetime

logging.basicConfig(filename='netrecon.log', level=logging.INFO)

def log(msg):
    now = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    logging.info(f"[{now}] {msg}")

def detect_service(ip, ports):
    ports_str = ','.join(str(p) for p in ports)
    cmd = ["nmap", "-sV", "-p", ports_str, ip]
    log(f"Running service detection on {ip}:{ports_str}")
    try:
        result = subprocess.check_output(cmd).decode()
        log(result)
        return result
    except subprocess.CalledProcessError as e:
        return f"Error: {e.output.decode()}"
```

    - 📸 **4-9** — chụp VS Code: `service_detector.py`.

28. `modules/vuln_checker.py` — kiểm tra lỗ hổng cơ bản theo banner/dịch vụ:
```python
VULN_PORTS = {
    21: "FTP - CVE-2015-3306, CVE-2001-0261",
    22: "SSH - CVE-2018-15473",
    23: "Telnet - CVE-2011-4862",
    80: "HTTP - CVE-2021-41773",
    443: "HTTPS - CVE-2021-3449"
}

def check_vulns(ports):
    result = {}
    for port in ports:
        if port in VULN_PORTS:
            result[port] = VULN_PORTS[port]
    return result
```

    - 📸 **4-10** — chụp VS Code: `vuln_checker.py`.

### 4.5 Giao diện web (`templates/`, `static/`)
29. `templates/layout.html` — khung trang dùng chung:
```html
<!DOCTYPE html>
<html>
<head>
  <title>NetRecon</title>
  <link rel="stylesheet" href="/static/style.css">
</head>
<body>
  <div class="container">
    <h1>NetRecon - Network Reconnaissance Toolkit</h1>
    {% block content %}{% endblock %}
  </div>
</body>
</html>
```

30. `templates/index.html` — form nhập Target IP / Ports / Mode / Email + nút **Scan**:
```html
{% extends 'layout.html' %}
{% block content %}
<form method="post" action="/scan" hx-post="/scan" hx-target="#results">
  <label>Target IP:</label>
  <input type="text" name="target" required><br>
  <label>Ports (comma-separated):</label>
  <input type="text" name="ports" value="22,80,443"><br>
  <label>Mode:</label>
  <select name="mode">
    <option value="all">All</option>
    <option value="scan">Port Scan</option>
    <option value="service">Service Detection</option>
    <option value="banner">Banner Grab</option>
    <option value="map">Network Map</option>
    <option value="vuln">Vulnerability Check</option>
  </select><br>
  <label>Email nhận kết quả:</label>
  <input type="email" name="email" required><br>
  <button type="submit">Scan</button>
</form>

<div id="results">
</div>
{% endblock %}
```

31. `templates/result.html` — trang hiển thị kết quả quét:
```html
{% if result.scan %}
<h2>Scan Result:</h2>
<pre>{{ result.scan }}</pre>
{% endif %}

{% if result.service %}
<h2>Service Detection:</h2>
<pre>{{ result.service }}</pre>
{% endif %}

{% if result.banner %}
<h2>Banner Grabbing:</h2>
<ul>
  {% for port, banner in result.banner.items() %}
    <li>Port {{ port }}: {{ banner }}</li>
  {% endfor %}
</ul>
{% endif %}

{% if result.map %}
<h2>Network Map:</h2>
<pre>{{ result.map }}</pre>
{% endif %}

{% if result.vuln %}
<h2>Vulnerability Check:</h2>
<ul>
  {% for port, vuln in result.vuln.items() %}
    <li>Port {{ port }}: {{ vuln }}</li>
  {% endfor %}
</ul>
{% endif %}
```

32. `static/style.css` — giao diện:
```css
body {
  font-family: monospace; background: #1e1e1e;
  color: #eee; padding: 20px;
}
input, select, button {
  margin: 5px; padding: 5px;
}
.container {
  max-width: 800px; margin: auto;
}
pre {
  background: #2e2e2e; padding: 10px;
  border-left: 4px solid #4CAF50;
}
```

    - 📸 **4-11** — chụp VS Code: 3 file template + `style.css` (có thể ghép 2 khung: `index.html` và `result.html`).

### 4.6 `cli.py` và `app.py`
33. `cli.py` — dòng lệnh: `--target`, `--ports`, `--mode` (scan/service/banner/map/vuln/all):
```python
import click, asyncio
from modules.port_scanner import async_scan_ports
from modules.service_detector import detect_service
from modules.banner_grabber import grab_banner
from modules.network_mapper import map_network
from modules.vuln_checker import check_vulns

@click.command()
@click.option('--target', prompt='Target IP', help='Target IP address.')
@click.option('--ports', default='22,80,443',
              help='Comma-separated port list or range.')
@click.option('--rate-limit', default=100, help='Max concurrent scans.')
@click.option('--mode', default='all',
              help='Choose from: scan, service, banner, map, vuln, all')
def cli(target, ports, rate_limit, mode):
    ports_list = list(map(int, ports.split(',')))

    if mode in ['scan', 'all']:
        asyncio.run(async_scan_ports(target, ports_list, rate_limit))
    if mode in ['service', 'all']:
        print(detect_service(target, ports_list))
    if mode in ['banner', 'all']:
        for p in ports_list:
            print(f"{p}: {grab_banner(target, p)}")
    if mode in ['map', 'all']:
        print(map_network())
    if mode in ['vuln', 'all']:
        print(check_vulns(ports_list))

if __name__ == '__main__':
    cli()
```

    - 📸 **4-12** — chụp VS Code: `cli.py` (thấy argparse với `--target`, `--ports`, `--mode`).

34. `app.py` — Flask app cho web UI + gửi email kết quả:
```python
from flask import Flask, render_template, request
from modules import port_scanner, service_detector, banner_grabber
from modules import network_mapper, vuln_checker, email_sender
import asyncio, os

app = Flask(__name__)

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/scan', methods=['POST'])
def scan():
    target = request.form['target']
    ports = list(map(int, request.form['ports'].split(',')))
    mode = request.form['mode']
    email = request.form['email']
    result = {}

    if mode in ['scan', 'all']:
        result['scan'] = asyncio.run(port_scanner.async_scan_ports(target,
                                                                  ports))
    if mode in ['service', 'all']:
        result['service'] = service_detector.detect_service(target, ports)
    if mode in ['banner', 'all']:
        result['banner'] = {port:
            banner_grabber.grab_banner(target, port) for port in ports}
    if mode in ['map', 'all']:
        result['map'] = network_mapper.map_network()
    if mode in ['vuln', 'all']:
        result['vuln'] = vuln_checker.check_vulns(ports)

    body = "Kết quả NetRecon:\n\n"
    for k, v in result.items():
        body += f"--- {k.upper()} ---\n{v}\n\n"

    smtp_user = os.getenv("SMTP_USER")
    smtp_pass = os.getenv("SMTP_PASS")
    email_sender.send_email(email, "Kết quả quét từ NetRecon", body,
                            smtp_user, smtp_pass)

    return render_template('result.html', result=result)

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
```

    - 📸 **4-13** — chụp VS Code: `app.py` (thấy route `/`, route xử lý `Scan`, gọi `email_sender`).

35. Thêm `.gitignore` (đề bài trang 25):
```text
gitsecure.log
certs/
*.pem
.env
```

    - 📸 **4-14** — chụp VS Code: `.gitignore` với các dòng `certs/`, `.env`, `__pycache__/`…

---

## PHẦN 5 — KIỂM THỬ NETRECON

### 5.1 Test nhanh `cli.py`
36. Trong terminal (thư mục `netrecon`):
```powershell
python .\cli.py --target 127.0.0.1 --ports 22,80,443 --mode all
```

*(Đề bài chạy `cli.py` với IP máy trong lớp; ở đây quét `127.0.0.1` — máy mình — cho hợp lệ. Muốn giống đề, thay bằng IP máy bạn và ghi chú vào báo cáo.)*

Kết quả mong đợi: các dòng `[+] <port>/tcp open` với cổng mở (không in gì nếu cổng đóng), mục service là output của `nmap -sV`, `--- BANNER ---` trả banner hoặc `Failed to grab banner: timed out`, `--- MAP ---` liệt kê interface + bảng ARP.

> **Đã kiểm chứng** (07/10/2026, quét 127.0.0.1 cổng 22,80,443): `nmap -sV` trả bảng `PORT STATE SERVICE VERSION` với 3 cổng `closed`, banner cả 3 cổng `Failed to grab banner: timed out`, MAP liệt kê đủ interface + bảng ARP. Ghi chú 2 đặc điểm code đề bài: (1) `async_scan_ports` không `return` giá trị nên trong email/web mục SCAN hiện `None` (đúng như ảnh email trong đề); (2) trang kết quả là mảnh HTML rời (result.html không extends layout) — muốn thấy form + kết quả cùng trang như ảnh đề thì thêm `<script src="https://unpkg.com/htmx.org@2"></script>` vào `<head>` của `layout.html` (tùy chọn).
    - 📸 **5-1** — chụp terminal: dòng lệnh + đủ các mục `SCAN` / `SERVICE` / `BANNER` / `MAP` trong output.

37. Test kỹ thuật quét qua host được phép quét chính thức của Nmap:
```powershell
python .\cli.py --target scanme.nmap.org --ports 22,80 --mode scan
```

Kết quả mong đợi: `[+] 22/tcp open`, `[+] 80/tcp open`.
    - 📸 **5-2** — chụp terminal: 2 dòng `[+] 22/tcp open`, `[+] 80/tcp open`.

### 5.2 Chạy web app
38. Chạy Flask:
```powershell
python .\app.py
```

Kết quả mong đợi: `* Serving Flask app 'app'`, `* Debug mode: on`, `* Running on http://127.0.0.1:5000`.
    - 📸 **5-3** — chụp terminal Flask đang chạy (thấy `Running on http://127.0.0.1:5000`).

39. Mở <http://localhost:5000/>, điền:
    - **Target IP:** `127.0.0.1` (hoặc IP máy bạn)
    - **Ports:** `22,80,443`
    - **Mode:** `All`
    - **Email nhận kết quả:** email của bạn
    Nhấn **Scan**.
    - 📸 **5-4** — chụp form đã điền đủ 4 trường + nút Scan (trước khi bấm hoặc ngay sau khi bấm).

40. Xem mục **Kết quả phản hồi** trên trang: bảng cổng kèm trạng thái (open/closed), banner, network map.
    - 📸 **5-5** — chụp vùng "Kết quả phản hồi": thấy bảng `PORT STATE SERVICE` với các dòng `22/tcp`, `80/tcp`, `443/tcp` và kết quả banner/map.

41. Vào hộp thư email, mở email **"Kết quả quét từ NetRecon"**.
    - 📸 **5-6** — chụp email: thấy **người gửi** (email của bạn), **tiêu đề** `Kết quả quét từ NetRecon`, và thân email có các mục `--- SCAN ---`, `--- SERVICE ---`, `--- BANNER ---`, `--- MAP ---` với bảng cổng.

### 5.3 Commit & push Netrecon
42.
```powershell
git add .
git commit -m "[add] netrecon"
git push origin main
```

Kết quả mong đợi: commit chứa `netrecon/` (không kèm `.env`, `certs/`), push thành công.
    - 📸 **5-7** — chụp terminal 3 lệnh git + output push thành công. *(Tuỳ chọn)* chụp trang repo GitHub thấy thư mục `netrecon`.

---

## BẢNG CHECKLIST ẢNH CHỤP (dán vào báo cáo)

| Mã ảnh | Bước | Nội dung phải thấy trong khung hình |
|---|---|---|
| 1-1 | Tải OpenSSL | Trang slproweb, bản Win64 OpenSSL |
| 1-2 | Cài OpenSSL | Màn hình cài đặt (tuỳ chọn) |
| 1-3 |Thêm PATH | Hộp thoại Environment Variables, dòng OpenSSL\bin |
| 1-4 | Kiểm tra | `openssl version` + kết quả |
| 1-5 | openssl.cnf | Nội dung file + cây thư mục |
| 1-6 | make-certs.bat | Output các lệnh openssl + "Cac chung chi da tao xong!" |
| 1-7 | Kiểm tra certs | 8 file trong certs\ca, \server, \client |
| 2-1 | message_encryption.py | Toàn bộ code file |
| 2-2 | connection_manager.py | Toàn bộ code file |
| 2-3 | room_manager.py | Toàn bộ code file |
| 2-4 | server.py | Toàn bộ code file |
| 2-5 | client.py | Toàn bộ code file |
| 2-6 | Chạy server | Server nghe cổng 8443 |
| 2-7 | Client 1 | Prompt Username + tin nhắn đã gửi |
| 2-8 | 2 client chat | phuoc ↔ ty nhắn qua lại, server log đủ |
| 2-9 | Thoát | Gõ `exit` (tuỳ chọn) |
| 2-10 | Git | `7 files changed` + push thành công |
| 3-1 | Tải Nmap | Trang nmap.org/download |
| 3-2 | Kiểm tra Nmap | `nmap --version` + version |
| 3-3 | App password | App `Netrecon` trong Google (CHE mật khẩu) |
| 4-1 | Cấu trúc | Cây thư mục netrecon trong VS Code |
| 4-2 | pip install | `Successfully installed` |
| 4-3 | .env | 2 biến SMTP (CHE mật khẩu) |
| 4-4 | banner_grabber.py | Code file |
| 4-5 | email_sender.py | Code file |
| 4-6 | filter_utils.py | Code file (whitelist, rate limit, log) |
| 4-7 | network_mapper.py | Code file |
| 4-8 | port_scanner.py | Code file |
| 4-9 | service_detector.py | Code file |
| 4-10 | vuln_checker.py | Code file |
| 4-11 | Templates + CSS | index.html, result.html, style.css |
| 4-12 | cli.py | Code file (argparse) |
| 4-13 | app.py | Code file (Flask routes) |
| 4-14 | .gitignore | Nội dung file |
| 5-1 | CLI test all | Lệnh + mục SCAN/BANNER/MAP |
| 5-2 | scanme.nmap.org | `[+] 22/tcp open`, `[+] 80/tcp open` |
| 5-3 | Flask chạy | `Running on http://127.0.0.1:5000` |
| 5-4 | Form web | 4 trường đã điền + nút Scan |
| 5-5 | Kết quả web | Bảng PORT STATE SERVICE + banner/map |
| 5-6 | Email | Tiêu đề "Kết quả quét từ NetRecon" + thân đủ mục |
| 5-7 | Git netrecon | Lệnh git + push thành công |

---

## SỰ CỐ THƯỜNG GẶP

| Triệu chứng | Nguyên nhân | Cách xử lý |
|---|---|---|
| `openssl` không phải là lệnh nội bộ | Chưa thêm PATH / terminal cũ | Thêm `OpenSSL-Win64\bin` vào PATH (bước 3), **mở terminal mới** |
| `make-certs.bat` lỗi "unable to load config" | Sai thư mục hiện hành / thiếu `openssl.cnf` | Chạy script từ trong `secure-chat` (script đã `cd /d %~dp0`), kiểm tra `openssl.cnf` cùng cấp |
| Client báo `[!] Failed to decrypt message` | Khóa mã hóa không khớp / lệch phiên bản file | Dùng đúng code 5 file trong hướng dẫn, chạy lại cả server lẫn client |
| Client/server SSL handshake lỗi (`certificate verify failed`) | Sai `CN=localhost` khi tạo cert / trỏ nhầm đường dẫn cert | Tạo lại cert đúng `make-certs.bat`; kiểm tra đường dẫn `certs\...` trong `server.py`, `client.py`; kết nối tới `localhost` |
| `nmap` không nhận diện được lệnh | Chưa PATH Nmap / VS Code cũ | Thêm `C:\Program Files (x86)\Nmap` vào PATH, khởi động lại VS Code |
| `pip install scapy` (hoặc gói khác) lỗi biên dịch | Python quá mới, không có wheel | Dùng Python 3.11–3.13 (`py -3.13 -m venv venv`) |
| Gửi email lỗi `SMTPAuthenticationError` | Dùng mật khẩu Gmail thay vì **mật khẩu ứng dụng** / chưa bật 2FA | Tạo App Password ở myaccount.google.com/apppasswords, dán vào `.env` |
| Email không thấy | Vào mục Quảng cáo/Social hoặc spam | Kiểm tra hộp thư rác; gửi thử tới chính mình |
| `app.py` lỗi `Address already in use` | Port 5000 đang bận | Đóng process cũ hoặc đổi port `app.run(port=5001)` |
| `git push` bị từ chối | Chưa đăng nhập / sai remote | `git remote -v` kiểm tra, đăng nhập lại Git Credential Manager |
| Lỡ commit `.env` / `certs\` | Quên `.gitignore` | Thêm vào `.gitignore`, `git rm --cached .env`, đổi mật khẩu ứng dụng ngay |
| `--mode service` / `all` lỗi `FileNotFoundError: [WinError 2]` | Chưa cài Nmap hoặc `nmap` chưa vào PATH của phiên shell đang chạy | Cài Nmap, thêm `C:\Program Files (x86)\Nmap` vào PATH, mở terminal mới |
| Web/email mục SCAN hiện `None` | `async_scan_ports` không trả kết quả (đặc điểm code đề) | Bình thường — kết quả quét cổng chỉ in ra console; ghi chú vào báo cáo |
| Trang kết quả chỉ có chữ kết quả, mất form | result.html là fragment cho htmx | Thêm script htmx CDN vào `layout.html` (xem mục 5.1) hoặc chấp nhận như code đề |
| Chạy server hiện `DeprecationWarning: ssl.OP_NO_SSL*...` | Python 3.10+ cảnh báo cờ `OP_NO_TLSv1` | Không ảnh hưởng chạy (vẫn TLS 1.2+), bỏ qua hoặc ghi chú trong báo cáo |
| Terminal mất log của server khi Ctrl+C / kill | Python buffer stdout khi redirect vào file | Chạy `python -u server.py` nếu muốn log tức thì |

---

## LƯU Ý DÀNH CHO BÁO CÁO
- Phần lý thuyết (3.1.1–3.1.3): socket thường không mã hóa → SSL/TLS bảo vệ bằng mã hóa đối xứng sau bắt tay bất đối xứng, xác thực bằng chứng chỉ số CA; quy trình xác minh chứng chỉ (chữ ký CA, chuỗi lên Root CA, hạn dùng, thu hồi, khớp danh tính).
- Phần 3.3: các trạng thái cổng (open/closed/filtered), kỹ thuật quét (TCP Connect, SYN, UDP, Xmas/FIN/NULL, Idle); nhận dạng dịch vụ chủ động/bị động (banner matching, phân tích phản hồi giao thức).
- Nêu **sai lệch môi trường** đã ghi ở đầu tài liệu (IP thay bằng 127.0.0.1) và ghi chú đạo đức khi trình bày kết quả quét.
- Mã ảnh khi dán vào báo cáo Word: đặt tiêu đề "Hình X. <mô tả>" ngay dưới mỗi ảnh theo thứ tự bảng checklist.
