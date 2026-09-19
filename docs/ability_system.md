# คู่มือระบบ Ability

เอกสารนี้อธิบายพฤติกรรมของระบบ Ability ตามโค้ดและข้อมูลที่ใช้อยู่จริง เหมาะสำหรับผู้ทำคอนเทนต์ โปรแกรมเมอร์ และผู้ทดสอบเกม

## ภาพรวม

Ability เป็นระบบแบบ data-driven: กติกาของแต่ละ Ability อยู่ใน Resource `.tres` ภายใต้ `data/ability/` และใช้ `AbilityData` เป็นโครงสร้างกลาง โค้ด Combat ไม่ควรตรวจชื่อหรือ `id` ของ Ability เป็นรายตัว แต่เลือกวิธีทำงานจาก Target, Attack, Effect, Cost และ Trait ที่ตั้งในข้อมูล

เส้นทางหลักของข้อมูลคือ:

`AbilityData` → Catalog/Class/Ancestry/Equipment → `CombatantState` → `AbilitySystem` → Executor ที่ตรงกับชนิดของ Ability → Combat Events/UI

ระบบแบ่งหน้าที่สำคัญดังนี้:

| ส่วน | หน้าที่ |
| --- | --- |
| `data/ability/ability_data.gd` | โครงสร้างข้อมูลหลัก ค่าใช้จ่าย เป้าหมาย การโจมตี และ Area |
| `data/ability/ability_effect_data.gd` | Passive/Triggered modifier เช่น To Hit, Damage, Speed, Resistance และ Skill modifier |
| `data/ability/ability_use_effect_data.gd` | Effect ที่เกิดตอนกดใช้ แยกตาม Always, Hit, Miss หรือ Damage |
| `combat/ability/ability_system.gd` | Equip, validation, cooldown, passive calculation และ lookup |
| `combat/ability/active_ability_executor.gd` | Ability เป้าหมายเดี่ยว, Self, Attack และ Effect-only |
| `combat/targeting/area_action_executor.gd` | Ground Area และ Self-centered Circle |
| `combat/ability/ability_movement_executor.gd` | Ability ที่ให้เลือกจุดเคลื่อนที่ |
| `combat/attack/attack_sequence_executor.gd` | Dual Weapon และการโจมตีหลายครั้ง |
| `combat/progression/progression_system.gd` | การเรียนด้วย Ability Point และการ Grant ตาม Level |
| `data/creation/default_creation_catalog.tres` | รายการ Ability ที่อนุญาตให้ Character Creation มองเห็น |

## สถานะ Ability ในตัวละคร

ค่าต่อไปนี้อยู่ใน `CombatantState` และมีความหมายต่างกัน:

| ค่า | ความหมาย |
| --- | --- |
| `available_abilities` | Resource ที่ตัวละครรู้จักและระบบสามารถค้นหาได้ |
| `selected_ability_ids` | Ability ที่ผู้เล่นซื้อด้วย Ability Point |
| `granted_ability_ids` | Ability ที่ได้ฟรีจาก Ancestry, Class หรือ Level reward |
| `equipped_abilities` | Ability ที่เปิดใช้งานจริง เก็บเป็น `id` |
| `ability_points` | แต้มที่ยังไม่ใช้และเก็บไว้ใช้ภายหลังได้ |
| `ability_cooldowns` | จำนวนเทิร์น cooldown ที่เหลือ แยกตาม `id` |
| `ability_uses_this_turn` | จำนวนครั้งที่ใช้หรือถูก consume ในเทิร์นปัจจุบัน |
| `ability_stacks` | stack ชั่วคราวของ Ability ใช้ key รูปแบบ `ability_id:effect_index` |

การมี Ability อยู่ใน `available_abilities` ยังไม่แปลว่า Effect ทำงาน โดยทั่วไป Ability ต้องอยู่ใน `equipped_abilities` ด้วย ส่วน Ability จากอาวุธจะ active ตามอาวุธที่ถือและเงื่อนไข Trait โดยไม่ต้องอยู่ในรายการ Equip ปกติ

