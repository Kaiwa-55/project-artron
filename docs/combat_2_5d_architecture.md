# Project Artron: แผนออกแบบ Combat และ Exploration แบบ 2.5D

## เป้าหมาย

ระบบใหม่ต้องใช้โลก 3D ชุดเดียวเป็นแหล่งข้อมูลของ Combat และ Exploration โดยยังคงหน้าตาแบบแผนที่ Dungeondraft มุมมองด้านบน และรักษากฎ Combat เดิมระหว่างการย้ายระบบ

ความสามารถเป้าหมายประกอบด้วย:

- อาคารหลายชั้นและพื้นต่างระดับ
- ช่องเปิดในพื้น บันได ระเบียง และราวกันตก
- การมองเห็นและการยิงขึ้นลงระหว่างชั้น
- การผลักออกจากขอบและการตกลงสู่พื้นด้านล่าง
- Navigation และ AI ที่เดินข้ามชั้นได้
- Combat และ Exploration ใช้ฉาก กำแพง พื้น ช่องเปิด และบันไดชุดเดียวกัน

ระบบจะไม่มีแผนที่สำหรับ Exploration และ Combat แยกกัน เมื่อการย้ายเสร็จ `DungeonWorld3D.tscn` จะเป็นโลกกลาง ส่วนแต่ละโหมดเพิ่มเฉพาะ Controller และ UI ของตัวเอง

## หลักการสำคัญ

1. โลก ฟิสิกส์ และการมองเห็นใช้ 3D จริง
2. ภาพพื้นยังใช้ PNG จาก Dungeondraft บนระนาบ 3D
3. Combat logic เดิมยังใช้หน่วยฟุตและ `Vector2` ระหว่างช่วงเปลี่ยนผ่าน
4. ชั้นไม่ถูกตัดสินด้วย `floor_id` เพียงอย่างเดียว ตำแหน่งและพื้นรองรับเป็นข้อมูลจริง
5. `surface_id` ใช้ระบุพื้นที่สำหรับ UI, Navigation และการบันทึกเกม แต่ความสูงจริงมาจากตำแหน่ง Y
6. การมองเห็นใช้ Physics Ray Query กับ Geometry ชุดเดียวกับโลก

## ระบบพิกัดและหน่วย

Combat เดิมใช้ 12 world units ต่อ 1 ฟุต ระบบ 3D จะใช้ 1 หน่วย 3D ต่อ 1 ฟุตเพื่อลดการแปลงค่า:

```gdscript
const LOGIC_UNITS_PER_FOOT := 12.0

func logic_2d_to_world_3d(position: Vector2, elevation_feet: float) -> Vector3:
    return Vector3(
        position.x / LOGIC_UNITS_PER_FOOT,
        elevation_feet,
        position.y / LOGIC_UNITS_PER_FOOT
    )

func world_3d_to_logic_2d(position: Vector3) -> Vector2:
    return Vector2(position.x, position.z) * LOGIC_UNITS_PER_FOOT
```

แผนที่ 1600 × 1600 หน่วยจึงมีขนาดประมาณ 133.33 × 133.33 ฟุตในโลก 3D ระดับความสูงเริ่มต้น:

| พื้นที่ | Elevation |
|---|---:|
| Ground | 0 ฟุต |
| Level 1 | 10 ฟุต |
| Roof | 20 ฟุต |

ค่าเหล่านี้ต้องเป็นข้อมูลใน Resource และแก้ได้โดยไม่แก้โค้ด

## โครงสร้างข้อมูลกลาง

สร้าง Resource หลัก `BuildingMapData`:

```gdscript
class_name BuildingMapData
extends Resource

@export var id: StringName
@export var map_size_feet: Vector2
@export var surfaces: Array[BuildingSurfaceData]
@export var transitions: Array[BuildingTransitionData]
@export var spawn_points: Array[BuildingSpawnData]
```

แต่ละพื้นใช้ `BuildingSurfaceData`:

```gdscript
class_name BuildingSurfaceData
extends Resource

@export var surface_id: StringName
@export var display_name: String
@export var elevation_feet: float
@export var texture: Texture2D
@export var walkable_polygons: Array[PackedVector2Array]
@export var opening_polygons: Array[PackedVector2Array]
@export var walls: Array[BuildingWallData]
@export var railings: Array[BuildingRailingData]
```

`walkable_polygons` ระบุพื้นที่ซึ่งมีพื้นรองรับ ส่วน `opening_polygons` ระบุช่องบันได พื้นแตก และช่องเปิดที่ Raycast กับตัวละครสามารถผ่านได้

