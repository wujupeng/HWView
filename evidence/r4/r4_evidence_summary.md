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

## 7. 待 PM 裁决

- **建议裁决：PASS**
- 遗留非阻塞项：
  1. 前端 dist 未部署至 Web 服务器静态目录（仅完成构建验证，生产接入 nginx 时一并完成）。
  2. REPORT_EXPORT 审计 actor 为空（待认证中间件贯通后自动填充）。
  3. 业务台账基准校验（E1=2000/E2=1980/E3=1680/E4=300 全台账）依赖完整 2026-09-06 台账数据录入，当前以 09-07/09-08 真实录入数据（row1=2000/row2=305/row5=519）完成公式级验证。