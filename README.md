# MCVNot — การบ้านและรีวิวบน macOS

<img src="App/Resources/AppIcon-source.png" alt="MCVNot app icon" width="96">

เช็กงาน **myCourseVille + ClassDeeDee** บนแอปและวิดเจ็ต Desktop พร้อมเตือนก่อนหมดเวลา

ต้องใช้ **macOS 14 ขึ้นไป**, อินเทอร์เน็ต และบัญชี CU รองรับ Apple Silicon และ Intel **ไม่ต้องลง Xcode**

## ดาวน์โหลดและติดตั้ง

1. [ดาวน์โหลด MCVNot (.dmg)](https://github.com/hogetee/MCV_homework_checklist/releases/download/v0.4.3/MCVNot-0.4.3-universal.dmg)
2. เปิดไฟล์ แล้วลาก **MCVNot → Applications** จากนั้นเปิดแอปจาก Applications
3. กด **myCourseVille** แล้วล็อกอิน CU ด้วย **รหัสนิสิต 10 หลัก** สำหรับ IT Chula จากนั้นกด **ปิดและซิงก์** ถ้าใช้ ClassDeeDee ให้เชื่อมผ่าน **Chula SSO** ด้วย
4. กด **เปิดแจ้งเตือน → Allow**
5. คลิกขวาบน Desktop → **Edit Widgets → การบ้าน MCV + ClassDeeDee** แล้วเลือกขนาดกลางหรือใหญ่

**รุ่นทดลอง:** ยังไม่ผ่านการรับรองจาก Apple และทดสอบเฉพาะ Mac ของผู้พัฒนา หาก macOS บล็อกและคุณเชื่อถือแอป ให้เลือก **System Settings → Privacy & Security → Open Anyway** ตาม [คำแนะนำของ Apple](https://support.apple.com/102445)

## วิธีใช้

- 🔴 ยังไม่ส่ง / รีวิวไม่ครบ · 🟢 ส่งแล้ว / รีวิวครบ · 🟠 อ่านสถานะไม่ได้
- คลิกงานเพื่อเปิดหน้าเว็บ หลังหมดกำหนดส่ง ClassDeeDee จะขึ้นงานรีวิวที่ต้องทำ
- เตือนล่วงหน้า **24, 6 และ 1 ชั่วโมง** งานที่ทำครบและพ้นกำหนดแล้วจะถูกซ่อน
- ซิงก์ทุก **15 นาทีขณะแอปทำงาน** ถ้าวิดเจ็ตไม่อัปเดต ให้เปิดแอปแล้วกด **ซิงก์**

เซสชันแยกจาก Safari หากแอปแจ้งว่าเซสชันหมดอายุ ให้ล็อกอินเว็บนั้นใหม่ แอปไม่เก็บรหัสผ่านและไม่ส่งงานแทนคุณ

เมื่ออัปเดต ให้ปิดแอปแล้วแทนที่แอปเดิมใน Applications เก็บไว้เพียงชุดเดียว แอปนี้เป็นโครงการอิสระที่ไม่ได้พัฒนาโดยมหาวิทยาลัยหรือเจ้าของเว็บ

[รุ่นทั้งหมด](https://github.com/hogetee/MCV_homework_checklist/releases) · [สำหรับผู้พัฒนา](docs/DEVELOPMENT.md)