บันไดและทางเชื่อมใช้ `BuildingTransitionData`:

```gdscript
class_name BuildingTransitionData
extends Resource

@export var transition_id: StringName
@export var from_surface_id: StringName
@export var to_surface_id: StringName
@export var entry_area: AABB
@export var exit_transform: Transform3D
@export var traversal_cost_feet: float
@export var bidirectional: bool = true
```

ข้อมูลนี้ใช้สร้างทั้ง Collision, Navigation และเครื่องหมายบนหน้าจอ จึงไม่ควรมีรายการบันไดซ้ำในสคริปต์ Combat หรือ Exploration

## โครงสร้างฉากกลาง

```text
DungeonWorld3D (Node3D)
├── Surfaces (Node3D)
│   ├── GroundSurface (DungeonSurface3D)
│   │   ├── Artwork (MeshInstance3D)
│   │   ├── FloorBodies (StaticBody3D)
│   │   ├── Walls (StaticBody3D)
│   │   ├── Railings (StaticBody3D)
│   │   └── NavigationRegion3D
│   └── Level1Surface (DungeonSurface3D)
├── Transitions (Node3D)
│   └── Stair01 (DungeonTransition3D)
│       ├── NavigationLink3D
│       └── Area3D
├── SpawnPoints (Node3D)
├── Actors (Node3D)
├── Visibility (Node3D)
└── CameraRig (Node3D)
    └── Camera3D
```

`DungeonWorld3D` รับ `BuildingMapData` แล้วสร้าง Geometry ทั้งหมด ไม่ผูกกับ Combat หรือ Exploration

## 1. สร้างฉาก 3D จาก Ground และ Level1

สร้าง PlaneMesh หนึ่งชิ้นต่อภาพ โดยตั้งขนาดตาม `map_size_feet` และหมุนให้นอนบนแกน XZ:

```text
Ground.png  → Y = 0
Level1.png  → Y = 10
roof.png    → Y = 20
```

ภาพ Level1 และ roof มี Alpha อยู่แล้ว จึงวางซ้อนบน Plane ขนาดเดียวกันได้ จุดศูนย์กลางและ Scale ต้องเหมือนกันทุกชั้น

Plane ที่แสดงภาพไม่เป็นตัวตัดสินว่าพื้นเดินได้หรือไม่ การเดินใช้ `walkable_polygons` ซึ่งสร้าง Collision และ Navigation แยกต่างหาก วิธีนี้ทำให้พื้นที่โปร่งใสใน PNG ไม่กลายเป็นพื้นล่องหน

Camera ใช้ Orthographic Projection เริ่มต้นที่มุมเกือบด้านบน สามารถกำหนด Preset สองแบบ:

- Tactical: มองเอียงเล็กน้อยเพื่อเห็นความสูงและขอบชั้น
- Top-down: มองตรงลงเพื่อรักษารูปลักษณ์ Dungeondraft

การเปลี่ยนมุมกล้องไม่มีผลต่อกฎระยะ การเดิน หรือ Line of Sight

เงื่อนไขจบระยะที่ 1:

- Ground และ Level1 ซ้อนตรงกัน
- เปลี่ยน Focus ระหว่างชั้นได้
- ซ่อน/ทำจางชั้นที่บังกล้องได้
- ภาพโปร่งใสไม่สร้างพื้น Collision เอง

## 2. กำแพง Collision3D และช่องเปิด

กำแพงแต่ละช่วงสร้างเป็น `StaticBody3D` กับ `BoxShape3D` โดยแปลงสี่เหลี่ยม 2D เดิมเป็นกล่อง 3D:

```gdscript
func wall_rect_to_box(rect: Rect2, base_y: float, height: float) -> Transform3D:
    var center_2d := rect.get_center() / LOGIC_UNITS_PER_FOOT
    return Transform3D(
        Basis.IDENTITY,
        Vector3(center_2d.x, base_y + height * 0.5, center_2d.y)
    )
```

ประตูต้องเกิดจากการแบ่งกำแพงเป็นสองช่วง ไม่ใช้ Collision เต็มแนวแล้วเจาะด้วยโค้ดภายหลัง ช่องบันไดต้องถูกหักออกจาก Floor Collision และ Navigation Mesh

Collision Layers ที่เสนอ:

| Layer | เนื้อหา |
|---:|---|
| 1 | Actor body |
| 2 | Walkable floor |
| 3 | Solid wall |
| 4 | Railing |
| 5 | Vision-only blocker |
| 6 | Transition trigger |
| 7 | Targeting surface |

