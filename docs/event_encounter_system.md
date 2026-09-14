# คู่มือระบบ Event และ Encounter — Project Artron

เอกสารนี้อธิบายความสามารถที่มีอยู่จริงในระบบปัจจุบัน วิธีสร้าง Event ด้วย Resource `.tres` การเชื่อม Event เข้ากับ RunMap และการส่งผู้เล่นเข้า–ออก Combat

## 1. ภาพรวมการทำงาน

Flow ที่รองรับในปัจจุบันคือ:

```text
RunMap
→ เข้าโหนด Event
→ เปิด EventPanel
→ แสดงภาพ ชื่อ คำอธิบาย และตัวเลือก
→ ตรวจ Condition
→ ผู้เล่นเลือก Choice
→ ใช้ Effect
→ ไป Event ถัดไป หรือแสดงหน้า Encounter Preview
→ เข้า Combat
→ Victory / Defeat
→ กลับ RunMap
→ ใช้ Reward และเปิด Result Event
```

ระบบแบ่งหน้าที่ดังนี้:

- `EventData`, `EventChoice`, `EventCondition` และ `EventEffect` เก็บข้อมูลที่ผู้สร้างเกมกำหนดใน Inspector
- `EventManager` เปิด Event ตรวจ Choice และควบคุม Event chain
- `EventPanel` แสดง Event และสถานะของ Choice บน RunMap
- `EncounterManager` รับ Encounter และแปลงผล Combat เป็น Result Event
- `CombatSystem` คำนวณการต่อสู้เท่านั้น ไม่เลือกผลเนื้อเรื่อง
- `GameState` เก็บสถานะของโลกที่ Event ใช้ร่วมกัน
- `RunState` เป็นเจ้าของ `GameState` ทำให้ค่าเดิมอยู่ต่อเมื่อสลับระหว่าง RunMap และ Combat

## 2. ความสามารถที่รองรับแล้ว

### EventData

| ช่อง | หน้าที่ |
| --- | --- |
| `id` | รหัส Event ต้องไม่ซ้ำ ใช้ตรวจ Event ที่เล่นจบแล้ว |
| `title` | ชื่อที่แสดงบน EventPanel |
| `description` | เนื้อเรื่องหรือคำอธิบายแบบหลายบรรทัด |
| `illustration` | ภาพประกอบ Event; เว้นว่างได้ |
| `choices` | รายการตัวเลือกของผู้เล่น |
| `start_conditions` | เงื่อนไขที่ต้องผ่านก่อนเริ่ม Event |
| `on_start_effects` | Effect ที่ทำทันทีเมื่อ Event เปิด |
| `on_end_effects` | Effect ที่ทำเมื่อออกจาก Event |
| `can_repeat` | อนุญาตให้ Event รหัสเดิมเริ่มซ้ำได้หรือไม่ |

### สถานะ Choice

Choice รองรับสามสถานะบน UI:

- แสดงและเลือกได้: Condition ทุกข้อผ่าน
- แสดงแต่ Disabled: Condition ไม่ผ่าน และตั้ง `failed_condition_presentation = DISABLED`
- ซ่อน: Condition ไม่ผ่าน และตั้ง `failed_condition_presentation = HIDDEN`

เมื่อ Choice ถูก Disabled ค่า `failure_reason` ของ Condition จะแสดงเป็น tooltip

### การเลือกตัวละครผู้ดำเนิน Choice

`EventChoice.actor_mode` กำหนดว่าใครเป็นผู้ดำเนิน Choice:

| ActorMode | พฤติกรรม |
| --- | --- |
| `CONTEXT_ACTOR` | ใช้ตัวละครปัจจุบันใน EventContext; บน RunMap ค่าเริ่มต้นคือ `player` |
| `SELECT_ONE` | เมื่อกด Choice จะเปิดรายชื่อสมาชิกที่ผ่าน Condition ให้ผู้เล่นเลือกหนึ่งคน |
| `ALL_PARTY` | ใช้ Effect ที่ผูกกับตัวละครกับสมาชิกปาร์ตี้ทุกคนทันที |

