# Phase 3: Personality & Interaction — 详细计划

## 素材盘点

Kittens pack 每只猫有 **48 个 GIF**，目前只用了 9 个。Phase 3 将充分利用剩余素材：

| 类别 | 文件 | 方向 | 当前状态 |
|------|------|------|----------|
| walk | walk_{left,right,up,down,left_up,left_d,right_up,right_d}.gif | 8方向 | ✅ 仅用 left/right |
| sleep | sleep{1-4}(l/r).gif | 左/右 × 4 姿势 | ✅ 仅用 sleep1 |
| meow | meow_{stand,sit,sit2,lie}.gif | 无方向 | ✅ 仅用 sit |
| yawn | yawn_{stand,sit,sit2,lie}.gif | 无方向 | ✅ 仅用 sit |
| wash | wash_{stand,sit,lie}.gif | 无方向 | ✅ 仅用 sit |
| scratch | scratch(l/r).gif | 左/右 | ✅ 已用 |
| **hiss** | hiss(l/r).gif | 左/右 | ❌ 未用 |
| **paw_att** | paw_att_{8方向}.gif | 8方向 | ❌ 未用 |
| **eat** | eat_{8方向}.gif | 8方向 | ❌ 未用 |
| **on_hind_legs** | on_hind_legs.gif | 无方向 | ❌ 未用 |

---

## 3.1 点击反应

**触发**: 左键点击猫咪（非拖拽，mouseUp 时 `!wasDragged`）

**行为**:
- 随机播放一个反应动画：meow_stand(50%)、hiss(30%)、on_hind_legs(20%)
- hiss 根据 `facingRight` 选择 hiss(l) 或 hiss(r)
- 动画播完后回到 sitIdle

**实现要点**:
- `PetView.mouseUp` 中检测到 `!wasDragged` 时，除了关闭重力，还通知 brain 进入 `clickReact` 状态
- 新增 `PetState.clickReact`
- 加载新动画：hiss(l/r)、meow_stand、on_hind_legs
- 注意：点击反应优先级高于重力捕获，两者可共存（点击既停住猫又触发反应）

**改动范围**:
- `PetBrain.loadAnims`: 新增 hiss_l, hiss_r, meow_stand, on_hind_legs
- `PetState`: 新增 `.clickReact`
- `PetBrain.enter/update`: 处理 clickReact
- `PetView.mouseUp`: 触发反应

---

## 3.2 鼠标跟随

**触发**: 猫咪在 sitIdle 状态时，有 20% 概率选择 "跟随鼠标" 而非随机走动

**行为**:
- 计算鼠标相对猫咪的方向（8方向之一）
- 使用对应方向的 walk 动画朝鼠标走去
- 走到鼠标附近（距离 < 50pt）或超时 5 秒后停下
- 到达后播放 paw_att 动画（朝鼠标方向"挠"一下）

**实现要点**:
- 新增 `PetState.followMouse`
- 需要在 tick 中获取 `NSEvent.mouseLocation` 并传给 brain
- 8方向动画映射：根据 dx/dy 的比例选择 left, right, up, down, left_up, left_d, right_up, right_d
- 加载全部 8 方向 walk 和 paw_att 动画
- `Movement` struct 增加 `dy` 字段用于垂直移动

**方向计算逻辑**:
```
angle = atan2(dy, dx)
分为 8 个 45° 扇区 → 映射到 8 个方向名
```

**改动范围**:
- `PetBrain.loadAnims`: 加载全部 8 方向 walk + 8 方向 paw_att
- `PetState`: 新增 `.followMouse`
- `PetBrain`: 新增方向计算方法、followMouse 的 update 逻辑
- `Movement`: 新增 `dy` 字段
- `PetInstance.tick`: 传入鼠标位置，处理 dy 移动
- `PetBrain.pickNext`: 加入 followMouse 概率

---

## 3.3 撸猫（长按抚摸）

**触发**: 鼠标按住猫咪不动超过 1 秒

**行为**:
- 进入 `petting` 状态，播放 wash_lie 或 wash_stand 动画（模拟被撸时舒服地舔毛）
- 持续按住期间循环播放
- 松手后播放 yawn_sit2（伸懒腰），然后回到 sitIdle

**实现要点**:
- `PetView` 中用 `mouseDownTime` 记录按下时间
- tick 中检测：isDragging && !wasDragged && 按住超过 1 秒 → 通知 brain 进入 petting
- 新增 `PetState.petting`
- 松手时如果在 petting 状态 → 进入 yawning 作为过渡

**改动范围**:
- `PetView`: 新增 mouseDownTime 属性
- `PetState`: 新增 `.petting`
- `PetBrain.loadAnims`: 加载 wash_lie, yawn_sit2
- `PetBrain.enter/update`: 处理 petting 状态
- `PetInstance.tick`: 检测长按并触发

---

## 3.4 随机趣味事件

**触发**: sitIdle 状态结束时，有小概率触发特殊行为（替代普通的 pickNext）

**事件列表**:

| 事件 | 概率 | 描述 | 动画 |
|------|------|------|------|
| Zoomies（发疯跑） | 5% | 快速来回跑 3-4 次，速度 2x | walk_left/right 交替，加速播放 |
| 追虫子 | 5% | 朝随机方向冲刺，到达后 paw_att，然后 eat | walk → paw_att → eat（同方向） |
| 伸懒腰 | 5% | 原地站起来 | on_hind_legs → yawn_stand |

**实现要点**:
- 新增 `PetState.zoomies(phase)`, `.chaseBug(phase)`, `.stretch`
- Zoomies: 内部计数器记录来回次数，每次切换方向，walkSpeed × 2
- 追虫子: 3 阶段状态机（走过去 → 拍 → 吃）
- 这些是复合状态，需要内部 phase 管理

**改动范围**:
- `PetState`: 新增 3 个状态
- `PetBrain`: 新增复合状态逻辑
- `PetBrain.loadAnims`: 加载 eat, paw_att, on_hind_legs, yawn_stand, meow_stand
- `PetBrain.pickNext`: 调整概率分配

---

## 3.5 边缘攀爬（降低优先级）

> 这个功能复杂度较高，建议放到 Phase 3.5 或 Phase 4 再做。

**原因**: 需要重写窗口位置逻辑（当前只支持水平移动），引入"附着边"概念（底边/左边/右边/顶边），walk_up/walk_down 动画在侧边时需要旋转渲染。对核心架构改动大，容易引入 bug。

**如果要做**:
- 新增 `EdgeSide` enum: bottom, left, right, top
- 猫走到屏幕边缘时有概率"爬上去"
- 沿边缘行走时使用 walk_up/walk_down
- 到达角落时转向到下一条边

---

## 实施顺序

建议按依赖关系排序：

1. **3.1 点击反应** — 最简单，独立性强，立竿见影
2. **3.2 鼠标跟随** — 需要 8 方向系统，为后续功能打基础
3. **3.3 撸猫** — 依赖点击检测基础设施
4. **3.4 随机事件** — 依赖 8 方向系统和更多动画
5. **3.5 边缘攀爬** — 视时间决定是否纳入本阶段

## 验证方法

每完成一个子功能后：
1. `bash build.sh` 编译通过
2. 运行桌宠，手动触发对应行为
3. 确认动画正确播放、状态正确切换、无卡顿或闪烁
4. 确认不影响已有功能（拖拽、重力、多猫、菜单）