กำแพงใช้ Geometry เดียวสำหรับการเดินและ Raycast หากกำแพงใดบังสายตาแต่เดินผ่านได้ ให้ใช้ Layer 5 เพิ่มเฉพาะกรณี

เงื่อนไขจบระยะที่ 2:

- เดินทะลุกำแพงไม่ได้
- เดินผ่านประตูได้
- ตกผ่านช่องเปิดได้
- ไม่มีพื้นล่องหนบริเวณช่องบันได
- เปิด Debug Geometry แล้วตรงกับภาพที่ยอมรับได้

## 3. แปลงการคลิกบนหน้าจอเป็นตำแหน่ง 3D

สร้าง `WorldPointer3D` เป็นจุดเดียวสำหรับ Mouse Picking:

```gdscript
func get_world_hit(screen_position: Vector2) -> Dictionary:
    var origin := camera.project_ray_origin(screen_position)
    var direction := camera.project_ray_normal(screen_position)
    var query := PhysicsRayQueryParameters3D.create(
        origin,
        origin + direction * 1000.0,
        TARGETING_SURFACE_MASK
    )
    return world_3d.direct_space_state.intersect_ray(query)
```

Collider ของพื้นต้องให้ข้อมูลต่อไปนี้:

```text
position          จุดชนในโลก
normal            ทิศตั้งฉากของพื้น
surface_id        พื้นหรือชั้นที่คลิก
navigation_region Region ที่ใช้หาเส้นทาง
```

ก่อนรับตำแหน่งคลิกต้องตรวจว่า:

1. Collider เป็น Targeting Surface
2. จุดอยู่บน Walkable Surface
3. ตัวละครสามารถเดินถึง Region นั้นได้
4. ระยะเดินและ AP เพียงพอ
5. จุดไม่ถูก Actor อื่นครอบครอง

หากมีพื้นหลายชั้นซ้อนกัน ให้ Raycast เลือกพื้นแรกที่มองเห็นจากกล้อง ชั้นที่ถูกซ่อนหรือปิดการเลือกต้องถูกถอดออกจาก Targeting Mask ชั่วคราว

เงื่อนไขจบระยะที่ 3:

- คลิกพื้นแต่ละชั้นได้ตำแหน่งและ `surface_id` ถูกต้อง
- คลิกช่องเปิดแล้วไม่คืนพื้นล่องหน
- Camera zoom/rotate แล้วยัง Picking ถูกต้อง

## 4. ย้าย Combatant ไปสู่ตำแหน่ง 3D โดยรักษา Combat เดิม

ช่วงเปลี่ยนผ่านให้ `CombatantState.position: Vector2` เป็นตำแหน่งเชิงกฎเดิม และเพิ่มข้อมูล:

```gdscript
var elevation_feet: float = 0.0
var surface_id: StringName = &"ground"
var is_airborne: bool = false
```

`Combatant3D` เป็น Presentation Node:

```text
Combatant3D (CharacterBody3D)
├── CollisionShape3D
├── TokenQuad (Sprite3D หรือ MeshInstance3D)
├── SelectionRing
├── StatusAnchor
└── GroundProbe (RayCast3D)
```

ตำแหน่งแสดงผลคำนวณจาก State ผ่าน Adapter:

```gdscript
global_position = logic_2d_to_world_3d(
    state.position,
    state.elevation_feet
)
```

ทุกการเคลื่อนที่ต้องเขียนกลับเข้า State หลัง Animation จบ ห้ามให้ CharacterBody3D กลายเป็นแหล่งข้อมูลหลักระหว่างช่วงเปลี่ยนผ่าน

ระยะ Combat แบบเดิมยังใช้ระยะ XZ ก่อน เมื่อระบบยิงข้ามชั้นพร้อมแล้วจึงเปลี่ยนเป็นระยะ 3D:

```gdscript
distance_3d = attacker.world_position.distance_to(target.world_position)
```

เงื่อนไขจบระยะที่ 4:

- Turn order, AP, HP, Mana, Status และ Ability เดิมทำงานเหมือนเดิม
- Actor ทุกตัวแสดงบน Surface ที่ถูกต้อง
- เลือกตัวละครด้วย Mouse Picking 3D ได้
- Save/Return จาก Combat ไม่สูญเสียตำแหน่งหรือทรัพยากร

## 5. การเดินและ NavigationLink ผ่านบันได

แต่ละ Surface มี `NavigationRegion3D` ของตัวเอง บันไดสร้าง `NavigationLink3D` เชื่อมจุดเข้าและออก

