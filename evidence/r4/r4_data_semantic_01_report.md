# R4-DATA-SEMANTIC-01 Dashboard 数据血缘核查报告

> 核查日期：2026-09-08
> 裁决来源：总设计师 R4 First Version Gate Review（CONDITIONAL PASS）
> 范围：仅查证据和代码数据血缘，不修改功能，不改变业务模型

## 1. 核查结论

**Dashboard 是 R4 4层隔离之外的第5个漏洞（总设计师判断正确）。**

| 指标 | Dashboard 显示值 | 实际语义 | 正确值（R4） | 结论 |
|------|----------------|---------|------------|------|
| 今日箱数 | 505 | TBL_PRODUCTION_RECORD 记录条数 COUNT(*) | 17（TBL_DAILY_PRODUCTION_PLAN.carton_count SUM） | **🔴 语义错误** |
| 今日总产量 | 10,970 | TBL_PRODUCTION_RECORD SUM(quantity)（补打标签数总和） | 519（TBL_DAILY_PRODUCTION_PLAN.actual_quantity SUM） | **🔴 语义错误** |

验证：10,970 ÷ 505 ≈ 21.72（非任何有效装箱规格），总设计师推算确认。

---

## 2. 精确数据血缘

### 2.1 今日箱数 505 来源

| 层 | 路径 | 字段/公式 |
|----|------|----------|
| 前端 | `OverviewPage.tsx:21` → `data.total_box_count` | `total_box_count` |
| API | `GET /api/v1/statistics/overview?date=2026-09-08` | `OverviewStatsResponse.TotalBoxCount` |
| Service | `statistics_service.go:70` → `resp.TotalBoxCount += stats.BoxCount` | 逐产线累加 |
| Service | `statistics_service.go:80` → `s.recordRepo.CountByLineAndDate(ctx, line.ID, date)` | `BoxCount` |
| Repo | `production_record_repo.go:41-43` → `COUNT(*)` | **记录条数** |
| SQL | `SELECT COUNT(*) FROM TBL_PRODUCTION_RECORD WHERE line_id=2 AND production_date='2026-09-08'` | = 505 |
| 数据表 | **TBL_PRODUCTION_RECORD** | 源系统采集表（非 R4 生产数据表） |
| 参与字段 | 无（COUNT(*) 不引用任何字段） | — |
| 记录数 | 505 条 | 9月8日采集的补打记录 |
| 去重规则 | 无 | — |
| 装箱规格 | 未参与 | — |
| 混入补打记录 | **是**（全部 505 条均为补打记录） | — |

### 2.2 今日总产量 10,970 来源

| 层 | 路径 | 字段/公式 |
|----|------|----------|
| 前端 | `OverviewPage.tsx:17` → `data.total_piece_count` | `total_piece_count` |
| API | `GET /api/v1/statistics/overview?date=2026-09-08` | `OverviewStatsResponse.TotalPieceCount` |
| Service | `statistics_service.go:71` → `resp.TotalPieceCount += stats.PieceCount` | 逐产线累加 |
| Service | `statistics_service.go:84` → `s.recordRepo.SumQuantityByLineAndDate(ctx, line.ID, date)` | `PieceCount` |
| Repo | `production_record_repo.go:49-51` → `COALESCE(SUM(quantity), 0)` | **SUM(quantity)** |
| SQL | `SELECT COALESCE(SUM(quantity), 0) FROM TBL_PRODUCTION_RECORD WHERE line_id=2 AND production_date='2026-09-08'` | = 10,970 |
| 数据表 | **TBL_PRODUCTION_RECORD** | 源系统采集表（非 R4 生产数据表） |
| 参与字段 | `quantity` | 源系统补打标签数（R1 确认语义） |
| 聚合公式 | `SUM(quantity)` | 无装箱规格换算 |
| 记录数 | 505 条 | 同上 |
| 去重规则 | 无 | — |
| 装箱规格 | **未参与** | 无 carton_count × units_per_carton 换算 |
| 混入补打记录 | **是**（全部 505 条均为补打记录） | — |

### 2.3 quantity 分布（9月8日）

| quantity | 记录数 | 小计 |
|----------|--------|------|
| 18 | 60 | 1,080 |
| 19 | 60 | 1,140 |
| 20 | 60 | 1,200 |
| 21 | 60 | 1,260 |
| 22 | 60 | 1,320 |
| 23 | 60 | 1,380 |
| 24 | 60 | 1,440 |
| 25 | 60 | 1,500 |
| 26 | 25 | 650 |
| **合计** | **505** | **10,970** |

