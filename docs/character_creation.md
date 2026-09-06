# Character Creation รุ่นใหม่

## จุดเริ่มต้น

เปิด `scenes/character_creation/CharacterCreation.tscn` ซึ่งยังเป็น main scene ของโปรเจกต์
scene นี้เรียก `creation_wizard.gd` แล้ว ไม่มีการใช้ UI เก่าควบคู่กัน
ลบ `character_creation.gd` และไฟล์ UID ของสคริปต์เก่าแล้ว
ยังคง scene path/scene UID เดิมเพื่อไม่ให้ลิงก์เข้าเกมขาด

มี 7 ขั้น: Identity, Ancestry, Class, Attributes, Abilities, Equipment, Review
ทุกขั้นมีแผงสรุปเดียวกัน ปุ่มย้อนกลับ และปุ่มถัดไปที่แสดงเหตุผลเมื่อเลือกไม่ครบ
โหมดปกติเริ่ม Lv.1; Identity มี Test mode สำหรับเลเวลสูง
แต้ม Ability/Attribute ที่เหลือเก็บไปเลือกผ่าน Level-up UI ในเกมได้
ปุ่ม Start Over ในโหมด standalone มีหน้าต่างยืนยันก่อนทิ้งฉบับร่าง

## แยกหน้าที่

| ไฟล์ | หน้าที่ |
| --- | --- |
| data/creation/default_creation_catalog.tres | รายการเนื้อหาที่อนุญาตในการสร้างตัวละคร |
| data/creation/creation_catalog.gd | Resource ของ Catalog และรวม Ability จาก Class/Ancestry/Progression |
| data/creation/creation_visual.gd | ภาพ ชื่อ portrait และข้อความอธิบายแบบ presentation-only |
| scenes/character_creation/creation_draft.gd | ฉบับร่าง คำนวณ preview ตรวจเงื่อนไข และสร้าง CharacterData |
| scenes/character_creation/creation_wizard.gd | โครงหน้าจอ navigation summary และการส่งผลลัพธ์ |
| scenes/character_creation/creation_pages.gd | เนื้อหาแต่ละขั้น |
| scenes/character_creation/creation_widgets.gd | สี ฟอนต์ กรอบ ปุ่ม ภาพ และ component ที่ใช้ร่วมกัน |

Catalog เป็นรายการ Resource แบบ explicit จึงติดไปกับ export ของ Godot
ไม่สแกนโฟลเดอร์ทั้งหมด ซึ่งอาจเผลอนำ Ability มอนสเตอร์เข้าระบบสร้างผู้เล่น
Base Character ปัจจุบันยังอ้าง player.tres เพื่อรักษา AP, ค่าตั้งต้น, spells และ reactions ของโปรเจกต์
หากต้องการเปลี่ยนกติกาเริ่มต้นให้แก้/เปลี่ยน Base Character ที่ Catalog ไม่ใช่แก้ใน UI

## เพิ่ม Class หรือ Ancestry

1. สร้าง Resource ด้วย class_data.gd หรือ ancestry_data.gd ตามปกติ
2. ใส่ข้อมูล Traits, โบนัส Attributes, จำนวนตัวเลือก และ Granted Abilities/Progression
3. เพิ่ม Resource ลง Classes หรือ Ancestries ใน Catalog
4. ถ้ามีภาพ เพิ่ม CreationVisual ใน Visuals โดย Source Id ตรงกับ id ของ Class

คลาสไม่มีภาพยังแสดงด้วยการ์ดข้อความได้
UI ไม่ตรวจชื่อ Assassin/Martial Artist เพื่อกำหนดโบนัสหรือรายการตัวเลือก
ภาพ portrait ที่เลือกเป็น cosmetic ไม่เปลี่ยน Class หรือ Attributes

## เพิ่ม Ability

เพิ่ม AbilityData ใน Catalog → Abilities หรือให้ Class/Ancestry/Progression อ้างผ่าน Granted Abilities
การเรียนและ prerequisite ใช้ ProgressionSystem เดิม
Traits ใช้แสดง/กรอง ส่วน Required Trait Ids ใช้จำกัดผู้เรียนตามกติกาเดิม
Automatic features ไม่เสีย Ability Point และไม่ซื้อซ้ำ
Ability ที่ยังเรียนไม่ได้ยังเปิดอ่านได้พร้อมเหตุผลที่ปุ่มเรียน
รายการมีตัวกรอง All, Basic, My class, Active, Passive, Reactive, Learnable now และช่องค้นหา (Enter)
ถอด prerequisite จะถอดตัวเลือกที่พึ่งพามันและคืนแต้ม
เปลี่ยน Class/Ancestry/Level จะตรวจตัวเลือกเดิมใหม่ โดยคงเฉพาะตัวที่ยังถูกต้อง

