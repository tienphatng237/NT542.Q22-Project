# NT542.Q22 - Đồ án cuối kì
# TRIỂN KHAI BẢO MẬT CHO HỆ THỐNG WINDOWS SERVER 2022 THEO TIÊU CHUẨN CIS BENCHMARK 

## 1. Tổng quan
![Sơ đồ tổng quan](pictures/diagram.png)

## 2. Các hạng mục triển khai

| Thành viên | Hạng mục | Các mục CIS phụ trách | Trọng tâm rủi ro |
| --- | --- | --- | --- |
| **Như Trang** | Identity & Access Control | `Mục 1 - Account Policies` <br>`Mục 2.2 - User Rights Assignment`<br>`Mục 2.3.1 - Security Options (Accounts)` | Brute-force và leo thang đặc quyền |
| **Trung Kiên** | Network & Services Security | `Mục 5 - System Services`<br>`Mục 9 - Windows Defender Firewall`<br>`Mục 18.6 - Administrative Templates (Network)` | Tấn công qua mạng, khai thác dịch vụ (PrintNightmare) |
| **Phú Thuận** | Auditing & Monitoring | `Mục 17 - Advanced Audit Policy Configuration`<br>`Mục 18.10.26 - Event Log Service`<br>`Mục 2.3.2 - Audit (Security Options)` | Thiếu bằng chứng điều tra, không phát hiện xâm nhập |
| **Tiến Phát** | System Hardening & Antimalware | `Mục 18.10.42 - Microsoft Defender Antivirus`<br>`Mục 18.4 & 18.5 - MS Security Guide & MSS (Legacy)`<br>`Mục 2.3.17 - User Account Control (UAC)`<br>`Mục 18.9.5 - Device Guard`<br>`Mục 18.9.27 - Local Security Authority (LSA)`<br>`Mục 18.10.8 - AutoPlay Policies`<br>`Mục 18.9.13 - Early Launch Antimalware (ELAM)`<br>`Mục 18.10.77 - Windows Defender SmartScreen` | Mã độc thực thi trái phép, đánh cắp chứng thực cục bộ |

## 3. Triển khai môi trường thực nghiệm

Hạ tầng lab được triển khai bằng Terraform theo 2 stack tách biệt:
- `kvm/terraform/windows`: tạo 3 máy Windows (`dc01`, `member01`, `fs01`) và network dùng chung `windows-lab-net`
- `kvm/terraform/linux/wazuh`: tạo máy Linux `log01` chạy Wazuh và nối vào cùng network

Lưu ý quan trọng:
- Phải `apply` stack Windows trước, sau đó mới `apply` stack Linux để bảo đảm network `windows-lab-net` đã tồn tại.
- Bộ mã hạ tầng này chỉ chạy trên môi trường Linux kernel có hỗ trợ ảo hóa `KVM/QEMU`.

### 3.1 Triển khai hạ tầng Windows

Chạy từ thư mục gốc repository:

```bash
cd kvm/terraform/windows
terraform init
terraform apply --auto-approve
```

Kết quả sau khi apply:
- Tạo network `windows-lab-net`
- Tạo 3 VM Windows: `dc01`, `member01`, `fs01`
- Sinh inventory Ansible cho Windows tại `ansible/inventories/vm/windows.ini`

### 3.2 Triển khai hạ tầng Linux (Wazuh)

```bash
cd kvm/terraform/linux/wazuh
terraform init
terraform apply --auto-approve
```

Kết quả sau khi apply:
- Tạo VM Linux `log01`
- Nối `log01` vào `windows-lab-net`
- Sinh inventory Ansible cho Linux tại `ansible/inventories/vm/log_server.ini`

### 3.3 Xóa và tạo lại môi trường

Khi cần reset lab, nên destroy theo thứ tự ngược lại:

```bash
cd kvm/terraform/linux/wazuh
terraform destroy --auto-approve

cd ../../windows
terraform destroy --auto-approve
```

Sau đó apply lại theo đúng thứ tự: `windows` trước, `linux/wazuh` sau.

## 4. Triển khai các công cụ

