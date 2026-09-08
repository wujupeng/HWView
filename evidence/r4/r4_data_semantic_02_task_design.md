# R4-DATA-SEMANTIC-02 Dashboard 生产统计语义修复 — Task/Design

> 来源：总设计师 R4-DATA-SEMANTIC-01 PASS 裁决（2026-09-08）
> 状态：**任务定义阶段（待大G项目经理 Coding Authorization）**
> 约束：在大G项目经理再次授权前，**禁止修改代码**

---

## 1. 任务定义

### TASK-R4-DATA-SEMANTIC-02 Dashboard Production Statistics Semantic Correction

**目标**：修复 Dashboard `/statistics/overview`，使其遵守 R2-AMENDMENT + R4 已冻结的生产数量语义。

### 当前问题（R4-DATA-SEMANTIC-01 已确认）

| 指标 | 当前值 | 当前来源 | 正确值 | 正确来源 |
|------|--------|---------|--------|---------|
| total_box_count | 505 | `COUNT(*) FROM TBL_PRODUCTION_RECORD` | 17 | `SUM(carton_count) FROM TBL_DAILY_PRODUCTION_PLAN` |
| total_piece_count | 10,970 | `SUM(quantity) FROM TBL_PRODUCTION_RECORD` | 519 | `SUM(actual_quantity) FROM TBL_DAILY_PRODUCTION_PLAN` |

**根因**：StatisticsService（EV1 主链组件）直接从 TBL_PRODUCTION_RECORD 聚合，绕过 R4 的 4 层隔离架构。

---

## 2. 修复方案

### 2.1 数据源切换

```
当前路径（错误）：
  StatisticsService → ProductionRecordRepo → TBL_PRODUCTION_RECORD
  BoxCount   = COUNT(*)
  PieceCount = SUM(quantity)

修复后路径（正确）：
  StatisticsService → DailyProductionPlanRepo → TBL_DAILY_PRODUCTION_PLAN
  BoxCount   = SUM(carton_count) WHERE actual_quantity IS NOT NULL
  PieceCount = SUM(actual_quantity) WHERE actual_quantity IS NOT NULL
```

### 2.2 具体修改清单

| 文件 | 修改内容 |
|------|---------|
| `internal/store/daily_production_plan_repo.go` | 新增 `SumCartonCountByDate` 和 `SumActualQuantityByDate` 方法 |
| `internal/server/statistics_service.go` | `computeLineStats` 数据源从 `recordRepo` 切换为 `planRepo`；BoxCount/PieceCount 改用 R4 聚合 |
| `internal/server/server.go` | `NewStatisticsService` 注入 `DailyProductionPlanRepo` |
| `internal/server/statistics_service_test.go`（新增） | 单元测试：验证 BoxCount=SUM(carton_count)、PieceCount=SUM(actual_quantity) |

### 2.3 不修改项（总设计师红线）

```
❌ R2-AMENDMENT
❌ actual_quantity 定义
❌ carton specification 三维模型
❌ row6 = row2 + row3 + row5
❌ Production Quantity FROZEN
❌ Jili 数据源语义
❌ Adapter 架构
❌ 新增 AI/预测
❌ 扩大业务范围
❌ Jili Fallback
```

---

## 3. 修复后 Dashboard 逻辑

### 3.1 聚合公式

```sql
-- 今日箱数
SELECT COALESCE(SUM(carton_count), 0)
FROM TBL_DAILY_PRODUCTION_PLAN
WHERE DATE(plan_date) = ? AND line_code = ? AND actual_quantity IS NOT NULL

-- 今日总产量
SELECT COALESCE(SUM(actual_quantity), 0)
FROM TBL_DAILY_PRODUCTION_PLAN
WHERE DATE(plan_date) = ? AND line_code = ? AND actual_quantity IS NOT NULL
```

### 3.2 架构关系

