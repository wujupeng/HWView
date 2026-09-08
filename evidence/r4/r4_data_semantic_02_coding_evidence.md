# R4-DATA-SEMANTIC-02 Dashboard 生产统计语义修复 — Coding Evidence Package

> 任务：R4-DATA-SEMANTIC-02 Dashboard Production Statistics Semantic Correction
> 执行团队：华为云开发团队
> 执行日期：2026-09-08
> 状态：**Coding/Test/E2E 完成，提交 Gate Review**

---

## 1. 修改清单

### 1.1 修改文件

| 文件 | 修改类型 | 说明 |
|------|---------|------|
| `internal/store/daily_production_plan_repo.go` | 新增方法 | `SumCartonCountByDateAndLine` + `SumActualQuantityByDateAndLine` + `HasPlanForDateAndLine` |
| `internal/server/statistics_service.go` | 修改 | 数据源从 `recordRepo` 切换为 `planRepo`；修复 NULL time scan 警告 |
| `internal/server/server.go` | 修改 | `NewStatisticsService` 注入 `planRepo` |
| `internal/server/statistics_service_test.go` | 新增 | 7项单元测试 |

### 1.2 不修改项（红线遵守）

- ❌ R2-AMENDMENT — 未修改
- ❌ actual_quantity 定义 — 未修改
- ❌ carton specification 三维模型 — 未修改
- ❌ row6 = row2 + row3 + row5 — 未修改
- ❌ Production Quantity FROZEN — 未修改
- ❌ Jili 数据源语义 — 未修改
- ❌ Adapter 架构 — 未修改
- ❌ 新增 AI/预测 — 未引入
- ❌ Jili Fallback — 未引入

---

## 2. 代码变更详情

### 2.1 DailyProductionPlanRepo 新增聚合方法

```go
// SUM(carton_count) WHERE actual_quantity IS NOT NULL
func (r *DailyProductionPlanRepo) SumCartonCountByDateAndLine(ctx, planDate, lineCode) (int64, error)

// SUM(actual_quantity) WHERE actual_quantity IS NOT NULL
func (r *DailyProductionPlanRepo) SumActualQuantityByDateAndLine(ctx, planDate, lineCode) (int64, error)

// COUNT(*) WHERE actual_quantity IS NOT NULL
func (r *DailyProductionPlanRepo) HasPlanForDateAndLine(ctx, planDate, lineCode) (bool, error)
```

### 2.2 StatisticsService 数据源切换

**修复前（错误路径）**：
```
BoxCount   = recordRepo.CountByLineAndDate(lineID, date)        → COUNT(*) FROM TBL_PRODUCTION_RECORD
PieceCount = recordRepo.SumQuantityByLineAndDate(lineID, date)  → SUM(quantity) FROM TBL_PRODUCTION_RECORD
```

**修复后（正确路径）**：
```
BoxCount   = planRepo.SumCartonCountByDateAndLine(date, lineCode)       → SUM(carton_count) FROM TBL_DAILY_PRODUCTION_PLAN WHERE actual_quantity IS NOT NULL
PieceCount = planRepo.SumActualQuantityByDateAndLine(date, lineCode)    → SUM(actual_quantity) FROM TBL_DAILY_PRODUCTION_PLAN WHERE actual_quantity IS NOT NULL
```

### 2.3 保留功能

- `batch_count`：仍从 TBL_PRODUCTION_RECORD 聚合（批次信息属于源系统采集范畴）
- `first_production_at` / `last_production_at`：仍从 TBL_PRODUCTION_RECORD 聚合（时间戳属于采集元数据）
- `shadow_mode` / `quantity_label`：保留不变

### 2.4 代码血缘验证

```
grep -E "CountByLineAndDate|SumQuantityByLineAndDate" statistics_service.go
→ No files found（确认不再引用旧方法）
```

---

## 3. 单元测试结果

### 3.1 测试执行

```
go test ./internal/server/ -run TestDashboard -v -count=1
```

### 3.2 测试结果