### 4.1 Wazuh
Wazuh được triển khai như nền tảng giám sát tập trung cho toàn bộ lab. Trong kiến trúc của nhóm, `log01` đóng vai trò `Wazuh manager/dashboard`, còn `dc01`, `member01`, `fs01` chạy `Wazuh agent` để gửi log, inventory và kết quả SCA.

Việc tích hợp Wazuh giúp theo dõi trạng thái sau hardening theo thời gian thực: online/offline agent, cảnh báo bảo mật, kết quả `Security Configuration Assessment (SCA)` và `Vulnerability Detection`.

Lý do lựa chọn Wazuh trong đồ án:
- `Ansible` và `Wazuh` không trùng vai trò mà bổ trợ cho nhau. `Ansible` là công cụ **thực thi thay đổi cấu hình** hàng loạt (audit/remediate/post-audit), còn `Wazuh` là công cụ **giám sát liên tục** sau khi cấu hình đã áp dụng.
- Nếu chỉ dùng Ansible pipeline, hệ thống chủ yếu được kiểm tra tại thời điểm chạy playbook; các thay đổi phát sinh ngoài ý muốn sau đó (drift cấu hình, tắt dịch vụ bảo mật, thay đổi policy thủ công) có thể không được phát hiện ngay.
- Wazuh cung cấp lớp vận hành SOC cơ bản cho lab: thu thập sự kiện tập trung, theo dõi mức tuân thủ theo thời gian, cảnh báo khi có dấu hiệu lệch chuẩn hoặc rủi ro mới.
- Việc thêm Wazuh góp phần hoàn thiện vòng đời bảo mật theo mô hình: `Triển khai (Ansible) -> Giám sát liên tục (Wazuh) -> Cảnh báo/điều chỉnh`.

#### Lệnh setup Wazuh
Chạy trong thư mục `ansible`:

```bash
cd ansible
ansible-playbook -i inventories/vm/windows.ini playbooks/bootstrap/bootstrap_windows.yml
ansible-playbook -i inventories/vm/log_server.ini -i inventories/vm/windows.ini playbooks/wazuh/wazuh.yml
```

Trong đó:
- `bootstrap/bootstrap_windows.yml`: bootstrap kênh WinRM trên các máy Windows
- `wazuh/wazuh.yml`: cài `Wazuh manager` trên `log01` và `Wazuh agent` trên các máy Windows

Nếu cần chạy tách:

```bash
cd ansible
ansible-playbook -i inventories/vm/log_server.ini playbooks/wazuh/wazuh_server.yml
ansible-playbook -i inventories/vm/log_server.ini -i inventories/vm/windows.ini playbooks/wazuh/wazuh_agent.yml
```

#### Tài khoản mặc định Wazuh dashboard
- user: `admin`
- password: `AdminWazuh9*`

### 4.2 HardeningKitty
HardeningKitty trong pipeline cần 2 thành phần local:
- `module/`: engine thực thi (`HardeningKitty.psd1`, `HardeningKitty.psm1`)
- `lists/`: baseline/finding list để chấm điểm theo vai trò máy chủ (DC/Member)

Để chạy từ đầu, thực hiện bootstrap như sau:

```bash
mkdir -p tooling/hardeningkitty/module tooling/hardeningkitty/lists

# 1) Tải engine HardeningKitty từ upstream
curl -fsSL -o tooling/hardeningkitty/module/HardeningKitty.psd1 \
  https://raw.githubusercontent.com/0x6d69636b/windows_hardening/master/HardeningKitty.psd1
curl -fsSL -o tooling/hardeningkitty/module/HardeningKitty.psm1 \
  https://raw.githubusercontent.com/0x6d69636b/windows_hardening/master/HardeningKitty.psm1

# 2) Tải 2 finding list mặc định đang dùng trong đồ án
#    (mapping tại ansible/inventories/vm/group_vars/all.yml)
curl -fsSL -o tooling/hardeningkitty/lists/finding_list_msft_security_baseline_windows_server_2022_21h2_dc_machine.csv \
  https://raw.githubusercontent.com/0x6d69636b/windows_hardening/master/lists/finding_list_msft_security_baseline_windows_server_2022_21h2_dc_machine.csv
curl -fsSL -o tooling/hardeningkitty/lists/finding_list_msft_security_baseline_windows_server_2022_21h2_member_machine.csv \
  https://raw.githubusercontent.com/0x6d69636b/windows_hardening/master/lists/finding_list_msft_security_baseline_windows_server_2022_21h2_member_machine.csv

# 3) Kiểm tra nhanh trước khi chạy pipeline
ls -la tooling/hardeningkitty/module
ls -la tooling/hardeningkitty/lists | grep -E "windows_server_2022_21h2_(dc|member)_machine"
```