เส้นทางอาจมีสามประเภท Segment:

```text
SurfacePath       เดินบนพื้นปกติ
TransitionPath    ใช้บันได ทางลาด หรือบันไดลิง
AirPath           กระโดด ตก หรือถูกผลัก
```

Movement cost คำนวณจากความยาว Path จริง ไม่ใช้ระยะเส้นตรง จุดเปลี่ยนชั้นอัปเดต `surface_id` เมื่อ Actor ผ่านกึ่งกลาง Transition หรือถึง Exit ตามชนิดบันได

ใน Combat:

- เริ่ม Move ใช้ AP ตามระบบเดิม
- เดินบนบันไดใช้ Movement Remaining
- ห้ามหยุดกลาง Transition ในรุ่นแรก
- Opportunity Attack ตรวจตาม Segment ก่อนเข้าและหลังออกจากบันได
- หากระยะไม่พอถึงปลายบันได ไม่อนุญาตให้เริ่มใช้บันได

AI ใช้ Navigation Path เดียวกับผู้เล่น จึงไม่ต้องเขียนกฎ “ถ้าอยู่คนละชั้นให้หาบันได” แยกเอง ตราบใดที่ NavigationLink เชื่อม Region ถูกต้อง

เงื่อนไขจบระยะที่ 5:

- ผู้เล่นและ AI หาเส้นทางข้ามชั้นได้
- Movement cost รวมบันไดถูกต้อง
- ไม่มีการวาร์ปหรือหยุดกลางชั้น
- Path Preview แสดง Segment ข้ามชั้นชัดเจน

## 6. Raycast สำหรับการมองเห็นและการยิงข้ามชั้น

การมองเห็นไม่เปรียบเทียบ `surface_id` โดยตรง แต่ยิง Ray จากจุดสายตาไปยังจุดเป้าหมาย:

```gdscript
observer_eye = observer.global_position + Vector3.UP * observer.eye_height
target_points = [
    target.global_position + Vector3.UP * target.torso_height,
    target.global_position + Vector3.UP * target.head_height,
]
```

เป้าหมายถือว่ามองเห็นหากมีอย่างน้อยหนึ่ง Ray ไปถึง Target Hitbox โดยไม่ชนกำแพง พื้น หลังคา หรือ Vision Blocker ก่อน

Raycast ต้องใช้ Collision Mask สำหรับ:

- กำแพง
- พื้นและเพดาน
- หลังคา
- ประตูที่ปิด
- วัตถุขนาดใหญ่ที่บังสายตา
- Target Hitbox

ราวเตี้ยอาจให้ Cover แต่ไม่บังการมองเห็นทั้งหมด ผล Ray ต้องคืนข้อมูลมากกว่า Boolean:

```gdscript
class_name LineOfSightResult

var visible: bool
var cover: int
var blocker: Object
var clear_rays: int
var tested_rays: int
```

การยิงใช้เส้น Projectile แยกจาก Vision Ray ได้ อาวุธบางชนิดอาจมองเห็นเป้าหมายแต่ยิงติดราวหรือขอบพื้น

เงื่อนไขจบระยะที่ 6:

- มองและยิงข้ามชั้นผ่านช่องเปิดได้
- พื้นทึบและกำแพงบัง Ray ได้
- ราวให้ Cover ตามความสูง
- เป้าหมายคนละชั้นไม่ถูกซ่อนเพียงเพราะ `surface_id` ต่างกัน
- UI แสดงสาเหตุเมื่อยิงไม่ได้

## 7. ราว ระเบียง การผลัก และการตก

ราวเป็น Geometry แยกจากกำแพง และมีข้อมูล:

```gdscript
class_name BuildingRailingData

@export var shape: BoxShape3D
@export var height_feet: float
@export var break_force: float
@export var cover_value: int
```

ขั้นตอนการผลัก:

1. คำนวณทิศและระยะผลักบนโลก 3D
2. Sweep Shape ของ Actor ไปตามเส้นทาง
3. ถ้าชนกำแพง ให้หยุดและใช้กฎกระแทก
4. ถ้าชนราว ให้ตรวจว่าราวหยุดการผลัก แตก หรือถูกข้าม
5. ถ้าออกนอก Walkable Surface ให้เข้าสถานะ `is_airborne`
6. Raycast ลงด้านล่างเพื่อหาพื้นแรก
7. คำนวณระยะตกและ Fall Damage
8. วาง Actor บน Surface ปลายทางและอัปเดต `surface_id`