กฎการตรวจ Condition:

- `ATTRIBUTE`, `ITEM`, `LEVEL` และ `STATUS` ที่เว้น `target_id` จะตรวจแยกตามตัวละครผู้ดำเนิน Choice
- `SELECT_ONE` เปิดให้เลือกได้เมื่อมีสมาชิกอย่างน้อยหนึ่งคนผ่าน และจะแสดงเฉพาะคนที่ผ่าน
- `ALL_PARTY` เลือกได้เมื่อสมาชิกทุกคนผ่าน Condition ที่ผูกกับตัวละคร หากต้องการให้ทำทุกคนโดยไม่มีข้อจำกัด ไม่ต้องเพิ่ม Condition ประเภทดังกล่าว
- `FLAG`, `QUEST`, `PARTY` และ `RANDOM` เป็น Condition ระดับ Event จึงตรวจเพียงครั้งเดียว
- หาก Condition ระบุ `target_id` ชัดเจน ระบบจะตรวจ id นั้น ไม่เปลี่ยนตามคนที่ผู้เล่นเลือก

กฎการใช้ Effect:

- Effect ที่เว้น `target_id` และเกี่ยวกับตัวละคร ได้แก่ Damage, Heal, Item, Status และการแก้ HP/Mana/AP/Faith จะใช้กับผู้ดำเนิน Choice
- ในโหมด `ALL_PARTY` Effect กลุ่มนี้จะทำครั้งหนึ่งต่อสมาชิกทุกคน
- Effect ระดับโลก เช่น Flag, Reputation, Gold, Reward, Teleport และ Start Encounter จะทำเพียงครั้งเดียว ไม่คูณตามจำนวนสมาชิก
- Effect ที่กรอก `target_id` ชัดเจนจะใช้กับ id นั้นเพียงคนเดียว แม้ Choice จะเป็น `ALL_PARTY`
- หาก `target_id` ไม่ตรงกับสมาชิกคนใด Effect จะไม่ถูกใส่ให้คนอื่นแทน ควรตรวจ id ให้ตรงกับข้อมูลปาร์ตี้

### EventCondition

Condition ปัจจุบันรองรับ 8 ประเภท:

| Type | วิธีตั้งค่า |
| --- | --- |
| `ATTRIBUTE` | ใส่ `key` เป็น `strength`, `dexterity`, `constitution`, `intelligence`, `wisdom`, `charisma`, `reflex`, `fortitude`, `will`, `hp`, `mana`, `ap` หรือ `faith`; กำหนดตัวเลขใน `required_number` |
| `ITEM` | ใส่ Item id ใน `key` และจำนวนใน `required_number` |
| `FLAG` | ใส่ชื่อ Flag ใน `key`; เลือก `value_type` และค่าที่ต้องการ |
| `LEVEL` | กำหนดเลเวลใน `required_number` |
| `STATUS` | ใส่ Status id ใน `key`; ใช้ `required_bool = true` เมื่อต้องมี Status หรือ `false` เมื่อต้องไม่มี |
| `QUEST` | ใส่ชื่อค่าใน `GameState.quest_state` แล้วกำหนดค่าที่ต้องการ |
| `PARTY` | ใส่ id สมาชิกใน `key`; ใช้ `required_bool` กำหนดว่าต้องมีหรือไม่มีสมาชิกนั้น |
| `RANDOM` | กำหนดโอกาสใน `chance` ตั้งแต่ `0.0–1.0` เช่น `0.25` เท่ากับ 25% |

ตัวเปรียบเทียบใน `comparison` มี `EQUAL`, `NOT_EQUAL`, `GREATER`, `GREATER_OR_EQUAL`, `LESS` และ `LESS_OR_EQUAL`