---

## 3. R4 正确数据源对比

### 3.1 TBL_DAILY_PRODUCTION_PLAN（R4 人工录入，9月8日）

| row_no | carton_count | units_per_carton | loose_quantity | actual_quantity |
|--------|-------------|-----------------|---------------|----------------|
| 1（目标） | — | — | — | — |
| 5（新线实际） | 17 | 30 | 9 | 519 |

### 3.2 正确聚合值

| 指标 | 正确公式 | 正确值 |
|------|---------|--------|
| 今日箱数 | `SUM(carton_count) FROM TBL_DAILY_PRODUCTION_PLAN WHERE plan_date='2026-09-08' AND actual_quantity IS NOT NULL` | **17** |
| 今日总产量 | `SUM(actual_quantity) FROM TBL_DAILY_PRODUCTION_PLAN WHERE plan_date='2026-09-08' AND actual_quantity IS NOT NULL` | **519** |

---

## 4. 漏洞根因分析

### 4.1 架构图

```
R4 报表路径（已验证 PASS）：
  人工录入 → TBL_DAILY_PRODUCTION_PLAN → report_service → 报表 API/Excel
  ✅ 4层隔离：存储/API/报表/公式

Dashboard 路径（本核查发现漏洞）：
  源系统采集 → TBL_PRODUCTION_RECORD → statistics_service → Dashboard API
  🔴 完全绕过 R4 隔离架构
  🔴 直接使用源系统 quantity（补打标签数语义）
  🔴 BoxCount=COUNT(*) 语义错误（记录数≠箱数）
  🔴 PieceCount=SUM(quantity) 语义错误（补打标签数总和≠生产产量）
```

### 4.2 代码位置

| 文件 | 行号 | 问题 |
|------|------|------|
| `statistics_service.go:80` | `BoxCount = recordRepo.CountByLineAndDate()` | 应从 TBL_DAILY_PRODUCTION_PLAN 聚合 carton_count |
| `statistics_service.go:84` | `PieceCount = recordRepo.SumQuantityByLineAndDate()` | 应从 TBL_DAILY_PRODUCTION_PLAN 聚合 actual_quantity |

### 4.3 历史原因

StatisticsService 是 EV1 主链的一部分（早于 R4），设计时假设 TBL_PRODUCTION_RECORD.quantity 就是生产数量。R2-AMENDMENT 修正了 quantity 语义为"补打标签数"，但 StatisticsService **未同步修正**——这是 R4 增量开发时遗漏的回归点。

---

## 5. 505 与 10,970 的完整解释

### 505 箱
```
505 = COUNT(*) FROM TBL_PRODUCTION_RECORD WHERE production_date='2026-09-08'
    = 9月8日源系统采集的补打记录条数
    ≠ 箱数
```

### 10,970 只
```
10,970 = SUM(quantity) FROM TBL_PRODUCTION_RECORD WHERE production_date='2026-09-08'
       = 60×(18+19+20+21+22+23+24+25) + 25×26
       = 60×172 + 650
       = 10,320 + 650
       = 补打标签数总和
       ≠ 生产产量
```

### 与 505 箱的关系
```
10,970 ÷ 505 ≈ 21.72（非有效装箱规格）
505 × 30 = 15,150 ≠ 10,970
505 × 60 = 30,300 ≠ 10,970
```

**505 和 10,970 使用了不同数据语义**（总设计师判断正确）：505 是记录条数，10,970 是 quantity 求和，两者无箱数×规格的数学关系。

---

## 6. 修复方向（仅建议，本核查不执行修复）

| 修复项 | 当前 | 应改为 |
|--------|------|--------|
| BoxCount 数据源 | TBL_PRODUCTION_RECORD COUNT(*) | TBL_DAILY_PRODUCTION_PLAN SUM(carton_count) |
| PieceCount 数据源 | TBL_PRODUCTION_RECORD SUM(quantity) | TBL_DAILY_PRODUCTION_PLAN SUM(actual_quantity) |
| StatisticsService | 依赖 recordRepo | 依赖 planRepo（新增） |

修复后 Dashboard 应显示：今日箱数=17，今日总产量=519。

---

## 7. Gate 裁决建议

```
R4 First Version = CONDITIONAL PASS（维持总设计师裁决）
R4-DATA-SEMANTIC-01 = PASS（数据血缘已查明，证据完整）
Dashboard 修复 = 新增 Closure Task R4-DATA-SEMANTIC-02（待授权）
```

**本核查未修改任何代码/数据/业务模型，仅提供数据血缘证据。**