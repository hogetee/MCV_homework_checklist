# สำหรับผู้พัฒนา

## Build จากซอร์ส

ต้องใช้ Xcode 27 หรือใหม่กว่า (รุ่นที่ทดสอบ) และ Apple Account

1. ดาวน์โหลด Source code จาก [Releases](https://github.com/hogetee/MCV_homework_checklist/releases) แตกไฟล์ไปไว้ในตำแหน่งถาวร แล้วเปิด `MCVNot.xcodeproj`
2. ลงชื่อเข้าใช้ Apple Account ใน **Xcode → Settings → Accounts** แล้วเลือก Signing Team ให้ทั้ง target `MCVNot` และ `MCVWidget` ใน **Signing & Capabilities**
3. เปลี่ยน App Group ให้เป็น `<Team ID>.com.mcvnot.shared` ตรงกันทั้ง `App/MCVNot.entitlements`, `Widget/MCVWidget.entitlements` และ `Shared/AssignmentStore.swift`
4. หาก Bundle Identifier ซ้ำ ให้เปลี่ยนทั้งสอง target โดย Widget ต้องใช้ชื่อที่ต่อท้าย Bundle Identifier ของแอป
5. รัน `bash tools/install_update.sh` สคริปต์จะ build ติดตั้ง `MCVNot.app` ข้างโปรเจกต์ และตรวจการลงทะเบียน WidgetKit ต้องจบด้วยข้อความ `Installed MCVNot and verified WidgetKit ...`

หลังแก้โค้ดให้รันสคริปต์ติดตั้งอีกครั้ง อย่าย้ายแอปที่สคริปต์ติดตั้งไว้หรือเก็บแอปหลายชุด เพราะ macOS จำตำแหน่งวิดเจ็ต ตรวจวิดเจ็ตที่รันจริงก่อนสรุปว่าการอัปเดตเสร็จ

## สร้างไฟล์แจก

```bash
# รุ่นทดลอง ต้องมีใบรับรอง Apple Development
bash tools/package_release.sh --development-preview

# รุ่นสำหรับแจก ต้องมี Developer ID Application และ notarytool profile ใน Keychain
bash tools/package_release.sh --notary-profile PROFILE
```

ไฟล์อยู่ใน `Build/Release/` ได้แก่ Universal `.dmg` พร้อมแอป วิดเจ็ต Applications shortcut คู่มือเริ่มใช้ และ `SHA256SUMS.txt` สคริปต์ตรวจลายเซ็น สถาปัตยกรรม Hardened Runtime และสิทธิ์ debugger โหมด notarization จะต้องได้ผล Accepted และตรวจ ticket สำเร็จ

รุ่นทดลองยังไม่ได้ผ่าน notarization และไม่รับรองว่า Gatekeeper จะอนุญาตบน Mac ทุกเครื่อง การแจกภายใต้การตั้งค่า Gatekeeper ปกติต้องใช้ [Developer ID และ notarization](https://developer.apple.com/developer-id/) ต้องทดสอบบน Mac เครื่องอื่นก่อนรับรองการติดตั้ง

## การซิงก์และการแก้ปัญหา

- myCourseVille ลองกู้เซสชันด้วยการโหลดหน้าเว็บและอ่านข้อมูลซ้ำหนึ่งครั้งก่อนแจ้งให้ล็อกอินใหม่ หากเครือข่ายผิดพลาดจะเก็บข้อมูลเดิมไว้
- เซสชันแยกจาก Safari คุกกี้ ClassDeeDee และ CU SSO เก็บใน Keychain โดยยังเคารพวันหมดอายุของเซิร์ฟเวอร์
- วิดเจ็ตใช้ข้อมูลล่าสุดที่แอปซิงก์ หากปิดแอปให้เปิดและซิงก์หลังส่งงาน เพื่ออัปเดตสถานะและยกเลิกการเตือนเดิม
- หากวิดเจ็ตว่างหลังอัปเดต ให้ตรวจว่ามีแอปเพียงชุดเดียว เปิดแอปและซิงก์ แล้วลบวิดเจ็ตและเพิ่มใหม่
- หากแจ้งเตือนไม่ขึ้น ตรวจ **System Settings → Notifications → MCVNot**

[กลับไป README](../README.md)