สูตรเริ่มต้นที่เสนอ:

```text
0–5 ฟุต     ไม่เสียหาย
มากกว่า 5 ฟุต  1d6 ต่อทุก 10 ฟุต
ตกค้างเมื่อถูกผลักชนกำแพง  ใช้กฎ Collision Damage แยก
```

ต้องกำหนดพฤติกรรมเมื่อไม่มีพื้นด้านล่าง เช่น ตกนอกแผนที่: Actor ถูกนำออกจาก Encounter หรือเข้าสู่สถานะพิเศษตาม Encounter Rule

เงื่อนไขจบระยะที่ 7:

- ผลักชนกำแพงและราวได้
- ผลักตกผ่านช่องเปิดและขอบระเบียงได้
- ตรวจพื้นปลายทางและความสูงตกถูกต้อง
- กล้องติดตามการตกโดยไม่เปลี่ยน Turn ก่อน Animation จบ
- AI ประเมินอันตรายจากขอบและโอกาสผลักศัตรูตกได้ในระดับพื้นฐาน

## 8. ย้าย Exploration มาใช้โลกเดียวกัน

เมื่อ Combat ผ่านทุกเงื่อนไขแล้ว ให้เปลี่ยน Exploration จาก Node2D เป็น Controller ที่ใช้งาน `DungeonWorld3D` เดียวกัน:

```text
DungeonWorld3D
├── ExplorationController
│   ├── Real-time movement
│   ├── Interaction
│   ├── Exploration visibility
│   └── Encounter trigger
└── CombatController
    ├── Turn manager
    ├── Tactical movement
    ├── Targeting
    └── Combat HUD
```

เมื่อ Encounter เริ่ม ไม่เปลี่ยนแผนที่หรือสร้างโลกใหม่ ให้หยุด Exploration Controller แล้วเปิด Combat Controller บนตำแหน่งเดิม ศัตรูและปาร์ตี้จึงไม่กระโดดตำแหน่งระหว่างโหมด

State ที่ต้องอยู่ต่อเนื่อง:

- Transform และ Surface ของ Actor ทุกตัว
- ประตูเปิด/ปิดและสิ่งก่อสร้างที่ถูกทำลาย
- ศัตรูที่พ่ายแพ้
- ของที่ตกบนพื้น
- แสงและ Vision Blocker
- Trap และพื้นที่อันตราย

เงื่อนไขจบระยะที่ 8:

- เริ่ม Combat ในตำแหน่ง Exploration ปัจจุบัน
- จบ Combat แล้วกลับควบคุมแบบ Real-time โดยไม่โหลดแผนที่ใหม่
- สภาพแวดล้อมที่เปลี่ยนระหว่าง Combat ยังคงอยู่
- ไม่มี Collision, Wall หรือ Stair data ซ้ำระหว่างสองโหมด

## การจัดไฟล์ที่เสนอ

```text
data/world/
├── building_map_data.gd
├── building_surface_data.gd
├── building_wall_data.gd
├── building_railing_data.gd
├── building_transition_data.gd
└── artron_dungeon.tres

scenes/world3d/
├── DungeonWorld3D.tscn
├── dungeon_world_3d.gd
├── DungeonSurface3D.tscn
├── dungeon_surface_3d.gd
├── DungeonTransition3D.tscn
├── world_pointer_3d.gd
└── world_coordinate_adapter.gd

scenes/combat3d/
├── CombatArena3D.tscn
├── combat_arena_3d.gd
├── Combatant3D.tscn
├── combatant_3d.gd
├── combat_camera_3d.gd
└── combat_line_of_sight_3d.gd
```

## แผนย้ายระบบและการย้อนกลับ

แต่ละระยะต้องเปิดด้วย Feature Flag:

```text
use_world_3d_presentation
use_world_3d_navigation
use_world_3d_line_of_sight
use_shared_exploration_world
```

Feature Flag มีไว้ระหว่างพัฒนาเท่านั้น เมื่องานระยะที่ 8 เสร็จและข้อมูลถูกย้ายครบ ให้ลบเส้นทางแผนที่ 2D เดิมและ Flag ทั้งหมด เพื่อไม่ให้โปรเจกต์มีระบบแผนที่สองชุดในระยะยาว

ลำดับ Dependency:

```text
ข้อมูลกลาง
   ↓
ฉากและ Collision 3D
   ↓
Mouse Picking + Combatant3D
   ↓
Navigation ข้ามชั้น
   ↓
Line of Sight / Projectile
   ↓
Push / Fall
   ↓
Exploration ใช้โลกเดียวกัน
   ↓
ลบระบบแผนที่ 2D เดิม
```