## 5. Triển khai quy trình benchmark

Quy trình benchmark trong đồ án được chạy theo vòng đời chuẩn:
`Bootstrap -> Audit -> Remediation -> Post-Audit -> Validation (HardeningKitty) -> Report`.

### 5.1 Chạy toàn bộ pipeline (khuyến nghị)

```bash
cd ansible

# B1: Bootstrap kênh quản trị WinRM ổn định trước
ansible-playbook -i inventories/vm/windows.ini playbooks/bootstrap/bootstrap_windows.yml

# B2: Chạy full pipeline benchmark
ansible-playbook -i inventories/vm/windows.ini playbooks/pipeline/pipeline.yml
```

### 5.2 Chạy theo từng pha (khi cần debug)

```bash
cd ansible

# Resolve runtime account WinRM
ansible-playbook -i inventories/vm/windows.ini playbooks/pipeline/resolve_windows_runtime.yml

# Audit
ansible-playbook -i inventories/vm/windows.ini playbooks/ops/audit.yml

# Remediation
ansible-playbook -i inventories/vm/windows.ini playbooks/ops/remediation.yml

# Post-Audit
ansible-playbook -i inventories/vm/windows.ini playbooks/ops/post_audit.yml

# Validation (HardeningKitty)
ansible-playbook -i inventories/vm/windows.ini playbooks/ops/validation.yml

# Report
ansible-playbook -i inventories/vm/windows.ini playbooks/ops/report.yml
```

### 5.3 Vị trí kết quả

- Report pipeline (HTML/JSON/CSV) lưu tại: `pipeline/reports/<host>/<module>/`
- Log thực thi script trên Windows: `C:\CIS-Automation\Logs\`
- Kết quả HardeningKitty được Ansible thu về thư mục report theo từng host.

### 5.4 Kiểm chứng giám sát tập trung bằng Wazuh

Sau khi pipeline hoàn tất, chạy Wazuh để giám sát định kỳ và chấm SCA tập trung:

```bash
cd ansible
ansible-playbook -i inventories/vm/log_server.ini -i inventories/vm/windows.ini playbooks/wazuh/wazuh.yml
```

Trong cấu hình hiện tại, agent dùng custom policy:
`cis_win2022_v5_custom_nt542.yml`.

### 5.5 Lưu ý vận hành

- Nếu vừa recreate VM, luôn chạy lại `bootstrap_windows.yml` trước pipeline.
- Nếu WinRM báo `credentials were rejected`, kiểm tra lại account runtime và trạng thái dịch vụ WinRM trên host.
- Nếu cần dọn report cũ trước khi benchmark lại, dọn trong `pipeline/reports/` để tránh nhầm kết quả.

## 6. Demo thực tế

Xem toàn bộ phần triển khai đồ án tại đây:

👉 **Video Demo:** [▶️ YouTube](https://www.youtube.com/watch?v=uFcGBNIMZTU)

- Thực hiện triển khai cơ sở hạ tầng sử dụng IaC
- Triển khai vòng đời bảo mật hoàn chỉnh sử dụng Ansible
- Cấu hình giám sát bảo mật định kì sử dụng Wazuh

## 7. Slide và báo cáo

Xem tại:

- 📄 Báo cáo: [NT542_Group7_FinalReport.pdf](documents/NT542_Group7_FinalReport.pdf)
- 📄 Slide: [Nhom07_slide.pptx](documents/Nhom07_slide.pptx)

## 8. Kết luận

Đồ án đã xây dựng được quy trình hardening Windows Server 2022 theo chuẩn CIS theo hướng tự động hóa, có thể lặp lại và dễ mở rộng. Mô hình kết hợp Terraform, Ansible, PowerShell, HardeningKitty và Wazuh giúp triển khai, kiểm định và giám sát hệ thống một cách nhất quán trong môi trường lab.