Passive ถูกออกแบบให้ “ทำงานตลอดเมื่อ Equip” และผู้เล่นกด Activate ไม่ได้ ค่า `is_passive` และ Trait `passive` เป็นคนละข้อมูล: ค่าแรกควบคุมพฤติกรรม ส่วน Trait ใช้จำแนก/แสดงผล ดังนั้น Passive ที่ถูกต้องควรตั้งทั้งสองอย่าง

## การได้รับ เรียน และ Equip

### การ Grant ฟรี

Ancestry และ Class เพิ่ม Resource เข้า `available_abilities` และบันทึก `id` ใน `granted_ability_ids` ถ้า `auto_equip_on_grant = true` จะเพิ่มเข้า `equipped_abilities` อัตโนมัติ

Class progression ทำขั้นตอนเดียวกันเมื่อถึง Level ของ entry นั้น และ Ability ที่ Grant Skill จะเพิ่ม Skill เข้า `available_skills`

### การซื้อด้วย Ability Point

`ProgressionSystem.learn_ability()` ตรวจตามลำดับ:

1. Ability ต้อง valid และไม่ใช่ Spell Training
2. ต้องยังไม่เคย Selected หรือ Granted
3. Ability ที่ Auto Grant ซื้อเองไม่ได้
4. Level และ `required_trait_ids` ต้องครบ
5. ต้องเรียน `prerequisite_id` ก่อน
6. Ability Point ต้องเพียงพอ

เมื่อเรียนสำเร็จ ระบบหักแต้ม เพิ่ม `selected_ability_ids`, เพิ่ม Resource เข้า `available_abilities` และ Equip ให้ทันที แต้มที่เหลือสามารถเก็บไปใช้ใน Level Up ภายหลังได้

Spell Training ใช้โควตาจาก `spell_choices_granted` แยกจาก Ability Point และกรองด้วย Spell trait/level ที่ Grantor กำหนด

### Equip/Unequip

`AbilitySystem.equip_ability()` ตรวจ Level, prerequisite และ required traits อีกครั้ง การ Unequip จะถูกปฏิเสธถ้ายังมี Ability ที่ Equip อยู่และอ้าง Ability นี้เป็น prerequisite เมื่อ Unequip สำเร็จ stack ของ Ability นั้นจะถูกล้าง

หมายเหตุ: ใน Combat การสลับ Equip ผ่าน UI อาจถูกจำกัดตามเทิร์นและสถานะของฉาก แม้ตัว `AbilitySystem` เองไม่ได้คิด AP สำหรับการ Equip

## ประเภทที่ระบบรองรับ

### Passive

ตั้ง `is_passive = true`, ใส่ Trait `passive` และกำหนดรายการ `effects` เช่นโบนัส To Hit, Range, Critical, Speed, Resistance, Defense จาก Faith หรือ modifier ของ Skill

Passive modifier ส่วนใหญ่ถูกอ่านจาก Ability ที่ active ทุกครั้งที่ระบบคำนวณ จึงตอบสนองต่อค่า Level, Faith หรือสถานะปัจจุบันได้ทันที

### Active แบบ Effect-only

ไม่ต้องกำหนด Attack ใช้ `target_mode`, Cost และ `use_effects` เพื่อ Heal, ใส่ Status หรือเรียก Dynamic Effect ระบบจะหัก AP/Faith/Finishing Gauge หลังผ่าน validation และยกเลิก movement ที่เหลือ

### Active Attack

กำหนด `attack_source` เป็น:

- `EQUIPPED_WEAPON` เพื่อใช้ Attack ของอาวุธที่ถือ
- `CONFIGURED_ATTACK` และใส่ `attack_data` เพื่อใช้ Attack เฉพาะ Ability

ตั้ง `required_attack_trait_ids` เมื่อต้องบังคับชนิดอาวุธหรือ Unarmed ความเสียหายเสริมเฉพาะการกดใช้กำหนดผ่าน `active_attack_*` เพื่อไม่ให้กลายเป็น Passive global bonus

### Area

ใช้ `target_mode = GROUND` หรือ `target_mode = SELF` ร่วมกับ `area_shape`:

