# 📦 QuickPO & Cost Tracker

**QuickPO & Cost Tracker** เป็น Cross-Platform Application พัฒนาด้วย **Flutter** และ **Supabase** ออกแบบมาเพื่อช่วยลดขั้นตอนการอนุมัติเอกสารคำขอสั่งซื้อ (Purchase Request / Purchase Order) ในองค์กร ให้มีความรวดเร็ว ปลอดภัย และแสดงผลแบบเรียลไทม์ พร้อมระบบจัดการสิทธิ์ผู้ใช้ (Role-based Access Control: RBAC)

---

## ✨ Key Features (คุณสมบัติหลัก)

- **📝 Purchase Request Creation:** สร้างคำขอซื้อ แนบไฟล์ใบเสนอราคา (PDF, JPG, PNG) พร้อมคำนวณราคารวมอัตโนมัติ
- **⚡ Fast-Track Auto Approval:** ระบบอนุมัติอัตโนมัติทันที หากยอดรวมของคำขอสั่งซื้อไม่เกินวงเงินที่องค์กรกำหนด (ผ่าน Database Trigger)
- **🔐 Authentication & Role Management:** ระบบ Login / Register ผ่าน Supabase Auth แบ่งสิทธิ์ชัดเจน:
  - **Employee (พนักงาน):** สร้างคำขอซื้อ และติดตามสถานะเอกสารของตนเอง
  - **Approver / Admin (ผู้อนุมัติ/แอดมิน):** ตรวจสอบรายการอนุมัติ จัดการงบประมาณ และอนุมัติ/ปฏิเสธคำขอซื้อ
- **🛡️ Row-Level Security (RLS):** กำหนดสิทธิ์การเข้าถึงข้อมูลระดับแถวในฐานข้อมูล เพื่อความปลอดภัยของข้อมูลแต่ละแผนก
- **📊 Realtime Dashboard & Cost Tracking:** สรุปภาพรวมค่าใช้จ่าย แยกตามหมวดหมู่แบบเรียลไทม์

---

## 🛠️ Tech Stack & Architecture

- **Frontend:** Flutter (Dart)
- **Backend-as-a-Service:** Supabase
  - **Database:** PostgreSQL (RLS, Triggers, Views, Indexes)
  - **Authentication:** Supabase Auth
  - **Storage:** Buckets (`pr_attachments`, `avatars`)

---

## 🚀 Getting Started (การติดตั้งและใช้งาน)

### 1. Clone Project
```bash
git clone [https://github.com/your-username/your-repository-name.git](https://github.com/your-username/your-repository-name.git)
cd quickpo-cost-tracker