## สิ่งที่ยังไม่ทำในเอกสารนี้

- การสร้างโมเดลกำแพงที่มองเห็นได้แบบ 3D
- ระบบทำลายพื้นและกำแพงระหว่างเล่น
- การบินและการลอยตัว
- Projectile ที่มีวิถีโค้ง
- Multiplayer synchronization

โครงสร้างรองรับการเพิ่มภายหลัง แต่ไม่ควรใส่ในช่วงย้ายระบบ 8 ระยะแรก

## การรองรับแผนที่ใหม่ในอนาคต

ระบบต้องเพิ่มแผนที่ใหม่ได้ด้วยการสร้าง Map Package และลงทะเบียนใน Catalog โดยไม่แก้โค้ดของ Combat, Exploration, Navigation, AI หรือระบบการมองเห็น

ห้ามกำหนดชื่อ `Ground`, `Level1`, จำนวนชั้น, ขนาด 1600 × 1600, ความสูง 10 ฟุต หรือเส้นทางไฟล์ PNG ไว้ตายตัวใน Controller ค่าทั้งหมดต้องมาจาก `BuildingMapData`

### Map Package

แผนที่แต่ละแห่งมีโฟลเดอร์ของตัวเอง:

```text
data/world/maps/
├── artron_keep/
│   ├── artron_keep_map.tres
│   ├── surfaces/
│   │   ├── courtyard.tres
│   │   ├── first_floor.tres
│   │   └── roof.tres
│   ├── transitions/
│   │   └── west_stairs.tres
│   ├── geometry/
│   │   ├── walls.tres
│   │   ├── railings.tres
│   │   └── openings.tres
│   └── encounters/
│       └── hall_guards.tres
└── new_map_id/
    └── ...

assets/maps/
├── artron_keep/
│   ├── ground.png
│   ├── first_floor.png
│   └── roof.png
└── new_map_id/
    └── ...
```

Map Package ต้องไม่มีสคริปต์เฉพาะแผนที่สำหรับพฤติกรรมมาตรฐาน เช่น กำแพง บันได ประตู ระเบียง และจุดเกิด สิ่งเหล่านี้ต้องสร้างจาก Resource กลาง หากแผนที่ต้องมีกลไกพิเศษ ให้ประกาศผ่าน `map_features` หรือ Scene Extension ที่มี Interface ชัดเจน

### Map Catalog

สร้าง `BuildingMapCatalog` เป็นทะเบียนแผนที่:

```gdscript
class_name BuildingMapCatalog
extends Resource

@export var maps: Array[BuildingMapData]

func get_map(map_id: StringName) -> BuildingMapData:
    for map_data in maps:
        if map_data.id == map_id:
            return map_data
    return null
```

Run Node และ Encounter อ้างอิง `map_id` กับ `spawn_group_id`:

```gdscript
@export var map_id: StringName
@export var player_spawn_group_id: StringName
@export var enemy_spawn_group_id: StringName
@export var encounter_region_id: StringName
```

Combat และ Exploration เรียก Loader เดียวกัน:

```gdscript
var map_data := map_catalog.get_map(request.map_id)
world.load_map(map_data)
world.spawn_group(request.player_spawn_group_id, party)
```

หากไม่พบ `map_id` ระบบต้องหยุดโหลดพร้อมข้อความที่ระบุ Encounter และ ID ที่ผิด ห้ามย้อนกลับไปใช้แผนที่เริ่มต้นโดยเงียบ ๆ เพราะจะทำให้พบปัญหาตอนเล่นจริงยาก

### ID ที่ต้องคงที่

Object ที่ต้องบันทึกสถานะข้ามการโหลดใช้ ID ถาวร:

- `map_id`
- `surface_id`
- `transition_id`
- `door_id`
- `destructible_id`
- `spawn_group_id`
- `encounter_region_id`
- `light_zone_id`

ห้ามใช้ NodePath หรือลำดับ Array เป็น Save ID เพราะเปลี่ยนเมื่อ Artist จัด Scene ใหม่ได้

Save State ต่อแผนที่มีรูปแบบ:

```gdscript
class_name MapRuntimeState
extends Resource

@export var map_id: StringName
@export var data_version: int
@export var opened_doors: Array[StringName]
@export var destroyed_objects: Array[StringName]
@export var defeated_encounters: Array[StringName]
@export var discovered_regions: Array[StringName]
@export var dropped_items: Array[Dictionary]
@export var actor_locations: Array[Dictionary]
```