`target_id` ใช้เลือกสมาชิกปาร์ตี้ที่ต้องตรวจ หากเว้นว่างระบบจะใช้ตัวละครหลัก (`player`) หรือสมาชิกคนแรกใน Context

### EventEffect

| Type | ผลที่เกิดขึ้นและช่องสำคัญ |
| --- | --- |
| `DAMAGE` | ลด HP ของ `target_id` ตาม `amount` โดยไม่ต่ำกว่า 0 |
| `HEAL` | เพิ่ม HP ตาม `amount` โดยไม่เกิน Max HP |
| `GAIN_ITEM` | เพิ่ม Resource `ItemData` ในช่อง `item`; `amount` คือจำนวน |
| `REMOVE_ITEM` | ลบ Item id ที่ระบุใน `key`; `amount` คือจำนวน |
| `ADD_STATUS` | เพิ่ม `EffectData` จากช่อง `status_effect` |
| `REMOVE_STATUS` | ลบ Status id ที่ระบุใน `key` |
| `MODIFY_FLAG` | ตั้ง Flag ชื่อ `key` เป็นค่า `bool_value` |
| `MODIFY_RESOURCE` | เพิ่ม/ลดทรัพยากรตาม `amount` |
| `START_ENCOUNTER` | ส่ง Encounter จากช่อง `encounter` ให้ EventManager เริ่ม |
| `TELEPORT` | บันทึกตำแหน่ง `position` ลง EventContext เพื่อให้ระบบแผนที่นำไปใช้ต่อ |
| `REWARD` | บันทึกข้อมูล Reward ลง EventContext เพื่อให้ Reward UI/ระบบภายนอกนำไปใช้ต่อ |

กฎของ `MODIFY_RESOURCE`:

- `key = hp`, `mana`, `ap` หรือ `faith` จะแก้ค่าของตัวละครและ clamp อยู่ระหว่าง 0 ถึงค่าสูงสุด
- `key` ที่ขึ้นต้นด้วย `reputation_` เช่น `reputation_empire` จะแก้ Reputation ของ faction นั้น
- key อื่น เช่น `gold` หรือ `supplies` จะถูกเก็บใน `GameState.resources`
- ใช้จำนวนติดลบเพื่อลดค่า เช่น `amount = -10`

ข้อควรระวัง: `DAMAGE` และ `HEAL` ของ Event เป็นผลนอก Combat จึงแก้ HP โดยตรง ไม่ผ่าน DamageSystem ของการต่อสู้ ส่วน `TELEPORT` และ `REWARD` ปัจจุบันสร้างข้อมูลไว้ใน Context แต่ยังไม่มีระบบปลายทางบน RunMap ที่นำข้อมูลนั้นไปใช้โดยอัตโนมัติ

### GameState

ค่าที่เก็บร่วมกันได้ประกอบด้วย:

- `flags`
- `reputation`
- `quest_state`
- `chapter`
- `world_state`
- `resources`
- `completed_event_ids`

ข้อมูลเหล่านี้อยู่ใน `RunState.game_state` และคงอยู่ระหว่าง Scene ภายใน Run ปัจจุบัน แต่ยังไม่มีระบบ Save/Load ลงไฟล์ถาวร

### Encounter และผล Combat

Encounter รองรับ Type ได้แก่ `COMBAT`, `AMBUSH`, `DEFENSE`, `SURVIVAL`, `ESCAPE` และ `BOSS` ในระดับข้อมูล

ช่องสำคัญ:

- `encounter_name` และ `encounter_description` ใช้ในหน้าพรีวิว
- `encounter_image` คือภาพหน้าพรีวิวก่อนเข้า Combat
- `battlefield_texture` คือภาพสนามที่ใช้ใน Combat
- หากไม่ตั้ง `encounter_image` หน้า Preview จะใช้ `battlefield_texture` แทน
- `enemies`, `player_party`, ตำแหน่งเกิด และข้อมูลแผนที่เดิมยังทำงานเหมือนเดิม
- `victory_event`, `partial_victory_event`, `defeat_event` และ `escape_event` กำหนด Event ปลายทาง
- `rewards` ใช้ EventEffect เมื่อผลเป็น Victory หรือ Partial Victory