```
R4 Production Truth（TBL_DAILY_PRODUCTION_PLAN）
    ↓
StatisticsService（修复后）
    ↓
/statistics/overview API
    ↓
Dashboard 前端

TBL_PRODUCTION_RECORD（源系统采集）
    ↓
仅作为 reference 数据（report_service.buildReference）
    ↓
不进入 Dashboard 生产统计
```

### 3.3 保留功能

- `batch_count`：仍从 TBL_PRODUCTION_RECORD 聚合（批次信息属于源系统采集范畴）
- `first_production_at` / `last_production_at`：仍从 TBL_PRODUCTION_RECORD 聚合（时间戳属于采集元数据）
- `online_line_count`：改为基于 TBL_DAILY_PRODUCTION_PLAN 是否有当日记录判断
- `shadow_mode` / `quantity_label`：保留不变

---

## 4. 测试要求

### 4.1 单元测试

| 测试 | 验证点 |
|------|--------|
| TestDashboardBoxCountFromPlan | BoxCount = SUM(carton_count) FROM TBL_DAILY_PRODUCTION_PLAN |
| TestDashboardPieceCountFromPlan | PieceCount = SUM(actual_quantity) FROM TBL_DAILY_PRODUCTION_PLAN |
| TestDashboardNoProductionRecordPollution | TBL_PRODUCTION_RECORD.quantity 不参与 BoxCount/PieceCount |
| TestDashboardEmptyDate | 无数据日期返回 0/0 |

### 4.2 E2E 验证

```
1. 录入 TBL_DAILY_PRODUCTION_PLAN: carton_count=17, actual_quantity=519
2. 采集 TBL_PRODUCTION_RECORD: 505 条记录, SUM(quantity)=10970
3. GET /statistics/overview → total_box_count=17, total_piece_count=519
4. 确认 505 和 10970 不出现在 Dashboard
```

### 4.3 回归测试

- R4 报表 API（row6=row2+row3+row5）不受影响
- E1-E4 台账基准不受影响
- 审计日志不受影响

---

## 5. Evidence 要求

修复完成后必须生成：

| Evidence | 要求 |
|----------|------|
| Dashboard E2E | GET /statistics/overview 返回 total_box_count=17, total_piece_count=519 |
| 数据隔离 | TBL_PRODUCTION_RECORD.quantity 不出现在 Dashboard 聚合链路 |
| 回归 | R4 报表 API + E1-E4 基准 + 审计日志 全部 PASS |
| 代码血缘 | statistics_service.go 不再引用 recordRepo.CountByLineAndDate / SumQuantityByLineAndDate |

---

## 6. 约束与红线

1. **不修改 R2-AMENDMENT 业务模型**
2. **不修改 actual_quantity 定义**
3. **不修改装箱规格三维模型**
4. **不修改 row6 = row2 + row3 + row5 公式**
5. **不修改 Production Quantity FROZEN 规则**
6. **不引入 Jili Fallback**
7. **不扩大数据源范围**
8. **不新增 AI/预测业务**
9. **TBL_PRODUCTION_RECORD 保留为 reference 数据源**
10. **在大G项目经理 Coding Authorization 前，禁止修改代码**

---

## 7. 执行流程

```
R4-DATA-SEMANTIC-01 PASS
    ↓
R4-DATA-SEMANTIC-02 Task/Design（本文档）
    ↓
大G项目经理 Coding Authorization
    ↓
华为云开发团队编码
    ↓
单元测试 + E2E 验证
    ↓
部署 + Dashboard E2E
    ↓
Evidence 提交
    ↓
最终 Gate Review
```

---

## 8. 预期影响

| 组件 | 影响 |
|------|------|
| StatisticsService | 数据源切换（recordRepo → planRepo） |
| Dashboard 前端 | 无代码修改（API 响应结构不变） |
| R4 报表 API | 无影响（独立路径） |
| TBL_PRODUCTION_RECORD | 不再被 Dashboard 引用（仅 report reference 使用） |
| TBL_DAILY_PRODUCTION_PLAN | 新增被 Dashboard 引用 |

**风险等级：低**（数据源切换，不涉及业务模型变更）