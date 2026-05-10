# NT542.Q22-Project

## 1. Tổng quan
```mermaid
%%{init: {'flowchart': {'curve': 'linear'}}}%%
flowchart LR
  A[Ansible Control Node] --> B[bootstrap_windows.yml]
  A --> C[pipeline.yml]
  A --> D[wazuh.yml]

  B --> E[dc01 - Windows Server 2022]
  B --> F[member01 - Windows Server 2022]
  B --> J[fileserver01 - Windows Server 2022]

  C --> E
  C --> F
  C --> J

  D --> G[log01 - Wazuh Manager + Dashboard]
  D --> E
  D --> F
  D --> J

  E -->|Agent events + SCA + Inventory| G
  F -->|Agent events + SCA + Inventory| G
  J -->|Agent events + SCA + Inventory| G

  G --> I[Compliance / Vulnerability / MITRE]
```

## 2. Các tiêu chí triển khai

## 3. Triển khai các công cụ

### 3.1 Wazuh
Wazuh được triển khai như một nền tảng giám sát an ninh tập trung cho hệ thống Windows Server trong lab. Trong kiến trúc của nhóm, `log01` đóng vai trò Wazuh manager/dashboard, còn các máy Windows như `dc01` và `member01` được cài Wazuh agent để gửi log, trạng thái hệ thống và kết quả đánh giá bảo mật về trung tâm.

Việc tích hợp Wazuh giúp nhóm không chỉ dừng ở bước hardening theo CIS, mà còn có thêm một lớp giám sát vận hành sau triển khai. Thông qua dashboard, nhóm có thể theo dõi tình trạng online/offline của agent, kết quả `Security Configuration Assessment (SCA)`, thông tin `Vulnerability Detection`, cũng như quan sát các thay đổi cấu hình hoặc sự kiện bảo mật trên từng máy.

Trong quy trình triển khai hiện tại, Wazuh được tự động hóa bằng Ansible. Sau khi các máy Windows được bootstrap kênh quản trị từ xa, playbook sẽ cài Wazuh agent lên từng máy và kết nối chúng về manager. Nhờ đó, hệ thống có thể được đánh giá tập trung, hỗ trợ đối chiếu trước/sau hardening, và tăng giá trị thực tiễn cho đồ án theo hướng giám sát liên tục thay vì chỉ cấu hình một lần.

#### Lệnh setup Wazuh
Chạy các lệnh sau trong thư mục `ansible`:

```bash
cd ansible
ansible-playbook playbooks/bootstrap_windows.yml
ansible-playbook playbooks/wazuh.yml
```

Trong đó:
- `bootstrap_windows.yml`: mở và duy trì kênh quản trị từ xa trên các máy Windows
- `wazuh.yml`: chạy toàn bộ quy trình cài `Wazuh manager` trên `log01` và `Wazuh agent` trên các máy Windows

Nếu cần chạy tách riêng từng phần, có thể dùng:

```bash
cd ansible
ansible-playbook playbooks/wazuh_server.yml
ansible-playbook playbooks/wazuh_agent.yml
```

#### Tài khoản mặc định của Wazuh dashboard
Role `wazuh_manager` hiện đã tự đặt mật khẩu dashboard theo biến trong `group_vars/log_servers.yml`.

Thông tin mặc định hiện tại:
- user: `admin`
- password: `AdminWazuh9*`