`EncounterManager` เข้าใจผล `VICTORY`, `PARTIAL_VICTORY`, `DEFEAT` และ `ESCAPE` แต่ Combat scene ปัจจุบันส่งกลับอัตโนมัติเฉพาะ Victory และ Defeat

## 3. วิธีสร้าง Event ใหม่ใน Godot Editor

### ขั้นที่ 1: สร้าง EventData

1. ใน FileSystem คลิกขวาโฟลเดอร์ `res://data/event/`
2. เลือก **New Resource**
3. ค้นหา `EventData`
4. บันทึกเป็นชื่อที่สื่อความหมาย เช่น `ancient_shrine.tres`
5. ตั้ง `id` เช่น `ancient_shrine`
6. ใส่ `title`, `description` และลาก Texture เข้า `illustration` หากต้องการภาพ
7. ตั้ง `can_repeat` ตามกฎของ Event

อย่าใช้ `id` ซ้ำกันสำหรับ Event คนละเหตุการณ์ เพราะ Event ที่ `can_repeat = false` ใช้ id นี้ตรวจประวัติการเล่น

### ขั้นที่ 2: เพิ่ม Choice

1. ขยาย Array `choices`
2. กดเพิ่มสมาชิก
3. เลือก **New EventChoice**
4. ตั้ง `text`
5. ตั้ง `actor_mode` เป็น `CONTEXT_ACTOR`, `SELECT_ONE` หรือ `ALL_PARTY`
6. เพิ่ม Condition และ Effect ตามต้องการ
7. ตั้งปลายทางอย่างใดอย่างหนึ่ง:
   - `next_event` สำหรับไป Event ถัดไป
   - `encounter` สำหรับเริ่ม Encounter
   - ไม่ตั้งทั้งสองช่องเพื่อจบ Event และกลับ RunMap

หากตั้งทั้ง `next_event` และ `encounter` ระบบจะให้ Encounter มีลำดับความสำคัญก่อน

ตัวอย่างให้ผู้เล่นเลือกผู้ตรวจร่องรอย:

```text
EventChoice
text = ตรวจหาร่องรอย
actor_mode = SELECT_ONE

Condition
type = ATTRIBUTE
key = reflex
comparison = GREATER_OR_EQUAL
required_number = 6

Effect
type = MODIFY_FLAG
key = discovered_ambush
bool_value = true
```

เมื่อกด Choice รายชื่อจะแสดงเฉพาะสมาชิกที่มี Reflex ตั้งแต่ 6 ขึ้นไป

ตัวอย่างฟื้นฟูทั้งปาร์ตี้:

```text
EventChoice
text = พักผ่อนรอบกองไฟ
actor_mode = ALL_PARTY

Effect
type = HEAL
amount = 10
target_id = เว้นว่าง
```

สมาชิกทุกคนจะฟื้น 10 HP หากเพิ่ม `MODIFY_RESOURCE key = gold amount = -5` ใน Choice เดียวกัน Gold จะถูกหักเพียง 5 หน่วย ไม่ถูกหักซ้ำตามจำนวนสมาชิก

### ขั้นที่ 3: เพิ่ม Condition

1. ขยาย `conditions` ของ Choice
2. เลือก **New EventCondition**
3. เลือก `type`
4. ตั้ง `key`, `comparison` และค่าที่เกี่ยวข้อง
5. เขียน `failure_reason` ให้ผู้เล่นเข้าใจ เช่น `ต้องมี Reflex 6`
6. ตั้ง `failed_condition_presentation` ที่ EventChoice ว่าจะ Disabled หรือ Hidden

ตัวอย่างตรวจ Reflex:

```text
type = ATTRIBUTE
key = reflex
comparison = GREATER_OR_EQUAL
required_number = 6
failure_reason = ต้องมี Reflex 6
```