### จำนวนชั้นและชนิด Surface

ระบบต้องรองรับ Surface จำนวนเท่าใดก็ได้ ไม่สมมติว่ามีเพียง Ground กับ Level 1 ตัวอย่าง Surface ที่อนุญาต:

- พื้นหลักของอาคาร
- ห้องใต้ดิน
- ชั้นลอย
- ระเบียง
- หลังคาที่เดินได้
- สะพาน
- พื้นลาด
- แท่นยกที่เคลื่อนที่ได้

`surface_id` เป็น StringName และ `elevation_feet` เป็นค่าจริง ดังนั้นแผนที่หนึ่งอาจมี `basement`, `courtyard`, `mezzanine`, `tower_01` และ `roof_walkway` โดยไม่ต้องแก้ Enum

UI สามารถจัดกลุ่ม Surface เป็นชั้นสำหรับผู้เล่นด้วย `display_group` แต่ระบบฟิสิกส์ยังใช้ Transform จริง

### ขนาด ทิศทาง และ Origin ของแผนที่

แต่ละแผนที่กำหนดค่าเอง:

```gdscript
@export var map_size_feet: Vector2
@export var source_image_size: Vector2i
@export var pixels_per_foot: float
@export var world_origin: Vector3
@export var north_direction: Vector3
```

ภาพทุกชั้นใน Map Package เดียวกันต้องใช้ Coordinate Frame เดียวกัน หากจำเป็นต้อง Crop ภาพแต่ละชั้น ต้องบันทึก `texture_offset_feet` ห้ามชดเชยตำแหน่งด้วยค่าที่เขียนไว้ใน Scene

### Map Loader

`DungeonWorld3D.load_map()` รับผิดชอบวงจรการโหลด:

1. ตรวจ Schema และ `data_version`
2. ยกเลิกการโหลดแผนที่เดิมอย่างปลอดภัย
3. โหลด Texture แบบ Async
4. สร้าง Visual Surface
5. สร้าง Floor, Wall, Railing และ Opening Collision
6. สร้าง NavigationRegion และ NavigationLink
7. สร้าง Spawn Point, Encounter Region และ Interaction
8. ใช้ `MapRuntimeState` ที่บันทึกไว้
9. ตรวจ Geometry และการเชื่อมต่อ Navigation
10. ส่ง Signal `map_ready(map_id)`

Controller ห้าม Spawn Actor จนกว่าจะได้รับ `map_ready`

Loader ต้องมี Signals อย่างน้อย:

```gdscript
signal map_load_started(map_id: StringName)
signal map_load_progress(map_id: StringName, progress: float)
signal map_ready(map_id: StringName)
signal map_load_failed(map_id: StringName, errors: Array[String])
```

### การนำเข้าจาก Dungeondraft

ช่วงแรกใช้ Workflow แบบกึ่งอัตโนมัติ:

1. Export ทุก Level ด้วยขนาด Canvas และ Scale เดียวกัน
2. ใช้ PNG หรือ WebP ที่รองรับ Alpha
3. คัดลอกภาพเข้าโฟลเดอร์ Map Package
4. สร้าง `BuildingMapData` จาก Template
5. วาด Walkable Polygon, Opening, Wall และ Railing ใน Godot Editor
6. วาง Transition และ Spawn Group
7. รัน Map Validator

เมื่อรูปแบบข้อมูลนิ่งแล้วจึงสร้าง Editor Import Plugin เพื่ออ่าน Manifest เช่น:

```json
{
  "map_id": "artron_keep",
  "pixels_per_foot": 12,
  "surfaces": [
    {"id": "ground", "image": "ground.png", "elevation_feet": 0},
    {"id": "first_floor", "image": "first_floor.png", "elevation_feet": 10},
    {"id": "roof", "image": "roof.png", "elevation_feet": 20}
  ]
}
```

Importer สร้าง Resource และ Scene ที่สร้างซ้ำได้ แต่ไฟล์ Geometry ที่ Artist แก้ด้วยมือจะต้องแยกจากไฟล์ Generated เพื่อไม่ให้ Import ครั้งใหม่เขียนทับ

```text
generated/     ภาพ Plane, Material และข้อมูลพื้นฐานที่สร้างใหม่ได้
authored/      Collision, Opening, Transition และ Spawn ที่ Artist วางเอง
runtime/       State ที่เกิดระหว่างเล่น
```

### Map Validator

ทุก Map Package ต้องผ่าน Validator ก่อนใช้งาน:

- `map_id` ไม่ซ้ำใน Catalog
- ID ภายในแผนที่ไม่ซ้ำ
- Texture มีอยู่และขนาด/Scale ตรงตามข้อมูล
- Walkable Polygon ไม่เสียรูปและมี Surface รองรับ
- Opening ถูกตัดออกจาก Floor Collision
- Transition อ้างอิง Surface ที่มีอยู่
- NavigationLink มีจุดต้นและปลายบน Navigation Region
- Spawn Point ไม่อยู่ในกำแพง ช่องเปิด หรือพื้นที่ตก
- Encounter Region มีทางเข้าถึงได้
- ประตูทุกบานเชื่อมพื้นที่ที่ถูกต้อง
- Raycast ผ่านช่องเปิดตัวอย่างได้
- จุดสำคัญทั้งหมดเชื่อมถึงกัน หรือถูกระบุว่าแยกโดยตั้งใจ
- Save ID ที่ถูกถอดออกมี Migration หรือประกาศว่าเลิกใช้

Validator แสดง Error สำหรับข้อมูลที่ทำให้เล่นไม่ได้ และ Warning สำหรับความเสี่ยง เช่น Texture ใหญ่เกิน Budget

### Performance และ Streaming

แผนที่ขนาดเล็กโหลดทั้ง Map Package ได้ แผนที่ขนาดใหญ่แบ่งเป็น Chunk:

```gdscript
class_name BuildingChunkData

@export var chunk_id: StringName
@export var bounds: AABB
@export var surfaces: Array[BuildingSurfaceData]
@export var neighbor_chunk_ids: Array[StringName]
```

Chunk Boundary ต้องไม่ตัดกลางบันได ประตู หรือ Encounter ที่กำลังทำงาน ระบบจะโหลด Chunk ปัจจุบันกับเพื่อนบ้าน และไม่ถอด Chunk ที่มี Actor, Projectile หรือ Active Effect อยู่

ตั้ง Budget ต่อแผนที่ไว้ในข้อมูล:

```gdscript
@export var texture_memory_budget_mb: int
@export var maximum_static_bodies: int
@export var maximum_navigation_regions: int
@export var streaming_enabled: bool
```

### Versioning และ Migration

`BuildingMapData` และ `MapRuntimeState` ต้องมี `data_version` เมื่อเปลี่ยน ID หรือโครงสร้างแผนที่ ให้เพิ่ม Migration:

```gdscript
func migrate_map_state(state: MapRuntimeState, target_version: int) -> MapRuntimeState:
    # Rename removed IDs, move actor locations, and discard invalid transient data.
    return state
```

ห้ามแก้ `map_id` หลังปล่อยให้ผู้เล่นใช้งานแล้ว หากต้องเปลี่ยน `surface_id` หรือ `door_id` ต้องมีตาราง Rename เพื่อรักษา Save เดิม

### ขั้นตอนเพิ่มแผนที่ใหม่

ผู้สร้างแผนที่ควรทำตามลำดับนี้:

1. สร้างโฟลเดอร์จาก Map Package Template
2. กำหนด `map_id`, ขนาด, Scale และ Origin
3. ใส่ภาพของทุก Surface
4. วาด Walkable Area, Opening, Wall และ Railing
5. วาง Transition ระหว่าง Surface
6. วาง Spawn Group และ Encounter Region
7. เพิ่ม Map Resource ลง Catalog
8. รัน Validator
9. เปิด Preview เพื่อตรวจภาพ Collision, Navigation และ Raycast
10. ผูก `map_id` เข้ากับ Run Node หรือ Encounter Data

การเพิ่มแผนที่มาตรฐานหนึ่งแห่งไม่ควรต้องสร้าง GDScript ใหม่

### เงื่อนไขรับงานด้าน Extensibility

- เพิ่มแผนที่ใหม่ผ่าน Resource และ Catalog ได้โดยไม่แก้ Controller
- รองรับจำนวน Surface และ Transition ที่ไม่ตายตัว
- Combat และ Exploration โหลด Map Package เดียวกัน
- Encounter เดิมเปลี่ยนแผนที่ได้ด้วย `map_id`
- State ของแต่ละแผนที่บันทึกแยกกันและโหลดกลับได้
- Validator ป้องกัน ID ซ้ำ จุดเกิดผิดตำแหน่ง และ Transition ขาด
- Reimport ภาพไม่เขียนทับ Geometry ที่วางด้วยมือ
- แผนที่ขนาดใหญ่เปิด Streaming ได้โดยไม่เปลี่ยน API ของ Controller