| # | 测试名称 | 验证点 | 结果 |
|---|---------|--------|------|
| 1 | TestDashboardBoxCountFromPlan | BoxCount = SUM(carton_count) FROM TBL_DAILY_PRODUCTION_PLAN | **PASS** (BoxCount=17) |
| 2 | TestDashboardPieceCountFromPlan | PieceCount = SUM(actual_quantity) FROM TBL_DAILY_PRODUCTION_PLAN | **PASS** (PieceCount=519) |
| 3 | TestDashboardActualQuantityNullExcluded | actual_quantity=NULL 行被明确排除 | **PASS** (BoxCount=10, PieceCount=300) |
| 4 | TestDashboardMultiplePlansSameDay | 同一天多条生产计划正确 SUM | **PASS** (BoxCount=17, PieceCount=519) |
| 5 | TestDashboardNoProductionRecordPollution | TBL_PRODUCTION_RECORD 不污染 Dashboard | **PASS** (BoxCount=17 not 505, PieceCount=519 not 10970) |
| 6 | TestDashboardEmptyDate | 无数据日期返回 0/0 | **PASS** (BoxCount=0, PieceCount=0) |
| 7 | TestDashboardCartonCountActualQuantityConsistency | carton_count 与 actual_quantity 数据血缘一致 | **PASS** (17*30+9=519) |

### 3.3 总设计师额外要求覆盖

| 要求 | 覆盖测试 | 状态 |
|------|---------|------|
| ① 正常记录→纳入统计 | TestDashboardBoxCountFromPlan + TestDashboardPieceCountFromPlan | ✅ |
| ② actual_quantity=NULL→明确排除 | TestDashboardActualQuantityNullExcluded | ✅ |
| ③ 非法装箱规格→不静默产生错误产量 | TestDashboardActualQuantityNullExcluded（NULL actual_quantity 即无规格） | ✅ |
| ④ 同一天多条生产计划→正确SUM | TestDashboardMultiplePlansSameDay | ✅ |
| ⑤ TBL_PRODUCTION_RECORD变化→Dashboard不变化 | TestDashboardNoProductionRecordPollution | ✅ |
| ⑥ carton_count与actual_quantity数据血缘一致 | TestDashboardCartonCountActualQuantityConsistency | ✅ |

### 3.4 全量回归测试

```
go test ./... -count=1
→ all PASS (collector, server, store)
```

---

## 4. E2E 验证结果

### 4.1 部署信息

- 服务器：192.168.2.110
- 二进制：/opt/hwview/bin/hwview-server (35,771,463 bytes)
- 服务状态：active (running)
- 编译时间：2026-09-08 18:52:53

### 4.2 Dashboard API E2E

#### 2026-09-07（有 row2 + row5 两条实际完成记录）

```
GET /api/v1/statistics/overview?date=2026-09-07
Response:
{
  "total_box_count": 27,       ← SUM(carton_count) = 10(row2) + 17(row5) = 27
  "total_piece_count": 824,    ← SUM(actual_quantity) = 305(row2) + 519(row5) = 824
  "online_line_count": 1,
  "total_line_count": 1
}
```

**对比修复前**：
| 指标 | 修复前（TBL_PRODUCTION_RECORD） | 修复后（TBL_DAILY_PRODUCTION_PLAN） |
|------|-------------------------------|-------------------------------------|
| total_box_count | 30 (COUNT(*) = 30条记录) | 27 (SUM(carton_count) = 10+17) |
| total_piece_count | 510 (SUM(quantity) = 510) | 824 (SUM(actual_quantity) = 305+519) |

✅ 30 和 510 不再出现在 Dashboard 生产统计中

#### 2026-09-06（有 row2 + row3 + row5 三条实际完成记录）

```
GET /api/v1/statistics/overview?date=2026-09-06
Response:
{
  "total_box_count": 66,       ← SUM(carton_count) = 50(row2) + 16(row3) + 0(row5) = 66
  "total_piece_count": 2000,   ← SUM(actual_quantity) = 1500(row2) + 500(row3) + 0(row5) = 2000
}
```

#### 2026-09-08（仅 row5 有 actual_quantity，row1 目标行无 actual_quantity 被排除）

```
GET /api/v1/statistics/overview?date=2026-09-08
Response:
{
  "total_box_count": 17,       ← SUM(carton_count) = 17(row5 only, row1 excluded)
  "total_piece_count": 519     ← SUM(actual_quantity) = 519(row5 only, row1 excluded)
}
```

### 4.3 R4 报表 API 回归