ตัวอย่างตรวจ World Flag:

```text
type = FLAG
key = saved_village
comparison = EQUAL
value_type = BOOLEAN
required_bool = true
```

### ขั้นที่ 4: เพิ่ม Effect

1. ขยาย `effects` ของ Choice หรือ `on_start_effects`/`on_end_effects` ของ Event
2. เลือก **New EventEffect**
3. เลือก `type`
4. กรอกเฉพาะช่องที่ Effect นั้นใช้

ตัวอย่าง Choice ดื่มน้ำต้องคำสาป:

```text
Effect 1
type = HEAL
target_id = player
amount = 20

Effect 2
type = ADD_STATUS
target_id = player
status_effect = Poison EffectData

Effect 3
type = MODIFY_FLAG
key = drank_cursed_water
bool_value = true
```

## 4. วิธีสร้าง Encounter พร้อมภาพ

1. สร้างหรือเปิด Resource `EncounterData` ใน `res://data/encounter/`
2. ตั้ง `id`, `encounter_name` และ `encounter_description`
3. ลากภาพสำหรับหน้าพรีวิวเข้า `encounter_image`
4. ลากภาพสนามต่อสู้เข้า `battlefield_texture`
5. ตั้ง `map_size_feet`, `player_spawn_positions_feet`, `enemies` และข้อมูลสนามตามปกติ
6. ลาก Event ผลลัพธ์เข้า `victory_event` และ `defeat_event`
7. เพิ่ม EventEffect ใน `rewards` หาก Encounter ต้องให้รางวัลก่อนเปิด Victory Event
8. ใน EventChoice ลาก EncounterData นี้เข้า `encounter`

เมื่อผู้เล่นเลือก Choice ระบบจะแสดงชื่อ คำอธิบาย และ `encounter_image` พร้อมปุ่ม **BEGIN ENCOUNTER** ก่อนเปลี่ยน Scene ไป Combat

ดูตัวอย่างได้ที่:

- `res://data/event/strange_caravan.tres`
- `res://data/encounter/bandit_ambush_event.tres`
- `res://data/event/bandit_victory.tres`
- `res://data/event/bandit_defeat.tres`

## 5. วิธีนำ Event ไปใช้บน RunMap

`MapNodeData` มีช่อง `event_data` สำหรับกำหนด Event ของโหนดชนิด `EVENT`

ระบบสร้าง Run แบบ procedural ปัจจุบันใช้ `RunGenerator.DEFAULT_EVENT` เป็นต้นแบบ แล้ว duplicate ให้แต่ละ Event node พร้อม id เฉพาะโหนด เพื่อไม่ให้การเล่น Event หนึ่งครั้งไปล็อก Event node อื่น

หากต้องการเปลี่ยน Event เริ่มต้นของทุกโหนด ให้แก้ `DEFAULT_EVENT` ใน `res://run/run_generator.gd`

หากสร้าง MapNodeData เอง:

1. ตั้ง `node_type = EVENT`
2. ลาก EventData ที่ต้องการเข้า `event_data`
3. เมื่อผู้เล่นเข้าโหนด RunMap จะเรียก EventManager และเปิด EventPanel ให้อัตโนมัติ

ปัจจุบันยังไม่มี Event Catalog หรือ weighted EventTable สำหรับสุ่ม Event คนละแบบในแต่ละโหนด

## 6. การทำ Event chain และ Result Event

### Event ไป Event

ตั้ง `EventChoice.next_event` เป็น EventData ปลายทาง เมื่อเลือก Choice ระบบจะ:

1. ใช้ Effect ของ Choice
2. ใช้ `on_end_effects` ของ Event ปัจจุบัน
3. บันทึก Event ปัจจุบันว่าเสร็จแล้ว
4. เปิด Event ถัดไปด้วย Context เดิม

### Event ไป Encounter

