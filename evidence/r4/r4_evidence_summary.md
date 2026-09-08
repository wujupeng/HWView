# EV1-R4 Evidence Summary — 报表增量验收摘要

> 生成日期：2026-09-08
> 服务器：192.168.2.110（hwview-server active，commit 基线 R4-005）
> 覆盖任务：TASK-HWV-EV1-R4-001 ~ R4-005（5 主任务 / 35 子任务）

## 1. R4 验收基准核对表（spec.md §18.10 + R4-BLOCKER 修正项）

| # | 验收项 | 结果 | 证据 |
|---|--------|------|------|
| 1 | 报表命名合规："102日产出计划报表"，非"生产数量报表" | **PASS** | xlsx sheet 名 = "102日产出计划"；sharedStrings 无"生产数量"字样 |
| 2 | 数据来源分离：标签补打数据不进入核心行 | **PASS** | 核心行数据全部来自 TBL_DAILY_PRODUCTION_PLAN（API `daily-plan` 录入）；TBL_PRODUCTION_RECORD 仅出现在 reference 区域（`report_api_response_2days.json` → `reference.per_date`） |
| 3 | 数据分离红线：quantity 不参与核心行计算 | **PASS** | report_service.go `buildReference` 仅输出 A_records/B_unique_barcodes/D_sum_quantity；核心矩阵无 quantity 求和 |
| 4 | R4-BLOCKER-02 合计公式：row6 = row2 + row3 + row5 | **PASS** | E2E：09-07 行6=824=305+0+519；09-08 行6=519=0+0+519；累计 1343=824+519。行4（目标新线）不参与计算 |
| 5 | R4-BLOCKER-02 行4 TARGET 标注 | **PASS** | row_colors 中 row4=green；行4 值独立录入（value 模式），无 CartonDetails |
| 6 | R2-AMENDMENT actual_quantity = carton_count × units_per_carton + loose_quantity | **PASS** | E2E：17×30+9=519；10×30+5=305（report_api_response_2days.json matrix row5/row2） |
| 7 | R4-BLOCKER-01 装箱规格三维适用范围：30 与 60 并存 | **PASS** | carton_spec_response.json：HW102/HW102=30 与 HW102/OTHER=60 同时生效；单测 TestCartonSpec3DQuery PASS |
| 8 | 装箱规格配置化：units_per_carton 非硬编码 | **PASS** | 源码 grep 无 `units_per_carton = 30` 等硬编码常量；units_per_carton 全部来自 TBL_CARTON_SPECIFICATION 快照 |
| 9 | 自动计算行（6/9）禁止手动录入 | **PASS** | 单测 TestAutoCalcRowForbidden PASS；Upsert 对 AutoCalcRows 返回 ErrAutoCalcRowForbidden |
| 10 | Production Quantity FROZEN：核心行不从源系统自动推导 | **PASS** | 核心行仅由 POST /reports/daily-plan 人工录入产生 |

## 2. Excel 导出格式验收（R4-005-02 验收标准第 2 项）

| 检查项 | 结果 |
|--------|------|
| 文件名格式 `102_daily_output_plan_{start}_to_{end}.xlsx`，禁含"生产数量" | **PASS** |
| Sheet 名"102日产出计划" | **PASS** |
| 10 行 × N 列矩阵 + 累计列 | **PASS**（2026-09-07~09-08 双日样本） |
| R2-AMENDMENT 辅助列：箱数 / 装箱规格 / 散件 / 实际件数 | **PASS**（行2: 10/30/5/305；行5: 34/30/18/1038） |
| 颜色编码：目标行绿 #90EE90 / 合计·库存行蓝 #ADD8E6 / 节假日黄 #FFFFE0 | **PASS**（excelize 样式注入） |

## 3. 审计日志验收（spec.md §18.9，R4-005-02 验收标准第 3 项）

`audit_log_sample.json` 共 5 条，覆盖全部四类 action：

| action | target | actor | 说明 |
|--------|--------|-------|------|
| REPORT_INPUT ×2 | DailyProductionPlan 2026-09-08/row5、row1 | admin | 录入（箱数模式 + value 模式各一） |
| HOLIDAY_CONFIG | HolidayCalendar 2026-10-01 | admin | 节假日配置 |
| REPORT_EXPORT ×2 | Report 2026-09-07~2026-09-08 | （匿名 HTTP 触发） | 导出 .xlsx |
| CARTON_SPEC_CONFIG | CartonSpecification | （历史 API 触发） | 装箱规格配置（30/60 并存两条） |