## Equipment

Catalog → Equipment คือ inventory เริ่มต้น ไม่ใช่ร้านค้าหรือระบบเงิน
เลือกใส่/ถอดได้ฟรีก่อนเข้า Combat:
- Hand 1 = slot 0
- Hand 2 = slot 3
- Armor = slot 1
- Weapon และ Shield ใช้ hand slots ร่วมกัน
- Two-Handed ใช้ทั้งสองช่อง ตาม EquipmentSystem เดิม

เพิ่ม CharacterData.starting_equipment_slots และ CombatantState.starting_equipment_slots
เพื่อให้การใส่ของเฉพาะ Hand 2 ไม่ย้ายไป Hand 1 ตอนเข้า Combat
ตัวละครเดิมที่ไม่กำหนด mapping ยังใช้พฤติกรรมเดิม
เพิ่ม CharacterData.portrait สำหรับบันทึกภาพที่เลือก; UI ใน Combat ยังเลือกว่าจะนำภาพนี้ไปแสดงตรงไหนได้

## การคำนวณและส่งข้อมูล

ทุกครั้งที่แก้ตัวเลือก Draft จะเริ่มจาก CharacterData สำเนาใหม่ แล้วเรียก
AncestrySystem, CharacterClassSystem, ProgressionSystem, EquipmentSystem และ StatSystem
การเปลี่ยนคลาสจึงไม่บวกโบนัสซ้อนบน preview เดิม และไม่แก้ Resource ต้นฉบับ

เมื่อยืนยันจะส่งข้อมูลดิบ + ตัวเลือกที่ผ่านการตรวจ ไม่ส่งค่าสถานะที่ถูกบวกโบนัสแล้ว
Combat จึงใช้ขั้นตอนเริ่มตัวละครตามปกติ โดยไม่บวก Class/Ancestry/Progression ซ้ำ
ทดสอบเทียบค่าทั้ง Attributes, HP, Mana, AP, Speed, Defenses และ Ability Points กับ Combat แล้ว

## เปิดจากฉากอื่น

Instance CharacterCreation.tscn แล้วตั้ง:
- Auto Start Combat = false
- เชื่อม signal character_created(character: CharacterData)
- เชื่อม signal creation_cancelled เพื่อปิดหน้าจอ/กลับฉากเดิม

โหมด standalone ค่าเริ่มต้น Auto Start Combat = true:
บันทึก created_character_data ใน SceneTree metadata แล้วเปิด Destination Scene
ซึ่งตั้งต้นเป็น PrototypeCombat.tscn

## เพิ่มขั้นตอนใหม่

1. เพิ่ม dictionary ที่มี id และ title ใน Catalog → Steps
2. ใช้ Pages Script ที่ extends creation_pages.gd และเพิ่ม build_<id>(host)
3. หากมีเงื่อนไขใหม่ ใช้ Draft Script ที่ extends creation_draft.gd แล้ว override step_error(id)
4. เก็บตัวเลือกใหม่ใน Draft และส่งออกจาก raw_character()/finish() ตามต้องการ

Navigation และ summary ใช้ร่วมกันทุกขั้น แถบขั้นตอนเลื่อนแนวนอนได้เมื่อเพิ่มจำนวนขั้น
ใช้ UI widgets เดิมให้ขนาด/สี/ระยะห่างสอดคล้องกัน
ยังไม่มีระบบ character appearance editor เต็มรูปแบบหรือ save/load ลงดิสก์;
ผลลัพธ์ปัจจุบันเป็น CharacterData สำหรับส่งต่อให้ระบบเกม

## ทดสอบ

`tests/creation/character_creation_test.gd`:
- ตรวจชื่อและ Attribute choices
- ป้องกันโบนัสซ้ำและ mutation ของ template
- เรียน/คืนแต้ม/ตรวจ prerequisite และ automatic features
- เปลี่ยนคลาสแล้วถอน ability ที่หมดเงื่อนไข
- เพิ่ม Class ใหม่ผ่าน Catalog และกดเลือกจาก UI จริง
- ช่องถือร่วม Shield / Two-Handed / Hand 2 และไม่เสีย AP
- Preview เทียบกับ Combat และส่ง CharacterData ผ่าน signal
- โหลดทั้ง 7 หน้าและทุกตัวกรอง Ability

`tests/creation/capture_creation.gd` ใช้ real renderer (ไม่ใส่ --headless)
บันทึกภาพใน work/creation-*-preview.png และ work/creation-class-fullhd.png
ภาพเป็นหลักฐานตรวจ UI ไม่ใช่ภาพพื้นหลังที่มีปุ่มปลอม