```
GET /api/v1/reports/daily-output-plan?start_date=2026-09-07&end_date=2026-09-07&line_code=HW102
Response:
{
  "matrix": [
    [2000],    // row1: 目标数量老线
    [305],     // row2: 实际完成老线白班
    [null],    // row3: 实际完成老线夜班
    [null],    // row4: 目标数量新线
    [519],     // row5: 实际完成新线
    [824],     // row6: 合计 = 305 + 0 + 519 = 824 ✅
    [null],    // row7: 成品入库
    [null],    // row8: 出货
    [0],       // row9: 成品库存
    [null]     // row10: 产线剩余
  ],
  "reference": {
    "description": "标签补打参考数据（来自TBL_PRODUCTION_RECORD，非生产数量）",
    "per_date": {
      "2026-09-07": {
        "A_records": 30,
        "B_unique_barcodes": 30,
        "D_sum_quantity": 510
      }
    }
  }
}
```

✅ row6 = row2 + row3 + row5 = 305 + 0 + 519 = 824（R4-BLOCKER-02 公式不受影响）
✅ reference 数据正确标注为"标签补打参考数据，非生产数量"

### 4.4 其他端点回归

| 端点 | 状态 |
|------|------|
| GET /api/v1/health | ✅ {"status":"ok"} |
| GET /api/v1/auth/check | ✅ {"auth_enabled":true,"status":"ok"} |

---

## 5. 数据隔离验证

### 5.1 TBL_PRODUCTION_RECORD 不参与 Dashboard 聚合

```
TBL_PRODUCTION_RECORD (2026-09-07):
  COUNT(*) = 30
  SUM(quantity) = 510

Dashboard (2026-09-07):
  total_box_count = 27 (≠ 30)
  total_piece_count = 824 (≠ 510)
```

✅ TBL_PRODUCTION_RECORD 的 COUNT(*) 和 SUM(quantity) 不出现在 Dashboard

### 5.2 TBL_DAILY_PRODUCTION_PLAN 是 Dashboard 唯一数据源

```
TBL_DAILY_PRODUCTION_PLAN (2026-09-07, actual_quantity IS NOT NULL):
  SUM(carton_count) = 10 + 17 = 27
  SUM(actual_quantity) = 305 + 519 = 824

Dashboard (2026-09-07):
  total_box_count = 27 ✅
  total_piece_count = 824 ✅
```

---

## 6. 架构关系

```
修复前（错误）：
  StatisticsService → ProductionRecordRepo → TBL_PRODUCTION_RECORD
  BoxCount   = COUNT(*)
  PieceCount = SUM(quantity)

修复后（正确）：
  StatisticsService → DailyProductionPlanRepo → TBL_DAILY_PRODUCTION_PLAN
  BoxCount   = SUM(carton_count) WHERE actual_quantity IS NOT NULL
  PieceCount = SUM(actual_quantity) WHERE actual_quantity IS NOT NULL

TBL_PRODUCTION_RECORD（源系统采集）
    ↓
  仅作为 reference 数据（report_service.buildReference）
    ↓
  不进入 Dashboard 生产统计
```

---

## 7. Gate Review 提交

### 7.1 Evidence 清单

| Evidence | 状态 |
|----------|------|
| 代码变更（4个文件） | ✅ 完成 |
| 单元测试（7项全 PASS） | ✅ 完成 |
| 全量回归测试（collector/server/store PASS） | ✅ 完成 |
| Dashboard E2E（3个日期验证） | ✅ 完成 |
| R4 报表 API 回归（row6=row2+row3+row5） | ✅ 完成 |
| 数据隔离验证（TBL_PRODUCTION_RECORD 不污染 Dashboard） | ✅ 完成 |
| 代码血缘（不引用旧方法） | ✅ 完成 |

### 7.2 红线遵守确认

| 红线 | 遵守 |
|------|------|
| 不修改 R2-AMENDMENT | ✅ |
| 不修改 actual_quantity 定义 | ✅ |
| 不修改 carton spec 三维模型 | ✅ |
| 不修改 row6 公式 | ✅ |
| 不修改 Production Quantity FROZEN | ✅ |
| 不引入 Jili Fallback | ✅ |
| 不扩大数据源范围 | ✅ |
| 不新增 AI/预测 | ✅ |
| TBL_PRODUCTION_RECORD 保留为 reference | ✅ |

### 7.3 Gate Review 请求

**华为云开发团队已完成 R4-DATA-SEMANTIC-02 编码/测试/E2E 全部工作，提交 Evidence Package 请求大G项目经理 Gate Review。**

**不得自行宣布 R4 FINAL PASS/CLOSED。**