> 备注：REPORT_EXPORT / 部分 CARTON_SPEC_CONFIG 由 curl 直接触发，无认证 actor 字段，生产接入 auth 中间件后自动填充。

## 4. R4 单元测试通过率（R4-004）

| 测试 | 验证点 | 结果 |
|------|--------|------|
| TestCartonSpec3DQuery | 30/60 并存（R4-BLOCKER-01） | PASS |
| TestActualQuantityCalculation | 17×30+9=519（R2-AMENDMENT） | PASS |
| TestAutoCalcRowForbidden | 行6/9 禁止录入（R4-BLOCKER-02） | PASS |
| TestActualQuantityInputRejected | actual_quantity 拒绝外部输入 | PASS |
| TestFormulaRow6 | row6=row2+row3+row5 ≠ row2+3+4+5 | PASS |

`go build ./...` PASS；`go vet ./...` PASS；`go test ./...` 全部包 PASS（2026-09-08）。

## 5. 端到端一致性（预览 ↔ 导出）

- 预览 API `matrix` 与 xlsx 单元格值逐项一致（2000/305/519/824/519/1343）。
- 导出文件：`102_daily_output_plan_2026-09-07_to_2026-09-08.xlsx`（6506 字节）。
- 前端构建产物：`web-dist/`（React 18 + TS Strict + Vite 5，tsc 零错误，143 modules，gzip 88KB）。

## 6. 部署验收（R4-005-01）

| 检查项 | 结果 |
|--------|------|
| 交叉编译 `GOOS=linux GOARCH=amd64 CGO_ENABLED=0`（含 excelize） | PASS（34.9MB） |
| systemd 服务 active | PASS |
| GORM AutoMigrate 自动建表（3 张新表） | PASS（sqlite3 .tables 确认） |
| 健康检查 `/api/v1/health` | PASS {"status":"ok"} |
| 冒烟：报表 API / 装箱规格 API | PASS（HTTP 200） |

## 7. 登录访问与遗留项收口（2026-09-08 第二轮）

| 遗留项 | 状态 | 证据 |
|--------|------|------|
| 登录访问可用 | **PASS** | `POST /api/v1/auth/login`（正确 key→200+token；错误 key→401）；前端 LoginPage + RequireAuth 路由保护 + axios 自动带 X-Admin-Key；nginx 80 端口全链路 |
| 前端 dist 静态部署（nginx） | **PASS** | nginx active，`/var/www/hwview`（index.html+assets），`/api/` 反代 127.0.0.1:8080，SPA try_files 回退 |
| 导出/录入审计 actor 贯通 | **PASS** | 认证开启后所有 report 路由挂 RequireAdmin；审计日志 actor=admin 填充（audit_log_sample.json id≥6） |
| E1-E4 完整业务台账基准 | **PASS** | 2026-09-06 单日：E1 row6累计=2000（1500+500+0）/ E2 row7=1980 / E3 row8=1680 / E4 row9=300（1980-1680 自动计算）；`102_daily_output_plan_baseline_2026-09-06.xlsx` |

认证细节：`auth.enabled=true`，admin_key=`hwview-shadow-deploy`（服务器 /opt/hwview/config/config.yaml）；未认证访问 report API 返回 401。

## 8. Source Semantic 证据链（总设计师 Gate Review 专项）

详见 `source_semantic_evidence_chain.md`。5 个关键问题已回答：

1. "17"来源：人工录入 TBL_DAILY_PRODUCTION_PLAN.carton_count（非源系统自动推导）
2. carton_count 定义：R2-AMENDMENT 业务证据（17箱×30+9=519），人工录入
3. loose_quantity=9 来源：人工录入（源系统无散件字段）
4. 519 是否独立验证：**否**，计算值（Production Quantity FROZEN）
5. 数据边界：标签补打（TBL_PRODUCTION_RECORD）与生产产量（TBL_DAILY_PRODUCTION_PLAN）4 层隔离

**保留的 source semantic ambiguity**：源系统 quantity=17 与人工录入 carton_count=17 数值巧合，系统不自动建立映射；Adapter 层未硬编码 carton_count=quantity。

## 9. R4 First Version Gate Review 提交

