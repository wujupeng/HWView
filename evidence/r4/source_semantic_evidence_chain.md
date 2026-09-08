# R4 Source Semantic 证据链 — 总设计师 Gate Review 专项

> 生成日期：2026-09-08
> 目的：回答总设计师 R4 First Version Gate Review 提出的 5 个 source semantic 关键问题
> 红线：禁止仅凭单条"17箱"证据静默覆盖历史 /Cron/Jili/lists/ "补打"标签数据源结论

## 0. 历史证据保留声明（不可覆盖）

**R1 实采验证结论（保留）**：
- 源系统 192.168.30.2:86/Cron/Jili/lists/ 是**标签补打记录系统**（华为在线包装系统），不是生产记录系统
- 全部 530 条历史记录操作类型均为"补打"（R1 Evidence）
- TBL_PRODUCTION_RECORD 表无 operation_type 字段，但源系统语义已由 R1/R2 确认为"补打"

**R3 生产数据源探索结论（保留）**：
- 192.168.30.2 上不存在生产数量数据源
- 40+ 端点探索仅发现 /Cron/Jili/lists/（数据）、/Cron/Jili/show（包装扫描UI）、/Cron/Jili/saveSuccess（POST保存）

**Production Quantity FROZEN（保留）**：
- 不能从源系统自动推导生产数量
- 核心行数据仅由人工录入产生

---

## 1. "17"来自哪个真实数据源？

### 1.1 源系统采集数据（TBL_PRODUCTION_RECORD）

```
9月7日：30 条记录，每条 quantity=17，SUM(quantity)=510
全部 535 条历史记录
```

源系统 192.168.30.2:86/Cron/Jili/lists/ → huawei102 adapter → TBL_PRODUCTION_RECORD

### 1.2 人工录入数据（TBL_DAILY_PRODUCTION_PLAN）

```
9月7日 row5：carton_count=17, units_per_carton_snapshot=30, loose_quantity=9, actual_quantity=519
录入方式：POST /api/v1/reports/daily-plan（人工录入，input_by=admin）
```

### 1.3 结论

**"17"有两个来源，语义不同：**

| 来源 | 字段 | 值 | 语义 |
|------|------|---|------|
| 源系统 TBL_PRODUCTION_RECORD | quantity | 17（每条记录） | 每次补打操作补打了 17 个标签（R1 确认：补打记录系统） |
| 人工录入 TBL_DAILY_PRODUCTION_PLAN | carton_count | 17 | 当日共生产 17 箱（R2-AMENDMENT 业务证据） |

**数值巧合警告**：源系统 30 条记录每条 quantity=17，与人工录入 carton_count=17 数值一致，但语义不同。30 条记录共补打 30×17=510 个标签，不是 510 箱。**禁止因数值巧合自动从源系统推导 carton_count。**

---

## 2. 该字段为什么定义为 carton_count？

### 2.1 R2-AMENDMENT 裁决链

1. R1 实采：源系统 quantity=17，初始解释为"补打标签数"
2. R2 业务数量语义确认：A=530(记录数), D=2609(SUM quantity)，均不匹配 E1/E2/E3/E4 业务台账基准
3. R2-AMENDMENT 裁决：引入新业务证据"9月7日 17箱 × 30件/箱 + 9散件 = 519件"，将 quantity 语义修正为 carton_count（整箱数）
4. design.md §3.3.2 记录：`carton_count 来源于源系统 quantity 字段（R2-AMENDMENT 修正语义）或人工录入`

### 2.2 实际实现

- TBL_DAILY_PRODUCTION_PLAN.carton_count 由**人工录入**（POST API），非 Adapter 自动推导
- TBL_PRODUCTION_RECORD.quantity 仍保留原始采集值（补打标签数语义），仅进入 reference 区域
- **Adapter 层未硬编码 carton_count = quantity 的映射**（Production Quantity FROZEN 红线）

### 2.3 结论

carton_count 定义为整箱数，依据是 R2-AMENDMENT 业务证据（17箱×30+9=519），**通过人工录入进入系统**，不是从源系统 quantity 自动推导。源系统 quantity 仍保留原始"补打标签数"语义。

---

## 3. loose_quantity=9 的来源

### 3.1 源系统字段检查

TBL_PRODUCTION_RECORD 表结构：
```
line_id, source_id, product_code, barcode, batch_no, quantity, created_at, production_date, collected_at
```

**源系统无 loose_quantity / 散件字段。**

### 3.2 结论

loose_quantity=9 来源：**人工录入**（POST /api/v1/reports/daily-plan，请求体 loose_quantity=9）。源系统不提供散件数据，散件数由业务人员人工盘点后录入。

---

## 4. 519 是否为独立验证的实际生产数量？

### 4.1 计算链

```
actual_quantity = carton_count × units_per_carton + loose_quantity
              = 17 × 30 + 9
              = 519
```

### 4.2 独立验证？

**否。519 是计算值，非独立验证的生产数量。**

- Production Quantity FROZEN：不能从源系统自动推导生产数量
- 519 依赖于三个人工录入值（carton_count=17, units_per_carton=30, loose_quantity=9）
- 系统不验证 519 与任何独立数据源的一致性
- 519 的业务正确性由录入人员（业务管理员）负责

### 4.3 结论