- `CIRCLE`: ใช้ `area_radius_feet`
- `LINE`: ใช้ `line_length_feet` และ `line_width_feet`
- `CONE`: ใช้ `targeting_range_feet` และ `cone_angle_degrees`

`target_filter` เลือก Enemy, Ally หรือทุกฝ่าย `include_caster` ระบุว่าผู้ใช้โดน Area ของตัวเองหรือไม่ และ Line of Sight/Obstacle ใช้ `requires_line_of_sight` กับ `area_blocked_by_obstacles`

ระบบจะตรวจจุดเป้าหมายและรวบรวมเป้าหมายก่อนหักทรัพยากร ถ้าไม่มีเป้าหมายที่ valid จะไม่เสีย Cost

### Movement Ability

เพิ่ม `AbilityEffectData` ชนิด `ABILITY_MOVEMENT` ตั้ง `movement_distance_feet` และ `movement_triggers_reactions` ขั้นตอนใช้งานมีสองจังหวะ: เริ่ม Ability แล้วเลือกปลายทาง ระบบ clamp ระยะสูงสุดและตรวจเส้นทางผ่าน MapRules

ตัวละครที่ Rooted ใช้ไม่ได้ การเคลื่อนที่จะใช้ AP, ยกเลิก movement ปกติที่เหลือ, เพิ่ม use count และเริ่ม cooldown

### Stance และ Aura

Stance ระบุด้วย Trait `stance` และมักใส่ Effect ให้ Caster ผ่าน `use_effects` ในเวลาเดียวกันมี Stance ได้หนึ่งชนิด การเปิด Stance อื่นจะถูกปฏิเสธจนกว่า Stance เดิมสิ้นสุด

Aura เป็น Effect ปกติที่มี radius และโบนัส Aura ระบบใช้โบนัสที่มากที่สุดต่อ Effect `id` เพื่อป้องกัน Effect ชื่อเดียวกัน stack จากหลายแหล่งโดยไม่ตั้งใจ

### Reaction-only

ตั้ง `reaction_only = true` เพื่อห้ามกดใช้ในเทิร์นปกติ และใส่รายการ `granted_reactions` เมื่อ Ability ถูก Equip ระบบจะ sync Reaction เข้า `active_reactions`; เมื่อถอด Ability ระบบจะนำ Reaction ที่ Ability เป็นเจ้าของออก

### Attack Sequence

ตั้ง `execution_mode = ATTACK_SEQUENCE`:

- `sequence_attack_count = 0` ใช้รูปแบบ Dual Weapon สองครั้ง
- ค่ามากกว่า 0 ทำ Attack เดิมซ้ำตามจำนวน
- `sequence_counts_each_attack_for_penalty` ระบุว่าจะนับ repeated-attack penalty แยกทุกครั้งหรือไม่

## Effect สองชั้น

### `AbilityEffectData`: Passive และ trigger ระหว่างระบบ

ใช้กับ Effect ที่ AbilitySystem ต้องนำไปประกอบการคำนวณ เช่น:

- To Hit แบบคงที่ แบบ stack หรือแบบมีเงื่อนไข
- Attack/Skill range, Critical chance/damage และ conditional damage
- Status หลังโจมตีโดนหรือหลังเดินครบระยะ
- Skill damage, mana discount และ cooldown modifier
- Speed, Resistance, Defense จาก Faith และ Max Faith จาก Level
- Ability movement

เงื่อนไข conditional damage เลือก `ANY` หรือ `ALL` และรองรับ HP threshold, target status, ระยะ, attack trait, เป้าหมายที่ยังไม่ถูกโจมตีในรอบ และ first successful hit per turn

### `AbilityUseEffectData`: ผลตอนกดใช้

`timing` รองรับ `ALWAYS`, `ON_HIT`, `ON_MISS`, `ON_DAMAGE` และ `recipient` เลือก Caster หรือ Target