| 项目 | 裁决 | 状态 |
|------|------|------|
| R2-AMENDMENT | 🟢 PASS | 已冻结 |
| R4-BLOCKER-01 三维适用范围 | 🟢 PASS | 30/60 并存 |
| R4-BLOCKER-02 行6公式 | 🟢 PASS | row6=row2+row3+row5 |
| Design/Task 一致性 | 🟢 PASS | — |
| Evidence-01 17×30+9=519 | 🟢 PASS | — |
| Evidence-02 30/60按维度选择 | 🟢 PASS | — |
| Evidence-03 row4=TARGET不参与 | 🟢 PASS | — |
| Evidence-04 无全局硬编码 | 🟢 PASS | — |
| Evidence-05 数据不污染 | 🟢 PASS | — |
| Source Semantic 证据链 | 🟢 已提交 | 5 问已答 + 3 项保留歧义 |
| 登录访问全链路 | 🟢 PASS | auth+nginx+前端路由守卫 |
| E1-E4 台账基准 | 🟢 PASS | 单日 ALL PASS |

**建议裁决：R4 First Version = PASS，授权 R4 全量生产化。**

非阻塞备忘：
1. 审计 actor 当前固定为 "admin"（单管理员模式），多用户/角色细分待 EV2。
2. 多日累计列包含混入的历史测试数据（09-07/09-08），生产切换前建议清库或仅录真实台账。
3. 前端登录密钥存 localStorage（单管理员场景可接受），EV2 若引入多用户需升级为会话/token 过期机制。
4. Source semantic ambiguity：源系统 quantity=17 与 carton_count=17 数值巧合，生产中需业务人员确认映射关系。

## 10. R4-DATA-SEMANTIC-02 Dashboard 生产统计语义修复（2026-09-08）

### 修复内容

Dashboard `/statistics/overview` 数据源从 `TBL_PRODUCTION_RECORD` 切换为 `TBL_DAILY_PRODUCTION_PLAN`：
- `BoxCount = SUM(carton_count) WHERE actual_quantity IS NOT NULL`
- `PieceCount = SUM(actual_quantity) WHERE actual_quantity IS NOT NULL`
- `TBL_PRODUCTION_RECORD.quantity` 不再参与 Dashboard 生产统计

### 验证结果

| 日期 | 修复前 box_count | 修复后 box_count | 修复前 piece_count | 修复后 piece_count |
|------|-----------------|-----------------|-------------------|-------------------|
| 2026-09-07 | 30 (COUNT(*)) | 27 (SUM(carton_count)) | 510 (SUM(quantity)) | 824 (SUM(actual_quantity)) |
| 2026-09-08 | 529 (COUNT(*)) | 17 (SUM(carton_count)) | 11,594 (SUM(quantity)) | 519 (SUM(actual_quantity)) |

### 测试覆盖

7 项单元测试全 PASS + 全量回归 22 项全 PASS。详见 `r4_data_semantic_02_final_evidence.md`。

---

## 11. EV1-R4 Final Gate Review 裁决（2026-09-08）

### 总设计师最终裁决

| Gate | 状态 |
|------|------|
| EV1-R1 Real Collection | 🟢 PASS / CLOSED |
| EV1-R2 Business Quantity Semantics | 🟢 PASS / CLOSED |
| EV1-R3 Production Source Discovery | 🟢 PASS / CLOSED |
| EV1-R4 Coding | 🟢 PASS |
| R4-DATA-SEMANTIC-01 | 🟢 PASS |
| R4-DATA-SEMANTIC-02 Design | 🟢 PASS |
| R4-DATA-SEMANTIC-02 Coding/Test/E2E | 🟢 PASS |
| R4 Evidence Closure | 🟢 PASS |
| **EV1-R4 FINAL** | **🟢 FINAL PASS / CLOSED** |

### 最终架构状态

```
TBL_PRODUCTION_RECORD（标签补打 / Source Data）
    ↓ Reference only
    ❌ 不进入 Production Truth

TBL_DAILY_PRODUCTION_PLAN（Production Truth）
    ├── carton_count
    ├── units_per_carton_snapshot
    ├── loose_quantity
    └── actual_quantity = carton_count × units_per_carton + loose_quantity
        ↓
    ├── Dashboard（SUM(carton_count) + SUM(actual_quantity)）
    └── Report（10-row matrix, row6=row2+row3+row5）
```

### 冻结结论

- Jili `/Cron/Jili/lists/` = 标签补打候选数据源，**NOT AUTHORIZED** 作为生产数量源
- Production Quantity FROZEN
- R2-AMENDMENT actual_quantity 公式 FROZEN
- Carton Specification 三维模型 FROZEN
- row6 = row2 + row3 + row5 FROZEN

### Git 提交

- commit `1342cd2`：R4-DATA-SEMANTIC-02 最终变更（7 files, +1285 -9）

**EV1-R4 正式结项。下一阶段（EV1-R5）须等待大G项目经理明确授权，华为云开发团队不得自行跨 Gate。**