ตั้ง `EventChoice.encounter` หรือใช้ `START_ENCOUNTER` Effect เมื่อเลือก Choice ระบบจะแสดง Encounter Preview และรอผู้เล่นยืนยัน

### Combat กลับ Result Event

Encounter ที่เริ่มจาก Event จะบันทึกสถานะไว้ใน SceneTree เมื่อ Combat จบ:

- Victory เปิด `victory_event`
- Defeat เปิด `defeat_event`
- Reward Effects ถูกใช้ก่อนเปิด Result Event เมื่อชนะ
- `GameState` และ RunState เดิมถูกนำกลับมาใช้ต่อ

Encounter ที่เริ่มจากโหนด Combat ปกติยังใช้ Reward Selection flow เดิมของ Run

## 7. การเรียกใช้จาก Scene อื่น

หากไม่ได้ใช้ RunMap ให้สร้าง Manager และ Context ดังนี้:

```gdscript
var game_state := GameState.new()
var encounter_manager := EncounterManager.new()
var event_manager := EventManager.new()

add_child(encounter_manager)
add_child(event_manager)
event_manager.configure(game_state, encounter_manager)

var context := EventContext.new(game_state, current_party)
context.actor_id = "player"
event_manager.start_event(my_event_data, context)
```

Signal ที่ UI หรือ Scene Flow สามารถรับได้:

- `EventManager.event_started`
- `EventManager.choices_changed`
- `EventManager.effects_applied`
- `EventManager.event_finished`
- `EventManager.encounter_requested`
- `EncounterManager.encounter_started`
- `EncounterManager.combat_requested`
- `EncounterManager.encounter_finished`
- `EncounterManager.event_requested`

## 8. สิ่งที่ยังไม่รองรับครบ

- Objective runtime เช่น DefeatTarget, SurviveTurns, ProtectUnit หรือ CapturePoint
- Boss Phase และการเปลี่ยน Ability/สนามระหว่าง Combat
- Combat Event ที่ trigger จาก Turn, HP, Unit death, Area หรือ Objective
- weighted Random Event ผ่าน EventTable
- Dynamic enemy groups ที่ประเมิน Condition แล้ว spawn อัตโนมัติ
- การใช้ข้อมูล `TELEPORT` และ `REWARD` โดยระบบปลายทางอัตโนมัติ
- Result แบบ Partial Victory และ Escape จาก Combat scene โดยอัตโนมัติ
- Save/Load ของ GameState ลงไฟล์ถาวร
- Localization และ rich text สำหรับเนื้อหา Event

ช่อง `enemy_groups` และ `objectives` ใน EncounterData เป็นจุดเตรียมขยายข้อมูล ยังไม่มีตัวประเมิน Objective หรือ spawner สำหรับกลุ่มศัตรู

## 9. การทดสอบ

ทดสอบแกน Event → Encounter → Result Event:

```powershell
powershell -ExecutionPolicy Bypass -File tests/run_regression.ps1 -Target tests/event
```

ทดสอบ Event UI, RunMap, ภาพ Encounter และการกลับจาก Combat:

```powershell
powershell -ExecutionPolicy Bypass -File tests/run_regression.ps1 -Target tests/run
```

ผลที่ควรได้:

- Event `.tres` โหลดได้
- Choice แสดง Enabled, Disabled และ Hidden ถูกต้อง
- Choice แบบเลือกหนึ่งคนกรองรายชื่อสมาชิกจาก Condition ถูกต้อง
- Choice แบบทั้งปาร์ตี้ใช้ Effect กับทุกคน แต่ใช้ Effect ระดับโลกเพียงครั้งเดียว
- Condition และ Effect ถูกใช้ตามลำดับ
- Event node เปิด EventPanel
- ภาพ Event และ Encounter แสดงจาก Resource
- Encounter ต้องยืนยันก่อนเข้า Combat
- Victory/Defeat กลับมาเปิด Result Event
- Event คนละโหนดไม่ใช้ completion id ร่วมกัน