Effect ปกติอ้าง `EffectData` ได้โดยตรง หรือใช้ Dynamic Effect สำหรับสูตร Faith ที่ระบบรองรับอยู่แล้ว การ scale แบบทั่วไปทำได้จาก Attribute modifier, Level, defense bonus หรือจำนวน status stacks โดย executor จะ duplicate Effect ก่อนแก้ค่าเพื่อไม่เปลี่ยน Resource ต้นฉบับ

`effects_on_use` เป็นช่อง legacy เท่านั้น คอนเทนต์ใหม่ควรใช้ `use_effects`

## Validation และลำดับการใช้

ก่อนใช้ Active ระบบตรวจว่า Combat ยังทำงาน, เป็นเทิร์นของผู้ใช้, ไม่มี Reaction/Movement choice ค้าง, Ability active, ไม่ใช่ Passive/Reaction-only, Level/Trait/อาวุธครบ, ทรัพยากรพอ, ไม่ติด cooldown และไม่เกิน `uses_per_turn`

สำหรับเป้าหมายเดี่ยวจะตรวจ target filter, range และ Line of Sight ก่อนจ่าย Cost การโจมตีจะใช้ AttackSystem เดิม จึงได้รับ repeated-attack penalty, defense reaction, resistance/immunity และ Combat Event ตามกติกากลาง

ลำดับผลตอนโจมตีคือ:

1. ตรวจ Ability และ Attack
2. snapshot ค่าที่สูตรต้องใช้ก่อนจ่าย Cost เช่น Faith
3. จ่าย Cost และเริ่ม action
4. เปิดโอกาสให้ defensive Reaction เปลี่ยน Hit เป็น Miss
5. apply `ALWAYS` และ Effect ตามผล Hit/Miss/Damage
6. เพิ่ม use count, เริ่ม cooldown และ emit `ABILITY_TRIGGERED`

Cooldown ที่เพิ่งเริ่มจะข้ามการลดครั้งแรก แล้วลด 1 เมื่อจบเทิร์นถัดไปของเจ้าของ จึงคงอยู่ครบจำนวนเทิร์นที่กำหนด `ability_uses_this_turn` ถูกล้างตอนเริ่มเทิร์น

## วิธีเพิ่ม Ability ใหม่

1. สร้าง `.tres` ใต้ `data/ability/` โดยใช้ `AbilityData`
2. ตั้ง `id` แบบ snake_case และห้ามซ้ำ, ชื่อ, คำอธิบาย, Level, Cost และ Traits
3. ตั้ง `required_trait_ids` สำหรับข้อจำกัดเชิงกติกา อย่าพึ่ง Trait ที่ใช้แสดงผลอย่างเดียว
4. เลือก Target/Attack/Area/Execution mode ให้ตรง recipe ด้านบน
5. สร้าง `AbilityEffectData` หรือ `AbilityUseEffectData` เฉพาะเท่าที่ต้องใช้ และใช้ `EffectData` กลางสำหรับ Status/Heal
6. ลงทะเบียนใน `default_creation_catalog.tres` ถ้าผู้เล่นต้องเห็นใน Character Creation หรือให้ Catalog รวบรวมผ่าน Class/Ancestry/Progression
7. ถ้าเป็นของ Class ให้เพิ่มใน progression entry ของ Level ที่ต้องการ; ถ้าได้อัตโนมัติให้ตั้ง `auto_equip_on_grant`
8. เพิ่ม focused test อย่างน้อยหนึ่งไฟล์ใน `tests/ability/` ครอบคลุม success, invalid target/ทรัพยากรไม่พอ, Cost, cooldown/use limit, Effect และ registration
9. รัน `tests/run_regression.ps1 -Target tests/ability` แล้วจึงรัน regression ทั้งหมดเมื่อมีการเปลี่ยนพฤติกรรม

Checklist ก่อนจบงาน:

- `id` ไม่ซ้ำและทุก prerequisite หาเจอ
- Passive มีทั้ง `is_passive` และ Trait `passive`
- `required_level`, class progression และคำอธิบายตรงกัน
- Cost ที่ตั้งไว้ถูกหักเพียงครั้งเดียว และการใช้ที่ถูก reject ไม่เสียทรัพยากร
- สูตรที่ใช้ Faith ระบุชัดว่าใช้ค่าก่อนหรือหลังจ่าย Cost
- เป้าหมาย, range, Line of Sight, obstacle และ `include_caster` ตรงกับข้อความในเกม
- Status แบบ On Hit/On Damage เกิดหลัง defensive Reaction สรุปผลแล้ว
- Resource ต้นฉบับไม่ถูกแก้ระหว่าง runtime
- Character Creation, Level Up, RunState และ Combat เห็น Ability ชุดเดียวกัน

## ผลตรวจระบบปัจจุบัน (15 กันยายน 2026)

ผลรอบแรกก่อนปรับชุดทดสอบรัน `tests/ability` จำนวน 36 tests: ผ่าน 24 และไม่ผ่าน 12 แต่ 7 รายการในกลุ่มที่ไม่ผ่านอ้างกติกาเก่า จึงไม่ใช่ defect ตามสเปกปัจจุบัน:

- `arcanist_class_test` ถูกลบแล้ว เพราะเปลี่ยนเงื่อนไขการได้รับ Spell
- Devotee ได้อัตโนมัติเพียง Belief, Pray และ Heal or Harm ส่วน Armor of Faith, Condemn, Unwavering Faith, Judgment Wave และ Radiance Burst ต้องเลือกด้วย Ability Point เทสต์ของ Ability เหล่านี้ต้องสร้างตัวละครที่เรียนและ Equip Ability ก่อนทดสอบ และไม่ควร assert ว่า Class progression Grant ให้
- Shared Blessing เป็น Active Ability ราคา 3 AP และ 2 Faith ค่าใน Resource ถูกต้อง แต่ test เดิมยังคาด 2 AP

หลังตัดความคาดหวังเก่าออก เหลือ 5 รายการจากรอบเดิมที่ยังต้องตรวจหรือปรับเทสต์แล้วรันใหม่:

- Bless และ Crushing Palm timeout หลัง test พยายามอ่าน Effect ที่ไม่มีอยู่
- Martial Artist Level 2 progression ยังไม่ได้ Grant Flowing Guard ตาม test; ต้องยืนยันว่า Flowing Guard ควรได้อัตโนมัติหรือซื้อด้วย Ability Point
- `Long Reach` ตั้ง `is_passive = true` แต่ไม่มี Trait `passive` ทำให้ passive trait test ไม่ผ่าน
- Sweeping Kick แบบ Self-centered Area ใช้งานไม่สำเร็จใน test เดิม

ผลของ Ability ฝั่ง Devotee ที่ล้มเหลวในรอบแรกยังไม่ยืนยันว่า execution ผิด เพราะ setup ของ tests ไม่ได้เรียน Ability ตามกติกาใหม่ ต้องแก้ fixture แล้วทดสอบ Damage, Effect, Cost, Targeting และ Area อีกครั้ง

ข้อจำกัดที่ควรรู้ก่อนสร้างคอนเทนต์ใหม่:

- Movement executor จ่ายเฉพาะ AP; อย่าตั้ง Faith หรือ Finishing Gauge cost ให้ Movement Ability จนกว่าจะเพิ่มการ consume และ rollback ให้ครบ
- Area executor และ Attack Sequence ตรวจ Finishing Gauge ผ่าน validation กลาง แต่ยังไม่หัก Gauge; ปัจจุบันควรใช้ `finishing_gauge_cost` กับ Active Attack เป้าหมายเดี่ยวเท่านั้น
- `get_attack_abilities()` ตรวจ Level แต่ไม่ตรวจ `required_trait_ids` ซ้ำ ข้อมูลที่มาจากอาวุธจึงต้องระวังไม่ Grant Passive attack modifier ให้ผู้ถือที่ขาด Trait

รายการนี้เป็นผล audit ไม่ใช่การเปลี่ยนบาลานซ์ การตัดสินว่าข้อมูลเกมหรือ tests เป็นสเปกที่ถูกต้องต้องทำก่อนแก้ เพื่อไม่ให้ Ability ถูก Grant หรือเปลี่ยน Cost โดยไม่ตั้งใจ