519 是基于人工录入参数的计算值，**不是从源系统独立验证的生产数量**。这是 Production Quantity FROZEN 红线的直接体现——系统提供计算工具，不提供数据源验证。

---

## 5. label reprint 与 production actual 的数据边界

### 5.1 数据流架构

```
源系统 192.168.30.2:86/Cron/Jili/lists/
    ↓ huawei102 adapter 采集
TBL_PRODUCTION_RECORD（quantity = 补打标签数）
    ↓ report_service.buildReference()
报表 reference 区域（A_records / B_unique_barcodes / D_sum_quantity）
    ✗ 不进入核心行

人工录入 POST /api/v1/reports/daily-plan
    ↓
TBL_DAILY_PRODUCTION_PLAN（carton_count / loose_quantity / actual_quantity）
    ↓ report_service.getReport()
报表核心行 matrix（行1-行10）
```

### 5.2 代码级边界

| 层 | 标签补打数据 | 生产产量数据 |
|----|------------|------------|
| 存储 | TBL_PRODUCTION_RECORD | TBL_DAILY_PRODUCTION_PLAN |
| API | 不直接暴露 | POST/GET /reports/daily-plan |
| 报表 | reference 区域（A/B/D 聚合） | 核心行 matrix（行1-行10） |
| 计算 | 不参与 row6 公式 | row6 = row2 + row3 + row5 |

### 5.3 代码证据

`report_service.go` buildReference()：
```go
// 仅输出 A_records / B_unique_barcodes / D_sum_quantity 到 reference 区域
// 核心行 matrix 不读取 TBL_PRODUCTION_RECORD
```

`report_service.go` getReport()：
```go
// 核心行 matrix 仅从 planMap（TBL_DAILY_PRODUCTION_PLAN）读取
// row6 = row2 + row3 + row5（不包含 reference 数据）
```

### 5.4 结论

标签补打数据（TBL_PRODUCTION_RECORD）与生产产量数据（TBL_DAILY_PRODUCTION_PLAN）在存储、API、报表渲染、公式计算四个层面完全隔离。**标签补打数据不能污染 production actual_quantity。**

---

## 6. Source Semantic Ambularity 声明

### 已消除的歧义
- quantity=17 不再解释为"17 件生产数量"
- quantity=17 不再解释为"17 箱"（源系统语义是补打标签数）
- carton_count=17 明确为人工录入的整箱数

### 保留的歧义（source semantic ambiguity）
1. **源系统 quantity=17 与人工录入 carton_count=17 的数值巧合**：系统不自动建立两者的映射关系，由业务人员判断是否一致
2. **源系统 quantity 的精确业务语义**：R1 确认为"补打标签数"，但每条记录补打 17 个标签的业务含义（17 个标签 = 1 箱？= 17 个产品？）未完全消除
3. **519 的独立验证**：系统不提供与独立数据源的交叉验证

### Adapter 层处理
- huawei102 adapter 采集 quantity 原值存入 TBL_PRODUCTION_RECORD，**不进行语义转换**
- **Adapter 层未硬编码 `carton_count = quantity` 的映射**（遵守 Production Quantity FROZEN）
- 语义转换由人工录入 + R2-AMENDMENT 公式计算完成

---

## 7. 总设计师 5 个 Evidence 对照

| Evidence | 要求 | 结果 |
|----------|------|------|
| Evidence-01 | 17 × 30 + 9 = 519 | **PASS**（actual_quantity=519，TBL_DAILY_PRODUCTION_PLAN 9月7日 row5） |
| Evidence-02 | 装箱规格按 product+line+date 选择，30 与 60 并存 | **PASS**（TBL_CARTON_SPECIFICATION: HW102/HW102=30, HW102/OTHER=60；TestCartonSpec3DQuery PASS） |
| Evidence-03 | row6 = row2 + row3 + row5，row4=TARGET 不参与 | **PASS**（E2E: 824=305+0+519；TestFormulaRow6 PASS） |
| Evidence-04 | 不存在全局硬编码 units_per_carton=30 或 60 | **PASS**（grep 源码无硬编码；units_per_carton 全部来自 TBL_CARTON_SPECIFICATION） |
| Evidence-05 | label reprint 不污染 production actual_quantity | **PASS**（数据边界 4 层隔离，见 §5） |

---

## 8. Gate Review 提交清单

| 项目 | 内容 |
|------|------|
| commit SHA | 2ad6bf8（最新）+ 868144b/9d59c9b/336cf34（前置） |
| 修改文件清单 | internal/auth/middleware.go, internal/server/{server,report_service}.go, internal/store/{daily_production_plan_repo,carton_spec_repo}.go, web/src/{App.tsx,api/client.ts,pages/auth/LoginPage.tsx}, web/index.html, evidence/r4/*, deploy/r4_*.sh |
| 测试结果 | go build PASS / go vet PASS / go test ./... 全 PASS / 5 个 R4 单测 PASS / E2E 全 PASS / E1-E4 基准 ALL PASS |
| Evidence 原始数据 | xlsx 样本（单日+双日+基准）, audit_log_sample.json（13条）, report_api_response.json, carton_spec_response.json, web-dist/ |
| 业务公式验证 | row6=row2+row3+row5 PASS / actual_quantity=carton_count×units_per_carton+loose_quantity PASS / E1-E4 ALL PASS |
| source semantic 证据链 | 本文档（5 个关键问题已回答 + 3 项保留歧义声明） |